#!/bin/bash
set -e

echo "=== Setting up BIND9 DNS ==="

apt-get update
apt-get install -y bind9 bind9utils

mkdir -p /etc/bind/zones
cp /dns/db.demo.local /etc/bind/zones/db.demo.local
cp /dns/named.conf.local /etc/bind/named.conf.local

cat > /etc/bind/zones/db.10.150.0 << 'EOF'
$TTL    604800
@       IN      SOA     ns.demo.local. admin.demo.local. (
                              1         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      ns.demo.local.
2       IN      PTR     proxy.demo.local.
3       IN      PTR     dns.demo.local.
4       IN      PTR     ingress.demo.local.
5       IN      PTR     monitoring.demo.local.
EOF

chown -R bind:bind /etc/bind/zones

systemctl enable named
systemctl restart named

echo "DNS server running on 10.150.0.3:53"
