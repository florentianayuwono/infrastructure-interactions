# DNS (BIND9)

Imitates internal DNS resolution for ps7 staging hostnames.

## Files

- `db.demo.local` — Zone file with ps7-like records
- `named.conf.local` — BIND9 config
- `setup-dns.sh` — Automated install script

## Usage

```bash
lxc exec dns -- bash /dns/setup-dns.sh
```

## ps7 Patterns Imitated

- Internal domain `.demo.local`
- A records for VMs and services
- CNAME records for ingress endpoints
- Forwarders to external DNS
