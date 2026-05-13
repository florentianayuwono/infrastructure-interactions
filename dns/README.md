# DNS Configuration

Local DNS zones for the demo environment.

## Zones

- `demo.local` — Main demo zone
- `services.demo.local` — Service endpoints
- `infra.demo.local` — Infrastructure endpoints

## Setup

```bash
lxc launch ubuntu:24.04 dns-server
lxc exec dns-server -- apt update
lxc exec dns-server -- apt install -y bind9
lxc file push named.conf.local dns-server/etc/bind/named.conf.local
lxc file push db.demo.local dns-server/etc/bind/db.demo.local
lxc exec dns-server -- systemctl restart bind9
```

## Files

- `named.conf.local` — BIND configuration
- `db.demo.local` — Zone file
- `setup-dns.sh` — Automated setup script
