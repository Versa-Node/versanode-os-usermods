# PiGen Stage — VNCP HTTPS Edge (maintenance‑free)

This PiGen stage installs:
- **Nginx** with HTTP→HTTPS redirect and a TLS vhost
- **Local CA + per-host server cert** (auto‑renew when <10 days remain)
- **Cockpit** reachable at `https://<hostname>/cockpit/`
- Dynamic reverse proxies via container label `io.versanode.vncp.proxies`
- **Auto reissue** on hostname change and 2‑minute periodic refresh

## Files placed on target
- `/usr/local/sbin/vncp-nginx-generate`
- `/etc/systemd/system/vncp-nginx-generate.service` + `.timer`
- `/etc/systemd/system/vncp-hostname.path` + `.service`
- `/usr/local/bin/install-versa-nginx.sh` (helper, optional)

## Adjustments
Set env vars at build-time or runtime to tune behavior:
- `RENEW_DAYS` (default 10)
- `SRV_DAYS` (default 825)
- `SRV_SANS` (extra SANs, e.g. `DNS:box.lan,IP:10.0.0.12`)
- `LISTEN_ADDR_HTTP`, `LISTEN_ADDR_HTTPS`, `COCKPIT_PORT`

After first boot, open: `https://<hostname>/cockpit/`. Import CA from
`/etc/nginx/tls/ca/ca.crt` on clients for a trusted lock.
