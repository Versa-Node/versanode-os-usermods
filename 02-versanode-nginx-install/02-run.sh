#!/bin/bash -e
set -euxo pipefail

# Install vncp-nginx-generate script
install -D -m 0755 files/vncp-nginx-generate \
  "${ROOTFS_DIR}/usr/local/sbin/vncp-nginx-generate"

# Install systemd units for vncp-nginx-generate
install -D -m 0644 files/vncp-nginx-generate.timer \
  "${ROOTFS_DIR}/etc/systemd/system/vncp-nginx-generate.timer"
install -D -m 0644 files/vncp-nginx-generate.service \
  "${ROOTFS_DIR}/etc/systemd/system/vncp-nginx-generate.service"

# (Optional) Install hostname watcher if provided
if [ -f files/vncp-hostname.path ]; then
  install -D -m 0644 files/vncp-hostname.path \
    "${ROOTFS_DIR}/etc/systemd/system/vncp-hostname.path"
fi
if [ -f files/vncp-hostname.service ]; then
  install -D -m 0644 files/vncp-hostname.service \
    "${ROOTFS_DIR}/etc/systemd/system/vncp-hostname.service"
fi

# Enable nginx service (will start on boot)
on_chroot <<'EOF'
set -eux
systemctl enable nginx || true
systemctl enable vncp-nginx-generate.timer || true
systemctl enable vncp-hostname.path || true
EOF

# Remove the default nginx site if you don’t want it active
rm -f "${ROOTFS_DIR}/etc/nginx/sites-enabled/default" || true

echo "✅ Installed vncp-nginx-generate + services successfully"
