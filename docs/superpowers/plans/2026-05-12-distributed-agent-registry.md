# Distributed Agent Registry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `RegistryServer` (HTTP server) and `AgentClient` (per-machine agent runner) so Copilot agents on separate machines can discover each other and exchange messages via a central REST registry.

**Architecture:** A dedicated `RegistryServer` (Express) holds the agent roster and per-agent message queues in memory. Each machine runs an `AgentClient` that registers on startup, polls for incoming messages, and processes them through its own `CopilotSession`. Agents delegate work to each other by calling a `send_to_agent` tool that POSTs to the registry.

**Tech Stack:** TypeScript/ESM, Node.js 18+, `@github/copilot-sdk`, `express`, `zod`

---

### Task 1: Add express dependency

**Files:**
- Modify: `package.json`

- [ ] **Step 1: Add express to dependencies**

Edit `package.json` — add to `"dependencies"` and `"devDependencies"`:

```json
{
  "dependencies": {
    "@github/copilot-sdk": "^0.3.0",
    "express": "^4.21.0",
    "zod": "^4.3.6"
  },
  "devDependencies": {
    "@types/express": "^4.17.21",
    "@types/node": "^22.0.0",
    "typescript": "^5.5.0"
  }
}
```

- [ ] **Step 2: Install**

```bash
npm install --legacy-peer-deps
```

Expected: `added N packages` with no errors.

- [ ] **Step 3: Commit**

```bash
git add package.json package-lock.json
git commit -m "chore: add express dependency for registry server"
```

---

### Task 2: Implement RegistryServer

**Files:**
- Create: `src/registry-server.ts`

- [ ] **Step 1: Create `src/registry-server.ts`**

```typescript
import express, { Request, Response } from "express";

interface AgentRecord {
  name: string;
  responsibilities: string;
}

const agents = new Map<string, AgentRecord>();
const queues = new Map<string, string[]>();

const app = express();
app.use(express.json());

// POST /agents — register a new agent
app.post("/agents", (req: Request, res: Response) => {
  const { name, responsibilities } = req.body as {
    name?: string;
    responsibilities?: string;
  };
  if (!name || !responsibilities) {
    res.status(400).json({ error: "name and responsibilities are required" });
    return;
  }
  if (agents.has(name)) {
    res.status(409).json({ error: `Agent "${name}" already registered` });
    return;
  }
  agents.set(name, { name, responsibilities });
  queues.set(name, []);
  res.status(201).json({ name });
});

// DELETE /agents/:name — deregister an agent
app.delete("/agents/:name", (req: Request, res: Response) => {
  const { name } = req.params;
  if (!agents.has(name)) {
    res.status(404).json({ error: `Unknown agent "${name}"` });
    return;
  }
  agents.delete(name);
  queues.delete(name);
  res.status(204).send();
});

// GET /agents — list all registered agents
app.get("/agents", (_req: Request, res: Response) => {
  res.json(Array.from(agents.values()));
});

// POST /messages/:name — enqueue a message for an agent
app.post("/messages/:name", (req: Request, res: Response) => {
  const { name } = req.params;
  const { message } = req.body as { message?: string };
  if (!agents.has(name)) {
    res.status(404).json({ error: `Unknown agent "${name}"` });
    return;
  }
  if (!message) {
    res.status(400).json({ error: "message is required" });
    return;
  }
  queues.get(name)!.push(message);
  res.status(202).json({ queued: true });
});

// GET /messages/:name — atomically dequeue all pending messages
app.get("/messages/:name", (req: Request, res: Response) => {
  const { name } = req.params;
  if (!agents.has(name)) {
    res.status(404).json({ error: `Unknown agent "${name}"` });
    return;
  }
  const messages = queues.get(name)!.splice(0);
  res.json({ messages });
});

const port = parseInt(process.env["PORT"] ?? "3000", 10);
app.listen(port, () => {
  console.log(`[RegistryServer] Listening on port ${port}`);
});
```

- [ ] **Step 2: Build and verify it compiles**

```bash
npm run build
```

Expected: exits 0, `dist/registry-server.js` present, no TypeScript errors.

- [ ] **Step 3: Smoke-test the server (optional but recommended)**

In one terminal:
```bash
node dist/registry-server.js
```

