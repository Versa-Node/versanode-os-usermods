#!/usr/bin/env bash
set -euxo pipefail
: "${ROOTFS_DIR:?ROOTFS_DIR must be set}"

on_chroot <<'EOF'
set -euxo pipefail

# --- 0) Block service starts only during package install ---
cat >/usr/sbin/policy-rc.d <<'P'
#!/bin/sh
exit 101
P
chmod +x /usr/sbin/policy-rc.d

# --- 1) Install Cockpit + toolchain ---
. /etc/os-release || true
CODENAME="${VERSION_CODENAME:-trixie}"

echo "deb http://deb.debian.org/debian ${CODENAME}-backports main" \
  > /etc/apt/sources.list.d/backports.list || true

apt-get update
if apt-cache policy | grep -q "${CODENAME}-backports"; then
  apt-get install -y -t "${CODENAME}-backports" cockpit || apt-get install -y cockpit
else
  apt-get install -y cockpit
fi

apt-get install -y --no-install-recommends \
  curl ca-certificates git make gettext appstream gnupg jq nodejs npm

# --- 2) Ensure cockpit.socket is enabled on FIRST BOOT ---
# Remove the block BEFORE enabling
rm -f /usr/sbin/policy-rc.d || true

# Use deb-systemd-helper in chroot; avoid systemctl here
if command -v deb-systemd-helper >/dev/null 2>&1; then
  deb-systemd-helper enable cockpit.socket || true
  deb-systemd-helper update-state cockpit.socket || true
else
  mkdir -p /etc/systemd/system/sockets.target.wants
  ln -sf /lib/systemd/system/cockpit.socket \
     /etc/systemd/system/sockets.target.wants/cockpit.socket
fi

# --- 3) Build & install the plugin (files on disk; Cockpit will see them on first run) ---
PLUGIN_DIR="/root/cockpit-vncp-manager"
rm -rf "${PLUGIN_DIR}" || true
git clone https://github.com/Versa-Node/versanode-cockpit-vncp-manager "${PLUGIN_DIR}"
cd "${PLUGIN_DIR}"

git -c submodule.node_modules.update=none submodule update --init --recursive

for f in build.js node-modules-fix.sh tools/node-modules; do
  [ -f "$f" ] || continue
  sed -i 's/\r$//' "$f" || true
  chmod +x "$f" || true
done

make pkg/lib/cockpit-po-plugin.js

[ -f package-lock.json ] || npm install --package-lock-only --ignore-scripts
npm ci --ignore-scripts
bash ./node-modules-fix.sh || true

NODE_ENV=production node ./build.js
test -f dist/manifest.json

mkdir -p po
: > po/LINGUAS

make PREFIX=/usr install

# --- 4) Trim optional stacks & clean ---
apt-get -y purge podman cockpit-podman cockpit-machines \
  libvirt-daemon-system libvirt-daemon libvirt-clients \
  qemu-system qemu-utils virt-manager virtinst || true
apt-get -y autoremove --purge || true

rm -rf "${PLUGIN_DIR}" || true
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "✅ Cockpit plugin build & install completed successfully."
EOF
