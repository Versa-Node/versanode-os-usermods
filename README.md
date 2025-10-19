# VersaNode OS – User-level mods Pi-gen stage

<p align="center">
  <!-- Workflows -->
  <a href="https://github.com/Versa-Node/versanode-os/actions/workflows/ci.yml">
    <img src="https://github.com/Versa-Node/versanode-os/actions/workflows/ci.yml/badge.svg?branch=main" alt="CI (lint & sanity)" />
  </a>
  <a href="https://github.com/Versa-Node/versanode-os/actions/workflows/build-release.yml">
    <img src="https://github.com/Versa-Node/versanode-os/actions/workflows/build-release.yml/badge.svg?branch=main" alt="Build & Release (pi-gen)" />
  </a>
  <a href="https://github.com/Versa-Node/versanode-os/actions/workflows/pr-labeler.yml">
    <img src="https://github.com/Versa-Node/versanode-os/actions/workflows/pr-labeler.yml/badge.svg?branch=main" alt="PR Labeler" />
  </a>
  <a href="https://github.com/Versa-Node/versanode-os/actions/workflows/release-drafter.yml">
    <img src="https://github.com/Versa-Node/versanode-os/actions/workflows/release-drafter.yml/badge.svg?branch=main" alt="Release Drafter" />
  </a>
</p>

<p align="center">
  <img src="docs/media/logo-white.png" alt="VersaNode OS logo" width="50%"/>
</p>

---

## 🔧 Overview

The **VersaNode OS User-level Mod Stage** enhances a PiGen-based build with a fully self-contained, secure, and user-accessible management interface.

It provisions:

- 🦺 **Nginx** — with automatic HTTP→HTTPS redirection and TLS vhost support  
- 🔐 **Local CA + per-host server certificate**  
  Automatically issues a mkcert-style TLS certificate signed by a locally trusted CA.  
  Certificates **auto-renew when fewer than 10 days remain** or the hostname changes.  
- 🧭 **Cockpit Dashboard** available at `https://<hostname>/cockpit/`  
- 🔁 **Dynamic reverse proxies** using container labels:  
  `io.versanode.vncp.proxies`
- 🔄 **Auto reissue** and 2-minute periodic refresh service via systemd

---

## 📂 Files Installed on Target

| Path | Description |
|------|--------------|
| `/usr/local/sbin/vncp-nginx-generate` | Core generator for Nginx config and TLS handling |
| `/etc/systemd/system/vncp-nginx-generate.service` | One-shot generation service |
| `/etc/systemd/system/vncp-nginx-generate.timer` | Timer triggering regeneration every 2 minutes |
| `/etc/systemd/system/vncp-hostname.path` | Watches for hostname changes |
| `/etc/systemd/system/vncp-hostname.service` | Regenerates TLS on hostname change |
| `/usr/local/bin/install-versa-nginx.sh` | Optional install helper script |

---

## ⚙️ Configuration Options

You can customize behavior either:
- **At build time** (via PiGen stage environment variables), or
- **At runtime** (by editing `/etc/systemd/system/vncp-nginx-generate.service.d/override.conf`).

| Variable | Default | Description |
|-----------|----------|-------------|
| `RENEW_DAYS` | `10` | Days before expiry to renew the certificate |
| `SRV_DAYS` | `825` | Validity of newly issued server certificates |
| `SRV_SANS` | _(empty)_ | Additional SAN entries, e.g. `DNS:box.lan,IP:10.0.0.12` |
| `LISTEN_ADDR_HTTP` | `80` | HTTP listen port (redirects to HTTPS) |
| `LISTEN_ADDR_HTTPS` | `443` | HTTPS listen port |
| `COCKPIT_PORT` | `9090` | Cockpit web service port |

---

## 🧩 How It Works

1. On boot or hostname change, `vncp-nginx-generate` runs:
   - Ensures a local CA exists at `/etc/nginx/tls/ca/`
   - Generates a per-host certificate signed by that CA
   - Writes Nginx configs under `/etc/nginx/conf.d/`
2. The CA is trusted locally and can be distributed to client systems:
   ```bash
   /etc/nginx/tls/ca/ca.crt
   ```
3. The Cockpit web interface is accessible at:
   ```bash
   https://<hostname>/cockpit/
   ```
4. If the hostname or IP changes, the systemd path triggers a regeneration automatically.

---

## 🧾 Client Trust Setup

To get a trusted HTTPS lock icon:

- Download the CA certificate:
  ```bash
  scp user@versanode.local:/etc/nginx/tls/ca/ca.crt .
  ```
- Import it into your client OS:

| Platform | Instructions |
|-----------|---------------|
| **Windows** | "Manage Computer Certificates" → Trusted Root Certification Authorities → Import |
| **macOS** | Keychain Access → System → Import |
| **Linux** | Copy to `/usr/local/share/ca-certificates/` and run `sudo update-ca-certificates` |
| **Android** | Settings → Security → Install from storage |

---

## 🚀 Access After Boot

Once your VersaNode boots:

1. Navigate to `https://<hostname>/cockpit/`
2. If you haven’t imported the CA, you’ll see a one-time browser warning.
3. After trusting the CA, the Cockpit dashboard will show as **secure**.

---

## 🧱 Troubleshooting

| Issue | Solution |
|--------|-----------|
| Browser shows “Not Secure” | Import `/etc/nginx/tls/ca/ca.crt` on your client |
| Cockpit not loading | Run `sudo systemctl restart cockpit.socket nginx` |
| No reverse proxy rules | Check container label `io.versanode.vncp.proxies` |
| Certificate not updating | Trigger manually: `sudo systemctl start vncp-nginx-generate.service` |

---

## 🧰 Development Notes

This stage is designed for:
- Embedded / edge systems
- VersaNode family of devices
- Fully offline or local deployments

The local CA model avoids dependency on external certificate authorities while maintaining HTTPS integrity and user trust through controlled distribution.

---

## 🪪 License

This project is licensed under the **LGPL-2.1** (same as Cockpit).

© 2025 Versa-Node. All rights reserved.
