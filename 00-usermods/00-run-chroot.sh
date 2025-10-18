#!/bin/bash -e
on_chroot <<'CHROOT'
set -euxo pipefail

# Enable backports and install Cockpit from backports
. /etc/os-release
echo "deb http://deb.debian.org/debian ${VERSION_CODENAME}-backports main" > /etc/apt/sources.list.d/backports.list
apt-get update
apt-get install -y -t "${VERSION_CODENAME}-backports" cockpit

# Enable cockpit socket (9090)
systemctl enable cockpit.socket

# Optional firewall opening
if command -v ufw >/dev/null 2>&1; then
  ufw allow 9090/tcp || true
fi

# Remove Podman/VM tools & their Cockpit modules if present
apt-get -y purge \
  podman \
  cockpit-podman \
  cockpit-machines \
  libvirt-daemon-system libvirt-daemon libvirt-clients \
  qemu-system qemu-utils virt-manager virtinst || true

apt-get -y autoremove --purge || true
apt-get -y clean || true

# Install plugin: cockpit-vncp-manager
apt-get install -y --no-install-recommends git gettext nodejs make
PLUGIN_CLONE="/root/cockpit-vncp-manager"
rm -rf "${PLUGIN_CLONE}" || true
git clone https://github.com/Versa-Node/cockpit-vncp-manager "${PLUGIN_CLONE}"
cd "${PLUGIN_CLONE}"
make -j"$(nproc)"
make install
cd /root
rm -rf "${PLUGIN_CLONE}" || true

# Show installed cockpit dirs for logging
find /usr/local/share/cockpit -maxdepth 2 -type d -print || true

CHROOT
