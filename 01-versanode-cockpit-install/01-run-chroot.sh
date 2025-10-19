#!/usr/bin/env bash
set -euxo pipefail

: "${ROOTFS_DIR:?ROOTFS_DIR must be set}"

# Everything below runs inside the target rootfs via pi-gen's on_chroot
on_chroot <<'EOF'
set -euxo pipefail

# --- 0) Prevent service start inside chroot (dbus/avahi noise) ---
cat >/usr/sbin/policy-rc.d <<'P'
#!/bin/sh
exit 101
P
chmod +x /usr/sbin/policy-rc.d

# --- 1) Cockpit from backports if not already present (you already installed base pkgs in packages) ---
. /etc/os-release || true
CODENAME="${VERSION_CODENAME:-bookworm}"

if ! dpkg -s cockpit >/dev/null 2>&1; then
  echo "deb http://deb.debian.org/debian ${CODENAME}-backports main" \
    > /etc/apt/sources.list.d/backports.list
  apt-get update
  apt-get install -y -t "${CODENAME}-backports" cockpit || apt-get install -y cockpit
fi

# --- 2) Node.js 22 + npm 10 inside the chroot (for build only) ---
if ! command -v node >/dev/null 2>&1 || [ "$(node -v | sed 's/^v//;s/\..*//')" -lt 22 ]; then
  # curl, ca-certificates, gnupg already provided by your packages file
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
  npm install -g npm@10.9.3
fi
node -v
npm -v

# --- 3) Fetch & build the plugin inside the chroot ---
PLUGIN_DIR="/root/cockpit-vncp-manager"
rm -rf "${PLUGIN_DIR}" || true
git clone --recursive https://github.com/Versa-Node/versanode-cockpit-vncp-manager "${PLUGIN_DIR}"
cd "${PLUGIN_DIR}"
git submodule sync --recursive
git submodule update --init --recursive

# Normalize line endings and ensure executables (harmless if already fine)
for f in build.js node-modules-fix.sh tools/node-modules; do
  [ -f "$f" ] || continue
  sed -i 's/\r$//' "$f" || true
  chmod +x "$f" || true
done

# Ensure cockpit helper pulled by Makefile exists
make pkg/lib/cockpit-po-plugin.js

# Lockfile + deterministic install
[ -f package-lock.json ] || npm install --package-lock-only --ignore-scripts
npm ci --ignore-scripts

# Run fixer explicitly via bash (avoids shebang/exec-bit issues)
bash ./node-modules-fix.sh

# Build dist expected by Makefile (dist/manifest.json)
NODE_ENV=production node ./build.js
test -f dist/manifest.json

# i18n dir for msgfmt (Makefile uses it)
mkdir -p po
: > po/LINGUAS

# Install under /usr so cockpit finds /usr/share/cockpit/<name>
make PREFIX=/usr install

# --- 4) Trim optional heavy stacks from the image ---
apt-get -y purge podman cockpit-podman cockpit-machines \
  libvirt-daemon-system libvirt-daemon libvirt-clients \
  qemu-system qemu-utils virt-manager virtinst || true
apt-get -y autoremove --purge || true

# --- 5) Enable cockpit (socket-activated) ---
systemctl enable cockpit.socket || true

# --- 6) Cleanup: remove source tree, restore service starts, apt clean ---
rm -rf "${PLUGIN_DIR}" || true
rm -f /usr/sbin/policy-rc.d || true
apt-get clean
rm -rf /var/lib/apt/lists/*
EOF
