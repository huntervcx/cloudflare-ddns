<h1 align="center">cloudflare-ddns</h1>

<p align="center">
  Un DDNS Cloudflare minimaliste.<br>
  Un script Bash d'une quarantaine de lignes et un timer systemd gardent un enregistrement <code>A</code> sur ton IPv4 publique actuelle.
</p>

<p align="center">
  <a href="https://raw.githubusercontent.com/huntervcx/cloudflare-ddns/main/install.sh"><img src="https://img.shields.io/badge/Installer-2ea44f?style=for-the-badge&logo=gnubash&logoColor=white" alt="Installer"></a>
  <a href="https://raw.githubusercontent.com/huntervcx/cloudflare-ddns/main/uninstall.sh"><img src="https://img.shields.io/badge/D%C3%A9sinstaller-d73a49?style=for-the-badge" alt="Désinstaller"></a>
  <a href="https://dash.cloudflare.com/profile/api-tokens"><img src="https://img.shields.io/badge/Cr%C3%A9er_un_token-F38020?style=for-the-badge&logo=cloudflare&logoColor=white" alt="Créer un token Cloudflare"></a>
  <a href="README.md"><img src="https://img.shields.io/badge/English-0055A4?style=for-the-badge" alt="English"></a>
</p>

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/huntervcx/cloudflare-ddns/main/install.sh | sudo bash
```

L'installateur demande l'enregistrement à maintenir à jour (par exemple `home.example.com`) et un token API Cloudflare, puis :

- installe `curl` et `jq` s'ils manquent (apt) ;
- retrouve tout seul l'identifiant de la zone et crée l'enregistrement `A` s'il n'existe pas ;
- range le token dans `/etc/cloudflare-ddns.env` (lisible par root uniquement, `chmod 600`) ;
- installe `/usr/local/bin/cloudflare-ddns` avec un service et un timer systemd (30 s après le démarrage, puis toutes les 5 minutes).

Sans aucune question :

```bash
curl -fsSL https://raw.githubusercontent.com/huntervcx/cloudflare-ddns/main/install.sh | sudo CF_API_TOKEN='cfat_xxx' CF_RECORD='home.example.com' INTERVAL=10min bash
```

## Token Cloudflare

Crée un **API Token** limité à la zone concernée, avec :

```text
Zone → DNS → Edit
Zone → Zone → Read
```

## Vérifier

```bash
systemctl list-timers cloudflare-ddns.timer
journalctl -fu cloudflare-ddns.service
dig +short home.example.com @1.1.1.1
```

Les logs affichent `home.example.com : 1.2.3.4 -> 203.0.113.42` quand l'adresse change, et `IP unchanged: 203.0.113.42` sinon.

## Désinstaller

```bash
curl -fsSL https://raw.githubusercontent.com/huntervcx/cloudflare-ddns/main/uninstall.sh | sudo bash
```

L'enregistrement DNS chez Cloudflare n'est pas touché.

## À savoir

- IPv4 uniquement. Un DDNS ne contourne ni le NAT ni le CGNAT : le nom pointera vers ton IP publique, ce qui ne garantit pas que les connexions entrantes passent.
- `install.sh` embarque le même script que [`cloudflare-ddns`](cloudflare-ddns) : la commande en une ligne n'a besoin de rien d'autre dans ce dépôt.
- Envoyer un script dans `sudo bash` revient à lui faire confiance aveuglément. Lis d'abord [`install.sh`](install.sh).

## Licence

[MIT](LICENSE)
