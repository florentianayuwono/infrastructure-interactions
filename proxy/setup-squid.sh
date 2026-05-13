#!/bin/bash
set -e

echo "=== Setting up Squid Proxy ==="

apt-get update
apt-get install -y squid

cp /proxy/squid.conf /etc/squid/squid.conf

systemctl enable squid
systemctl restart squid

echo "Squid proxy running on port 3128"
