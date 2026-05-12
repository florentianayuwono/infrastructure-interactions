# superpilot

A multi-agent registry built on [`@github/copilot-sdk`](https://www.npmjs.com/package/@github/copilot-sdk) that lets multiple named Copilot agents coexist in a single process, discover each other's responsibilities, and queue work to each other via a `send_to_agent` tool.

## Features

- **Multiple named agents** — each backed by its own `CopilotSession`.
- **Fire-and-forget messaging** — agents queue messages to each other without blocking.
- **LLM-driven delegation** — each agent's LLM can call `send_to_agent` to route work.
- **Peer awareness** — every agent sees its peers and their responsibilities at session start.
- **Sequential per-agent processing** — FIFO queue, one message at a time per agent.

## Installation

```bash
npm install
```

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
