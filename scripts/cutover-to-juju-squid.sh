#!/usr/bin/env bash
# cutover-to-juju-squid.sh
#
# Cuts the demo infrastructure over from the LXD-native squid-proxy VM
# to the Juju-managed squid-reverseproxy unit.
#
# What it does:
#   1. Gets the IP of the Juju squid unit
#   2. Updates the HAProxy backend on ingress-controller to use the new IP
#   3. Updates /etc/hosts on the host (optional, for local testing)
#   4. Stops (but does not delete) the old squid-proxy LXD VM
#
# Usage:
#   bash scripts/cutover-to-juju-squid.sh [--dry-run]

set -euo pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "==> DRY RUN — no changes will be made."
fi

MODEL_NAME="demo-squid"
OLD_VM="squid-proxy"
OLD_IP="10.142.65.2"
SQUID_PORT="3128"
INGRESS_VM="ingress-controller"

run() {
  if $DRY_RUN; then
    echo "    [dry-run] $*"
  else
    "$@"
  fi
}

echo "==> Getting Juju squid unit IP..."

JUJU_SQUID_IP=$(juju status --model "${MODEL_NAME}" squid --format json 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
units = data.get('applications', {}).get('squid', {}).get('units', {})
for unit, info in units.items():
    addr = info.get('public-address', '')
    if addr:
        print(addr)
        break
")

if [[ -z "${JUJU_SQUID_IP}" ]]; then
  echo "ERROR: Could not determine Juju squid unit IP."
  echo "       Is the charm deployed and active? Check: juju status --model ${MODEL_NAME}"
  exit 1
fi

echo "==> Juju squid unit IP: ${JUJU_SQUID_IP}"

# Verify squid is responding on the new IP
echo "==> Verifying squid is responding on ${JUJU_SQUID_IP}:${SQUID_PORT}..."
if ! nc -z -w5 "${JUJU_SQUID_IP}" "${SQUID_PORT}" 2>/dev/null; then
  echo "ERROR: Squid not responding on ${JUJU_SQUID_IP}:${SQUID_PORT}. Aborting."
  exit 1
fi
echo "    OK"

# Update HAProxy on ingress-controller
echo "==> Updating HAProxy backend on ${INGRESS_VM} (${OLD_IP} -> ${JUJU_SQUID_IP})..."
run lxc exec "${INGRESS_VM}" -- bash -c "
  sed -i 's|${OLD_IP}:${SQUID_PORT}|${JUJU_SQUID_IP}:${SQUID_PORT}|g' /etc/haproxy/haproxy.cfg && \
  systemctl reload haproxy && \
  echo 'HAProxy reloaded.'
"

# Update demo/defs/hosts.yaml
echo "==> Updating demo/defs/hosts.yaml squid-proxy IP..."
HOSTS_FILE="demo/defs/hosts.yaml"
if [[ -f "${HOSTS_FILE}" ]]; then
  run sed -i "s|${OLD_IP}|${JUJU_SQUID_IP}|g" "${HOSTS_FILE}"
  echo "    Updated ${HOSTS_FILE}"
fi

# Stop the old LXD squid-proxy (kept for rollback)
echo "==> Stopping old LXD VM '${OLD_VM}' (kept for rollback, not deleted)..."
if lxc list --format csv | grep -q "^${OLD_VM},"; then
  run lxc stop "${OLD_VM}"
  echo "    Stopped. To roll back: lxc start ${OLD_VM}"
else
  echo "    '${OLD_VM}' not found or already stopped."
fi

echo ""
echo "==> Cutover complete!"
echo ""
echo "    New squid proxy: ${JUJU_SQUID_IP}:${SQUID_PORT} (Juju-managed)"
echo "    Old LXD VM '${OLD_VM}' is stopped (run 'lxc start ${OLD_VM}' to roll back)"
echo ""
echo "    Test proxy:"
echo "      curl -x http://${JUJU_SQUID_IP}:${SQUID_PORT} http://example.com"
echo ""
echo "    Verify juju status:"
echo "      juju status --model ${MODEL_NAME}"
