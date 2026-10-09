# Phase 1 — Fork, Inspect, Run Locally: Notes

## What the starter provided

- Flask backend (`application/backend/app.py`): products, orders, `/health`,
  `/ready` (checks Postgres + Redis).
- Static HTML/JS frontend (`application/frontend/index.html`).
- A small pytest smoke suite.
- Explicitly **no** Dockerfiles, Compose file, Kubernetes manifests, CI,
  Terraform, Ansible, or monitoring config — by design, per the starter
  README. All of that is this repository's own work (see `docker/`, `k8s/`,
  `.github/workflows/`, `terraform/`, `ansible/`, `monitoring/`).

## Problem 1 — missing `/metrics` endpoint

The assignment's business-application list (and the observability phase)
both require `GET /metrics` exposing Prometheus-format metrics, but the
starter `app.py` had no such route and no `prometheus_client` dependency.

**Resolution:** added `prometheus-flask-exporter` to `requirements.txt` and
instrumented the app with `PrometheusMetrics(app)` in `app.py`. This adds a
`/metrics` endpoint and automatically tracks `flask_http_request_total` and
`flask_http_request_duration_seconds`, labeled by method, path and status —
which covers the Phase 9 minimums (request count/rate, latency, HTTP
errors) without hand-rolling metric names.

## Problem 2 — no way to initialize the database on container start

`app.py` only runs `db.create_all()` when executed directly
(`if __name__ == '__main__'`), but the production entrypoint is `gunicorn`,
which imports the module without running that block. Without it, the first
request against an empty database would fail.

**Resolution:** added `application/backend/entrypoint.sh`, which runs
`flask --app app init-db` (idempotent — only creates missing tables) before
starting gunicorn. A `SEED_DB=true` environment variable optionally also
runs `flask --app app seed`; this is set in `docker/docker-compose.yml` for
local convenience and intentionally left unset in the Kubernetes manifests.

## Verification (fill in after running `docker compose up --build`)

```bash
cd docker
docker compose up --build
docker compose ps
```

```
# TODO: paste `docker compose ps` output here — all four services Up/healthy
```

```bash
curl http://localhost:5000/health
curl http://localhost:5000/ready
curl http://localhost:5000/metrics | head -20
curl http://localhost:5000/api/products
```

```
# TODO: paste each command's output here
```

Screenshot evidence: `screenshots/phase1/` (compose up output, `docker compose ps`,
the frontend at http://localhost:8080 showing seeded products, and `/metrics`
output).
