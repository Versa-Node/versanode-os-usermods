#!/bin/bash -e
on_chroot <<'CHROOT'
set -euxo pipefail

. /etc/os-release
echo "deb http://deb.debian.org/debian ${VERSION_CODENAME}-backports main" > /etc/apt/sources.list.d/backports.list
apt-get update

# Packages
apt-get install -y --no-install-recommends \
  nginx-light docker.io jq git gettext nodejs make
apt-get install -y -t "${VERSION_CODENAME}-backports" cockpit

# Ensure script is executable (shipped via files/)
chmod +x /usr/local/sbin/vncp-nginx-generator.sh

# Enable services
systemctl enable docker
systemctl start docker
systemctl enable nginx || true
systemctl enable cockpit.socket
systemctl enable --now vncp-nginx-generator.timer

# Optional firewall
if command -v ufw >/dev/null 2>&1; then
  ufw allow 80/tcp  || true
  ufw allow 9090/tcp || true
fi

# Remove Podman/VM stacks (ignore if not installed)
apt-get -y purge \
  podman \
  cockpit-podman \
  cockpit-machines \
  libvirt-daemon-system libvirt-daemon libvirt-clients \
  qemu-system qemu-utils virt-manager virtinst || true
apt-get -y autoremove --purge || true
apt-get -y clean || true

# Cockpit plugin: cockpit-vncp-manager
PLUGIN_CLONE="/root/cockpit-vncp-manager"
rm -rf "${PLUGIN_CLONE}" || true
git clone https://github.com/Versa-Node/cockpit-vncp-manager "${PLUGIN_CLONE}"
cd "${PLUGIN_CLONE}"
make -j"$(nproc)"
make install
cd /root
rm -rf "${PLUGIN_CLONE}" || true

# Seed initial config & reload nginx if valid
/usr/local/sbin/vncp-nginx-generator.sh || true
nginx -t && systemctl reload nginx || true

# Logs for build output
systemctl status --no-pager docker || true
systemctl status --no-pager cockpit.socket || true
systemctl list-timers --all | grep -i vncp || true
CHROOT
