import { fileURLToPath } from "url";
import { CopilotClient, CopilotSession, approveAll, defineTool } from "@github/copilot-sdk";
import { z } from "zod";

export interface AgentClientOptions {
  registryUrl: string;
  name: string;
  responsibilities: string;
  /** Appended to the system message when creating a new session. Ignored when hooking an existing session. */
  systemPrompt: string;
  pollIntervalMs?: number;
  /**
   * Connect to an already-running Copilot CLI server instead of spawning a new process.
   * Format: "localhost:8080" or "http://127.0.0.1:8080".
   *
   * When set, the agent hooks into your existing session (foreground session in TUI, or
   * most-recently-modified session as fallback). The send_to_agent tool is injected into
   * that session so the LLM can delegate work to other registry agents.
   *
   * The Copilot CLI must be running in server mode:
   *   copilot --ui-server       (recommended — exposes foreground session API)
   *   copilot --server          (server only, no TUI)
   */
  copilotCliUrl?: string;
  /**
   * Pass --yolo (--allow-all) to the spawned Copilot CLI process so the agent
   * can execute tools without confirmation prompts. Only applies in spawn mode
   * (ignored when copilotCliUrl is set, since the CLI is already running).
   * @default false
   */
  yolo?: boolean;
}

export class AgentClient {
  private readonly _registryUrl: string;
  private readonly _name: string;
  private readonly _responsibilities: string;
  private readonly _systemPrompt: string;
  private readonly _pollIntervalMs: number;
  private readonly _copilotCliUrl: string | undefined;
  private readonly _copilotClient: CopilotClient;
  private _pollTimer: ReturnType<typeof setInterval> | null = null;
  private _stopping = false;

  constructor(opts: AgentClientOptions) {
    this._registryUrl = opts.registryUrl;
    this._name = opts.name;
    this._responsibilities = opts.responsibilities;
    this._systemPrompt = opts.systemPrompt;
    this._pollIntervalMs = opts.pollIntervalMs ?? 2000;
    this._copilotCliUrl = opts.copilotCliUrl;

    if (opts.copilotCliUrl) {
      this._copilotClient = new CopilotClient({ cliUrl: opts.copilotCliUrl });
    } else {
      const cliArgs = opts.yolo ? ["--yolo"] : [];
      this._copilotClient = new CopilotClient(cliArgs.length ? { cliArgs } : {});
    }
  }

  async start(): Promise<void> {
    await this._copilotClient.start();

    // 1. Fetch peer roster BEFORE registering — avoids a phantom registration
    //    if session creation/hookup fails or hangs.
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

    const sendToAgentTool = defineTool("send_to_agent", {
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
    });

    // 2. Get or create session BEFORE registering.
    const session = this._copilotCliUrl
      ? await this._hookExistingSession(sendToAgentTool, peerBlock)
      : await this._copilotClient.createSession({
          onPermissionRequest: approveAll,
          systemMessage: {
            content: `${this._systemPrompt}\n\n${peerBlock}`.trim(),
          },
          tools: [sendToAgentTool],
        });

    // 3. Register NOW — session is live and poll loop is about to start.
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

    const mode = this._copilotCliUrl ? `hooked into existing CLI at ${this._copilotCliUrl}` : "new session";
    console.log(
      `[AgentClient] "${this._name}" started (${mode}) — polling ${this._registryUrl} every ${this._pollIntervalMs}ms`,
    );
  }

