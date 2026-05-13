#!/bin/bash
# Setup script for DNS server on LXD VM
# Imitates internal DNS from ps7

set -euo pipefail

echo "=== Setting up DNS Server for Demo ==="

# Update packages
apt-get update
apt-get install -y bind9 bind9utils

# Backup original config
cp /etc/bind/named.conf.local /etc/bind/named.conf.local.bak

# Install zone config
cat > /etc/bind/named.conf.local << 'EOF'
zone "demo.local" {
    type master;
    file "/etc/bind/db.demo.local";
};

zone "65.142.10.in-addr.arpa" {
    type master;
    file "/etc/bind/db.10.142.65";
};

allow-query { 10.142.0.0/16; 127.0.0.1; };

forwarders {
    8.8.8.8;
    8.8.4.4;
};
EOF

# Install zone file
cp /etc/bind/db.demo.local /etc/bind/db.demo.local 2>/dev/null || true

# Create reverse zone file
cat > /etc/bind/db.10.142.65 << 'EOF'
$TTL    604800
@       IN      SOA     ns1.demo.local. admin.demo.local. (
                              1         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      ns1.demo.local.

2       IN      PTR     proxy.demo.local.
3       IN      PTR     dns.demo.local.
4       IN      PTR     ingress.demo.local.
5       IN      PTR     monitoring.demo.local.
EOF

# Set permissions
chown -R bind:bind /etc/bind
chmod 644 /etc/bind/db.*

# Restart BIND
systemctl restart bind9
systemctl enable bind9

echo "=== DNS Server setup complete ==="
echo "DNS running on port 53"
echo "Zone: demo.local"
echo "Nameserver: 10.142.65.3"
