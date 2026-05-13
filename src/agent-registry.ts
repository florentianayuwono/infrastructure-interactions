import { CopilotClient, CopilotSession, approveAll, defineTool } from "@github/copilot-sdk";
import { z } from "zod";

/** A registered agent's runtime state. */
export interface AgentEntry {
  name: string;
  responsibilities: string;
  session: CopilotSession;
  queue: string[];
  busy: boolean;
}

/** Configuration passed to `register()`. Stored until `start()` creates sessions. */
interface AgentRegistration {
  name: string;
  responsibilities: string;
  systemPrompt: string;
}

/**
 * AgentRegistry — orchestrates multiple named Copilot agents in a single process.
 *
 * Typical lifecycle:
 * ```ts
 * const client = new CopilotClient();
 * await client.start();
 *
 * const registry = new AgentRegistry(client);
 * registry.register("researcher", "Finds information on a topic", "You are a research expert.");
 * registry.register("writer", "Drafts content from notes", "You are a skilled writer.");
 * await registry.start();
 *
 * registry.send("researcher", "Find AI trends in 2025");
 *
 * // later...
 * await registry.dispose();
 * await client.stop();
 * ```
 */
export class AgentRegistry {
  /** All live agents, available after `start()`. */
  readonly agents: Map<string, AgentEntry> = new Map();

  private readonly _client: CopilotClient;
  private readonly _registrations: AgentRegistration[] = [];
  private _started = false;

  constructor(client: CopilotClient) {
    this._client = client;
  }

  /**
   * Register a named agent.
   * Must be called before `start()`. Throws on duplicate names.
   */
  register(name: string, responsibilities: string, systemPrompt: string): void {
    if (this._started) {
      throw new Error(`AgentRegistry: cannot register "${name}" after start() has been called`);
    }
    if (this._registrations.some((r) => r.name === name)) {
      throw new Error(`AgentRegistry: duplicate agent name "${name}"`);
    }
    this._registrations.push({ name, responsibilities, systemPrompt });
  }

  /**
   * Finalize peer awareness and create all sessions.
   * After this call, agents can receive messages via `send()`.
   */
  async start(): Promise<void> {
    if (this._started) {
      throw new Error("AgentRegistry: start() has already been called");
    }
    this._started = true;

    for (const reg of this._registrations) {
      const peerBlock = this._buildPeerBlock(reg.name);
      const peerRosterDesc = this._buildPeerRosterDesc(reg.name);

      // Pre-create the entry so the tool handler can reference the registry
      // by the time any session actually invokes send_to_agent.
      const entry: AgentEntry = {
        name: reg.name,
        responsibilities: reg.responsibilities,
        session: undefined as unknown as CopilotSession,
        queue: [],
        busy: false,
      };
      this.agents.set(reg.name, entry);

      const session = await this._client.createSession({
        onPermissionRequest: approveAll,
        systemMessage: {
          content: `${reg.systemPrompt}\n\n${peerBlock}`,
        },
        tools: [
          defineTool("send_to_agent", {
            description:
              `Queue a fire-and-forget message to another agent in this registry. ` +
              `Available agents: ${peerRosterDesc}`,
            parameters: z.object({
              to: z.string().describe("Name of the target agent"),
              message: z.string().describe("Message to send to that agent"),
            }),
            skipPermission: true,
            handler: async ({ to, message }) => {
              this.send(to, message);
              return `Message queued to ${to}.`;
            },
          }),
        ],
      });

      entry.session = session;
    }
  }

  /**
   * Enqueue a message to a named agent and start draining the queue.
   * Fire-and-forget: returns immediately.
   * Throws synchronously if the registry is not started or the agent is unknown.
   */
  send(to: string, message: string): void {
    if (!this._started) {
      throw new Error("AgentRegistry: call start() before send()");
    }
    const entry = this.agents.get(to);
    if (!entry) {
      throw new Error(`AgentRegistry: unknown agent "${to}"`);
    }
    entry.queue.push(message);
    this._drain(to);
  }

  /**
   * Disconnect all sessions. Call when done with the registry.
   */
  async dispose(): Promise<void> {
    for (const entry of this.agents.values()) {
      await entry.session.disconnect();
    }
    this.agents.clear();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /** FIFO drain loop for a single agent. Re-entrant calls are no-ops while busy. */
  private _drain(name: string): void {
    const entry = this.agents.get(name)!;
    if (entry.busy) return;

    entry.busy = true;

    const loop = async () => {
      while (entry.queue.length > 0) {
        const message = entry.queue.shift()!;
        try {
          await entry.session.sendAndWait({ prompt: message });
        } catch (err) {
          console.error(`[AgentRegistry] Error processing message for agent "${name}":`, err);
        }
      }
      entry.busy = false;
    };

    loop().catch((err) => {
      console.error(`[AgentRegistry] Unexpected drain error for agent "${name}":`, err);
      entry.busy = false;
    });
  }

  /** Build the ## Available Agents block seen by agent `forAgent`. */
  private _buildPeerBlock(forAgent: string): string {
    const peers = this._registrations.filter((r) => r.name !== forAgent);
    if (peers.length === 0) return "";
    const lines = peers.map((p) => `- **${p.name}** — ${p.responsibilities}`);
    return `## Available Agents\nYou can delegate work via the send_to_agent tool:\n${lines.join("\n")}`;
  }

  /** One-line peer roster used in the send_to_agent tool description. */
  private _buildPeerRosterDesc(forAgent: string): string {
    return this._registrations
      .filter((r) => r.name !== forAgent)
      .map((r) => `${r.name} (${r.responsibilities})`)
      .join("; ");
  }
}
