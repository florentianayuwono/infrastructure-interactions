#!/bin/bash
# Quick start script for the entire demo infrastructure

set -euo pipefail

echo "=========================================="
echo "Infrastructure Interactions Demo Setup"
echo "=========================================="
echo ""

# Check prerequisites
command -v lxd >/dev/null 2>&1 || { echo "LXD is required. Install with: sudo snap install lxd"; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo "Terraform is required. See: https://developer.hashicorp.com/terraform/install"; exit 1; }

echo "Step 1: Initialize LXD (if not already done)"
lxd init --auto 2>/dev/null || echo "LXD already initialized"

echo ""
echo "Step 2: Deploy LXD VMs via Terraform"
cd terraform/deployments/local-demo
terraform init
terraform apply -auto-approve
cd ../../..

echo ""
echo "Step 3: Configure Squid Proxy"
lxc file push proxy/squid.conf squid-proxy/etc/squid/squid.conf
lxc exec squid-proxy -- bash -c "apt-get update && apt-get install -y squid && systemctl restart squid"

echo ""
echo "Step 4: Configure DNS"
lxc file push dns/named.conf.local dns-server/etc/bind/named.conf.local
lxc file push dns/db.demo.local dns-server/etc/bind/db.demo.local
lxc exec dns-server -- bash -c "apt-get update && apt-get install -y bind9 && systemctl restart bind9"

echo ""
echo "Step 5: Configure Firewall"
lxc exec squid-proxy -- bash < firewall/ufw-rules.sh
lxc exec dns-server -- bash < firewall/ufw-rules.sh
lxc exec ingress-controller -- bash < firewall/ufw-rules.sh
lxc exec monitoring -- bash < firewall/ufw-rules.sh

echo ""
echo "Step 6: Configure Ingress"
lxc file push ingress/haproxy.cfg ingress-controller/etc/haproxy/haproxy.cfg
lxc exec ingress-controller -- bash -c "apt-get update && apt-get install -y haproxy && systemctl restart haproxy"

echo ""
echo "=========================================="
echo "Demo infrastructure setup complete!"
echo "=========================================="
echo ""
echo "Services:"
echo "  Proxy:      http://10.142.65.2:3128 (proxy.demo.local)"
echo "  DNS:        10.142.65.53 (dns.demo.local)"
echo "  Ingress:    http://10.142.65.4 (ingress.demo.local)"
echo "  Monitoring: http://10.142.65.5 (monitoring.demo.local)"
echo ""
echo "Add to your /etc/hosts:"
echo "  10.142.65.4  proxy.demo.local dns.demo.local ingress.demo.local monitoring.demo.local"
echo ""
