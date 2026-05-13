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
  console.log(
    "NOTE: Start the registry server first in another terminal: PORT=3000 npm run registry\n",
  );

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

  // Start all agents (each registers itself with the registry)
  await orchestrator.start();
  await researcher.start();
  await writer.start();

  console.log("\nAll agents started. Sending task to orchestrator via registry...\n");

  // Kick off the pipeline by posting a message directly to the registry
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
