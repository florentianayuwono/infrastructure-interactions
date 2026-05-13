# Infrastructure Interactions Demo

This repository contains a **local demo infrastructure** that imitates Canonical's production ps7 OpenStack environment for hackathon purposes.

## Overview

Instead of deploying to real OpenStack ps7, this demo uses **LXD VMs** running locally to simulate the infrastructure stack.

## Components

| Component | Production (ps7) | Demo (Local) |
|-----------|-----------------|--------------|
| Compute | OpenStack | LXD VMs |
| Proxy | egress.ps7.internal:3128 | Squid Proxy on LXD VM |
| DNS | Internal DNS zones | Local DNS (bind9 or dnsmasq) |
| Storage | S3 (radosgw.ps7.canonical.com) | Local filesystem |
| Auth | Vault + Keystone | Skipped for demo |
| Ingress | HAProxy + Juju | HAProxy or nginx on LXD VM |
| Monitoring | COS Lite | COS Lite or simplified monitoring |

## Structure

```
├── proxy/          # Squid proxy configuration
├── dns/            # DNS zone configurations
├── firewall/       # Firewall rules for LXD VMs
├── ingress/        # HAProxy / nginx ingress configs
├── terraform/      # Local Terraform deployments
│   ├── modules/    # Reusable modules
│   └── deployments/# Demo deployment configs
└── docs/           # Documentation
```

## Quick Start

1. Install LXD: `sudo snap install lxd`
2. Initialize LXD: `lxd init --auto`
3. Deploy VMs: `cd terraform && terraform init && terraform apply`
4. Configure proxy: `cd proxy && ./setup-squid.sh`
5. Configure DNS: `cd dns && ./setup-dns.sh`
6. Configure firewall: `cd firewall && ./setup-firewall.sh`
7. Configure ingress: `cd ingress && ./setup-ingress.sh`

## Requirements

- LXD installed locally
- Terraform >= 1.5
- Local network access (no external cloud required)

## Notes

- This is a **demo/hackathon project** — not production infrastructure
- No Vault, Keystone, or S3 required — all state is local
- Proxy, DNS, firewall, and ingress configurations imitate ps7 patterns but run on LXD VMs

