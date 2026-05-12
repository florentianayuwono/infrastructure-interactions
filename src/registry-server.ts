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
