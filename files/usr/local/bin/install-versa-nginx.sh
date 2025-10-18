#!/usr/bin/env bash
set -euo pipefail
echo "[install] Installing VNCP nginx generator + systemd units"

install -d /usr/local/sbin
install -m 0755 "$(dirname "$0")/../usr/local/sbin/vncp-nginx-generate" /usr/local/sbin/vncp-nginx-generate

install -d /etc/systemd/system
install -m 0644 "$(dirname "$0")/../etc/systemd/system/vncp-nginx-generate.service" /etc/systemd/system/
install -m 0644 "$(dirname "$0")/../etc/systemd/system/vncp-nginx-generate.timer"   /etc/systemd/system/
install -m 0644 "$(dirname "$0")/../etc/systemd/system/vncp-hostname.service"       /etc/systemd/system/
install -m 0644 "$(dirname "$0")/../etc/systemd/system/vncp-hostname.path"          /etc/systemd/system/

systemctl daemon-reload
systemctl enable --now vncp-nginx-generate.timer
systemctl enable --now vncp-hostname.path

/usr/local/sbin/vncp-nginx-generate
echo "[install] Visit: https://$(hostname)/cockpit/"
echo "[install] CA: /etc/nginx/tls/ca/ca.crt"
