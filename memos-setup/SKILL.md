---
name: memos-setup
description: Deploy Memos (open source note-taking service) to a remote Ubuntu host behind a TLS router. Downloads the release binary, installs via scp, registers systemd service via serviceman.
depends: []
---

## Overview

Memos deployed as a systemd service behind a TLS router.

| Role | Path |
|------|------|
| Binary | `~/bin/memos` |
| Data | `~/srv/memos/data/` (SQLite DB) |
| Workdir | `~/srv/memos/` |

### Key Flags

| Flag | Purpose |
|------|---------|
| `--data` | Data directory (SQLite DB path) |
| `--port` | Port (`3080` for TLS router) |
| `--addr` | Bind address (`0.0.0.0`) |

## Deploy Steps

### 1. Provision the host

```sh
./scripts/provision.sh root@memos.example.com
```

This runs dist-upgrade, installs basic tools, sets locale/timezone, installs ssh-utils, creates the `app` user, and disables password SSH login.

### 2. Set up the app skeleton

```sh
./scripts/setup-app.sh app@memos.example.com memos
```

This installs `serviceman` via webi, adds `~/bin` to PATH, and creates `~/bin`, `~/srv/memos`, and `~/.config/memos`.

### 3. Download and deploy

```sh
./scripts/deploy.sh app@memos.example.com
```

This downloads the latest Memos binary (or a specified version), installs it to `~/bin/memos`, registers the systemd service on port 3080, and verifies it's running.

For a specific version:

```sh
./scripts/deploy.sh app@memos.example.com 0.29.1
```

### 4. Disable user registration

Memos allows public registration by default. For a private instance, disable it:

```sh
# Via web UI: Settings → System → "Disallow user registration"
```

### 5. Verify

```sh
# Via TLS router CNAME
curl -s -o /dev/null -w "%{http_code}" https://tls-10-11-99-21.vms.example.net
curl -s -o /dev/null -w "%{http_code}" https://memos.example.com
```

## Manage

```sh
# Restart
ssh app@memos.example.com '. ~/.config/envman/PATH.env && serviceman restart memos'

# Stop
ssh app@memos.example.com '. ~/.config/envman/PATH.env && serviceman stop memos'

# Start
ssh app@memos.example.com '. ~/.config/envman/PATH.env && serviceman start memos'
```

## Troubleshooting

- **Service won't start**: Check `systemctl status memos` and `journalctl -u memos -n 30`.
- **Port already in use**: Kill stale processes (`ps aux | grep memos`).
- **Binary not found**: Ensure `~/bin` is on PATH via `~/.config/envman/PATH.env`.
- **TLS router returns 502**: Memos isn't listening on port 3080. Verify `--port 3080 --addr 0.0.0.0` flags.
- **Public registration enabled**: Memos allows public registration by default. Disable via Settings → System.

## Troubleshooting Checklist

Verify locally first, then externally:

### Internal checks (from the host)

```sh
# Check if memos is listening
curl -s -o /dev/null -w "%{http_code}" http://localhost:3080
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3080
curl -s -o /dev/null -w "%{http_code}" http://10.11.99.21:3080
curl -s -o /dev/null -w "%{http_code}" -H 'Host: memos.example.com' http://10.11.99.21:3080
```

### External checks (from a local machine)

```sh
# Via TLS router CNAME
curl -s -o /dev/null -w "%{http_code}" https://tls-10-11-99-21.vms.example.net
curl -s -o /dev/null -w "%{http_code}" https://memos.example.com
```

If internal checks pass but external fails, the issue is DNS or TLS router routing.
