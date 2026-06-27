# Memos Deployment Checklist

## Pre-flight

- [ ] LXC container created (proxmox-create)
- [ ] DNS CNAME set (`memos.example.com` → `tls-10-11-99-21.vms.example.net`)
- [ ] Host provisioned (packages, user, ssh hardening)

## Deploy

- [ ] Binary downloaded and extracted
- [ ] Binary installed to `~/bin/memos`
- [ ] `~/bin` added to `~/.config/envman/PATH.env`
- [ ] `serviceman` installed on host
- [ ] Service registered with `--workdir ~/srv/memos`
- [ ] Service running (`systemctl status memos`)

## Post-deploy

- [ ] **Disable user registration** (Settings → System — required for private instances)
- [ ] Internal checks pass (`curl http://localhost:3080`)
- [ ] External checks pass (`curl https://memos.example.com`)
- [ ] Tarball cleaned up from `~/srv/memos/`

## Troubleshooting

If the service won't start:
1. `journalctl -u memos -n 30`
2. Verify `--data` directory exists and is writable
3. Verify port 3080 is not in use (`ss -tlnp | grep 3080`)

If external access fails but internal works:
1. Check DNS CNAME resolves
2. Check TLS router routing (see `tlsrouter` docs)
3. Verify CNAME points to `tls-10-11-99-21.vms.example.net` (not `tcp-...`)
