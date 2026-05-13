#!/bin/bash
set -e

echo "=== Configuring iptables Firewall ==="

# Flush existing rules
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X

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

# Allow Squid proxy
iptables -A INPUT -p tcp --dport 3128 -j ACCEPT

# Allow DNS
iptables -A INPUT -p tcp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --dport 53 -j ACCEPT

# Allow intra-subnet
iptables -A INPUT -s 10.150.0.0/24 -j ACCEPT

# Allow ICMP
iptables -A INPUT -p icmp -j ACCEPT

# Save rules (Debian/Ubuntu)
if command -v netfilter-persistent &> /dev/null; then
    netfilter-persistent save
fi

echo "iptables configured"
