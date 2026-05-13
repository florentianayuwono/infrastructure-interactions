# Local Terraform Deployments

Terraform configs for deploying the demo infrastructure on LXD VMs.

## Structure

```
terraform/
├── modules/
│   ├── lxd-vm/       # Reusable LXD VM module
│   ├── proxy/        # Squid proxy module
│   ├── dns/          # DNS server module
│   ├── firewall/     # Firewall rules module
│   └── ingress/      # HAProxy ingress module
└── deployments/
    └── local-demo/   # Main demo deployment
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── backend.tf
```

## Backend

Local backend (no S3 required):

```hcl
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
```

## Usage

```bash
cd terraform/deployments/local-demo
terraform init
terraform plan
terraform apply
```

## Requirements

- LXD provider for Terraform
- Local LXD initialized
