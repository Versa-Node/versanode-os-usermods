#!/bin/bash -e
set -euxo pipefail

. /etc/os-release

# Backports: newer cockpit on Bookworm/Trixie
echo "deb http://deb.debian.org/debian ${VERSION_CODENAME}-backports main" \
  > /etc/apt/sources.list.d/backports.list
apt-get update

# Core cockpit
apt-get install -y -t "${VERSION_CODENAME}-backports" cockpit

# Build deps
apt-get install -y --no-install-recommends \
  nodejs npm make git gettext appstream ca-certificates

# Optional: keep stack lean (remove if you actually want these)
apt-get -y purge podman cockpit-podman cockpit-machines \
  libvirt-daemon-system libvirt-daemon libvirt-clients \
  qemu-system qemu-utils virt-manager virtinst || true
apt-get -y autoremove --purge || true
apt-get -y clean || true

# Prevent service starts in chroot (quietens avahi/dbus noise)
cat >/usr/sbin/policy-rc.d <<'POLICY'
#!/bin/sh
exit 101
POLICY
chmod +x /usr/sbin/policy-rc.d

# Clone plugin
PLUGIN_CLONE="/root/cockpit-vncp-manager"
rm -rf "$PLUGIN_CLONE" || true
git clone --recursive https://github.com/Versa-Node/versanode-cockpit-vncp-manager "$PLUGIN_CLONE"
cd "$PLUGIN_CLONE"
git submodule sync --recursive
git submodule update --init --recursive

# Ensure executables needed by Makefile are executable
chmod +x build.js node-modules-fix.sh || true
[ -f tools/node-modules ] && chmod +x tools/node-modules || true


# Optional: ensure po dir exists (won’t hurt if empty)
mkdir -p po
: > po/LINGUAS

# Build & install (PREFIX=/usr so cockpit sees it under /usr/share/cockpit)
make PREFIX=/usr install

# Cleanup
cd /
rm -f /usr/sbin/policy-rc.d    # restore normal service start on first boot
rm -rf "$PLUGIN_CLONE" || true

# Enable cockpit (don’t --now in chroot)
systemctl enable cockpit.socket || true
