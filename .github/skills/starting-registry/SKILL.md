---
name: starting-registry
description: Use when starting or verifying the superpilot RegistryServer — the central HTTP hub that distributed AgentClients register with and poll for messages
---

# Starting the superpilot RegistryServer

## Overview

The RegistryServer is a lightweight Express HTTP server. It holds the agent roster and per-agent message queues **in memory** — state does not survive restarts. Agents re-register on their own startup.

## Prerequisites

- Node.js ≥ 18, npm installed
- `superpilot` repo cloned and `npm install` run:
  ```bash
  git clone https://github.com/yanksyoon/superpilot.git && cd superpilot && npm install
  ```
- Port available (default 3000)

## Start the Server

**macOS / Linux:**
```bash
PORT=3000 npm run registry
```

**Windows (CMD):**
```cmd
set PORT=3000 && npm run registry
```

**Windows (PowerShell):**
```powershell
$env:PORT=3000; npm run registry
```

> `npm run registry` builds TypeScript first, then starts `dist/registry-server.js`.

**Expected startup output:**
```
[RegistryServer] Listening on port 3000
```

The server binds to **all interfaces** (`0.0.0.0`), so remote machines can reach it immediately — no extra bind configuration needed.

## Starting the Copilot CLI in server mode (for hook mode agents)

If you want agents to hook into an *existing* running Copilot CLI session (rather than spawning their own), start the CLI in server mode **before** running the agent:

```bash
# Recommended — TUI + server API (exposes foreground session)
copilot --ui-server

# Headless server only (no TUI)
copilot --server
```

The CLI prints its server URL on startup, e.g.:
```
Listening on http://127.0.0.1:8080
```

Pass this as `COPILOT_CLI_URL=localhost:8080` when starting the agent. See the `joining-registry` skill for full details.

## Verify It Is Working

```bash
# 1. Register a test agent
curl -s -X POST http://localhost:3000/agents \
  -H "Content-Type: application/json" \
  -d '{"name":"smoke","responsibilities":"smoke test"}' | cat
# → {"name":"smoke"}

# 2. List agents
curl -s http://localhost:3000/agents | cat
# → [{"name":"smoke","responsibilities":"smoke test"}]

# 3. Enqueue a message
curl -s -X POST http://localhost:3000/messages/smoke \
  -H "Content-Type: application/json" \
  -d '{"message":"hello"}' | cat
# → {"queued":true}

# 4. Dequeue (destructive — queue is now empty)
curl -s http://localhost:3000/messages/smoke | cat
# → {"messages":["hello"]}

# 5. Cleanup
curl -s -X DELETE http://localhost:3000/agents/smoke
# → HTTP 204 No Content
```

**Remote verification** — from another machine, replace `localhost` with the server's IP/hostname.

## Keeping the Server Running (Linux)

To survive SSH logout, use `nohup` (quick) or a systemd service (production).

**Quick (nohup):**
```bash
PORT=3000 nohup npm run registry > registry.log 2>&1 &
echo "PID: $!"   # save this to kill it later
tail -f registry.log
```

**Firewall (Ubuntu/Debian):**
```bash
sudo ufw allow 3000/tcp
```

**Firewall (RHEL/CentOS):**
```bash
sudo firewall-cmd --add-port=3000/tcp --permanent && sudo firewall-cmd --reload
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| `PORT=3000 npm run registry` fails on Windows | Use `set PORT=3000 && npm run registry` |
| Remote agents can't connect | Check firewall rules — port 3000 must be open inbound |
| Server crashes and agents stop working | Agents detect errors on next poll; restart server and restart agents |
| Duplicate agent name (409) | Restart the offending agent after the old one deregisters, or call `DELETE /agents/:name` manually |
| State lost after restart | Expected — RegistryServer is in-memory only; agents re-register on their own start |

## API Reference

| Method | Path | Body | Success | Error |
|--------|------|------|---------|-------|
| POST | `/agents` | `{ name, responsibilities }` | 201 `{ name }` | 409 duplicate |
| DELETE | `/agents/:name` | — | 204 | 404 unknown |
| GET | `/agents` | — | 200 `[{ name, responsibilities }]` | — |
| POST | `/messages/:name` | `{ message }` | 202 `{ queued: true }` | 404 unknown agent |
| GET | `/messages/:name` | — | 200 `{ messages: string[] }` | 404 unknown agent |

`GET /messages/:name` atomically dequeues — calling it twice returns empty on the second call.
