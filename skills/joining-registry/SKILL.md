---
name: joining-registry
description: Use when connecting a machine to a running superpilot RegistryServer as a named AgentClient, or when debugging why an agent failed to register or receive messages
---

# Joining the superpilot Registry as an AgentClient

## Overview

Each machine runs one `AgentClient`. On `start()` it:
1. Registers itself with the RegistryServer (`POST /agents`)
2. Fetches the peer roster and injects it into the CopilotSession
3. Starts a poll loop — checks for messages every `pollIntervalMs` (default 2 s)
4. Processes each message through `sendAndWait()` sequentially (FIFO)

On SIGINT/SIGTERM it deregisters cleanly and exits.

## Prerequisites

- RegistryServer is running and reachable (`curl http://<registry-host>:3000/agents` returns 200)
- Node.js ≥ 18, npm installed, `npm install` run in the superpilot repo
- GitHub Copilot CLI authenticated — verify with:
  ```bash
  copilot auth status   # should show "Logged in"
  # or
  gh auth status
  ```
  If not authenticated: `copilot auth login` or `gh auth login`

## Start an Agent (CLI mode)

**macOS / Linux:**
```bash
REGISTRY_URL=http://<registry-host>:3000 \
AGENT_NAME=researcher \
AGENT_RESPONSIBILITIES="Finds and summarizes information on a topic" \
AGENT_SYSTEM_PROMPT="You are a research expert. Forward findings to the writer." \
npm run agent
```

**Windows (PowerShell):**
```powershell
$env:REGISTRY_URL="http://<registry-host>:3000"
$env:AGENT_NAME="researcher"
$env:AGENT_RESPONSIBILITIES="Finds and summarizes information on a topic"
$env:AGENT_SYSTEM_PROMPT="You are a research expert. Forward findings to the writer."
npm run agent
```

**Windows (CMD):**
```cmd
set REGISTRY_URL=http://<registry-host>:3000
set AGENT_NAME=researcher
set AGENT_RESPONSIBILITIES=Finds and summarizes information on a topic
set AGENT_SYSTEM_PROMPT=You are a research expert. Forward findings to the writer.
npm run agent
```

`AGENT_SYSTEM_PROMPT` is **optional** — defaults to `"You are an agent named <AGENT_NAME>."` if omitted.

**Expected startup output:**
```
[AgentClient] "researcher" started — polling http://<registry-host>:3000 every 2000ms
```

## Verify the Agent Is Registered

From any machine that can reach the registry:
```bash
curl -s http://<registry-host>:3000/agents | cat
# → [{"name":"researcher","responsibilities":"Finds and summarizes information on a topic"}]
```

## Send a Task to the Agent

```bash
curl -s -X POST http://<registry-host>:3000/messages/researcher \
  -H "Content-Type: application/json" \
  -d '{"message":"Research the latest trends in AI agents."}' | cat
# → {"queued":true}
```

The agent picks it up within `pollIntervalMs` ms.

## Programmatic Use

```typescript
import { AgentClient } from "./src/agent-client.js";

const client = new AgentClient({
  registryUrl: "http://registry-host:3000",
  name: "researcher",
  responsibilities: "Finds and summarizes information on a topic",
  systemPrompt: "You are a research expert. Forward findings to the writer.",
  pollIntervalMs: 2000, // optional
});
await client.start(); // blocks until SIGINT/SIGTERM
```

## Lifecycle Reference

| Event | Behavior |
|-------|----------|
| Startup | Registers with registry; throws if name already taken (409) |
| Shutdown (Ctrl-C / SIGTERM) | Deregisters, disconnects session, exits cleanly |
| Registry restart | Agent detects errors on next poll; **restart agent** to re-register |
| Duplicate agent name | Server returns 409 → agent throws `Error` and exits. Deregister old instance first: `curl -X DELETE http://<registry>:3000/agents/<name>` |
| Multiple agents on one machine | Supported — run separate processes with different `AGENT_NAME` values |
| Poll interval | Default 2 s. Lower = more responsive, more HTTP traffic |

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| `curl /agents` shows agent not listed | Check startup output for errors; ensure `REGISTRY_URL` resolves from the agent machine |
| Registry restarts, agent stops working | Restart the agent — it must re-register on startup |
| Duplicate name error on restart | Old process didn't deregister (crashed). Run `curl -X DELETE http://<registry>:3000/agents/<name>` then restart agent |
| Messages enqueued but agent never processes them | Verify poll loop started (look for startup log); check for `sendAndWait` errors in stderr |
| Works locally, fails on remote machine | Confirm `REGISTRY_URL` uses the registry's actual IP/hostname, not `localhost` |
