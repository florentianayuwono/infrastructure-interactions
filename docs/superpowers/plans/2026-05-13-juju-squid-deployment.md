# Juju Squid Egress Proxy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `juju-squid` Terraform module deploying the `squid-reverseproxy` charm and wire it into the existing `juju-demo` deployment alongside haproxy and grafana-agent.

**Architecture:** A new self-contained `terraform/modules/juju-squid/` module (mirroring `juju-haproxy/`) deploys one unit of `squid-reverseproxy` on the bare VM Juju model with ACLs matching the demo network. `juju-demo/main.tf` is extended to call this module and integrate squid with the existing grafana-agent for metrics.

**Tech Stack:** Terraform (juju provider), Juju, `squid-reverseproxy` charm (Charmhub), `grafana-agent` charm (existing)

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `terraform/modules/juju-squid/variables.tf` | Create | Input variables for the squid module |
| `terraform/modules/juju-squid/main.tf` | Create | Deploy squid-reverseproxy charm with ACL config |
| `terraform/modules/juju-squid/outputs.tf` | Create | Expose application_name for wiring in parent |
| `terraform/deployments/juju-demo/main.tf` | Modify | Add squid module + grafana-agent integration |

---

## Task 1: Create `juju-squid` module — variables

**Files:**
- Create: `terraform/modules/juju-squid/variables.tf`

- [ ] **Step 1: Create the variables file**

```hcl
# terraform/modules/juju-squid/variables.tf

variable "model_name" {
  description = "Juju model name to deploy squid into"
  type        = string
  default     = "hackathon-infra-interactions-ps7-staging"
}
```

- [ ] **Step 2: Validate HCL syntax**

```bash
cd terraform/modules/juju-squid
terraform init -backend=false 2>&1 | grep -E "Error|Warning|Initialized"
```

Expected: no errors (or "no configuration files" since main.tf doesn't exist yet — that's fine at this step).

- [ ] **Step 3: Commit**

```bash
git add terraform/modules/juju-squid/variables.tf
git commit -m "feat(juju-squid): add module variables"
```

---

## Task 2: Create `juju-squid` module — main deployment

**Files:**
- Create: `terraform/modules/juju-squid/main.tf`

- [ ] **Step 1: Create main.tf**

```hcl
# terraform/modules/juju-squid/main.tf
# Juju-based squid egress proxy deployment
# Imitates the ps7 squid.internal egress proxy
# Upstream firewall source: git+ssh://charlie4284@git.launchpad.net/canonical-is-firewalls
# Upstream proxy source:    git+ssh://charlie4284@git.launchpad.net/~charlie4284/canonical-is-internal-proxy-configs

locals {
  model_name = var.model_name
}

data "juju_model" "demo_model" {
  name = local.model_name
}

resource "juju_application" "squid" {
  name  = "squid"
  model = data.juju_model.demo_model.name

  charm {
    name    = "squid-reverseproxy"
    channel = "latest/stable"
  }

  units = 1

  config = {
    # Port — mirrors defs/ports.yaml: squid: [tcp/3128]
    port = "3128"

    # Allowed source networks — mirrors demo/rules/demo/proxy.yaml:
    #   subnets/demo-network (10.142.0.0/16)
    #   subnets/rfc1918 (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)
    allowed-networks = "10.142.0.0/16 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16"

    # Safe outbound ports — mirrors upstream rules/is/squid.yaml allowed ports:
    #   ftp (21), http (80), https (443), matrix-federation (8448)
    safe-ports = "21 80 443 8448"
  }
}
```

- [ ] **Step 2: Validate HCL syntax**

```bash
cd terraform/modules/juju-squid
terraform fmt -check && echo "fmt OK"
```

Expected: `fmt OK` (or lists files that need formatting — run `terraform fmt` to fix, then re-check).

- [ ] **Step 3: Commit**

```bash
git add terraform/modules/juju-squid/main.tf
git commit -m "feat(juju-squid): deploy squid-reverseproxy charm with ACL config"
```

---

## Task 3: Create `juju-squid` module — outputs

**Files:**
- Create: `terraform/modules/juju-squid/outputs.tf`

- [ ] **Step 1: Create outputs.tf**

```hcl
# terraform/modules/juju-squid/outputs.tf

output "application_name" {
  description = "Name of the squid Juju application, for use in integrations"
  value       = juju_application.squid.name
}
```

- [ ] **Step 2: Run terraform fmt across the new module**

```bash
cd terraform/modules/juju-squid
terraform fmt
terraform fmt -check && echo "fmt OK"
```

Expected: `fmt OK`

- [ ] **Step 3: Commit**

```bash
git add terraform/modules/juju-squid/outputs.tf
git commit -m "feat(juju-squid): add module outputs"
```

---

## Task 4: Wire squid into juju-demo deployment

**Files:**
- Modify: `terraform/deployments/juju-demo/main.tf`

- [ ] **Step 1: Add squid module block after the existing `module "grafana_agent"` block**

In `terraform/deployments/juju-demo/main.tf`, add the following after the `module "grafana_agent"` block and before the K8s section comment:

```hcl
module "squid" {
  source = "../../modules/juju-squid"

  model_name = local.bare_model
}
```

- [ ] **Step 2: Add grafana-agent → squid integration**

Append the following `juju_integration` resource after the `module "squid"` block:

```hcl
resource "juju_integration" "grafana_agent_squid" {
  model_uuid = data.juju_model.bare_model.uuid

  application {
    name     = module.grafana_agent.application_name
    endpoint = "juju-info"
  }

  application {
    name     = module.squid.application_name
    endpoint = "juju-info"
  }
}
```

Note: `data.juju_model.bare_model` is not yet declared in `juju-demo/main.tf` — it references the model by local name. Add this data source at the top of the bare VM section if it is missing:

```hcl
data "juju_model" "bare_model" {
  name = local.bare_model
}
```

- [ ] **Step 3: Add squid to outputs**

At the bottom of `terraform/deployments/juju-demo/main.tf`, add:

```hcl
output "squid_app" {
  value = module.squid.application_name
}
```

- [ ] **Step 4: Validate the full deployment config**

```bash
cd terraform/deployments/juju-demo
terraform fmt -check && echo "fmt OK"
terraform validate 2>&1
```

Expected:
```
fmt OK
Success! The configuration is valid.
```

If `terraform validate` fails with "provider not configured", that is expected without a live Juju controller — the HCL structure is still validated.

- [ ] **Step 5: Commit**

```bash
git add terraform/deployments/juju-demo/main.tf
git commit -m "feat(juju-demo): add squid module and grafana-agent integration"
```

---

## Task 5: Push and verify

- [ ] **Step 1: Push all commits**

```bash
git push origin main
```

- [ ] **Step 2: Verify file structure is complete**

```bash
find terraform/modules/juju-squid -type f | sort
```

Expected:
```
terraform/modules/juju-squid/main.tf
terraform/modules/juju-squid/outputs.tf
terraform/modules/juju-squid/variables.tf
```

- [ ] **Step 3: Confirm squid module is referenced in juju-demo**

```bash
grep -n "squid" terraform/deployments/juju-demo/main.tf
```

Expected output includes:
```
module "squid" {
  source = "../../modules/juju-squid"
  model_name = local.bare_model
}
resource "juju_integration" "grafana_agent_squid" {
```
