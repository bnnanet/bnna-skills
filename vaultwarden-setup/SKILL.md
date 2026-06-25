---
name: vaultwarden-setup
description: Deploy Vaultwarden (unofficial Bitwarden server) to a remote Alpine host behind a TLS router. Extracts binary from Docker image, installs via scp, registers systemd service via serviceman.
depends: []
---

## Overview

Vaultwarden deployed as a systemd service behind a TLS router.

| Role | Path |
|------|------|
| Binary | `~/bin/vaultwarden` |
| Config | `~/.config/vaultwarden/vaultwarden.env` (dotenv) |
| Data | `~/srv/vaultwarden/data/` (DB, config.json) |
| Web vault | `~/srv/vaultwarden/web-vault/` (static frontend) |

### Key ENVs (in `~/.config/vaultwarden/vaultwarden.env`)

| Variable | Purpose |
|----------|---------|
| `DATABASE_URL` | SQLite DB path |
| `WEB_VAULT_FOLDER` | Frontend directory |
| `DATA_FOLDER` | DB + config storage |
| `ROCKET_ADDRESS` | Bind address (`0.0.0.0`) |
| `ROCKET_PORT` | Port (`3080` for TLS router) |
| `ADMIN_TOKEN` | Admin API auth (random hex string) |

### config.json

Vaultwarden writes `~/srv/vaultwarden/data/config.json` on first run. After that, all settings in `config.json` take precedence over env vars. Manage via admin panel or edit directly.

## Deploy Steps

### 1. Extract binary + web-vault from Docker image

```sh
mkdir -p ./vw-image
cd ./vw-image
curl -LO https://raw.githubusercontent.com/jjlin/docker-image-extract/main/docker-image-extract
chmod +x ./docker-image-extract
./docker-image-extract vaultwarden/server:latest-alpine
```

Output: `./output/vaultwarden` (static ELF x86-64 binary) and `./output/web-vault/` (static frontend).

### 2. Create directories

```sh
HOST=warden.example.com
USER=app

ssh $USER@$HOST 'mkdir -p ~/bin ~/srv/vaultwarden/data ~/.config/vaultwarden'
```

### 3. Install binary on remote host

```sh
HOST=warden.example.com
USER=app

# Atomic rename + scp
ssh $USER@$HOST 'mv ~/bin/vaultwarden ~/bin/vaultwarden.old 2>/dev/null; true'
scp ./output/vaultwarden $USER@$HOST:~/bin/vaultwarden
ssh $USER@$HOST 'chmod +x ~/bin/vaultwarden && ~/bin/vaultwarden --version'
```

### 4. Install web-vault

```sh
scp -r ./output/web-vault $USER@$HOST:~/srv/vaultwarden/web-vault
```

### 5. Create dotenv file

Vaultwarden needs env vars (`WEB_VAULT_FOLDER`, `DATA_FOLDER`, etc.) that aren't stored in `config.json`. Use `dotenv` to load them.

```sh
ssh $USER@$HOST 'cat > ~/.config/vaultwarden/vaultwarden.env << ENVEOF
DATABASE_URL=/home/app/srv/vaultwarden/data/db.sqlite3
ROCKET_ADDRESS=0.0.0.0
ROCKET_PORT=3080
WEB_VAULT_FOLDER=/home/app/srv/vaultwarden/web-vault
DATA_FOLDER=/home/app/srv/vaultwarden/data
ADMIN_TOKEN=YOUR_ADMIN_TOKEN_HERE
ENVEOF'
```

Install dotenv on the remote host if not present:

```sh
ssh $USER@$HOST '. ~/.config/envman/PATH.env && webi dotenv'
```

### 6. Register service with serviceman

```sh
ssh $USER@$HOST '. ~/.config/envman/PATH.env && serviceman add --name vaultwarden -- dotenv -f ~/.config/vaultwarden/vaultwarden.env ~/bin/vaultwarden'
```

Verify:

