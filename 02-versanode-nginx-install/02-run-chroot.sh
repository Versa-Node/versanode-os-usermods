#!/bin/bash -e
set -euxo pipefail

# Ensure generator is executable
chmod +x /usr/local/sbin/vncp-nginx-generate || true

# Remove Debian default nginx site to avoid default_server conflicts on :80
rm -f /etc/nginx/sites-enabled/default || true

# Enable services/timers
systemctl enable --now nginx || true
systemctl enable --now vncp-nginx-generate.timer || true
systemctl enable --now vncp-hostname.path || true

# Seed configs once *now* (inside chroot) so nginx validates,
# then nginx will be corrected on first boot by the timer/hostname.path
/usr/local/sbin/vncp-nginx-generate || true
nginx -t && systemctl reload nginx || true
