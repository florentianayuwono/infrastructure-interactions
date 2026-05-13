# Proxy (Squid)

Imitates `egress.ps7.internal:3128` — the HTTP/HTTPS egress proxy used in ps7 staging.

## Files

- `squid.conf` — Squid proxy configuration
- `setup-squid.sh` — Automated install script

## Usage

```bash
lxc exec proxy -- bash /proxy/setup-squid.sh
```

## ps7 Patterns Imitated

- HTTP proxy on port 3128
- ACL restrictions for internal subnets
- Access logging
- Connection limits
