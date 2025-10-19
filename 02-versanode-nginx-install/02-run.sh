#!/bin/bash -e
set -euxo pipefail

# ---------------------------------------------------------------------------
# 🧭 Diagnostics: environment overview
# ---------------------------------------------------------------------------
: "${ROOTFS_DIR:?ROOTFS_DIR must be set}"

echo "──────────────────────────────────────────────"
echo "🔧 Starting vncp-nginx installation stage"
echo "📂 ROOTFS_DIR = ${ROOTFS_DIR}"
echo "📂 Current working directory: $(pwd)"
echo "📂 Files available under: $(ls -1 files || true)"
echo "──────────────────────────────────────────────"

# ---------------------------------------------------------------------------
# 🧱 Ensure target directories exist
# ---------------------------------------------------------------------------
echo "📁 Ensuring destination directories exist..."
mkdir -pv \
  "${ROOTFS_DIR}/usr/local/sbin" \
  "${ROOTFS_DIR}/etc/systemd/system" \
  "${ROOTFS_DIR}/etc/nginx/sites-available" \
  "${ROOTFS_DIR}/etc/nginx/sites-enabled"

# ---------------------------------------------------------------------------
# 1️⃣ Install helper script
# ---------------------------------------------------------------------------
echo "⚙️ Installing vncp-nginx-generate helper..."
install -v -D -m 0755 files/vncp-nginx-generate \
  "${ROOTFS_DIR}/usr/local/sbin/vncp-nginx-generate"

# ---------------------------------------------------------------------------
# 2️⃣ Install systemd units (timer + service)
# ---------------------------------------------------------------------------
echo "⚙️ Installing systemd units..."
install -v -D -m 0644 files/vncp-nginx-generate.timer \
  "${ROOTFS_DIR}/etc/systemd/system/vncp-nginx-generate.timer"
install -v -D -m 0644 files/vncp-nginx-generate.service \
  "${ROOTFS_DIR}/etc/systemd/system/vncp-nginx-generate.service"

# Optional hostname watcher units (only if shipped)
if [ -f files/vncp-hostname.path ]; then
  echo "⚙️ Installing vncp-hostname.path..."
  install -v -D -m 0644 files/vncp-hostname.path \
    "${ROOTFS_DIR}/etc/systemd/system/vncp-hostname.path"
fi

if [ -f files/vncp-hostname.service ]; then
  echo "⚙️ Installing vncp-hostname.service..."
  install -v -D -m 0644 files/vncp-hostname.service \
    "${ROOTFS_DIR}/etc/systemd/system/vncp-hostname.service"
fi

# ---------------------------------------------------------------------------
# 3️⃣ (Optional) Ship nginx site and enable it
# ---------------------------------------------------------------------------
if [ -f files/nginx/vncp.conf ]; then
  echo "🌐 Installing nginx site vncp.conf..."
  install -v -D -m 0644 files/nginx/vncp.conf \
    "${ROOTFS_DIR}/etc/nginx/sites-available/vncp.conf"
  ln -svf ../sites-available/vncp.conf \
    "${ROOTFS_DIR}/etc/nginx/sites-enabled/vncp.conf"
else
  echo "ℹ️ No custom nginx site (files/nginx/vncp.conf) provided."
fi

# ---------------------------------------------------------------------------
# 4️⃣ Remove default nginx site (if present)
# ---------------------------------------------------------------------------
if [ -e "${ROOTFS_DIR}/etc/nginx/sites-enabled/default" ]; then
  echo "🧹 Removing default nginx site..."
  rm -vf "${ROOTFS_DIR}/etc/nginx/sites-enabled/default"
else
  echo "ℹ️ Default nginx site not present — skipping removal."
fi

# ---------------------------------------------------------------------------
# 5️⃣ In-chroot actions
# ---------------------------------------------------------------------------
echo "🚀 Entering chroot to finalize setup..."
on_chroot <<'EOF'
set -eux

echo "🔍 Inside chroot environment"
echo "📍 Current hostname: $(hostname)"
echo "📦 Checking nginx installation..."

if ! dpkg -s nginx >/dev/null 2>&1; then
  echo "📦 Installing nginx..."
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y nginx
else
  echo "✅ nginx already installed."
fi

echo "🔁 Reloading systemd daemon..."
systemctl daemon-reload || true

echo "🧩 Enabling units if present..."
[ -f /etc/systemd/system/vncp-nginx-generate.timer ] && systemctl enable vncp-nginx-generate.timer || true
[ -f /etc/systemd/system/vncp-nginx-generate.service ] && systemctl enable vncp-nginx-generate.service || true
[ -f /etc/systemd/system/vncp-hostname.path ] && systemctl enable vncp-hostname.path || true
[ -f /etc/systemd/system/vncp-hostname.service ] && systemctl enable vncp-hostname.service || true

echo "🌐 Enabling nginx service..."
systemctl enable nginx || true

echo "✅ vncp-nginx setup inside chroot completed."
EOF

echo "✅ Completed vncp-nginx installation and diagnostics summary:"
echo "   - Helper script installed in /usr/local/sbin"
echo "   - Systemd units installed in /etc/systemd/system"
echo "   - nginx site installed (if provided)"
echo "──────────────────────────────────────────────"
