# Infrastructure Interactions

A high-fidelity imitation of Canonical's production ps7 OpenStack environment, designed for local development and hackathon demonstrations. This project transforms static configuration-as-code into a verifiable, visual, and manageable infrastructure.

## 🌟 Key Capabilities

- **LXD-Based Simulation:** Imitates a complex cloud environment using local LXD VMs, removing the need for real OpenStack dependencies.
- **Topology Visualization:** Automatically derives a network graph from YAML configs, providing instant visibility into service interdependencies.
<img width="1598" height="958" alt="Screenshot from 2026-05-13 22-09-41" src="https://github.com/user-attachments/assets/5d8a35f9-9081-402b-b17a-f86f37be05e7" />

- **Agentic Connection Management:** Integrates with AI agents to automate the process of proposing and implementing network connections via PRs/MRs.
- **Verifiable Connectivity:** Includes an E2E test suite to ensure the visual topology matches the actual network state.

## 🛠️ Architecture

The project maps production patterns to a local environment:

| Component | Production (ps7) | Demo (Local) |
|-----------|-----------------|--------------|
| **Compute** | OpenStack | LXD VMs |
| **Proxy** | `egress.ps7.internal` | Squid Proxy (Local) |
| **DNS** | Internal DNS zones | BIND9 (`.demo.local`) |
| **Ingress** | HAProxy + Juju | HAProxy (Local) |
| **Connectivity** | Security Groups | UFW / LXD ACLs |
| **Monitoring** | COS Lite | Prometheus / Grafana |

## 📂 Repository Structure

```text
├── .github/skills/      # Agent skills (e.g., visualize-infra)
├── demo/                # The "Source of Truth"
│   ├── defs/            # Host and subnet definitions
│   ├── rules/           # Connectivity rules (proxy, ingress, etc.)
│   └── services/        # Service-specific configurations
├── terraform/           # IaC for deploying the LXD environment
├── tests/               # E2E connectivity tests (test-e2e.sh)
└── DEMO_GUIDE.md        # Step-by-step showcase narrative
```

## 🚀 Quick Start

### 1. Deploy Infrastructure
```bash
cd terraform
terraform init
terraform apply -auto-approve
```

### 2. Visualize Topology
If you have the `superpilot` toolset installed:
```bash
# Generate the graph
python3 src/infra_graph/main.py --generate
# Launch the visualization
cd src/infra_graph/web && python3 -m http.server 8000
```
Then open `http://localhost:8000` in your browser.

### 3. Verify Connectivity
```bash
./tests/test-e2e.sh
```

![Demo](agent_collab.mov)

## 🤖 Agent Integration
This repository is designed to be managed by AI agents. Using the provided skills in `.github/skills/`, agents can:
- **Visualize:** Map the current state of the infrastructure.
- **Connect:** Propose and implement new network paths by generating diffs for the config repos.
- **Validate:** Ensure that changes didn't break existing connectivity.

## Requirements
- LXD installed and initialized (`lxd init`)
- Terraform >= 1.5
- Python 3.x (with `PyYAML`)

