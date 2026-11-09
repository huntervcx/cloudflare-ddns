#!/usr/bin/env bash
# Removes cloudflare-ddns (script, config with token, systemd units). The DNS record is left untouched.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Error: run as root (sudo)" >&2; exit 1; }
systemctl disable --now cloudflare-ddns.timer 2>/dev/null || true
rm -f /etc/systemd/system/cloudflare-ddns.service /etc/systemd/system/cloudflare-ddns.timer \
      /usr/local/bin/cloudflare-ddns /etc/cloudflare-ddns.env
systemctl daemon-reload
echo "cloudflare-ddns removed (the DNS record in Cloudflare was not touched)."
