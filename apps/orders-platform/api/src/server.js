import express from "express";
import pg from "pg";
import { createClient } from "redis";

const PORT = Number(process.env.PORT ?? 3000);
const STREAM = process.env.ORDERS_STREAM ?? "orders";

const db = new pg.Pool({ connectionString: process.env.DATABASE_URL });
const redis = createClient({ url: process.env.REDIS_URL });
redis.on("error", (err) => console.error("redis error:", err.message));

await redis.connect();
// v0: the API owns the schema. Proper migrations come later.
// The advisory lock keeps several replicas starting at once from racing on CREATE TABLE.
await migrate();

async function migrate() {
  const client = await db.connect();
  try {
    await client.query("BEGIN");
    await client.query("SELECT pg_advisory_xact_lock(hashtext('orders-schema'))");
    await client.query(`
      CREATE TABLE IF NOT EXISTS orders (
        id         SERIAL PRIMARY KEY,
        item       TEXT        NOT NULL,
        quantity   INTEGER     NOT NULL CHECK (quantity > 0),
        status     TEXT        NOT NULL DEFAULT 'pending',
        created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )
    `);
    await client.query("COMMIT");
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    client.release();
  }
}

const app = express();
app.use(express.json());

// Liveness: the process answers.
app.get("/healthz", (_req, res) => res.json({ status: "ok" }));

// Readiness: dependencies answer.
app.get("/readyz", async (_req, res) => {
  try {
    await Promise.all([db.query("SELECT 1"), redis.ping()]);
    res.json({ status: "ready" });
  } catch (err) {
    res.status(503).json({ status: "not ready", error: err.message });
  }
});

app.get("/api/orders", async (_req, res) => {
  const { rows } = await db.query("SELECT * FROM orders ORDER BY id DESC LIMIT 50");
  res.json(rows);
});

app.get("/api/orders/:id", async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id < 1) return res.status(400).json({ error: "invalid id" });
  const { rows } = await db.query("SELECT * FROM orders WHERE id = $1", [id]);
  if (rows.length === 0) return res.status(404).json({ error: "order not found" });
  res.json(rows[0]);
});

app.post("/api/orders", async (req, res) => {
  const { item, quantity } = req.body ?? {};
  if (typeof item !== "string" || item.trim() === "" || item.length > 100) {
    return res.status(400).json({ error: "item must be a non-empty string (max 100 chars)" });
  }
  if (!Number.isInteger(quantity) || quantity < 1 || quantity > 1000) {
    return res.status(400).json({ error: "quantity must be an integer between 1 and 1000" });
  }
  const { rows } = await db.query(
    "INSERT INTO orders (item, quantity) VALUES ($1, $2) RETURNING *",
    [item.trim(), quantity],
  );
  await redis.xAdd(STREAM, "*", { order_id: String(rows[0].id) });
  console.log(`order ${rows[0].id} queued`);
  res.status(201).json(rows[0]);
});

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: "internal error" });
});

const server = app.listen(PORT, () => console.log(`orders-api listening on :${PORT}`));

// Graceful shutdown: Docker and Kubernetes send SIGTERM before killing the pod.
process.on("SIGTERM", () => {
  console.log("SIGTERM received, shutting down");
  server.close(async () => {
    await Promise.allSettled([db.end(), redis.quit()]);
    process.exit(0);
  });
});
