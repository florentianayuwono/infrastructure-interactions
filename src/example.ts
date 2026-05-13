/**
 * Example: three-agent pipeline — orchestrator → researcher → writer
 *
 * Run with:
 *   npm run example
 */
import { CopilotClient } from "@github/copilot-sdk";
import { AgentRegistry } from "./agent-registry.js";

async function main() {
  const client = new CopilotClient();
  await client.start();

  const registry = new AgentRegistry(client);

  registry.register(
    "orchestrator",
    "Breaks down high-level tasks and delegates to specialist agents",
    `You are an orchestrator. When you receive a task, break it down and delegate to specialist agents using send_to_agent. Do not do the work yourself.`,
  );

  registry.register(
    "researcher",
    "Finds and summarizes information on a topic",
    `You are a research specialist. When you receive a research request, find relevant information and summarize it clearly. When done, send your findings to the writer agent via send_to_agent.`,
  );

  registry.register(
    "writer",
    "Drafts polished content from research notes or outlines",
    `You are a professional writer. When you receive research notes or an outline, draft polished content based on them. Print the final result to the conversation.`,
  );

  await registry.start();

  console.log("Registry started. Sending initial task to orchestrator...\n");

  // Kick off the pipeline
  registry.send("orchestrator", "Write a short blog post about the latest trends in AI agents.");

  // Give agents time to process. In production you would hook into session events.
  await new Promise((resolve) => setTimeout(resolve, 60_000));

  console.log("\nDisposing registry...");
  await registry.dispose();
  await client.stop();
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
