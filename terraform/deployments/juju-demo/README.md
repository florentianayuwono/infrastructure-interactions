# Juju Demo Deployment

This deployment imitates ps7 staging architecture using Juju-based Terraform modules.

## Components

| Module | Purpose | Real ps7 Equivalent |
|--------|---------|-------------------|
| juju-haproxy | HAProxy ingress + DDOS + keepalived | deployments/haproxy/ps7/staging |
| juju-cos | COS-lite monitoring stack | deployments/cos/ps7/staging |
| juju-compute | Sample VM | infrastructure-services compute |
| dns-records | DNS zone definitions | canonical-is-dns-configs |
| firewall-rules | Firewall rules | canonical-is-firewalls |

## Usage

```bash
cd terraform/deployments/juju-demo
terraform init
terraform plan
terraform apply
```

## Notes

- No Vault/AppRole authentication — structural imitation only
- Uses local backend for state
- Juju model: `hackathon-infra-interactions-ps7-staging`
