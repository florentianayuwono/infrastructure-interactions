#!/bin/bash
# Firewall rules for LXD VMs using UFW
# Imitates ps7 network isolation

set -euo pipefail

echo "=== Setting up Firewall Rules for Demo ==="

# Install UFW if not present
apt-get update
apt-get install -y ufw

# Reset UFW
ufw --force reset

# Default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH from host (LXD bridge)
ufw allow in on eth0 to any port 22

# Allow HTTP/HTTPS between VMs
ufw allow 80/tcp
ufw allow 443/tcp

# Allow proxy port (3128) from VMs
ufw allow from 10.142.0.0/16 to any port 3128 proto tcp

# Allow DNS from VMs
ufw allow from 10.142.0.0/16 to any port 53

# Allow inter-VM traffic on demo network
ufw allow from 10.142.0.0/16

# Allow ping
ufw allow proto icmp

# Enable firewall
ufw --force enable

echo "=== Firewall setup complete ==="
echo "Status:"
ufw status verbose
