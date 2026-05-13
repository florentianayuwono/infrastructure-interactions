#!/bin/bash
# Setup script for Squid proxy on LXD VM
# Imitates egress.ps7.internal:3128

set -euo pipefail

echo "=== Setting up Squid Proxy for Demo ==="

# Update packages
apt-get update
apt-get install -y squid

# Backup original config
cp /etc/squid/squid.conf /etc/squid/squid.conf.bak

# Install demo config
cat > /etc/squid/squid.conf << 'EOF'
# Squid proxy configuration for demo environment
http_port 3128

# Access control - allow local demo network
acl localnet src 10.0.0.0/8
acl localnet src 172.16.0.0/12
acl localnet src 192.168.0.0/16
acl demo_network src 10.142.0.0/16
acl localhost src 127.0.0.1/32

# Safe ports
acl Safe_ports port 80
acl Safe_ports port 443
acl Safe_ports port 3128
acl Safe_ports port 53
acl Safe_ports port 22

# Allow access from demo network
http_access allow demo_network
http_access allow localnet
http_access allow localhost
http_access deny all

# Logging
access_log /var/log/squid/access.log

# Cache settings
cache_dir ufs /var/spool/squid 100 16 256
cache_mem 64 MB

# DNS settings
dns_nameservers 10.142.65.3 8.8.8.8

# Refresh patterns
refresh_pattern ^ftp:           1440    20%     10080
refresh_pattern ^gopher:        1440    0%      1440
refresh_pattern -i (/cgi-bin/|\?) 0     0%      0
refresh_pattern .               0       20%     4320
EOF

# Create cache directory
mkdir -p /var/spool/squid
chown -R proxy:proxy /var/spool/squid

# Restart squid
systemctl restart squid
systemctl enable squid

echo "=== Squid Proxy setup complete ==="
echo "Proxy running on port 3128"
echo "Logs: /var/log/squid/access.log"
