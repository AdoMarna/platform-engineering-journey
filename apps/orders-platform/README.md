# orders-platform

Reference application of the platform: deliberately small, enriched module after module.

```text
front (nginx) ──/api──► api (Node.js) ──► PostgreSQL
                            │
                            └─ XADD ──► Redis stream ──► worker (Python) ──► PostgreSQL
```

| Service | Stack | Port | Role |
|---|---|---|---|
| `front` | nginx-unprivileged, static HTML | 8080 | UI + reverse proxy `/api/` → API |
| `api` | Node.js 24, Express 5 | 3000 | REST API, owns the DB schema, publishes orders |
| `worker` | Python 3.14, psycopg 3, redis-py | — | Consumes orders (Redis consumer group), updates their status |
| `postgres` | PostgreSQL 18 | — | Orders storage |
| `redis` | Redis 8 | — | `orders` stream |

## Run

```bash
make up                              # build + start, wait until healthy
make order ITEM=mouse QTY=2          # create an order from the CLI
make orders                          # list orders
make clean                           # stop + delete the volume
```

`make` alone lists every target. UI: http://localhost:8080

## API

| Method | Path | Notes |
|---|---|---|
| `GET` | `/healthz` | Liveness (process is up) |
| `GET` | `/readyz` | Readiness (Postgres + Redis reachable), `503` otherwise |
| `GET` | `/api/orders` | Last 50 orders |
| `GET` | `/api/orders/:id` | One order |
| `POST` | `/api/orders` | `{"item": "keyboard", "quantity": 2}` → `201`, status `pending` → `processing` → `completed` |

## Configuration (environment variables)

| Variable | Service | Default |
|---|---|---|
| `DATABASE_URL` | api, worker | — (required) |
| `REDIS_URL` | api, worker | — (required) |
| `ORDERS_STREAM` | api, worker | `orders` |
| `ORDERS_GROUP` | worker | `workers` |
| `PROCESSING_SECONDS` | worker | `2` |
| `RECLAIM_IDLE_MS` | worker | `30000` — an unacknowledged order older than this is taken over by another worker |
| `API_UPSTREAM` | front | `http://api:3000` |
| `PORT` | api | `3000` |

## Built for the next modules

- **Kubernetes-ready:** all config via env vars, `/healthz` + `/readyz` probes, graceful `SIGTERM` shutdown, stateless replicas.
- **Pod Security `restricted`:** every image runs as a numeric non-root UID (api `1000`, worker `10001`, front `101`) and works with `readOnlyRootFilesystem`.
  The front needs two writable `emptyDir` volumes: `/tmp` and `/etc/nginx/conf.d` (the nginx config is rendered from a template at startup).
- **Multiple replicas:** schema creation is guarded by a Postgres advisory lock; workers share a Redis consumer group.
- **Chaos-proof:** an order is acknowledged only once processed; if a worker is killed mid-order, another one reclaims it after `RECLAIM_IDLE_MS`.

Known v0 shortcuts, to be replaced later: schema created by the API at startup (no migration tool), Redis without auth/persistence, local-only default credentials.
