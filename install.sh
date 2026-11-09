#!/usr/bin/env bash
# cloudflare-ddns installer: script + env file + systemd service + timer.
# Interactive:      curl -fsSL https://raw.githubusercontent.com/huntervcx/cloudflare-ddns/main/install.sh | sudo bash
# Non-interactive:  curl -fsSL .../install.sh | sudo CF_API_TOKEN=... CF_RECORD=home.example.com bash
set -euo pipefail

INTERVAL="${INTERVAL:-5min}"
BIN=/usr/local/bin/cloudflare-ddns
ENV_FILE=/etc/cloudflare-ddns.env
UNIT_DIR=/etc/systemd/system

die() { echo "Error: $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run as root (sudo)"
command -v systemctl >/dev/null || die "systemd is required"

# Dependencies
if ! command -v curl >/dev/null || ! command -v jq >/dev/null; then
    command -v apt-get >/dev/null || die "install curl and jq first"
    apt-get update -qq && apt-get install -y -qq curl jq
fi

# Questions (read from the terminal even when piped through curl | bash)
ask() { # ask VAR "prompt" [secret]
    local var=$1 text=$2 secret=${3:-} val
    [ -n "${!var:-}" ] && return
    [ -r /dev/tty ] || die "$var is not set and there is no terminal to ask for it"
    if [ -n "$secret" ]; then read -r -s -p "$text: " val </dev/tty; echo >/dev/tty
    else read -r -p "$text: " val </dev/tty; fi
    [ -n "$val" ] || die "$var is required"
    printf -v "$var" '%s' "$val"
}
ask CF_RECORD "DNS record to update (e.g. home.example.com)"
ask CF_API_TOKEN "Cloudflare API token (Zone:DNS:Edit + Zone:Zone:Read)" secret

AUTH=(-H "Authorization: Bearer $CF_API_TOKEN")
API=https://api.cloudflare.com/client/v4

curl -fsS "${AUTH[@]}" "$API/user/tokens/verify" | jq -e '.success' >/dev/null \
    || die "Cloudflare rejected the API token"

# Find the zone: try the record name, then each parent domain
CF_ZONE_ID=""
candidate=$CF_RECORD
while [[ $candidate == *.* ]]; do
    id=$(curl -fsS "${AUTH[@]}" "$API/zones?name=$candidate" | jq -r '.result[0].id // empty')
    if [ -n "$id" ]; then CF_ZONE_ID=$id; break; fi
    candidate=${candidate#*.}
done
[ -n "$CF_ZONE_ID" ] || die "no Cloudflare zone found for $CF_RECORD (does the token have access to it?)"
echo "Zone: $candidate ($CF_ZONE_ID)"

# Create the A record if it does not exist yet
IP=$(curl -fsS -4 https://api.ipify.org)
existing=$(curl -fsS "${AUTH[@]}" "$API/zones/$CF_ZONE_ID/dns_records?type=A&name=$CF_RECORD" | jq -r '.result[0].id // empty')
if [ -z "$existing" ]; then
    echo "Creating A record $CF_RECORD -> $IP"
    curl -fsS -X POST "${AUTH[@]}" -H "Content-Type: application/json" \
        "$API/zones/$CF_ZONE_ID/dns_records" \
        --data "{\"type\":\"A\",\"name\":\"$CF_RECORD\",\"content\":\"$IP\",\"ttl\":1,\"proxied\":false}" \
        | jq -e '.success' >/dev/null || die "could not create the DNS record"
fi

# Script
cat > "$BIN" <<'SCRIPT'
#!/usr/bin/env bash
# Updates a Cloudflare A record with the current public IPv4 address.
# Config (from /etc/cloudflare-ddns.env via systemd): CF_API_TOKEN, CF_ZONE_ID, CF_RECORD
set -euo pipefail

: "${CF_API_TOKEN:?CF_API_TOKEN is not set}"
: "${CF_ZONE_ID:?CF_ZONE_ID is not set}"
: "${CF_RECORD:?CF_RECORD is not set}"

API="https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records"
AUTH=(-H "Authorization: Bearer $CF_API_TOKEN")

# Current public IPv4
IP=$(curl -fsS -4 https://api.ipify.org)

# Record id + currently published address
RECORD_JSON=$(curl -fsS "${AUTH[@]}" "$API?type=A&name=$CF_RECORD")
RECORD_ID=$(jq -r '.result[0].id // empty' <<<"$RECORD_JSON")
CURRENT=$(jq -r '.result[0].content // empty' <<<"$RECORD_JSON")

if [ -z "$RECORD_ID" ]; then
    echo "Record $CF_RECORD not found"
    exit 1
fi

if [ "$CURRENT" = "$IP" ]; then
    echo "IP unchanged: $IP"
    exit 0
fi

curl -fsS -X PATCH "${AUTH[@]}" \
  -H "Content-Type: application/json" \
  "$API/$RECORD_ID" \
  --data "{\"content\":\"$IP\"}" \
  | jq -e '.success' >/dev/null

echo "$CF_RECORD : $CURRENT -> $IP"
SCRIPT
chmod 700 "$BIN"

# Token + config, readable by root only
umask 077
cat > "$ENV_FILE" <<ENV
CF_API_TOKEN=$CF_API_TOKEN
CF_ZONE_ID=$CF_ZONE_ID
CF_RECORD=$CF_RECORD
ENV
chown root:root "$ENV_FILE"; chmod 600 "$ENV_FILE"

# systemd
cat > "$UNIT_DIR/cloudflare-ddns.service" <<'UNIT'
[Unit]
Description=Cloudflare DDNS updater
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
EnvironmentFile=/etc/cloudflare-ddns.env
ExecStart=/usr/local/bin/cloudflare-ddns
UNIT

cat > "$UNIT_DIR/cloudflare-ddns.timer" <<UNIT
[Unit]
Description=Update Cloudflare DDNS every $INTERVAL

[Timer]
OnBootSec=30s
OnUnitActiveSec=$INTERVAL
Persistent=true

[Install]
WantedBy=timers.target
UNIT

systemctl daemon-reload
systemctl enable --now cloudflare-ddns.timer
systemctl start cloudflare-ddns.service || true

echo
journalctl -u cloudflare-ddns.service -n 3 --no-pager -o cat || true
echo
echo "Done. $CF_RECORD will be checked every $INTERVAL."
echo "  Logs:    journalctl -fu cloudflare-ddns.service"
echo "  Timer:   systemctl list-timers cloudflare-ddns.timer"
echo "  Remove:  curl -fsSL https://raw.githubusercontent.com/huntervcx/cloudflare-ddns/main/uninstall.sh | sudo bash"