In another:
```bash
# Register an agent
curl -s -X POST http://localhost:3000/agents \
  -H "Content-Type: application/json" \
  -d '{"name":"researcher","responsibilities":"Finds info"}' | cat
# Expected: {"name":"researcher"}

# List agents
curl -s http://localhost:3000/agents | cat
# Expected: [{"name":"researcher","responsibilities":"Finds info"}]

# Enqueue a message
curl -s -X POST http://localhost:3000/messages/researcher \
  -H "Content-Type: application/json" \
  -d '{"message":"Find AI trends"}' | cat
# Expected: {"queued":true}

# Dequeue messages
curl -s http://localhost:3000/messages/researcher | cat
# Expected: {"messages":["Find AI trends"]}

# Second dequeue — queue is now empty
curl -s http://localhost:3000/messages/researcher | cat
# Expected: {"messages":[]}

# Unknown agent — 404
curl -s -o /dev/null -w "%{http_code}" \
  -X POST http://localhost:3000/messages/nobody \
  -H "Content-Type: application/json" \
  -d '{"message":"hello"}'
# Expected: 404
```

Stop the server with Ctrl-C.

- [ ] **Step 4: Commit**

```bash
git add src/registry-server.ts
git commit -m "feat: add RegistryServer HTTP server"
```

---

### Task 3: Implement AgentClient

**Files:**
- Create: `src/agent-client.ts`

- [ ] **Step 1: Create `src/agent-client.ts`**

```typescript
import { fileURLToPath } from "url";
import { CopilotClient, approveAll, defineTool } from "@github/copilot-sdk";
import { z } from "zod";

export interface AgentClientOptions {
  registryUrl: string;
  name: string;
  responsibilities: string;
  systemPrompt: string;
  pollIntervalMs?: number;
}

export class AgentClient {
  private readonly _registryUrl: string;
  private readonly _name: string;
  private readonly _responsibilities: string;
  private readonly _systemPrompt: string;
  private readonly _pollIntervalMs: number;
  private readonly _copilotClient: CopilotClient;
  private _pollTimer: ReturnType<typeof setInterval> | null = null;
  private _stopping = false;

  constructor(opts: AgentClientOptions) {
    this._registryUrl = opts.registryUrl;
    this._name = opts.name;
    this._responsibilities = opts.responsibilities;
    this._systemPrompt = opts.systemPrompt;
    this._pollIntervalMs = opts.pollIntervalMs ?? 2000;
    this._copilotClient = new CopilotClient();
  }

  async start(): Promise<void> {
    await this._copilotClient.start();

    // 1. Register with the registry server
    const regRes = await fetch(`${this._registryUrl}/agents`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        name: this._name,
        responsibilities: this._responsibilities,
      }),
    });
    if (regRes.status === 409) {
      throw new Error(`Agent "${this._name}" is already registered at ${this._registryUrl}`);
    }
    if (!regRes.ok) {
      throw new Error(
        `Failed to register agent "${this._name}": ${regRes.status} ${await regRes.text()}`,
      );
    }

    // 2. Fetch current roster to build peer awareness
    const peersRes = await fetch(`${this._registryUrl}/agents`);
    if (!peersRes.ok) {
      throw new Error(`Failed to fetch agent roster: ${peersRes.status}`);
    }
    const peers = (await peersRes.json()) as Array<{
      name: string;
      responsibilities: string;
    }>;
    const peerBlock = this._buildPeerBlock(peers);
    const peerRosterDesc = peers
      .filter((p) => p.name !== this._name)
      .map((p) => `${p.name} (${p.responsibilities})`)
      .join("; ");

    // 3. Create CopilotSession with send_to_agent tool
    const session = await this._copilotClient.createSession({
      onPermissionRequest: approveAll,
      systemMessage: {
        content: `${this._systemPrompt}\n\n${peerBlock}`.trim(),
      },
      tools: [
        defineTool("send_to_agent", {
          description:
            `Queue a fire-and-forget message to another agent. ` +
            `Available agents: ${peerRosterDesc || "none registered yet"}`,
          parameters: z.object({
            to: z.string().describe("Name of the target agent"),
            message: z.string().describe("Message to send to that agent"),
          }),
          skipPermission: true,
          handler: async ({ to, message }) => {
            try {
              const r = await fetch(
                `${this._registryUrl}/messages/${encodeURIComponent(to)}`,
                {
                  method: "POST",
                  headers: { "Content-Type": "application/json" },
                  body: JSON.stringify({ message }),
                },
              );
              if (r.status === 404) return `Unknown agent: "${to}". Check the agent roster.`;
              if (!r.ok) return `Failed to queue message to "${to}": HTTP ${r.status}`;
              return `Message queued to ${to}.`;
            } catch (err) {
              return `Network error sending to "${to}": ${String(err)}`;
            }
          },
        }),
      ],
    });

    // 4. Graceful shutdown handler
    const shutdown = async () => {
      if (this._stopping) return;
      this._stopping = true;
      console.log(`\n[AgentClient:${this._name}] Shutting down...`);
      if (this._pollTimer !== null) clearInterval(this._pollTimer);
      try {
        await fetch(
          `${this._registryUrl}/agents/${encodeURIComponent(this._name)}`,
          { method: "DELETE" },
        );
      } catch {
        // best-effort deregister
      }
      await session.disconnect();
      await this._copilotClient.stop();
      process.exit(0);
    };

    process.on("SIGINT", () => void shutdown());
    process.on("SIGTERM", () => void shutdown());

    // 5. Poll loop — sequential FIFO processing
    let busy = false;
    this._pollTimer = setInterval(() => {
      if (busy || this._stopping) return;
      busy = true;
      (async () => {
        try {
          const r = await fetch(
            `${this._registryUrl}/messages/${encodeURIComponent(this._name)}`,
          );
          if (!r.ok) {
            console.error(
              `[AgentClient:${this._name}] Poll error: HTTP ${r.status}`,
            );
            return;
          }
          const { messages } = (await r.json()) as { messages: string[] };
          for (const msg of messages) {
            try {
              await session.sendAndWait({ prompt: msg });
            } catch (err) {
              console.error(
                `[AgentClient:${this._name}] sendAndWait error:`,
                err,
              );
            }
          }
        } catch (err) {
          console.error(`[AgentClient:${this._name}] Fetch error:`, err);
        } finally {
          busy = false;
        }
      })();
    }, this._pollIntervalMs);

    console.log(
      `[AgentClient] "${this._name}" started — polling ${this._registryUrl} every ${this._pollIntervalMs}ms`,
    );
  }

  private _buildPeerBlock(
    peers: Array<{ name: string; responsibilities: string }>,
  ): string {
    const others = peers.filter((p) => p.name !== this._name);
    if (others.length === 0) return "";
    const lines = others.map((p) => `- **${p.name}** — ${p.responsibilities}`);
    return `## Available Agents\nYou can delegate work via the send_to_agent tool:\n${lines.join("\n")}`;
  }
}

