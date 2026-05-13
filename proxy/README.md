# Squid Proxy Configuration

Imitates egress.ps7.internal:3128 for the local demo environment.

## Upstream Source

These proxy configurations are based on the canonical proxy configs maintained at:

```
git+ssh://charlie4284@git.launchpad.net/~charlie4284/canonical-is-internal-proxy-configs
```

## Setup

```bash
lxc launch ubuntu:24.04 squid-proxy
lxc exec squid-proxy -- apt update
lxc exec squid-proxy -- apt install -y squid
lxc file push squid.conf squid-proxy/etc/squid/squid.conf
lxc exec squid-proxy -- systemctl restart squid
```

## Configuration

The proxy runs on port 3128 and allows local demo traffic.

## Files

- `squid.conf` — Main Squid configuration
- `setup-squid.sh` — Automated setup script
