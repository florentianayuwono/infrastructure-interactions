# Distributed Multi-Agent Registry Design

**Date:** 2026-05-12
**Status:** Approved
**Language:** TypeScript / Node.js
**SDK:** `@github/copilot-sdk`
**Extends:** `2026-05-12-multi-agent-registry-design.md`

## Problem

The existing `AgentRegistry` runs all agents in a single process on one machine. Users with three separate machines each running a Copilot session need agents to discover each other and exchange messages across the network.

## Goals

- A dedicated registry server holds the agent roster and per-agent message queues.
- Each machine runs an `AgentClient` that registers itself, polls for messages, and processes them through a local `CopilotSession`.
- Any machine can originate a task at any time.
- Agents delegate work via the existing `send_to_agent` tool concept, but routed over HTTP.
- The existing single-process `AgentRegistry` is unchanged.

## Non-Goals

- Cross-process persistence (state is in-memory; agents re-register on restart).
- Authentication (trusted internal network assumed).
- WebSocket or webhook delivery (polling is sufficient).
- Bounded queue sizes / back-pressure.

## Architecture

```
Machine A             Machine B             Machine C
┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│ AgentClient  │      │ AgentClient  │      │ AgentClient  │
│  "researcher"│      │  "writer"    │      │  "orchestrat"│
│  CopilotSess.│      │  CopilotSess.│      │  CopilotSess.│
│  polls /msgs │      │  polls /msgs │      │  polls /msgs │
└──────┬───────┘      └──────┬───────┘      └──────┬───────┘
       │  HTTP REST          │                     │
       └────────────┬────────┘─────────────────────┘
                    │
          ┌─────────▼──────────┐
          │  RegistryServer    │
          │  POST /agents      │
          │  DELETE /agents/:n │
          │  GET  /agents      │
          │  POST /messages/:n │
          │  GET  /messages/:n │
          └────────────────────┘
```

## Components

### RegistryServer (`src/registry-server.ts`)

Lightweight Express HTTP server. No Copilot dependency. All state is in-memory.

**In-memory state:**
```
agents: Map<name, { name, responsibilities }>
queues: Map<name, string[]>
```

**Endpoints:**

| Method | Path | Body | Response | Notes |
|--------|------|------|----------|-------|
| `POST` | `/agents` | `{ name, responsibilities }` | 201 / 409 | Register; 409 on duplicate |
| `DELETE` | `/agents/:name` | — | 204 / 404 | Remove agent + queue |
| `GET` | `/agents` | — | `[{ name, responsibilities }]` | Roster snapshot |
| `POST` | `/messages/:name` | `{ message }` | 202 / 404 | Enqueue; 404 if unknown |
| `GET` | `/messages/:name` | — | `{ messages: string[] }` | Atomically dequeue all pending |

Started via `npm run registry` (listens on `PORT` env var, default 3000).

### AgentClient (`src/agent-client.ts`)

Runs on each agent machine. Constructor options:

```ts
interface AgentClientOptions {
  registryUrl: string;       // e.g. "http://registry-host:3000"
  name: string;              // unique agent name
  responsibilities: string;  // one-line description shown to peers
  systemPrompt: string;      // appended to this agent's system message
  pollIntervalMs?: number;   // default 2000
}
```

**Lifecycle (`start()`):**
1. `POST /agents` — register self; throw on 409.
2. `GET /agents` — fetch roster; build peer-awareness block (same format as `AgentRegistry`).
3. Create `CopilotSession` with:
   - `systemMessage.content` = `${systemPrompt}\n\n${peerBlock}`
   - `tools` = `[send_to_agent]` — POSTs to `POST /messages/:to`; returns `"Message queued to <to>."`.
4. Start poll loop: every `pollIntervalMs`, call `GET /messages/:name`, process each message through `session.sendAndWait()` sequentially.

**Lifecycle (`stop()`):**
1. Cancel poll loop.
2. `DELETE /agents/:name`.
3. `session.disconnect()`.

Registers SIGINT/SIGTERM handlers to call `stop()` automatically.

### send_to_agent Tool

Registered on the `CopilotSession` at `start()`:

- **Name:** `send_to_agent`
- **Parameters:** `{ to: string, message: string }`
- **Description:** includes live peer roster so LLM knows valid targets.
- **Handler:** `POST /messages/:to` to the registry server; returns `"Message queued to <to>."`. On 404, returns `"Unknown agent: <to>."` (no throw — lets LLM recover).
- **`skipPermission: true`**

### Data Flow

```
AgentClient("orchestrator").send("Write a blog post about AI agents")
→ poll loop picks up message
→ session.sendAndWait(...)
→ LLM calls send_to_agent { to:"researcher", message:"Find AI trends 2025" }
→ POST /messages/researcher → queue
→ researcher polls, picks up message
→ session.sendAndWait(...)
→ LLM calls send_to_agent { to:"writer", message:"Draft blog with: ..." }
→ POST /messages/writer → queue
→ writer polls, picks up message → done
```

## File Layout

```
src/
  agent-registry.ts           existing — unchanged
  example.ts                  existing — unchanged
  registry-server.ts          NEW — Express HTTP server
  agent-client.ts             NEW — per-machine agent runner
  example-distributed.ts      NEW — usage example for distributed setup
```

**package.json scripts added:**
```json
"registry": "node dist/registry-server.js",
"agent":    "node dist/agent-client.js"
```

**New dependency:** `express` + `@types/express`

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Duplicate agent name on register | Server: 409. Client: throws `Error` synchronously. |
| `send_to_agent` targets unknown agent | Server: 404. Tool handler: returns error string to LLM (no throw). |
| Registry unreachable during poll | Log to stderr, skip interval, retry next tick. |
| `sendAndWait` throws | Log to stderr, continue polling next message. |
| Agent restarts | Re-registers (`POST /agents`). Old queue is discarded on `DELETE`, or a new queue starts fresh. |
| Registry restarts | All agents detect 404/connection-refused on next poll, log error. Re-registration happens on next `start()`. |

## Usage

**Machine 0 (registry server):**
```bash
PORT=3000 npm run registry
```

**Machine A:**
```bash
REGISTRY_URL=http://machine0:3000 \
AGENT_NAME=researcher \
AGENT_RESPONSIBILITIES="Finds and summarizes information" \
npm run agent
```

**Machine B / C:** same pattern with different env vars.

Or use `AgentClient` programmatically:
```ts
const client = new AgentClient({
  registryUrl: "http://machine0:3000",
  name: "researcher",
  responsibilities: "Finds and summarizes information on a topic",
  systemPrompt: "You are a research expert. Forward findings to the writer.",
  pollIntervalMs: 2000,
});
await client.start(); // blocks until stop() or signal
```
