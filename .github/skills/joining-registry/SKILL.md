---
name: joining-registry
description: Use when connecting a Copilot CLI session to a running superpilot RegistryServer — either by hooking the current session (recommended) or by spawning a fresh agent process. Also use when debugging why an agent failed to register or receive messages.
---

# Joining the superpilot Registry as an AgentClient

## Overview

Each machine runs one `AgentClient`. On `start()` it:
1. Fetches the peer roster from the RegistryServer
2. Creates or hooks into a CopilotSession and injects the `send_to_agent` tool
3. Registers itself (`POST /agents`)
4. Starts a poll loop — checks for messages every `pollIntervalMs` (default 2 s)
5. Delivers each message into the session via `sendAndWait()` sequentially (FIFO)

On SIGINT/SIGTERM it deregisters cleanly and exits.

## Two modes

| Mode | When to use |
|------|-------------|
| **Hook mode** (`COPILOT_CLI_URL` set) | You already have a Copilot CLI session running. The agent attaches to it — no new session spawned, conversation history preserved. **This is the recommended way to join from a running Copilot CLI.** |
| **Spawn mode** (default) | No Copilot CLI running yet. The agent spawns its own CLI process and creates a fresh session. |

---

## Hook mode — join from a running Copilot CLI session

> **Use this when the skill is invoked from inside a Copilot CLI session.**
> The agent hooks into the session you're already talking to, registers it with the registry, and starts accepting work from other agents — all without interrupting your conversation.

### Step 1 — find the CLI server URL

The Copilot CLI server URL is needed so the agent process can reconnect to the already-running CLI. Check in order:

```bash
# Check if the env var is already set (set by --ui-server / --server launch)
echo $COPILOT_CLI_URL

# If not set, check the default socket/port used by this CLI instance
# (look at the process args for --port or --ui-server-port)
ps aux | grep copilot | grep -v grep
```

If neither gives you a URL, the CLI is likely running in interactive (non-server) mode. Start it in server mode instead:
```bash
# macOS / Linux — TUI + server API (preferred)
copilot --ui-server

# server only (no TUI)
copilot --server
```
The startup line will print the URL, e.g. `Listening on http://127.0.0.1:8080`.

### Step 2 — run the agent in hook mode

**macOS / Linux:**
```bash
REGISTRY_URL=http://<registry-host>:3000 \
AGENT_NAME=<your-name> \
AGENT_RESPONSIBILITIES="<what this session is good at>" \
COPILOT_CLI_URL=localhost:8080 \
npm run agent
```

**Windows (PowerShell):**
```powershell
$env:REGISTRY_URL="http://<registry-host>:3000"
$env:AGENT_NAME="<your-name>"
$env:AGENT_RESPONSIBILITIES="<what this session is good at>"
$env:COPILOT_CLI_URL="localhost:8080"
npm run agent
```

**Expected startup output:**
```
[AgentClient:<your-name>] Hooking into foreground session <session-id>
[AgentClient] "<your-name>" started (hooked into existing CLI at localhost:8080) — polling http://<registry-host>:3000 every 2000ms
```

The `send_to_agent` tool is injected into the existing session, so you (and the AI) can delegate work to other agents in the registry simply by using it.

### What happens during hook mode

1. `AgentClient` connects to the already-running CLI via `COPILOT_CLI_URL` (no new process spawned)
2. Tries `getForegroundSessionId()` (requires `--ui-server` mode) — uses that session
3. Falls back to the most recently modified session from `listSessions()`
4. Calls `resumeSession(id, { tools: [send_to_agent], systemMessage: { mode: "append", content: peerBlock } })`
   - Your existing system prompt and conversation history are untouched
   - The peer-awareness block (which agents are available) is appended
   - `send_to_agent` tool is made available in this session
5. Registers with the RegistryServer and starts polling

---

## Spawn mode — start a fresh agent

Use this when no Copilot CLI is running. `npm run agent` will automatically spawn `copilot --ui-server`, giving you an interactive TUI session, then hook the AgentClient into it.

Before the TUI takes over the terminal it prints the command to hook additional agents:

```
[AgentClient] Starting Copilot UI server on port 54321...
[AgentClient] To hook another agent into this session, run in a new terminal:
  COPILOT_CLI_URL=localhost:54321 REGISTRY_URL=... AGENT_NAME=<name> AGENT_RESPONSIBILITIES=<desc> npm run agent
```

**macOS / Linux:**
```bash
REGISTRY_URL=http://<registry-host>:3000 \
AGENT_NAME=researcher \
AGENT_RESPONSIBILITIES="Finds and summarizes information on a topic" \
AGENT_SYSTEM_PROMPT="You are a research expert. Forward findings to the writer." \
npm run agent
```

To allow the agent to run tools without confirmation prompts, add `YOLO=1`:

