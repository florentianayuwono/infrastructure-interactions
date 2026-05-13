#!/usr/bin/env bash
# End-to-end tests for infrastructure-interactions
# Validates full stack connectivity and service behavior after Terraform apply
# Requires: LXD VMs running from local-demo deployment

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RESULTS_DIR="${SCRIPT_DIR}/results"

mkdir -p "${RESULTS_DIR}"

echo "============================================"
echo " E2E TESTS: infrastructure-interactions"
echo " Target: ps7 imitation"
echo "============================================"
echo ""
echo "⚠️  These tests require the local-demo LXD VMs to be running"
echo "   Deploy first: cd terraform/deployments/local-demo && terraform apply"
echo ""

PASSED=0
FAILED=0

# ── helpers ─────────────────────────────────
run_test() {
  local name="$1"
  shift
  echo ""
  echo "▶️  ${name}"
  if "$@" > "${RESULTS_DIR}/${name}.log" 2>&1; then
    echo "   ✅ PASS"
    ((PASSED++))
  else
    echo "   ❌ FAIL (see results/${name}.log)"
    ((FAILED++))
  fi
}

# ── check all required VMs exist and are running ─────────────────────────────────
check_vms() {
  if ! command -v lxc >/dev/null 2>&1; then
    echo "❌ LXC not installed. Skipping E2E tests."
    return 1
  fi

  local required=(squid-proxy dns-server ingress-controller monitoring)
  for vm in "${required[@]}"; do
    if ! lxc info "$vm" >/dev/null 2>&1; then
      echo "❌ LXD container/VM '$vm' not found"
      return 1
    fi
    local status
    status=$(lxc info "$vm" | grep -i "Status:" | awk '{print $2}')
    if [ "$status" != "Running" ]; then
      echo "❌ LXD container/VM '$vm' status: $status (expected Running)"
      return 1
    fi
  done
  echo "✅ All LXD container/VMs Running"
  return 0
}

# ── Test 1: VM inter-connectivity (ping) ─────────────────────────────────
test_vm_ping() {
  for src in squid-proxy dns-server ingress-controller monitoring; do
    for dst in 10.142.65.2 10.142.65.3 10.142.65.4 10.142.65.5; do
      lxc exec "$src" -- ping -c 2 -W 2 "$dst" >/dev/null
    done
  done
}

# ── Test 2: DNS resolution via BIND9 ─────────────────────────────────
test_dns_resolution() {
  lxc exec proxy -- dig +short @10.142.65.3 proxy.demo.local
  lxc exec proxy -- dig +short @10.142.65.3 ingress.demo.local
  lxc exec proxy -- dig +short @10.142.65.3 monitoring.demo.local
}

# ── Test 3: Squid proxy functionality ─────────────────────────────────
test_proxy_functionality() {
  lxc exec monitoring -- curl -s -x http://10.142.65.2:3128 \
    --connect-timeout 5 http://example.com -o /dev/null
}

# ── Test 4: HAProxy routing ─────────────────────────────────
test_ingress_routing() {
  curl -sf --connect-timeout 5 http://10.142.65.4:8404/stats >/dev/null
}

# ── Test 5: Firewall denies unexpected ports ─────────────────────────────────
test_firewall_deny() {
  # port 9999 should NOT be open on dns container
  if lxc exec proxy -- timeout 3 bash -c "exec 3<>/dev/tcp/10.142.65.3/9999" 2>/dev/null; then
    echo "Port 9999 should be blocked"
    return 1
  fi
  return 0
}

# ── Test 6: Cross-VM TCP service reachability ─────────────────────────────────
test_cross_vm_tcp() {
  lxc exec dns   -- timeout 3 bash -c "exec 3<>/dev/tcp/10.142.65.2/3128"
  lxc exec proxy -- timeout 3 bash -c "exec 3<>/dev/tcp/10.142.65.3/53"
  lxc exec proxy -- timeout 3 bash -c "exec 3<>/dev/tcp/10.142.65.4/80"
  lxc exec proxy -- timeout 3 bash -c "exec 3<>/dev/tcp/10.142.65.4/443"
}

# ── Test 7: Terraform state integrity ─────────────────────────────────
test_terraform_state() {
  cd "${REPO_ROOT}/terraform/deployments/local-demo"
  terraform show >/dev/null
  terraform state list | grep -q "module.proxy\."
  terraform state list | grep -q "module.dns\."
  terraform state list | grep -q "module.ingress\."
  terraform state list | grep -q "module.monitoring\."
}

# ── Run E2E tests ─────────────────────────────────
if ! check_vms; then
  echo ""
  echo "⏭️  Skipping E2E tests (VMs not running)"
  exit 0
fi

run_test "vm-ping"           test_vm_ping
run_test "dns-resolution"    test_dns_resolution
run_test "proxy-functionality" test_proxy_functionality
run_test "ingress-routing"   test_ingress_routing
run_test "firewall-deny"     test_firewall_deny
run_test "cross-vm-tcp"      test_cross_vm_tcp
run_test "terraform-state"   test_terraform_state

echo ""
echo "============================================"
echo " RESULTS: ${PASSED} passed, ${FAILED} failed"
echo "============================================"

if [ "${FAILED}" -gt 0 ]; then
  echo ""
  echo "Failed test logs:"
  for log in "${RESULTS_DIR}"/*.log; do
    name=$(basename "$log" .log)
    if grep -q "Error\|FAIL\|❌" "$log" 2>/dev/null; then
      echo ""
      echo "--- ${name} ---"
      tail -20 "$log"
    fi
  done
  echo ""
  echo "🔧 Debug: ssh ubuntu@<vm_ip> or lxc exec <vm> -- bash"
  exit 1
fi

echo ""
echo "✅ All E2E tests passed — ps7 imitation verified!"
