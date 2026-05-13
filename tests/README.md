# Testing Plan: `infrastructure-interactions`

Comprehensive E2E and integration tests for the ps7 staging imitation.

## Quick Start

```bash
cd tests/
./test-e2e.sh          # Validates deployed LXD VMs
```

## File Index

| Test File | Scope | When to Run |
|-----------|-------|-------------|
| `test-e2e.sh` | Full VM validation | After `terraform apply` |
| `README.md` | Manual checklist | Before, during, after |

## Manual Checklist (Phase 1–7)

### Phase 1: Terraform Validation

```bash
cd terraform/deployments/local-demo
cd ../juju-demo
```

**Expected:**
- `init`: Provider downloads successfully
- `validate`: No syntax errors
- `plan`: Shows all expected resources

### Phase 2: Verify Deployment

- [ ] `lxd_network.demo` created with `10.142.65.0/24`
- [ ] `lxd_network_acl.demo_acl` attached
- [ ] 4 VMs created: proxy, dns, ingress, monitoring
- [ ] Each VM has correct static IP
- [ ] Cloud-init completes on each VM

### Phase 3: Proxy (Squid) Tests

**Unit:**
- [ ] Config syntax: `lxc exec proxy -- squid -k check`
- [ ] Port 3128 listening

**Integration:**
- [ ] Egress via proxy: `curl -x http://10.142.65.2:3128 http://example.com`
- [ ] ACL blocks non-demo traffic

### Phase 4: DNS (BIND9) Tests

**Unit:**
- [ ] Config syntax: `lxc exec dns -- named-checkconf`
- [ ] Zone syntax: `lxc exec dns -- named-checkzone demo.local`

**Integration:**
- [ ] Resolve internal: `dig @10.142.65.3 proxy.demo.local`
- [ ] Resolve external: `dig @10.142.65.3 example.com`
- [ ] Reverse DNS for 10.142.65.x

### Phase 5: Ingress (HAProxy) Tests

**Unit:**
- [ ] Config syntax: `lxc exec ingress -- haproxy -c -f`

**Integration:**
- [ ] Stats page: `curl http://10.142.65.4:8404/stats`
- [ ] HTTP backend: `curl http://10.142.65.4:80`
- [ ] HTTPS backend: `curl -k https://10.142.65.4:443`

### Phase 6: Firewall (ACL) Tests

- [ ] SSH (22) open
- [ ] HTTP (80) open
- [ ] HTTPS (443) open
- [ ] Proxy (3128) open
- [ ] DNS (53) open
- [ ] Random port (e.g. 9999) blocked

### Phase 7: Cross-Model Integration (Juju)

- [ ] `juju_model.k8s` created
- [ ] `juju_application.canonical_k8s` deployed
- [ ] `juju_integration.k8s_cluster` active
- [ ] COS-lite ingress URLs resolvable

## Automated E2E Tests

Run `./test-e2e.sh` for automated validation of Phases 2–6.

### Test Coverage

| Test | Description | Command Equivalent |
|------|-------------|------------------|
| vm-ping | All VMs reach each other | `ping -c 2` |
| dns-resolution | BIND resolves zones | `dig @10.142.65.3` |
| proxy-functionality | Squid forwards traffic | `curl -x 10.142.65.2:3128` |
| ingress-routing | HAProxy serves backends | `curl http://10.142.65.4:8404` |
| firewall-deny | ACL blocks unknown ports | `nc -z 10.142.65.3 9999` |
| cross-vm-tcp | Services reachable over TCP | `bash /dev/tcp/<IP>/<PORT>` |
| terraform-state | State file valid | `terraform show` |

## Cleanup

```bash
cd terraform/deployments/local-demo
terraform destroy -auto-approve
```