```sh
ssh $USER@$HOST 'systemctl status vaultwarden --no-pager'
```

### 7. Disable signups

Vaultwarden writes `config.json` on first run. For a private instance, disable public signups:

```sh
ssh $USER@$HOST 'python3 -c "
import json
with open(\"/home/app/srv/vaultwarden/data/config.json\") as f:
    cfg = json.load(f)
cfg[\"signups_allowed\"] = False
with open(\"/home/app/srv/vaultwarden/data/config.json\", \"w\") as f:
    json.dump(cfg, f, indent=2)
print(\"signups_allowed set to false\")
"'
```

Restart the service for the change to take effect:

```sh
ssh $USER@$HOST '. ~/.config/envman/PATH.env && serviceman restart vaultwarden'
```

### 8. Verify

```sh
curl -s -o /dev/null -w "%{http_code}" http://warden.example.com/
# Should return 301 (TLS router redirect) or 200
```

## Manage

```sh
# Restart
ssh $USER@$HOST '. ~/.config/envman/PATH.env && serviceman restart vaultwarden'

# Stop
ssh $USER@$HOST '. ~/.config/envman/PATH.env && serviceman stop vaultwarden'

# Start
ssh $USER@$HOST '. ~/.config/envman/PATH.env && serviceman start vaultwarden'
```

## Admin API

The admin panel API (`/admin/...`) is **undocumented** — reverse-engineered from the Vaultwarden source. It uses cookie-based session auth (not Bearer tokens).

**Two separate APIs:**

| API | Purpose | Auth | Docs |
|-----|---------|------|------|
| `/api/...` | Org management (members, collections, groups, policies) | OAuth2 Bearer token | Official, OAS3 at `/api/docs/` |
| `/admin/...` | Instance admin (users, invite, settings, config) | Session cookie | Undocumented, see `src/api/admin.rs` |

Two-step flow:

### 1. Login (get session cookie)

```sh
VAULTWARDEN_ADMIN_TOKEN=$(cat ~/.config/vaultwarden/vaultwarden.env | grep ADMIN_TOKEN | cut -d= -f2)
curl -c /tmp/vw-cookies.txt -X POST https://warden.example.com/admin \
  -d "token=$VAULTWARDEN_ADMIN_TOKEN&redirect=/admin/users"
```

### 2. Create user

The admin invite endpoint creates the user record + DB invitation but does **not** set a password. The user completes registration via the web vault.

```sh
curl -b /tmp/vw-cookies.txt -X POST https://warden.example.com/admin/invite \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com"}'
```

**Without SMTP:** The invitation is saved to the DB. The user goes to `https://warden.example.com/#/register` with their email — the server finds the pending invitation and lets them set a password.

**With SMTP:** An invite email is sent with a registration link.

The source checks for a pending invitation **before** checking `signups_allowed`, so this works even with signups disabled. If you need a known password, temporarily enable signups, register through the web vault, then disable signups again.

### List users

```sh
curl -b /tmp/vw-cookies.txt https://warden.example.com/admin/users
```

## Troubleshooting

- **Service won't start**: Check `systemctl status vaultwarden` and `journalctl -u vaultwarden -n 30`.
- **Port already in use**: Kill stale processes (`ps aux | grep vaultwarden`).
- **Web vault 404**: Verify `WEB_VAULT_FOLDER` points to a directory containing `index.html`.
- **config.json overrides env**: Vaultwarden persists config to `config.json` on first run. After that, all settings in `config.json` take precedence over env vars. Edit `config.json` or use admin panel for those settings. For private instances, set `signups_allowed` to `false` after first run.
- **dotenv not found**: Install via `webi dotenv` on the remote host.
- **Proxy 4xx kills sessions**: If the server returns 4xx (at least 401/403) on sync, Vaultwarden clients will log out the user. Configure your TLS router/proxy to return 502 or timeout when the Vaultwarden service is unavailable — never 401/403.
