---
name: create-proxy-config-mr
description: Use when adding or updating service ACL entries in the canonical-is-internal-proxy-configs Launchpad repository and creating a merge request for review
---

# Create Proxy Config MR

## Overview

Guides you through adding a service ACL to the Canonical IS internal proxy config repo and submitting a Launchpad merge request.

## Step 1: Gather Service ACL Details

Ask the user for the following before touching any files:

- **Service name** — what is the service being granted proxy access? (e.g. `my-charm`, `grafana-agent`)
- **Source** — which unit/charm/subnet needs outbound access? (e.g. `10.0.0.0/24`, charm name)
- **Destination hosts** — which external hosts/domains must be reachable? (e.g. `api.example.com`, `*.ubuntu.com`)
- **Destination ports** — which ports? (e.g. `443`, `80,443`)
- **Protocol** — `http`, `https`, or both?
- **Justification** — one-line reason (used in the commit message and MR description)

Do not proceed until all fields are confirmed.

## Step 2: Set Up the Repo

```bash
# Clone if not already present
git clone git+ssh://charlie4284@git.launchpad.net/~charlie4284/canonical-is-internal-proxy-configs
cd canonical-is-internal-proxy-configs

# Or, if already cloned, pull latest
git checkout main && git pull
```

Create a feature branch named after the service:

```bash
git checkout -b add-acl-<service-name>
```

## Step 3: Add the ACL Entry

Locate the correct config file (typically named by environment or charm) and add the ACL block. Follow the existing format in the file exactly. Example pattern:

```
# <service-name>: <justification>
acl <service_name>_dst dstdomain <destination-hosts>
http_access allow <source> <service_name>_dst
```

Confirm the edit looks correct before committing.

## Step 4: Commit and Push

```bash
git add <changed-file>
git commit -m "feat: add proxy ACL for <service-name>

<justification>

Source: <source>
Destinations: <destination-hosts>:<ports>"

git push origin add-acl-<service-name>
```

## Step 5: Create the Merge Request

Open the Launchpad merge proposal page in a browser:

```
https://code.launchpad.net/~charlie4284/canonical-is-internal-proxy-configs/+git/canonical-is-internal-proxy-configs/+ref/add-acl-<service-name>/+register-merge
```

Fill in:
- **Target branch**: `main`
- **Description**: Include service name, source, destinations, ports, and justification
- **Reviewers**: Add the IS Charms or IS Security team as appropriate

Share the merge proposal URL with the user when done.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Wrong ACL format | Copy an existing block from the file and adapt it |
| Missing `dstdomain` vs `dst` | Use `dstdomain` for FQDNs, `dst` for IPs |
| Pushing to `main` directly | Always use a feature branch |
| Vague MR description | Include source, destination, ports, and justification |
