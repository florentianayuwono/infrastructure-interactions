#!/bin/bash
# Firewall rules using iptables
# Alternative to UFW for more granular control

set -euo pipefail

echo "=== Setting up iptables Firewall Rules for Demo ==="

# Flush existing rules
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# Default policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT

# Allow established connections
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow SSH
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow HTTP/HTTPS
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Allow proxy (3128) from demo network
iptables -A INPUT -p tcp -s 10.142.0.0/16 --dport 3128 -j ACCEPT

# Allow DNS (53) from demo network
iptables -A INPUT -p udp -s 10.142.0.0/16 --dport 53 -j ACCEPT
iptables -A INPUT -p tcp -s 10.142.0.0/16 --dport 53 -j ACCEPT

# Allow inter-VM traffic
iptables -A INPUT -s 10.142.0.0/16 -j ACCEPT

# Allow ping
iptables -A INPUT -p icmp -j ACCEPT

# Log dropped packets
iptables -A INPUT -j LOG --log-prefix "iptables-dropped: " --log-level 4

# Save rules
iptables-save > /etc/iptables/rules.v4 2>/dev/null || true

echo "=== iptables rules applied ==="
iptables -L -v
