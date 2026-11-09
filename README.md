# cloudflare-ddns

[🇫🇷 Version française](README.fr.md)

Tiny Dynamic DNS for Cloudflare: a ~40-line Bash script plus a systemd timer that keeps an `A` record pointing at your current public IPv4.
Un DDNS Cloudflare minimaliste : un script Bash et un timer systemd qui gardent un enregistrement `A` sur ton IPv4 publique actuelle.

## Install / Installation

```bash
curl -fsSL https://raw.githubusercontent.com/huntervcx/cloudflare-ddns/main/install.sh | sudo bash
```

It asks for the record (e.g. `home.example.com`) and a Cloudflare API token, then:

- installs `curl` and `jq` if missing (apt),
- finds the zone ID by itself and creates the `A` record if it does not exist,
- stores the token in `/etc/cloudflare-ddns.env` (root only, `chmod 600`),
- installs `/usr/local/bin/cloudflare-ddns` and a systemd `oneshot` service + timer (30 s after boot, then every 5 min).

Non-interactive / sans questions :

```bash
curl -fsSL https://raw.githubusercontent.com/huntervcx/cloudflare-ddns/main/install.sh | sudo CF_API_TOKEN='cfat_xxx' CF_RECORD='home.example.com' INTERVAL=10min bash
```

## Cloudflare token

Create an **API Token** limited to the one zone, with:

```text
Zone → DNS → Edit
Zone → Zone → Read
```

## Check / Vérifier

```bash
systemctl list-timers cloudflare-ddns.timer
journalctl -fu cloudflare-ddns.service
dig +short home.example.com @1.1.1.1
```

Expected logs / logs attendus : `home.example.com : 1.2.3.4 -> 203.0.113.42` on change, `IP inchangée : 203.0.113.42` otherwise.

## Uninstall / Désinstaller

```bash
curl -fsSL https://raw.githubusercontent.com/huntervcx/cloudflare-ddns/main/uninstall.sh | sudo bash
```

The DNS record in Cloudflare is left untouched.

## Notes

- IPv4 only. DDNS does not get around NAT/CGNAT: the name will point to your public IP, which does not guarantee inbound connections work.
- `install.sh` embeds the same script as [`cloudflare-ddns`](cloudflare-ddns), so the one-liner needs nothing else from the repo.
- Piping a script into `sudo bash` is convenient but blindly trusting: read [`install.sh`](install.sh) first.

Step-by-step explanation / explication pas à pas : https://perrot.pt (article "Configurer un Dynamic DNS Cloudflare sous Debian avec systemd").

## License

MIT
