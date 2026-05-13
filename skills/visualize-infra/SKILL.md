---
name: visualize-infra
description: "Use this skill to generate and visualize the current infrastructure connection graph based on the demo configuration repositories."
---

# Visualize Infrastructure Connections

This skill generates a visual graph of the infrastructure by parsing the configuration files in the `demo/` directory and launching a local web server to display the result.

## Workflow

1. **Generate Graph Data**
   Run the graph generation engine to parse YAML configs and produce the `graph.json` file.
   
   Run: `python3 /home/ubuntu/superpilot/src/infra_graph/main.py --generate`
   Expected: "Demo-based graph generated at src/infra_graph/web/graph.json"

2. **Launch Visualization Server**
   Start the local HTTP server to serve the frontend and the generated data.
   
   Run: `cd /home/ubuntu/superpilot/src/infra_graph/web && python3 -m http.server 8000`
   
3. **Access the Graph**
   Inform the user that the graph is available at: `http://localhost:8000`

## Troubleshooting
- If the graph looks empty, ensure the `demo/` directory in `infrastructure-interactions` is up to date with `git pull origin main`.
- If the server fails to start, check if port 8000 is already in use.
