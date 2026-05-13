# Multi-Agent Registry Design

**Date:** 2026-05-12  
**Status:** Approved  
**Language:** TypeScript / Node.js  
**SDK:** `@github/copilot-sdk`

## Problem

The Copilot SDK supports creating individual `CopilotSession` instances, but provides no built-in way for multiple agents to communicate, discover each other's responsibilities, or queue work to each other. This project introduces a self-contained `AgentRegistry` that solves these problems.

## Goals

- Multiple named agents, each backed by its own `CopilotSession`, coexist in one process.
- Agents queue messages to each other fire-and-forget.
- The LLM inside each agent delegates work via a `send_to_agent` tool.
- Each agent knows peer agents and their responsibilities (agent skills).
- Per-agent message processing is sequential (FIFO queue, one at a time).

## Non-Goals

- Cross-process or distributed agents.
- Synchronous request/response between agents.
- Bounded queue size / back-pressure.
- Unit tests (recipe/example project).

## Architecture

```
AgentRegistry
  register(name, responsibilities, systemPrompt)
  start()    ← finalizes peer awareness
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

## Components

### AgentRegistry (src/agent-registry.ts)

- `register()` — creates a `CopilotSession`, stores `AgentEntry`.
- `start()` — builds `## Available Agents` peer block, sends it as a system message to each session, registers `send_to_agent` tool on every session, arms drain loops.
- `send(to, message)` — enqueues message, calls `_drain(name)`.
- `dispose()` — disposes all sessions.

### Drain Loop

Per agent, an async FIFO loop:
1. Pop message from front of queue.
2. Set `busy = true`, call `session.sendAndWait({ prompt: message })`.
3. Set `busy = false`, repeat.
4. On error: log to stderr, continue.

### send_to_agent Tool

Registered on every session at `start()`:
- Name: `send_to_agent`
- Params: `{ to: string, message: string }`
- Description includes live agent roster so LLM knows valid targets.
- Handler: `registry.send(to, message)`, returns `"Message queued to <to>."`.

### Agent Skills / Peer Awareness

At `start()`, each agent's session receives an additional system message:

```
## Available Agents
You can delegate via send_to_agent:
- **researcher** — Finds and summarizes information on a topic.
- **writer** — Drafts content from research or notes.
```

Each agent sees all peers except itself.

## Data Flow

```
registry.send("orchestrator", "Write a blog post about AI")
→ enqueue → orchestrator drain
→ LLM calls send_to_agent { to:"researcher", message:"Find AI trends 2025" }
→ enqueue → researcher drain
→ LLM calls send_to_agent { to:"writer", message:"Draft blog with: ..." }
→ enqueue → writer drain
→ done
```

## Error Handling

| Scenario | Behavior |
|---|---|
| Unknown agent target | Throws synchronously |
| `send()` before `start()` | Throws synchronously |
| `sendAndWait` error | Logged to stderr, drain continues |
| Duplicate registration | Throws synchronously |

## File Layout

```
superpilot/
  src/
    agent-registry.ts
    example.ts
  package.json
  tsconfig.json
  README.md
```
