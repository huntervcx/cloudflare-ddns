<h1 align="center">cloudflare-ddns</h1>

<p align="center">
  Tiny Dynamic DNS for Cloudflare.<br>
  A ~40-line Bash script and a systemd timer keep an <code>A</code> record pointed at your current public IPv4.
</p>

<p align="center">
  <a href="https://raw.githubusercontent.com/huntervcx/cloudflare-ddns/main/install.sh"><img src="https://img.shields.io/badge/Install-2ea44f?style=for-the-badge&logo=gnubash&logoColor=white" alt="Install"></a>
  <a href="https://raw.githubusercontent.com/huntervcx/cloudflare-ddns/main/uninstall.sh"><img src="https://img.shields.io/badge/Uninstall-d73a49?style=for-the-badge" alt="Uninstall"></a>
  <a href="https://dash.cloudflare.com/profile/api-tokens"><img src="https://img.shields.io/badge/Create_a_token-F38020?style=for-the-badge&logo=cloudflare&logoColor=white" alt="Create a Cloudflare token"></a>
  <a href="README.fr.md"><img src="https://img.shields.io/badge/Fran%C3%A7ais-0055A4?style=for-the-badge" alt="Français"></a>
</p>

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/huntervcx/cloudflare-ddns/main/install.sh | sudo bash
```

The installer asks for the record to keep updated (e.g. `home.example.com`) and a Cloudflare API token, then:

- installs `curl` and `jq` if they are missing (apt);
- finds the zone ID by itself and creates the `A` record if it does not exist;
- stores the token in `/etc/cloudflare-ddns.env` (root only, `chmod 600`);
- installs `/usr/local/bin/cloudflare-ddns` with a systemd service and timer (30 s after boot, then every 5 minutes).

No questions asked:

```bash
curl -fsSL https://raw.githubusercontent.com/huntervcx/cloudflare-ddns/main/install.sh | sudo CF_API_TOKEN='cfat_xxx' CF_RECORD='home.example.com' INTERVAL=10min bash
```

## Cloudflare token

Create an **API Token** limited to the zone, with:

```text
Zone → DNS → Edit
Zone → Zone → Read
```

## Check

```bash
systemctl list-timers cloudflare-ddns.timer
journalctl -fu cloudflare-ddns.service
dig +short home.example.com @1.1.1.1
```

The log shows `home.example.com : 1.2.3.4 -> 203.0.113.42` when the address changes, and `IP unchanged: 203.0.113.42` otherwise.

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/huntervcx/cloudflare-ddns/main/uninstall.sh | sudo bash
```

The DNS record in Cloudflare is left untouched.

## Notes

- IPv4 only. DDNS does not get around NAT or CGNAT: the name will point to your public IP, which does not guarantee that inbound connections work.
- `install.sh` embeds the same script as [`cloudflare-ddns`](cloudflare-ddns), so the one-liner needs nothing else from this repo.
- Piping a script into `sudo bash` means trusting it blindly. Read [`install.sh`](install.sh) first.

## License

[MIT](LICENSE)
