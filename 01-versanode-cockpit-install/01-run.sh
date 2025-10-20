#!/usr/bin/env bash
set -euxo pipefail
: "${ROOTFS_DIR:?ROOTFS_DIR must be set}"

on_chroot <<'EOF'
set -euxo pipefail

# 0) Block service starts during package install
cat >/usr/sbin/policy-rc.d <<'P'
#!/bin/sh
exit 101
P
chmod +x /usr/sbin/policy-rc.d

# 1) Install Cockpit + minimal toolchain for plugin build
. /etc/os-release || true
CODENAME="${VERSION_CODENAME:-bookworm}"

apt-get update
apt-get install -y cockpit git make nodejs npm

# 2) Enable cockpit.socket for first boot (remove block first)
rm -f /usr/sbin/policy-rc.d || true
if command -v deb-systemd-helper >/dev/null 2>&1; then
  deb-systemd-helper enable cockpit.socket || true
  deb-systemd-helper update-state cockpit.socket || true
else
  mkdir -p /etc/systemd/system/sockets.target.wants
  ln -sf /lib/systemd/system/cockpit.socket \
         /etc/systemd/system/sockets.target.wants/cockpit.socket
fi

# 3) Build & install the plugin
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

# Install under /usr/local (preferred for custom plugins)
make PREFIX=/usr/local install

# 4) Clean up
rm -rf "${PLUGIN_DIR}" || true
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "✅ Cockpit plugin installed. Will load on first Cockpit session."
EOF
