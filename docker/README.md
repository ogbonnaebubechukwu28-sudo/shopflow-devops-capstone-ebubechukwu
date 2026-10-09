# Docker / Local Development

Runs the full stack (frontend, backend, PostgreSQL, Redis) with Docker Compose.

## Run it

```bash
cd docker
docker compose up --build
```

First start seeds three sample products (`SEED_DB=true` in `docker-compose.yml`,
dev-only — leave unset in Kubernetes).

## Verify

```bash
docker compose ps
curl http://localhost:5000/health
curl http://localhost:5000/ready
curl http://localhost:5000/metrics
curl http://localhost:5000/api/products
```

Open the frontend at http://localhost:8080 — it calls the backend through
nginx's `/api/` reverse proxy (see `application/frontend/nginx.conf`), not
directly, so it works the same way it will later behind a Kubernetes Service.

## Stop

```bash
docker compose down        # keep the Postgres volume (data persists)
docker compose down -v     # also delete the Postgres volume
```

## Images

| Service  | Dockerfile                          | Base image                        | Runs as |
|----------|--------------------------------------|------------------------------------|---------|
| backend  | `application/backend/Dockerfile`     | `python:3.12-slim`                 | uid 1000 (non-root) |
| frontend | `application/frontend/Dockerfile`    | `nginxinc/nginx-unprivileged:1.27-alpine` | non-root, port 8080 |
| db       | `postgres:16-alpine` (official)      | —                                   | — |
| cache    | `redis:7-alpine` (official)          | —                                   | — |

Both app images are pinned to explicit version tags (`1.0.0`), not `latest`.
