#!/bin/bash -e
set -euxo pipefail

. /etc/os-release

# Backports (for newer cockpit on Bookworm/Trixie)
echo "deb http://deb.debian.org/debian ${VERSION_CODENAME}-backports main" \
  > /etc/apt/sources.list.d/backports.list
apt-get update

# Install cockpit from backports
apt-get install -y -t "${VERSION_CODENAME}-backports" cockpit

# Optional: remove podman/VM stacks
apt-get -y purge \
  podman \
  cockpit-podman \
  cockpit-machines \
  libvirt-daemon-system libvirt-daemon libvirt-clients \
  qemu-system qemu-utils virt-manager virtinst || true
apt-get -y autoremove --purge || true
apt-get -y clean || true

# Build & install your cockpit plugin
PLUGIN_CLONE="/root/cockpit-vncp-manager"
rm -rf "$PLUGIN_CLONE" || true
git clone https://github.com/Versa-Node/cockpit-vncp-manager "$PLUGIN_CLONE"
cd "$PLUGIN_CLONE"
sudo -n make install
cd /root
rm -rf "$PLUGIN_CLONE" || true

# Enable cockpit (socket-activated)
systemctl enable --now cockpit.socket || true