```bash
REGISTRY_URL=http://<registry-host>:3000 \
AGENT_NAME=researcher \
AGENT_RESPONSIBILITIES="Finds and summarizes information on a topic" \
AGENT_SYSTEM_PROMPT="You are a research expert. Forward findings to the writer." \
YOLO=1 \
npm run agent
```

**Windows (PowerShell):**
```powershell
$env:REGISTRY_URL="http://<registry-host>:3000"
$env:AGENT_NAME="researcher"
$env:AGENT_RESPONSIBILITIES="Finds and summarizes information on a topic"
$env:AGENT_SYSTEM_PROMPT="You are a research expert. Forward findings to the writer."
$env:YOLO="1"   # optional — remove to keep confirmation prompts
npm run agent
```

**Windows (CMD):**
```cmd
set REGISTRY_URL=http://<registry-host>:3000
set AGENT_NAME=researcher
set AGENT_RESPONSIBILITIES=Finds and summarizes information on a topic
set AGENT_SYSTEM_PROMPT=You are a research expert. Forward findings to the writer.
set YOLO=1
npm run agent
```

`AGENT_SYSTEM_PROMPT` is **optional** (ignored in hook mode) — defaults to `"You are an agent named <AGENT_NAME>."`.
`YOLO` is **optional** (ignored in hook mode) — set to `1` or `true` to pass `--yolo` to the spawned CLI.

**Expected startup output:**
```
[AgentClient] "researcher" started (new session) — polling http://<registry-host>:3000 every 2000ms
```

---

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

## Verify the Agent Is Registered

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

The agent picks it up within `pollIntervalMs` ms and runs it in the hooked (or spawned) session.

## Programmatic Use

```typescript
import { AgentClient } from "./src/agent-client.js";

// Hook mode — attach to existing CLI session
const client = new AgentClient({
  registryUrl: "http://registry-host:3000",
  name: "researcher",
  responsibilities: "Finds and summarizes information on a topic",
  systemPrompt: "ignored in hook mode",
  copilotCliUrl: "localhost:8080", // set this to hook existing session
  pollIntervalMs: 2000, // optional
});

// Spawn mode — fresh CLI process (defaults to --ui-server)
const worker = new AgentClient({
  registryUrl: "http://registry-host:3000",
  name: "worker",
  responsibilities: "Executes background tasks",
  systemPrompt: "You are a worker agent.",
  yolo: true, // optional — pass --yolo to spawned CLI; ignored in hook mode
  pollIntervalMs: 2000,
});

await client.start(); // blocks until SIGINT/SIGTERM
```

## Environment Variable Reference

| Variable | Required | Description |
|----------|----------|-------------|
| `REGISTRY_URL` | ✅ | URL of the RegistryServer, e.g. `http://host:3000` |
| `AGENT_NAME` | ✅ | Unique agent identifier |
| `AGENT_RESPONSIBILITIES` | ✅ | One-line description shown to peer agents |
| `AGENT_SYSTEM_PROMPT` | — | System prompt for new session (spawn mode only). Defaults to `"You are an agent named <name>."` |
| `COPILOT_CLI_URL` | — | Hook an already-running CLI, e.g. `localhost:8080` (activates hook mode) |
| `YOLO` | — | Set to `1` or `true` to pass `--yolo` to the spawned CLI (spawn mode only) |
| `POLL_INTERVAL_MS` | — | Message poll interval in ms. Default `2000` |

## Lifecycle Reference

| Event | Behavior |
|-------|----------|
| Startup (hook mode) | Resumes foreground or most-recent session; registers with registry |
| Startup (spawn mode) | Creates new session with full systemPrompt; registers with registry |
| Shutdown (Ctrl-C / SIGTERM) | Deregisters, disconnects session, exits cleanly |
| Registry restart | Agent detects errors on next poll; **restart agent** to re-register |
| Duplicate agent name | Server returns 409 → agent throws `Error` and exits. Deregister old instance first: `curl -X DELETE http://<registry>:3000/agents/<name>` |
| Multiple agents on one machine | Supported — run separate processes with different `AGENT_NAME` values |
| Poll interval | Default 2 s. Lower = more responsive, more HTTP traffic |

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Hook mode: `getForegroundSessionId` fails | CLI not in `--ui-server` mode — agent falls back to most-recent session automatically |
| Hook mode: no existing sessions found | No prior sessions in this CLI instance — agent falls back to creating a new session |
| `curl /agents` shows agent not listed | Check startup output for errors; ensure `REGISTRY_URL` resolves from the agent machine |
| Registry restarts, agent stops working | Restart the agent — it must re-register on startup |
| Duplicate name error on restart | Old process didn't deregister (crashed). Run `curl -X DELETE http://<registry>:3000/agents/<name>` then restart agent |
| Messages enqueued but agent never processes them | Verify poll loop started (look for startup log); check for `sendAndWait` errors in stderr |
| Works locally, fails on remote machine | Confirm `REGISTRY_URL` uses the registry's actual IP/hostname, not `localhost` |
