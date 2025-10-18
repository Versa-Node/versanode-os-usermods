#!/usr/bin/env bash
set -euxo pipefail

# Remove podman/virt stack (if present)
apt-get update
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
make -j"$(nproc)"
make install
cd /root
rm -rf "$PLUGIN_CLONE" || true

# Enable cockpit (socket-activated)
systemctl enable --now cockpit.socket || true
