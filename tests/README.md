# Testing Plan

This document outlines the test cases for validating the demo infrastructure.

## Phase 1: Terraform Validation

```bash
cd terraform/deployments/local-demo
terraform init
terraform validate
terraform plan
```

**Expected:**
- `init`: Provider downloads successfully
- `validate`: No syntax errors in any `.tf` files
- `plan`: Shows 5 resources (1 network + 4 VMs + 1 ACL)

## Phase 2: Infrastructure Deployment

```bash
terraform apply -auto-approve
```

**Verify:**
- [ ] `lxd_network.demo` created with `10.142.65.0/24`
- [ ] `lxd_network_acl.demo_acl` attached
- [ ] 4 VMs created: proxy, dns, ingress, monitoring
- [ ] Each VM has correct static IP
- [ ] Cloud-init completes on each VM

## Phase 3: Proxy (Squid) Tests

**Unit:**
- [ ] Config syntax: `lxc exec proxy -- squid -f /etc/squid/squid.conf -k check`
- [ ] Port 3128 listening: `lxc exec proxy -- netstat -tlnp | grep 3128`

**Integration:**
- [ ] Egress via proxy: `lxc exec dns -- curl -x http://10.142.65.2:3128 http://example.com`
- [ ] ACL blocks non-demo: Verify denied from `192.168.1.x`
- [ ] Cache dir: `/var/spool/squid` exists
- [ ] Access log: `/var/log/squid/access.log` has entries

## Phase 4: DNS (BIND9) Tests

**Unit:**
- [ ] Config syntax: `lxc exec dns -- named-checkconf /etc/bind/named.conf.local`
- [ ] Zone syntax: `lxc exec dns -- named-checkzone demo.local /etc/bind/db.demo.local`

**Integration:**
- [ ] Resolve proxy: `lxc exec proxy -- dig @10.142.65.3 proxy.demo.local`
- [ ] Resolve ingress: `lxc exec proxy -- dig @10.142.65.3 ingress.demo.local`
- [ ] CNAME works: `lxc exec proxy -- dig @10.142.65.3 cos-lite-ps7.demo.local`
- [ ] Reverse DNS: `lxc exec proxy -- dig -x 10.142.65.2`

## Phase 5: Firewall (LXD ACL) Tests

**Unit:**
- [ ] ACL exists: `lxc network acl show demo-firewall`

**Integration:**
- [ ] SSH works: `lxc exec proxy -- ssh -v dns@10.142.65.3`
- [ ] HTTP allowed: `lxc exec proxy -- curl http://10.142.65.4`
- [ ] Proxy port allowed: `lxc exec dns -- curl -x http://10.142.65.2:3128 http://example.com`
- [ ] DNS port allowed: `lxc exec proxy -- dig @10.142.65.3 monitoring.demo.local`
- [ ] Inter-VM traffic: `lxc exec proxy -- ping -c3 10.142.65.5`
- [ ] ICMP works: `lxc exec proxy -- ping -c3 10.142.65.3`
- [ ] Random port denied: `lxc exec proxy -- nc -zv 10.142.65.4 9999` (should fail)

## Phase 6: Ingress (HAProxy) Tests

**Unit:**
- [ ] Config syntax: `lxc exec ingress -- haproxy -f /etc/haproxy/haproxy.cfg -c`
- [ ] SSL cert exists: `lxc exec ingress -- ls /etc/haproxy/certs/demo.local.pem`

**Integration:**
- [ ] Route proxy: `curl -H "Host: proxy.demo.local" http://10.142.65.4`
- [ ] Route dns: `curl -H "Host: dns.demo.local" http://10.142.65.4`
- [ ] Route monitoring: `curl -H "Host: monitoring.demo.local" http://10.142.65.4`
- [ ] Stats page: `curl http://10.142.65.4:8404/stats`
- [ ] HTTPS: `curl -k https://10.142.65.4`
- [ ] HTTP→HTTPS redirect: `curl -I http://10.142.65.4 | grep 301`

## Phase 7: Integration Tests

**Cross-VM connectivity:**
- [ ] proxy → dns: `lxc exec proxy -- ping -c3 10.142.65.3`
- [ ] dns → ingress: `lxc exec dns -- ping -c3 10.142.65.4`
- [ ] ingress → monitoring: `lxc exec ingress -- ping -c3 10.142.65.5`

**End-to-end:**
- [ ] proxy → DNS → ingress: `lxc exec proxy -- curl -H "Host: monitoring.demo.local" http://10.142.65.4`
- [ ] Via proxy: `lxc exec dns -- curl -x http://10.142.65.2:3128 -H "Host: proxy.demo.local" http://10.142.65.4`

## Phase 8: Cleanup

```bash
cd terraform/deployments/local-demo
terraform destroy -auto-approve
```

**Verify:**
- [ ] All VMs destroyed
- [ ] Network removed
- [ ] ACL removed
