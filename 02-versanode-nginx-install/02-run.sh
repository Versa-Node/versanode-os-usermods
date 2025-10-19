#!/bin/bash -e
set -euxo pipefail

# ---------------------------------------------------------------------------
# Resolve paths relative to this script (robust in CI)
# ---------------------------------------------------------------------------
: "${ROOTFS_DIR:?ROOTFS_DIR must be set}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILES_DIR="${SCRIPT_DIR}/files"

echo "──────────────────────────────────────────────"
echo "🔧 Starting vncp-nginx installation stage"
echo "📂 ROOTFS_DIR      = ${ROOTFS_DIR}"
echo "📂 SCRIPT_DIR      = ${SCRIPT_DIR}"
echo "📂 FILES_DIR       = ${FILES_DIR}"
echo "📂 pwd             = $(pwd)"
echo "📂 files/ contents:"
ls -la "${FILES_DIR}" || { echo "❌ files/ directory missing at ${FILES_DIR}"; exit 1; }
echo "──────────────────────────────────────────────"

# Sanity checks for required files
[ -f "${FILES_DIR}/vncp-nginx-generate" ] || { echo "❌ Missing ${FILES_DIR}/vncp-nginx-generate"; exit 1; }
# The unit files are optional; we check existence later

# ---------------------------------------------------------------------------
# Ensure destination directories exist
# ---------------------------------------------------------------------------
mkdir -pv \
  "${ROOTFS_DIR}/usr/local/sbin" \
  "${ROOTFS_DIR}/etc/systemd/system" \
  "${ROOTFS_DIR}/etc/nginx/sites-available" \
  "${ROOTFS_DIR}/etc/nginx/sites-enabled"

# ---------------------------------------------------------------------------
# 1) Copy helper script
# ---------------------------------------------------------------------------
echo "⚙️ Installing vncp-nginx-generate helper..."
cp -v "${FILES_DIR}/vncp-nginx-generate" \
      "${ROOTFS_DIR}/usr/local/sbin/vncp-nginx-generate"
chmod 0755 "${ROOTFS_DIR}/usr/local/sbin/vncp-nginx-generate"

# ---------------------------------------------------------------------------
# 2) Copy systemd units (timer + service) if present
# ---------------------------------------------------------------------------
echo "⚙️ Installing systemd units (if provided)..."
if [ -f "${FILES_DIR}/vncp-nginx-generate.timer" ]; then
  cp -v "${FILES_DIR}/vncp-nginx-generate.timer" \
        "${ROOTFS_DIR}/etc/systemd/system/vncp-nginx-generate.timer"
  chmod 0644 "${ROOTFS_DIR}/etc/systemd/system/vncp-nginx-generate.timer"
fi

if [ -f "${FILES_DIR}/vncp-nginx-generate.service" ]; then
  cp -v "${FILES_DIR}/vncp-nginx-generate.service" \
        "${ROOTFS_DIR}/etc/systemd/system/vncp-nginx-generate.service"
  chmod 0644 "${ROOTFS_DIR}/etc/systemd/system/vncp-nginx-generate.service"
fi

# Optional hostname watcher units
if [ -f "${FILES_DIR}/vncp-hostname.path" ]; then
  cp -v "${FILES_DIR}/vncp-hostname.path" \
        "${ROOTFS_DIR}/etc/systemd/system/vncp-hostname.path"
  chmod 0644 "${ROOTFS_DIR}/etc/systemd/system/vncp-hostname.path"
fi

if [ -f "${FILES_DIR}/vncp-hostname.service" ]; then
  cp -v "${FILES_DIR}/vncp-hostname.service" \
        "${ROOTFS_DIR}/etc/systemd/system/vncp-hostname.service"
  chmod 0644 "${ROOTFS_DIR}/etc/systemd/system/vncp-hostname.service"
fi

# ---------------------------------------------------------------------------
# 3) (Optional) nginx site
# ---------------------------------------------------------------------------
if [ -f "${FILES_DIR}/nginx/vncp.conf" ]; then
  echo "🌐 Installing nginx site vncp.conf..."
  cp -v "${FILES_DIR}/nginx/vncp.conf" \
        "${ROOTFS_DIR}/etc/nginx/sites-available/vncp.conf"
  chmod 0644 "${ROOTFS_DIR}/etc/nginx/sites-available/vncp.conf"
  ln -svf ../sites-available/vncp.conf \
        "${ROOTFS_DIR}/etc/nginx/sites-enabled/vncp.conf"
else
  echo "ℹ️ No custom nginx site at ${FILES_DIR}/nginx/vncp.conf (skipping)"
fi

# ---------------------------------------------------------------------------
# 4) Remove default nginx site (if present)
# ---------------------------------------------------------------------------
rm -vf "${ROOTFS_DIR}/etc/nginx/sites-enabled/default" || true

# ---------------------------------------------------------------------------
# 5) In-chroot actions
# ---------------------------------------------------------------------------
on_chroot <<'EOF'
set -eux

export DEBIAN_FRONTEND=noninteractive

# Install nginx if missing
if ! dpkg -s nginx >/dev/null 2>&1; then
  apt-get update
  apt-get install -y --no-install-recommends nginx
fi

# Make systemd aware of the new units and enable them if present
systemctl daemon-reload || true
[ -f /etc/systemd/system/vncp-nginx-generate.timer ] && systemctl enable vncp-nginx-generate.timer || true
[ -f /etc/systemd/system/vncp-nginx-generate.service ] && systemctl enable vncp-nginx-generate.service || true
[ -f /etc/systemd/system/vncp-hostname.path ] && systemctl enable vncp-hostname.path || true
[ -f /etc/systemd/system/vncp-hostname.service ] && systemctl enable vncp-hostname.service || true

systemctl enable nginx || true
EOF

echo "✅ Completed vncp-nginx installation."
