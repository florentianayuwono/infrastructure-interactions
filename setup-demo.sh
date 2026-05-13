#!/bin/bash
set -e

echo "=== infrastructure-interactions Demo Setup ==="
echo "This script sets up the local demo environment using Terraform + LXD."

if ! command -v lxd &> /dev/null; then
    echo "Installing LXD..."
    sudo snap install lxd
fi

if ! lxd info &> /dev/null; then
    echo "Initializing LXD..."
    sudo lxd init --auto --network-address=127.0.0.1 --network-port=8443
fi

cd terraform/deployments/local-demo

echo "Initializing Terraform..."
terraform init

echo "Planning deployment..."
terraform plan -out=tfplan

echo "Applying deployment..."
terraform apply tfplan

echo "=== Demo environment ready! ==="
echo "Proxy:     lxc exec proxy -- curl -s http://localhost:3128"
echo "DNS:       lxc exec dns -- dig @localhost app.local"
echo "Ingress:   lxc exec ingress -- curl -s http://localhost:80"
echo "Monitoring:lxc exec monitoring -- curl -s http://localhost:9090"
