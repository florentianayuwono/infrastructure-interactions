# Ingress Configuration

HAProxy / nginx ingress configs for routing to local services.

## Setup

```bash
lxc launch ubuntu:24.04 ingress-controller
lxc exec ingress-controller -- apt update
lxc exec ingress-controller -- apt install -y haproxy
lxc file push haproxy.cfg ingress-controller/etc/haproxy/haproxy.cfg
lxc exec ingress-controller -- systemctl restart haproxy
```

## Services

- `proxy.demo.local` — Squid proxy
- `dns.demo.local` — DNS server
- `monitoring.demo.local` — COS Lite / monitoring

## Files

- `haproxy.cfg` — HAProxy configuration
- `nginx.conf` — Alternative nginx configuration
- `setup-ingress.sh` — Automated setup script
