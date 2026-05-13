# Firewall

Network isolation and access control for LXD VMs.

## Files

- `ufw-rules.sh` — UFW-based firewall rules
- `iptables-rules.sh` — Alternative iptables rules

## ps7 Patterns Imitated

- Default deny incoming
- Allow SSH (22), HTTP (80), HTTPS (443)
- Allow Squid proxy (3128)
- Allow intra-subnet traffic
- Allow DNS (53)
- Allow ICMP (ping)
