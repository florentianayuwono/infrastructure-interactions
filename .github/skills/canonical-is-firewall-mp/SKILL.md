---
name: canonical-is-firewall-mp
description: Use when adding or updating firewall rules, defining new services, or connecting services together in the canonical-is-firewalls repository
---

# Canonical IS Firewall Map

## Overview

The canonical-is-firewalls repo uses YAML files to declare firewall rules and service definitions. Changes require two things: a **service definition** (who/what is the service) and **rules** (what traffic is allowed to/from it).

## Repo Layout

```
canonical-is-firewalls/
  services/<team>/<service-name>.yaml   # service host/subnet definitions
  rules/<team>/<service-name>.yaml      # firewall allow rules
  external/<vendor>.yaml                # third-party service host definitions
  defs/
    hosts.yaml    # named hosts → IPs
    subnets.yaml  # named subnets → CIDR ranges
    ports.yaml    # named ports → tcp/udp numbers
    juju.yaml     # auto-generated juju application addresses
```

## Questions to Ask the User

### For a new service definition (`services/<team>/<name>.yaml`)

1. **Service name** — What is the service called? (becomes the YAML key, e.g. `my-service`)
2. **Team/owner** — Which team owns it? (e.g. `is`, `bootstack`, `comms`)
3. **Host type** — Are hosts defined by:
   - Static IPs?
   - Named hosts from `defs/hosts.yaml`?
   - Juju application addresses (`juju/<controller>/<model>/...`)?
4. **Host groups** — What logical groups do the hosts fall into? (e.g. `frontends`, `db`, `workers`, `servers`)
5. **Subnets** — Are there subnets (CIDR ranges) associated with this service? If so, what are they called and what are the ranges?

### For new firewall rules (`rules/<team>/<name>.yaml`)

6. **Connection direction** — For each rule:
   - What is the **source** (`from`)? A service group, subnet, or `any`?
   - What is the **destination** (`to`)? A service group, subnet, or `any`?
   - What **ports/protocols** are needed? (use named ports from `defs/ports.yaml` where possible, e.g. `https`, `postgres`, `ssh`)
   - What is a short human-readable **comment** describing why this connection is needed?
7. **External services** — Does the service need to reach any external third-party services (e.g. GitHub, PagerDuty)? If so, does an entry already exist in `external/`?

## File Formats

### Service definition

```yaml
my-service:
  owner: is
  hosts:
    frontends:
    - 185.125.189.99
    workers:
    - juju/prodstack-is-ps5/admin/prod-my-model/my-app/public
  subnets:
    db-network:
    - 10.131.164.0/24
```

### Rules file

```yaml
my-service:
  rules:
    - comment: "Allow k8s workers to reach the DB"
      from: [services/is/my-service/workers]
      to: [services/is/my-service/db-network]
      ports: [postgres]

    - comment: "Allow staff VPN access to frontend"
      from: [subnets/canonical-staff]
      to: [services/is/my-service/frontends]
      ports: [https]
```

## Reference Paths

- Named hosts: `hosts/<name>` (resolved via `defs/hosts.yaml`)
- Named subnets: `subnets/<name>` (resolved via `defs/subnets.yaml`)
- Named ports: defined in `defs/ports.yaml`
- Service groups: `services/<team>/<service>/<group>`
- External services: `external/<vendor>/<group>`

## Common Mistakes

- **Missing both files**: Every service needs both a `services/` entry (what it is) and a `rules/` entry (what traffic is allowed).
- **Inventing port names**: Only use port names that exist in `defs/ports.yaml`; add new ones there if needed.
- **Wrong team path**: The `<team>` directory in `services/` and `rules/` must match the `owner` field.
- **Referencing undefined host groups**: A group used in `rules/` (e.g. `services/is/foo/workers`) must be declared in `services/is/foo.yaml`.