// ── CLI entry point ──────────────────────────────────────────────────────────
// When run directly (npm run agent), reads config from environment variables.
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const registryUrl = process.env["REGISTRY_URL"];
  const name = process.env["AGENT_NAME"];
  const responsibilities = process.env["AGENT_RESPONSIBILITIES"];
  const systemPrompt = process.env["AGENT_SYSTEM_PROMPT"] ?? `You are an agent named ${name}.`;
  const pollIntervalMs = parseInt(process.env["POLL_INTERVAL_MS"] ?? "2000", 10);

  if (!registryUrl || !name || !responsibilities) {
    console.error(
      "Usage: REGISTRY_URL=<url> AGENT_NAME=<name> AGENT_RESPONSIBILITIES=<desc> npm run agent",
    );
    process.exit(1);
  }

  const client = new AgentClient({
    registryUrl,
    name,
    responsibilities,
    systemPrompt,
    pollIntervalMs,
  });

  client.start().catch((err: unknown) => {
    console.error("Fatal:", err);
    process.exit(1);
  });
}
```

- [ ] **Step 2: Build and verify it compiles**

```bash
npm run build
```

Expected: exits 0, `dist/agent-client.js` present, no TypeScript errors.

- [ ] **Step 3: Commit**

```bash
git add src/agent-client.ts
git commit -m "feat: add AgentClient per-machine agent runner"
```

---

### Task 4: Add npm scripts and example

**Files:**
- Modify: `package.json`
- Create: `src/example-distributed.ts`

- [ ] **Step 1: Add `registry` and `agent` scripts to `package.json`**

Edit the `"scripts"` section of `package.json`:

```json
"scripts": {
  "build": "tsc",
  "example": "npm run build && node dist/example.js",
  "registry": "npm run build && node dist/registry-server.js",
  "agent": "npm run build && node dist/agent-client.js"
}
```

- [ ] **Step 2: Create `src/example-distributed.ts`**

This file shows how to drive the distributed system from a single process (useful for local testing before deploying to separate machines).

```typescript
/**
 * Distributed example — runs registry server + 3 agents in one process for local testing.
 *
 * In production, run each piece on its own machine:
 *
 *   Machine 0:  PORT=3000 npm run registry
 *   Machine A:  REGISTRY_URL=http://machine0:3000 AGENT_NAME=orchestrator \
 *                 AGENT_RESPONSIBILITIES="Breaks down tasks and delegates" \
 *                 npm run agent
 *   Machine B:  REGISTRY_URL=http://machine0:3000 AGENT_NAME=researcher \
 *                 AGENT_RESPONSIBILITIES="Finds and summarizes information" \
 *                 npm run agent
 *   Machine C:  REGISTRY_URL=http://machine0:3000 AGENT_NAME=writer \
 *                 AGENT_RESPONSIBILITIES="Drafts polished content from notes" \
 *                 npm run agent
 *
 * Then send a task to any agent:
 *   curl -X POST http://machine0:3000/messages/orchestrator \
 *     -H "Content-Type: application/json" \
 *     -d '{"message":"Write a blog post about AI agents"}'
 */
