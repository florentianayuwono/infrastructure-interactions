# K8s Demo Deployment

This deployment imitates the k8s-cos-ps7 pattern from infrastructure-services.

## Components

| Application | Purpose | Real ps7 Equivalent |
|-------------|---------|-------------------|
| kubernetes-control-plane | K8s cluster | k8s-cos-ps7 |
| containerd | Container runtime | k8s worker nodes |
| cos-lite | Monitoring on K8s | k8s-pfe-ps7-cos-staging |

## Usage

```bash
cd terraform/deployments/k8s-demo
terraform init
terraform plan
terraform apply
```

## Model

- Juju model: `k8s-hackathon-ps7-staging`
