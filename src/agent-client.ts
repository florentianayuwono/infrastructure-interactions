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

    // 1. Fetch peer roster BEFORE registering — avoids a phantom registration
    //    if session creation fails or hangs (Copilot not authenticated, CLI down, etc.)
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

    // 2. Create CopilotSession BEFORE registering — if this hangs or throws
    //    (unauthenticated, CLI not running), the agent won't appear in the registry
    //    with no poll loop to service it.
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

    // 3. Register NOW — session is live and poll loop is about to start,
    //    so any message enqueued immediately after this will be consumed.
    const regRes = await fetch(`${this._registryUrl}/agents`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        name: this._name,
        responsibilities: this._responsibilities,
      }),
    });
    if (regRes.status === 409) {
      await session.disconnect();
      throw new Error(`Agent "${this._name}" is already registered at ${this._registryUrl}`);
    }
    if (!regRes.ok) {
      await session.disconnect();
      throw new Error(
        `Failed to register agent "${this._name}": ${regRes.status} ${await regRes.text()}`,
      );
    }

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
            console.error(`[AgentClient:${this._name}] Poll error: HTTP ${r.status}`);
            return;
          }
          const { messages } = (await r.json()) as { messages: string[] };
          for (const msg of messages) {
            try {
              await session.sendAndWait({ prompt: msg });
            } catch (err) {
              console.error(`[AgentClient:${this._name}] sendAndWait error:`, err);
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
  const systemPrompt =
    process.env["AGENT_SYSTEM_PROMPT"] ?? `You are an agent named ${name}.`;
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
