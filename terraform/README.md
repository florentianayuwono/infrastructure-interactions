# Terraform

Local demo deployment using LXD provider.

## Structure

```
terraform/
├── modules/
│   ├── lxd-vm/         # Reusable LXD VM/container module
│   ├── lxd-proxy/      # Squid proxy deployment
│   ├── lxd-dns/        # BIND9 DNS deployment
│   ├── lxd-ingress/    # HAProxy ingress deployment
│   └── lxd-firewall/   # Firewall rules module
└── deployments/
    └── local-demo/
        ├── backend.tf
        ├── providers.tf
        ├── versions.tf
        ├── variables.tf
        ├── network.tf
        ├── main.tf
        └── outputs.tf
```

## Usage

```bash
cd terraform/deployments/local-demo
terraform init
terraform plan
terraform apply
```
