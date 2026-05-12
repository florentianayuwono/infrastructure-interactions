#!/usr/bin/env bash
# Install the superpilot skills into GitHub Copilot CLI.
#
# Usage:
#   ./install-skills.sh            # install from GitHub (yanksyoon/superpilot)
#   ./install-skills.sh --local    # install from this local checkout

set -euo pipefail

LOCAL=0
for arg in "$@"; do
  case "$arg" in
    --local) LOCAL=1 ;;
    *) echo "Unknown argument: $arg"; exit 1 ;;
  esac
done

if ! command -v copilot &>/dev/null; then
  echo "Error: GitHub Copilot CLI not found. Install it first:"
  echo "  curl -fsSL https://gh.io/copilot-install | bash"
  exit 1
fi

if [ "$LOCAL" -eq 1 ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  echo "Installing superpilot skills from local directory: $SCRIPT_DIR"
  copilot plugin install "$SCRIPT_DIR"
else
  echo "Installing superpilot skills from GitHub (yanksyoon/superpilot)..."
  copilot plugin install yanksyoon/superpilot
fi

echo ""
echo "Done! Skills available in Copilot CLI:"
echo "  starting-registry  — start or verify the RegistryServer"
echo "  joining-registry   — connect a session to a running RegistryServer"
echo ""
echo "Run '/skills' inside a Copilot CLI session to confirm."
