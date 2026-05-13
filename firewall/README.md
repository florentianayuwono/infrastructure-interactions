# Firewall Configuration

Firewall rules for LXD VMs imitating ps7 network isolation.

## Rules

1. Allow SSH (port 22) from host
2. Allow HTTP/HTTPS (ports 80, 443) between VMs
3. Allow proxy port (3128) from VMs to proxy VM
4. Allow DNS (port 53) from VMs to DNS VM
5. Allow inter-VM traffic on demo network
6. Deny all other inbound traffic by default

## Setup

```bash
lxc launch ubuntu:24.04 firewall-test
lxc exec firewall-test -- apt update
lxc exec firewall-test -- apt install -y ufw
lxc file push ufw-rules.sh firewall-test/root/ufw-rules.sh
lxc exec firewall-test -- bash /root/ufw-rules.sh
```

## Files

- `ufw-rules.sh` — UFW rule configuration script
- `iptables-rules.sh` — Alternative iptables-based rules
