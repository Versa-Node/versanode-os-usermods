#!/bin/bash -e
on_chroot <<'CHROOT'
set -euxo pipefail

. /etc/os-release
echo "deb http://deb.debian.org/debian ${VERSION_CODENAME}-backports main" > /etc/apt/sources.list.d/backports.list
apt-get update
apt-get install -y -t "${VERSION_CODENAME}-backports" cockpit

# Ensure executables
chmod +x /usr/local/sbin/vncp-nginx-generate || true
chmod +x /usr/local/bin/install-versa-nginx.sh || true

# Enable & start services
systemctl enable docker
systemctl start docker
systemctl enable nginx
systemctl enable cockpit.socket

# Allow default user in docker group
DEFAULT_USER="$(ls /home | head -n1 || true)"
if [ -n "$DEFAULT_USER" ]; then
  groupadd -f docker
  usermod -aG docker "$DEFAULT_USER"
fi

# Enable VNCP components
systemctl daemon-reload
systemctl enable --now vncp-nginx-generate.timer
systemctl enable --now vncp-hostname.path

# Optional firewall
if command -v ufw >/dev/null 2>&1; then
  ufw allow 80/tcp  || true
  ufw allow 443/tcp || true
fi

# Build Cockpit plugin (optional)
PLUGIN_CLONE="/root/cockpit-vncp-manager"
rm -rf "${PLUGIN_CLONE}" || true
git clone https://github.com/Versa-Node/cockpit-vncp-manager "${PLUGIN_CLONE}"
cd "${PLUGIN_CLONE}"
make -j"$(nproc)"
make install
cd /root
rm -rf "${PLUGIN_CLONE}" || true

# Initial seed: certs + nginx confs
/usr/local/sbin/vncp-nginx-generate || true
nginx -t && systemctl reload nginx || true

# Logs for build output
systemctl status --no-pager docker || true
systemctl status --no-pager cockpit.socket || true
systemctl list-timers --all | grep -i vncp || true
CHROOT
