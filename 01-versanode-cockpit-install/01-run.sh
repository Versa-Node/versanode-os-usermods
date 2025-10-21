#!/usr/bin/env bash
set -euxo pipefail
: "${ROOTFS_DIR:?ROOTFS_DIR must be set}"

# Write the public GHCR token into the target rootfs
install -d -m 0755 "${ROOTFS_DIR}/etc/versanode"
printf '%s' "${GHCR_READ_PACKAGES_PUBLIC:-}" > "${ROOTFS_DIR}/etc/versanode/github.token"
# World-readable is fine if you truly don't care about leakage; otherwise use 0600
chmod 0644 "${ROOTFS_DIR}/etc/versanode/github.token"

on_chroot <<'EOF'
set -euxo pipefail

# 0) Block service starts during package install
cat >/usr/sbin/policy-rc.d <<'P'
#!/bin/sh
exit 101
P
chmod +x /usr/sbin/policy-rc.d

# Ensure base tools for repo setup/build
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl gnupg git make jq

# Detect codename (default to bookworm for Raspberry Pi OS 12)
. /etc/os-release || true
CODENAME="${VERSION_CODENAME:-bookworm}"

# 1) Install Docker (from Docker's official repo) BEFORE the plugin
install -m 0755 -d /etc/apt/keyrings
# Use tee to avoid odd write issues in some chroots
curl -fsSL https://download.docker.com/linux/debian/gpg | tee /etc/apt/keyrings/docker.asc >/dev/null
chmod 0644 /etc/apt/keyrings/docker.asc

arch="$(dpkg --print-architecture)"   # armhf or arm64
echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian ${CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y --no-install-recommends \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 1a) Add first normal user to 'docker' group so docker works without sudo
getent group docker >/dev/null || groupadd docker || true
VN_USER="$(awk -F: '$3>=1000 && $1!="nobody"{print $1; exit}' /etc/passwd || true)"
[ -n "${VN_USER:-}" ] && usermod -aG docker "$VN_USER" || true

# 2) Install Cockpit + minimal toolchain for plugin build
apt-get install -y --no-install-recommends cockpit nodejs npm

# 3) Enable cockpit.socket for first boot (remove block first)
rm -f /usr/sbin/policy-rc.d || true
if command -v deb-systemd-helper >/dev/null 2>&1; then
  deb-systemd-helper enable cockpit.socket || true
  deb-systemd-helper update-state cockpit.socket || true
else
  mkdir -p /etc/systemd/system/sockets.target.wants
  ln -sf /lib/systemd/system/cockpit.socket \
         /etc/systemd/system/sockets.target.wants/cockpit.socket
fi

# Also enable docker service for first boot; it couldn't start earlier due to policy-rc.d
systemctl enable docker || true

# 4) Build & install the plugin
PLUGIN_DIR="/root/cockpit-vncp-manager"
rm -rf "${PLUGIN_DIR}" || true
git clone https://github.com/Versa-Node/versanode-cockpit-vncp-manager "${PLUGIN_DIR}"
cd "${PLUGIN_DIR}"

# If the repo has submodules, init them; safe to no-op otherwise
git submodule update --init --recursive || true

# Pull Cockpit helper files required for build (per upstream Makefile)
make pkg/lib/cockpit-po-plugin.js

# Deterministic deps + build
[ -f package-lock.json ] || npm install --package-lock-only --ignore-scripts
npm ci --ignore-scripts
NODE_ENV=production node ./build.js
test -f dist/manifest.json

# Install vncp manager plugin
make install

# 5) Cleanup
rm -rf "${PLUGIN_DIR}" || true
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "✅ Docker installed and enabled. Cockpit plugin installed. Will load on first Cockpit session."
EOF
