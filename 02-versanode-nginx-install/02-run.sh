#!/usr/bin/env bash
set -Eeuo pipefail

# -----------------------------------------------------------------------------
# VersaNode OS — vncp-nginx installation (mkcert-enabled, NO DOCKER HERE)
# Copies helpers/units/site, installs nginx(+deps) and mkcert inside chroot,
# prepares TLS dirs, mirrors mkcert CA, enables services, and primes config.
# -----------------------------------------------------------------------------

: "${ROOTFS_DIR:?ROOTFS_DIR must be set}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILES_DIR="${SCRIPT_DIR}/files"

echo "──────────────────────────────────────────────"
echo "🔧 Starting vncp-nginx installation stage (no Docker)"
echo "📂 ROOTFS_DIR      = ${ROOTFS_DIR}"
echo "📂 SCRIPT_DIR      = ${SCRIPT_DIR}"
echo "📂 FILES_DIR       = ${FILES_DIR}"
echo "📂 pwd             = $(pwd)"
echo "📂 files/ contents:"
ls -la "${FILES_DIR}" || { echo "❌ files/ directory missing at ${FILES_DIR}"; exit 1; }
echo "──────────────────────────────────────────────"

# Sanity check
[ -f "${FILES_DIR}/vncp-nginx-generate" ] || { echo "❌ Missing ${FILES_DIR}/vncp-nginx-generate"; exit 1; }

# -----------------------------------------------------------------------------
# Ensure destination directories exist
# -----------------------------------------------------------------------------
mkdir -pv \
  "${ROOTFS_DIR}/usr/local/sbin" \
  "${ROOTFS_DIR}/etc/systemd/system" \
  "${ROOTFS_DIR}/etc/nginx/sites-available" \
  "${ROOTFS_DIR}/etc/nginx/sites-enabled" \
  "${ROOTFS_DIR}/etc/nginx/tls/ca" \
  "${ROOTFS_DIR}/etc/nginx/tls/server" \
  "${ROOTFS_DIR}/etc/cockpit/ws-certs.d" \
  "${ROOTFS_DIR}/etc/default"

# -----------------------------------------------------------------------------
# 1) Copy generator helper
# -----------------------------------------------------------------------------
echo "⚙️ Installing vncp-nginx-generate helper…"
install -m 0755 "${FILES_DIR}/vncp-nginx-generate" \
                 "${ROOTFS_DIR}/usr/local/sbin/vncp-nginx-generate"

# -----------------------------------------------------------------------------
# 2) Copy systemd units (timer/service/hostname watcher) if present
# -----------------------------------------------------------------------------
echo "⚙️ Installing systemd units (if provided)…"
for f in vncp-nginx-generate.timer vncp-nginx-generate.service vncp-hostname.path vncp-hostname.service; do
  if [ -f "${FILES_DIR}/${f}" ]; then
    install -m 0644 "${FILES_DIR}/${f}" "${ROOTFS_DIR}/etc/systemd/system/${f}"
  fi
done

# -----------------------------------------------------------------------------
# 3) (Optional) nginx site
# -----------------------------------------------------------------------------
if [ -f "${FILES_DIR}/nginx/vncp.conf" ]; then
  echo "🌐 Installing nginx site vncp.conf…"
  install -m 0644 "${FILES_DIR}/nginx/vncp.conf" \
                   "${ROOTFS_DIR}/etc/nginx/sites-available/vncp.conf"
  ln -svf ../sites-available/vncp.conf \
          "${ROOTFS_DIR}/etc/nginx/sites-enabled/vncp.conf"
else
  echo "ℹ️ No custom nginx site at ${FILES_DIR}/nginx/vncp.conf (skipping)"
fi

# Remove default site to avoid conflicts
rm -vf "${ROOTFS_DIR}/etc/nginx/sites-enabled/default" || true

# -----------------------------------------------------------------------------
# 4) Provide default environment for the generator (if not supplied)
# -----------------------------------------------------------------------------
DEFAULT_ENV_PATH="${ROOTFS_DIR}/etc/default/vncp-nginx"
if [ ! -f "${DEFAULT_ENV_PATH}" ]; then
  cat > "${DEFAULT_ENV_PATH}" <<'CONF'
# VersaNode Nginx/Cockpit TLS settings (mkcert)
# Adjust these as needed; service loads them on start.
LOCAL_HOSTNAME="versanode.local"
# Comma-separated SANs e.g. DNS:versanode,IP:127.0.0.1,IP:10.0.0.5
EXTRA_SANS="DNS:versanode,IP:127.0.0.1"
RENEW_DAYS="10"
CONF
  chmod 0644 "${DEFAULT_ENV_PATH}"
fi

# -----------------------------------------------------------------------------
# 5) In-chroot actions: install pkgs, TLS prep, enable units, prime once
# -----------------------------------------------------------------------------
on_chroot <<'EOF'
set -eux
export DEBIAN_FRONTEND=noninteractive

# Basic apt hygiene
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl gnupg jq openssl

# ── NGINX: prefer nginx-light; fall back to nginx if not available ───────────
if ! apt-get install -y --no-install-recommends nginx-light; then
  echo "⚠️ nginx-light unavailable, falling back to 'nginx'"
  apt-get install -y --no-install-recommends nginx
fi

# ── mkcert (and NSS tools for cert store integration) ────────────────────────
apt-get install -y --no-install-recommends mkcert libnss3-tools

# ── Ensure TLS dirs exist ────────────────────────────────────────────────────
install -d -m 0755 /etc/nginx/tls/ca /etc/nginx/tls/server /etc/cockpit/ws-certs.d

# ── Mirror mkcert CA to a stable path (handy for field docs) ────────────────
if command -v mkcert >/dev/null 2>&1; then
  CA_ROOT="$(mkcert -CAROOT || true)"
  if [ -n "$CA_ROOT" ] && [ -f "${CA_ROOT}/rootCA.pem" ]; then
    install -m 0644 "${CA_ROOT}/rootCA.pem" /etc/nginx/tls/ca/ca.crt
  fi
fi

# ── Make systemd aware & enable units ────────────────────────────────────────
systemctl daemon-reload || true
[ -f /etc/systemd/system/vncp-nginx-generate.timer ]   && systemctl enable vncp-nginx-generate.timer   || true
[ -f /etc/systemd/system/vncp-nginx-generate.service ] && systemctl enable vncp-nginx-generate.service || true
[ -f /etc/systemd/system/vncp-hostname.path ]          && systemctl enable vncp-hostname.path          || true
[ -f /etc/systemd/system/vncp-hostname.service ]       && systemctl enable vncp-hostname.service       || true
systemctl enable nginx || true

# ── Prime once so image ships with certs/config present (no-op if missing) ──
if [ -x /usr/local/sbin/vncp-nginx-generate ]; then
  /usr/local/sbin/vncp-nginx-generate || true
fi
EOF

echo "✅ Completed vncp-nginx installation."