import { AgentClient } from "./agent-client.js";

const REGISTRY_URL = "http://localhost:3000";

async function main() {
  console.log("Starting distributed example (local mode)...");
  console.log("NOTE: Start the registry server first: PORT=3000 npm run registry\n");

  const orchestrator = new AgentClient({
    registryUrl: REGISTRY_URL,
    name: "orchestrator",
    responsibilities: "Breaks down high-level tasks and delegates to specialist agents",
    systemPrompt:
      "You are an orchestrator. When you receive a task, break it down and " +
      "delegate to specialist agents using send_to_agent. Do not do the work yourself.",
  });

  const researcher = new AgentClient({
    registryUrl: REGISTRY_URL,
    name: "researcher",
    responsibilities: "Finds and summarizes information on a topic",
    systemPrompt:
      "You are a research specialist. Find relevant information and summarize it " +
      "clearly. When done, send your findings to the writer agent via send_to_agent.",
  });

  const writer = new AgentClient({
    registryUrl: REGISTRY_URL,
    name: "writer",
    responsibilities: "Drafts polished content from research notes or outlines",
    systemPrompt:
      "You are a professional writer. Draft polished content based on the research " +
      "notes you receive. Print the final result to the conversation.",
  });

  // Start all agents (they register themselves with the registry)
  await orchestrator.start();
  await researcher.start();
  await writer.start();

  console.log("\nAll agents started. Sending task to orchestrator via registry...\n");

  // Kick off the pipeline by posting a message to the registry
  await fetch(`${REGISTRY_URL}/messages/orchestrator`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      message: "Write a short blog post about the latest trends in AI agents.",
    }),
  });

  console.log("Task enqueued. Agents are processing (Ctrl+C to stop)...");
}

main().catch((err) => {
  console.error("Fatal:", err);
  process.exit(1);
});
```

- [ ] **Step 3: Build and verify it compiles**

```bash
npm run build
```

Expected: exits 0, `dist/example-distributed.js` present, no TypeScript errors.

- [ ] **Step 4: Commit**

```bash
git add package.json src/example-distributed.ts
git commit -m "feat: add distributed example and npm scripts for registry/agent"
```

---

### Task 5: Update README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add Distributed Usage section to README**

Add the following section after the existing `## Architecture` section in `README.md`:

```markdown
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

Repeat for each agent with different `AGENT_NAME` / `AGENT_RESPONSIBILITIES`.

### 3. Send a Task

From any machine (or a curl call), enqueue a message to any agent:

```bash
curl -X POST http://<registry-host>:3000/messages/researcher \
  -H "Content-Type: application/json" \
  -d '{"message": "Research the latest trends in AI agents."}'
```

### Local Test (all in one process)

To test the distributed flow without multiple machines, start the registry server in one terminal and run the distributed example in another:

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
| `GET` | `/messages/:name` | Dequeue all pending messages (returns `{ messages: string[] }`) |

### AgentClient API

```typescript
import { AgentClient } from "./src/agent-client.js";

const client = new AgentClient({
  registryUrl: "http://registry-host:3000",  // required
  name: "researcher",                         // required
  responsibilities: "Finds info on a topic", // required — shown to peers
  systemPrompt: "You are a research expert.",// required — injected into session
  pollIntervalMs: 2000,                       // optional, default 2000ms
});

await client.start(); // registers, creates session, starts polling — blocks until SIGINT/SIGTERM
```
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add distributed mode usage to README"
```
