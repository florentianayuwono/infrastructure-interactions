#!/bin/bash
set -e

echo "=== Setting up HAProxy Ingress ==="

apt-get update
apt-get install -y haproxy

cp /ingress/haproxy.cfg /etc/haproxy/haproxy.cfg

# Generate self-signed SSL cert for demo
mkdir -p /etc/haproxy/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/haproxy/ssl/demo.key \
    -out /etc/haproxy/ssl/demo.crt \
    -subj "/CN=demo.local" \
    -addext "subjectAltName=DNS:demo.local,DNS:app.demo.local,DNS:grafana.demo.local"

cat /etc/haproxy/ssl/demo.crt /etc/haproxy/ssl/demo.key > /etc/haproxy/ssl/demo.pem

systemctl enable haproxy
systemctl restart haproxy

echo "HAProxy ingress running on ports 80 and 443"
