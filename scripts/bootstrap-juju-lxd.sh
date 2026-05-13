#!/usr/bin/env bash
# bootstrap-juju-lxd.sh
#
# Sets up a local Juju controller on LXD and creates the model used by
# terraform/deployments/juju-squid-local.
#
# Run once before: cd terraform/deployments/juju-squid-local && terraform apply
#
# Usage:
#   bash scripts/bootstrap-juju-lxd.sh

set -euo pipefail

CONTROLLER_NAME="demo-controller"
MODEL_NAME="demo-squid"

echo "==> Checking prerequisites..."

if ! command -v lxc &>/dev/null; then
  echo "ERROR: lxd/lxc is not installed or not in PATH"
  exit 1
fi

# Install Juju if missing
if ! command -v juju &>/dev/null; then
  echo "==> Installing Juju via snap..."
  sudo snap install juju --channel=3/stable
  # Ensure snap bin is on PATH
  export PATH="/snap/bin:$PATH"
fi

echo "==> Juju version: $(juju version)"

# Bootstrap controller on LXD if not already registered
if juju controllers --format json 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); exit(0 if '${CONTROLLER_NAME}' in d.get('controllers', {}) else 1)" 2>/dev/null; then
  echo "==> Controller '${CONTROLLER_NAME}' already exists, skipping bootstrap."
else
  echo "==> Bootstrapping Juju controller '${CONTROLLER_NAME}' on LXD (localhost)..."
  juju bootstrap localhost "${CONTROLLER_NAME}" \
    --config logging-config="<root>=WARNING" \
    --no-gui
  echo "==> Controller bootstrapped."
fi

# Create model if it doesn't exist
if juju models --format json 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
models = [m['short-name'] for m in data.get('models', [])]
exit(0 if '${MODEL_NAME}' in models else 1)
" 2>/dev/null; then
  echo "==> Model '${MODEL_NAME}' already exists, skipping."
else
  echo "==> Creating model '${MODEL_NAME}' on localhost (LXD)..."
  juju add-model "${MODEL_NAME}" localhost
  echo "==> Model created."
fi

echo ""
echo "==> Done! Ready to deploy:"
echo ""
echo "    cd terraform/deployments/juju-squid-local"
echo "    terraform init"
echo "    terraform apply"
echo ""
echo "    Then run: bash scripts/cutover-to-juju-squid.sh"
