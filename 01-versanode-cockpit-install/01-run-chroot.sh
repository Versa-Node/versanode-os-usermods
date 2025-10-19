#!/bin/bash -e
set -euxo pipefail

. /etc/os-release

# Backports (for newer cockpit on Bookworm/Trixie)
echo "deb http://deb.debian.org/debian ${VERSION_CODENAME}-backports main" \
  > /etc/apt/sources.list.d/backports.list
apt-get update

# 1) Cockpit from backports (no podman/machines)
apt-get install -y -t "${VERSION_CODENAME}-backports" cockpit

# 2) Build deps for the plugin
#    - nodejs, npm: for build.js + node-modules-fix.sh
#    - make, git: build tooling
#    - gettext: msgfmt/xgettext used in i18n targets
#    - appstream (optional): provides appstream-util; Makefile handles "if present"
apt-get install -y --no-install-recommends \
  nodejs npm make git gettext appstream

# Optional: trim podman/VM stacks
apt-get -y purge \
  podman cockpit-podman cockpit-machines \
  libvirt-daemon-system libvirt-daemon libvirt-clients \
  qemu-system qemu-utils virt-manager virtinst || true
apt-get -y autoremove --purge || true
apt-get -y clean || true

# 3) Clone plugin (recursive for submodules)
PLUGIN_CLONE="/root/cockpit-vncp-manager"
rm -rf "$PLUGIN_CLONE" || true
git clone --recursive https://github.com/Versa-Node/versanode-cockpit-vncp-manager "$PLUGIN_CLONE"
cd "$PLUGIN_CLONE"
git submodule sync --recursive
git submodule update --init --recursive

# 4) Make sure helper scripts are executable (just in case)
chmod +x node-modules-fix.sh || true
chmod +x build.js || true
chmod +x tools/node-modules || true

# Diagnostics
node -v
npm -v
command -v msgfmt
command -v xgettext
command -v appstream-util || echo "appstream-util not installed (ok)"
ls -l node-modules-fix.sh build.js tools/node-modules


# 5) Build & install (we are root in chroot; no sudo needed)
make install

# 6) Clean up
cd /
rm -rf "$PLUGIN_CLONE" || true

# 7) Enable cockpit (socket-activated)
systemctl enable --now cockpit.socket || true
