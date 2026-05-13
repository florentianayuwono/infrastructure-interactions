---
name: visualize-infra
description: "Use this skill to generate and visualize the current infrastructure connection graph based on the demo configuration repositories. This tool parses YAML config files to map dependencies between services."
---

# Visualize Infrastructure Connections

This skill allows an agent to generate a visual graph of the infrastructure by analyzing the configuration files in the `demo/` directory. It provides a high-level architectural view of how services are interconnected.

## Prerequisites
The agent must have:
1. Access to the `infrastructure-interactions` repository.
2. Python 3.x installed with the `PyYAML` library.
3. Ability to run a local HTTP server.

## Workflow

### 1. Generate Graph Data
The agent should implement a parsing script (or use an existing one) that follows this logic:
- **DNS Mapping:** Parse `demo/defs/hosts.yaml` to create a mapping of IPs to service names.
- **Connection Extraction:**
  - Parse `demo/rules/demo/proxy.yaml` for egress rules (Source $\rightarrow$ Internet).
  - Parse `demo/rules/demo/ingress.yaml` for routing rules (Ingress $\rightarrow$ Backend).
  - Parse `demo/rules/demo/firewall.yaml` (if present) for allowed TCP/UDP paths.
- **Graph Compilation:** Resolve all IP addresses to their human-readable names and generate a `graph.json` file in the format:
  ```json
  {
    "nodes": [{"id": "service-name", "label": "Service Label"}],
    "edges": [{"source": "src", "target": "dst", "label": "port/protocol"}]
  }
  ```

### 2. Launch Visualization
To display the results to the user, start a local web server in the directory containing `graph.json`:
```bash
python3 -m http.server 8000
```

### 3. Access the Map
Direct the user to access the visualization at: `http://localhost:8000`

## Implementation Details for the Agent
If a parsing script is not already available in the environment, the agent should create a Python script that:
- Uses `re` or `PyYAML` to extract rules.
- Normalizes paths like `services/demo/proxy/internal` to clean names like `demo-proxy`.
- Handles subnets (e.g., `subnets/demo-infra`) as distinct source nodes.

## Troubleshooting
- **Empty Graph:** Check if the `demo/` directory is populated via `git pull origin main`.
- **Port Conflict:** If port 8000 is taken, use `python3 -m http.server 8080`.
- **Missing Dependencies:** Install PyYAML via `pip install PyYAML`.
