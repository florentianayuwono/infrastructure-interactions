# superpilot

A multi-agent registry built on [`@github/copilot-sdk`](https://www.npmjs.com/package/@github/copilot-sdk) that lets multiple named Copilot agents coexist in a single process, discover each other's responsibilities, and queue work to each other via a `send_to_agent` tool.

## Features

- **Multiple named agents** — each backed by its own `CopilotSession`.
- **Fire-and-forget messaging** — agents queue messages to each other without blocking.
- **LLM-driven delegation** — each agent's LLM can call `send_to_agent` to route work.
- **Peer awareness** — every agent sees its peers and their responsibilities at session start.
- **Sequential per-agent processing** — FIFO queue, one message at a time per agent.

## Installation

### npm dependencies

```bash
npm install
```

### Copilot CLI skills

Install the `starting-registry` and `joining-registry` skills into GitHub Copilot CLI:

```bash
# From GitHub (recommended)
copilot plugin install yanksyoon/superpilot

# Or run the bundled script
./install-skills.sh

# Install from a local checkout instead
./install-skills.sh --local
```

After installation, run `/skills` inside a Copilot CLI session to confirm the skills are available.

## Usage

```typescript
import { CopilotClient } from "@github/copilot-sdk";
import { AgentRegistry } from "./src/agent-registry.js";

const client = new CopilotClient();
await client.start();

const registry = new AgentRegistry(client);

registry.register(
  "researcher",
  "Finds and summarizes information on a topic",
  "You are a research expert. When done, forward your findings to the writer."
);
registry.register(
  "writer",
  "Drafts polished content from research notes",
  "You are a professional writer. Draft content from research notes."
);

await registry.start();

// Kick off the pipeline — fire and forget
registry.send("researcher", "Research the latest trends in AI agents.");

// ...await completion however suits your app, then clean up
await registry.dispose();
await client.stop();
```

## Running the Example

```bash
npm run example
```

The example wires up three agents (orchestrator, researcher, writer) and sends a blog-post task into the pipeline.

## API

### `AgentRegistry`

#### `new AgentRegistry(client: CopilotClient)`

Create a registry backed by an already-started `CopilotClient`.

#### `register(name, responsibilities, systemPrompt): void`

Register a named agent. Must be called before `start()`. Throws on duplicate names.

- `name` — unique agent identifier.
- `responsibilities` — one-line description shown to peer agents.
- `systemPrompt` — additional instructions appended to this agent's system message.

#### `async start(): Promise<void>`

Create sessions for all registered agents, inject peer-awareness system messages, and register the `send_to_agent` tool on every session.

#### `send(to, message): void`

Enqueue a message to the named agent. Returns immediately. Throws if called before `start()` or for an unknown agent name.

#### `async dispose(): Promise<void>`

Disconnect all agent sessions.

#### `agents: Map<string, AgentEntry>`

Live agent entries (populated after `start()`). Each entry exposes `name`, `responsibilities`, `session`, `queue`, and `busy`.

## Architecture

```
AgentRegistry
  register(name, responsibilities, systemPrompt)
  start()    ← creates sessions, injects peers, arms drain loops
  send(to, msg)
  dispose()
  agents: Map<string, AgentEntry>

AgentEntry
  name: string
  responsibilities: string
  session: CopilotSession
  queue: string[]
  busy: boolean
```

Data flow:

```
registry.send("orchestrator", "Write a blog post about AI")
→ enqueue → orchestrator drain
→ LLM calls send_to_agent { to:"researcher", message:"Find AI trends 2025" }
→ enqueue → researcher drain
→ LLM calls send_to_agent { to:"writer", message:"Draft blog with: ..." }
→ enqueue → writer drain → done
```

## Distributed Mode (Multiple Machines)

For agents on separate machines, use `RegistryServer` + `AgentClient` instead of `AgentRegistry`.

### 1. Start the Registry Server

On a dedicated machine (or any reachable host):

```bash
PORT=3000 npm run registry
```

### 2. Start an Agent on Each Machine

On each agent machine, set environment variables and run:

```bash
REGISTRY_URL=http://<registry-host>:3000 \
AGENT_NAME=researcher \
AGENT_RESPONSIBILITIES="Finds and summarizes information on a topic" \
AGENT_SYSTEM_PROMPT="You are a research expert. Forward findings to the writer." \
npm run agent
```

To let the agent run tools without confirmation prompts, add `YOLO=1`:

```bash
REGISTRY_URL=http://<registry-host>:3000 \
AGENT_NAME=researcher \
AGENT_RESPONSIBILITIES="Finds and summarizes information on a topic" \
AGENT_SYSTEM_PROMPT="You are a research expert. Forward findings to the writer." \
YOLO=1 \
npm run agent
```

Repeat for each agent with a different `AGENT_NAME` / `AGENT_RESPONSIBILITIES`.

### 3. Send a Task

From any machine (or a curl call), enqueue a message to any agent:

```bash
curl -X POST http://<registry-host>:3000/messages/researcher \
  -H "Content-Type: application/json" \
  -d '{"message": "Research the latest trends in AI agents."}'
```

### Local Test (all in one process)

Start the registry server in one terminal and the distributed example in another:

```bash
# Terminal 1
PORT=3000 npm run registry

# Terminal 2
npm run build && node dist/example-distributed.js
```

### Registry API

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/agents` | Register `{ name, responsibilities }` |
| `DELETE` | `/agents/:name` | Deregister |
| `GET` | `/agents` | List all agents |
| `POST` | `/messages/:name` | Enqueue `{ message }` for an agent |
| `GET` | `/messages/:name` | Dequeue all pending messages → `{ messages: string[] }` |

### AgentClient API

```typescript
import { AgentClient } from "./src/agent-client.js";

const client = new AgentClient({
  registryUrl: "http://registry-host:3000",   // required
  name: "researcher",                          // required
  responsibilities: "Finds info on a topic",  // required — shown to peers
  systemPrompt: "You are a research expert.", // required — injected into session
  pollIntervalMs: 2000,                        // optional, default 2000ms
  copilotCliUrl: "localhost:8080",             // optional — hook an existing CLI session
  yolo: true,                                  // optional — pass --yolo to spawned CLI (spawn mode only)
});

await client.start(); // registers, creates/hooks session, starts polling — blocks until SIGINT/SIGTERM
```

#### Environment variables (CLI entry point)

| Variable | Required | Description |
|----------|----------|-------------|
| `REGISTRY_URL` | ✅ | URL of the RegistryServer, e.g. `http://host:3000` |
| `AGENT_NAME` | ✅ | Unique agent identifier |
| `AGENT_RESPONSIBILITIES` | ✅ | One-line description shown to peer agents |
| `AGENT_SYSTEM_PROMPT` | — | System prompt injected into a new session (spawn mode only). Defaults to `"You are an agent named <name>."` |
| `COPILOT_CLI_URL` | — | Hook an already-running CLI, e.g. `localhost:8080` (hook mode) |
| `YOLO` | — | Set to `1` or `true` to pass `--yolo` to the spawned CLI (spawn mode only) |
| `POLL_INTERVAL_MS` | — | Poll interval in milliseconds. Default `2000` |
