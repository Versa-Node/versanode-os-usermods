#!/bin/bash -e
set -euxo pipefail

. /etc/os-release

# ---------------------------------------------------------------------------
# 🧩 Add backports (for newer cockpit on Bookworm/Trixie)
# ---------------------------------------------------------------------------
echo "deb http://deb.debian.org/debian ${VERSION_CODENAME}-backports main" \
  > /etc/apt/sources.list.d/backports.list
apt-get update

# ---------------------------------------------------------------------------
# 🧱 Install dependencies for Cockpit and Node build
# ---------------------------------------------------------------------------
apt-get install -y -t "${VERSION_CODENAME}-backports" cockpit
apt-get install -y --no-install-recommends \
  curl ca-certificates make git gettext appstream gnupg

# ---------------------------------------------------------------------------
# 📦 Install Node.js v22.20.0 and npm v10.9.3 from NodeSource
# ---------------------------------------------------------------------------
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs

# Force npm upgrade to v10.9.3 (Node 22 ships ~10.x but ensure pinned)
npm install -g npm@10.9.3

echo "✅ Node.js version: $(node -v)"
echo "✅ npm version: $(npm -v)"

# ---------------------------------------------------------------------------
# 🧹 Optional: trim podman/VM stack (keep chroot clean)
# ---------------------------------------------------------------------------
apt-get -y purge podman cockpit-podman cockpit-machines \
  libvirt-daemon-system libvirt-daemon libvirt-clients \
  qemu-system qemu-utils virt-manager virtinst || true
apt-get -y autoremove --purge || true
apt-get -y clean || true

# ---------------------------------------------------------------------------
# 🧩 Clone plugin
# ---------------------------------------------------------------------------
PLUGIN_CLONE="/root/cockpit-vncp-manager"
rm -rf "$PLUGIN_CLONE" || true
git clone --recursive https://github.com/Versa-Node/versanode-cockpit-vncp-manager "$PLUGIN_CLONE"
cd "$PLUGIN_CLONE"

# ---------------------------------------------------------------------------
# 🧰 Ensure executables and directories exist
# ---------------------------------------------------------------------------
chmod +x build.js node-modules-fix.sh || true
[ -f tools/node-modules ] && chmod +x tools/node-modules || true
mkdir -p po
: > po/LINGUAS

# ---------------------------------------------------------------------------
# 🏗️ Build and install plugin (under /usr/share/cockpit)
# ---------------------------------------------------------------------------
make PREFIX=/usr install

# ---------------------------------------------------------------------------
# ⚙️ Enable cockpit (socket-activated)
# ---------------------------------------------------------------------------
systemctl enable cockpit.socket || true

echo "✅ Cockpit + VNCP Manager build complete with Node $(node -v) / npm $(npm -v)"
