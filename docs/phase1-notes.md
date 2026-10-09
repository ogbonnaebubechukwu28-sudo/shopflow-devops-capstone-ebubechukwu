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
`flask_http_request_duration_seconds`, labeled by method, path and status.

## Problem 2 — no way to initialize the database on container start

`app.py` only runs `db.create_all()` when executed directly, but the
production entrypoint is `gunicorn`, which never runs that block.

**Resolution:** added `application/backend/entrypoint.sh`, which runs
`flask --app app init-db` (idempotent) before starting gunicorn. A
`SEED_DB=true` environment variable optionally also runs
`flask --app app seed`; set in `docker-compose.yml` for local convenience
only, left unset in the Kubernetes manifests.

## Problem 3 — unpinned SQLAlchemy pulled in a psycopg v3 dependency

`requirements.txt` pinned `Flask-SQLAlchemy` and `psycopg2-binary` but not
`SQLAlchemy` itself. pip resolved the newest SQLAlchemy release, which
defaults a bare `postgresql://` connection string to the `psycopg` (v3)
driver rather than `psycopg2` (v2) - and `psycopg` v3 wasn't installed.
Result: `ModuleNotFoundError: No module named 'psycopg'` on every backend
start, crash-looping the container.

**Resolution:** pinned `SQLAlchemy==2.0.36` in `requirements.txt` and made
the driver explicit in the connection string (`postgresql+psycopg2://`) in
both `app.py`'s default and `docker-compose.yml`.

## Verification

```
$ docker compose ps
NAME                IMAGE                     STATUS                     PORTS
docker-backend-1    shopflow-api:1.0.0        Up (healthy)               0.0.0.0:5000->5000/tcp
docker-cache-1      redis:7-alpine            Up (healthy)               6379/tcp
docker-db-1         postgres:16-alpine        Up (healthy)               5432/tcp
docker-frontend-1   shopflow-frontend:1.0.0   Up (unhealthy)             0.0.0.0:8080->8080/tcp
```

```
$ curl http://localhost:5000/health
{"status":"healthy"}

$ curl http://localhost:5000/ready
{"database":"ok","redis":"ok","status":"ready"}

$ curl http://localhost:5000/api/products
[{"description":"Multi-port USB-C hub for laptops.","id":3,"name":"USB-C Hub","price":45000.0,"stock":29},
 {"description":"Ergonomic wireless mouse.","id":2,"name":"Wireless Mouse","price":35000.0,"stock":40},
 {"description":"Compact mechanical keyboard for developers.","id":1,"name":"Mechanical Keyboard","price":75000.0,"stock":25}]
```

`/metrics` returns standard Python/process metrics plus Flask request
counters (`flask_http_request_total`, etc.) - confirmed working via browser
and curl.

Frontend container shows `(unhealthy)` in `docker compose ps` despite
serving the page correctly in the browser and via nginx's `/api/` proxy
(confirmed: products load, an order was placed successfully, `POST
/api/orders` returned `201`). Healthcheck command itself needed
investigating - see follow-up fix below.

Screenshot evidence: `screenshots/phase1/` (compose up output, `docker
compose ps`, `/metrics` output, frontend showing seeded products).
