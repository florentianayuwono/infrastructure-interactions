# Juju Squid Egress Proxy Deployment Design

**Date:** 2026-05-13
**Status:** Approved

## Problem Statement

The existing LXD demo infrastructure runs a Squid egress proxy manually on a bare VM (`squid-proxy`, `10.142.65.2`). The goal is to replicate this as a native Juju deployment within the existing `terraform/deployments/juju-demo/` Terraform stack, using the `squid-reverseproxy` Charmhub charm — consistent with how HAProxy, COS-lite, and Grafana are already deployed.

## Current State

`terraform/deployments/juju-demo/main.tf` already manages:
- `juju-haproxy` module — HAProxy ingress with ingress-configurator
- `juju-cos` module — COS-lite (includes Grafana, Prometheus, Loki, Alertmanager) on K8s model
- `juju-compute`, `juju-falcosidekick`, `juju-grafana-agent` modules on bare VM model
- Cross-model offers wiring grafana-agent → COS-lite Prometheus

Grafana is already provided by COS-lite; no standalone grafana charm is needed.

## Chosen Approach

**Extend `juju-demo` with a new `juju-squid` Terraform module** using the `squid-reverseproxy` charm from Charmhub. This follows the same module pattern as `juju-haproxy` and keeps all Juju resources managed consistently through Terraform.

Alternatives considered and rejected:
- Custom machine charm: too much maintenance overhead for a standard Squid setup.
- `squid-deb-proxy` charm: purpose-built for Debian package caching, not general egress.

## Architecture

```
Bare VM Juju model (hackathon-infra-interactions-ps7-staging)
│
├── haproxy          (existing) — HAProxy ingress, virtual IP 10.142.65.4
├── ingress-configurator (existing) — routes proxy.demo.local → squid
├── compute          (existing) — workload VMs
├── falcosidekick    (existing) — security events
├── grafana-agent    (existing) — metrics scraping → COS-lite
└── squid            (NEW)     — egress proxy on tcp/3128
      └── ← grafana-agent integration (metrics)

K8s Juju model (k8s-hackathon-ps7-staging)
└── cos-lite (existing) — Grafana, Prometheus, Loki, Alertmanager
```

## Components

### 1. New module: `terraform/modules/juju-squid/`

**Files:** `main.tf`, `variables.tf`, `outputs.tf`

`main.tf` deploys `squid-reverseproxy` charm (1 unit) with config:
- `port: 3128` — matches upstream `defs/ports.yaml: squid: [tcp/3128]`
- ACL allowing `10.142.0.0/16` (demo network) — mirrors `demo/rules/demo/proxy.yaml`
- Safe ports: 80, 443, 21, 8448 — mirrors upstream `rules/is/squid.yaml` allowed outbound ports

**Inputs:** `model_name` (string)
**Outputs:** `application_name`, `endpoints`

### 2. Updates to `terraform/deployments/juju-demo/main.tf`

Add `module "squid"` block calling `../../modules/juju-squid` with `model_name = local.bare_model`.

Add `juju_integration` resource wiring squid into `grafana-agent`'s `target_apps` so metrics flow into COS-lite Grafana automatically.

## Data Flow

```
Demo VMs (10.142.0.0/16)
    │  tcp/3128
    ▼
squid-reverseproxy charm
    │  http/https/ftp outbound
    ▼
Internet

grafana-agent → scrapes squid metrics → COS-lite Prometheus → Grafana dashboards
```

## Relations

| From | Endpoint | To | Endpoint |
|---|---|---|---|
| `ingress-configurator` | `haproxy-route` | `haproxy` | `haproxy-route` |
| `grafana-agent` | `juju-info` | `squid` | `juju-info` |

## Alignment with Upstream Demo Structure

The `demo/rules/demo/proxy.yaml` YAML rules map directly to squid charm config:
- `services/demo/proxy/internal` → the squid charm unit
- `subnets/demo-network` → ACL src `10.142.0.0/16`
- Ports (ftp, http, https, matrix-federation) → squid `safe_ports` config

## Files Changed

| File | Change |
|---|---|
| `terraform/modules/juju-squid/main.tf` | New — squid charm deployment |
| `terraform/modules/juju-squid/variables.tf` | New — input variables |
| `terraform/modules/juju-squid/outputs.tf` | New — application_name, endpoints |
| `terraform/deployments/juju-demo/main.tf` | Add squid module + grafana-agent integration |
