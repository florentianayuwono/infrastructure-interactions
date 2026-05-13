#!/bin/bash
set -e

echo "=== Configuring UFW Firewall ==="

apt-get update
apt-get install -y ufw

# Default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH
ufw allow 22/tcp

# Allow HTTP/HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Allow Squid proxy
ufw allow 3128/tcp

# Allow DNS
ufw allow 53/tcp
ufw allow 53/udp

# Allow intra-subnet
ufw allow from 10.150.0.0/24

# Allow ICMP
ufw allow proto icmp

# Enable
ufw --force enable

echo "UFW configured"