  /**
   * Hook into an already-running Copilot CLI session.
   *
   * Priority:
   *   1. Foreground session (requires CLI running with --ui-server)
   *   2. Most recently modified session from listSessions()
   *   3. New session as fallback (CLI is running but has no sessions yet)
   *
   * The send_to_agent tool and peer-awareness block are injected via resumeSession,
   * leaving the existing session's persona and history intact.
   */
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  private async _hookExistingSession(
    sendToAgentTool: ReturnType<typeof defineTool<any>>,
    peerBlock: string,
  ): Promise<CopilotSession> {
    let sessionId: string | undefined;

    // Try foreground session first (only works with --ui-server)
    try {
      sessionId = await this._copilotClient.getForegroundSessionId() ?? undefined;
      if (sessionId) {
        console.log(`[AgentClient:${this._name}] Hooking into foreground session ${sessionId}`);
      }
    } catch {
      // getForegroundSessionId is only available in --ui-server mode; fall through
    }

    // Fall back to most recently modified session
    if (!sessionId) {
      const sessions = await this._copilotClient.listSessions();
      sessions.sort((a, b) => b.modifiedTime.getTime() - a.modifiedTime.getTime());
      sessionId = sessions[0]?.sessionId;
      if (sessionId) {
        console.log(`[AgentClient:${this._name}] Hooking into most recent session ${sessionId}`);
      }
    }

    if (sessionId) {
      return this._copilotClient.resumeSession(sessionId, {
        onPermissionRequest: approveAll,
        tools: [sendToAgentTool],
        // Append peer awareness without overwriting the existing system prompt
        systemMessage: peerBlock
          ? { mode: "append", content: `\n\n${peerBlock}` }
          : undefined,
      });
    }

    // No existing session found — create a fresh one
    console.log(`[AgentClient:${this._name}] No existing session found, creating new session`);
    return this._copilotClient.createSession({
      onPermissionRequest: approveAll,
      systemMessage: { content: `${this._systemPrompt}\n\n${peerBlock}`.trim() },
      tools: [sendToAgentTool],
    });
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
  const { spawn } = await import("node:child_process");
  const { createServer } = await import("node:net");

  const registryUrl = process.env["REGISTRY_URL"];
  const name = process.env["AGENT_NAME"];
  const responsibilities = process.env["AGENT_RESPONSIBILITIES"];
  const systemPrompt =
    process.env["AGENT_SYSTEM_PROMPT"] ?? `You are an agent named ${name}.`;
  const pollIntervalMs = parseInt(process.env["POLL_INTERVAL_MS"] ?? "2000", 10);
  const yolo = process.env["YOLO"] === "1" || process.env["YOLO"] === "true";

  if (!registryUrl || !name || !responsibilities) {
    console.error(
      "Usage: REGISTRY_URL=<url> AGENT_NAME=<name> AGENT_RESPONSIBILITIES=<desc> npm run agent\n" +
      "       COPILOT_CLI_URL=localhost:8080  (optional — hook into existing Copilot CLI)\n" +
      "       YOLO=1                          (optional — allow all tools without confirmation)",
    );
    process.exit(1);
  }

  // Resolve the CLI URL: use an existing CLI if provided, otherwise spawn a
  // new `copilot --ui-server` process so the user gets an interactive TUI.
  let copilotCliUrl = process.env["COPILOT_CLI_URL"];
  let spawnedCli: ReturnType<typeof spawn> | null = null;

  if (!copilotCliUrl) {
    // Find a free TCP port for the CLI server.
    const port = await new Promise<number>((resolve, reject) => {
      const s = createServer();
      s.listen(0, "127.0.0.1", () => {
        const addr = s.address() as { port: number };
        s.close(() => resolve(addr.port));
      });
      s.on("error", reject);
    });

    copilotCliUrl = `localhost:${port}`;

    console.log(`[AgentClient] Starting Copilot UI server on port ${port}...`);
    console.log(`[AgentClient] To hook another agent into this session, run in a new terminal:`);
    console.log(`  COPILOT_CLI_URL=localhost:${port} REGISTRY_URL=${registryUrl} AGENT_NAME=<name> AGENT_RESPONSIBILITIES=<desc> npm run agent`);
    console.log();

    const cliArgs = ["--ui-server", "--port", String(port), "--no-auto-update"];
    if (yolo) cliArgs.push("--yolo");

    spawnedCli = spawn("copilot", cliArgs, { stdio: "inherit" });

    spawnedCli.on("exit", (code) => {
      process.exit(code ?? 0);
    });

    // Give the CLI server time to bind its port before connecting.
    await new Promise<void>((resolve) => setTimeout(resolve, 2000));
  }

  const client = new AgentClient({
    registryUrl,
    name,
    responsibilities,
    systemPrompt,
    pollIntervalMs,
    copilotCliUrl,
    yolo,
  });

  // If we spawned the CLI, make sure it's cleaned up when the agent exits.
  if (spawnedCli) {
    const origExit = process.exit.bind(process);
    process.exit = ((code?: number) => {
      spawnedCli?.kill();
      origExit(code);
    }) as typeof process.exit;
  }

  client.start().catch((err: unknown) => {
    console.error("Fatal:", err);
    process.exit(1);
  });
}
