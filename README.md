# ShopFlow DevOps Capstone

ShopFlow is a small e-commerce application (Flask API + PostgreSQL + Redis + static frontend). This repository takes it
through a full DevOps lifecycle: containers, CI/CD with security gates, Kubernetes on Minikube, GitOps with Argo CD,
monitoring, blue-green releases, SRE objectives and failure testing.

**Track:** A - Local (Minikube). Track B (AWS EC2, Terraform, Ansible) is not attempted; those folders are placeholders.

## 1. Project Overview

ShopFlow lets a user list products and place orders. The frontend is a static page served by nginx, the backend is a Flask
API (gunicorn) backed by PostgreSQL, and Redis is used as a cache and readiness dependency. The application code is given;
this repository demonstrates everything around it: how it is built, tested, scanned, packaged, deployed, observed, released
and recovered. Each phase has a write-up in `docs/` with the problems found and how they were solved.

### Architecture

```mermaid
flowchart LR
  dev["Developer"] --> pr["Pull request"]
  pr --> ci["GitHub Actions: lint, test, scans, build"]
  ci --> repo[("GitHub repo: k8s/ and gitops/")]
  repo --> argo["Argo CD (core)"]
  user["User"] --> fe["frontend: nginx x2"]
  vercel["Vercel static page"] -. "tunnel, demo only" .-> svc{{"Service: backend"}}
  subgraph shop["Minikube: namespace shopflow"]
    fe --> svc
    svc -->|"selector: backend (blue)"| blue["backend 1.0.1 x2 + HPA + PDB"]
    svc -. "selector: backend-green" .-> green["backend-green 1.0.2"]
    blue --> pg[("PostgreSQL StatefulSet + 1Gi PVC")]
    blue --> redis[("Redis")]
    green --> pg
    green --> redis
  end
  argo -->|"syncs k8s/"| svc
  subgraph mon["namespace monitoring"]
    prom["Prometheus + kube-state-metrics"]
    graf["Grafana (config in Git)"]
  end
  prom -. "scrapes /metrics" .-> blue
  graf --> prom
```

## 2. Environment

| Tool | Version |
|---|---|
| OS | Ubuntu 24.04 (WSL2), about 3.8 GB RAM available to WSL |
| Docker | 29.1.3 |
| Minikube | v1.38.1 (Kubernetes v1.35.1, docker driver) |
| kubectl | v1.31.14 |
| Helm | v3.22.0+g144ca65 |
| Argo CD | v3.5.4 (core install) |
| Prometheus chart | prometheus-community/prometheus 29.34.0 |
| Grafana chart | grafana-community/grafana 13.7.0 |
| Loki and Alloy | grafana-community/loki 18.17.1 (Loki 3.7.8), Alloy v1.21.1 |
| Python / Postgres / Redis / nginx | 3.12 / 16-alpine / 7-alpine / nginx-unprivileged 1.27-alpine |

## 3. Repository Structure

```
shopflow-devops/
|-- application/        Flask backend and static frontend (Dockerfiles live with each app)
|-- docker/             docker-compose.yml, .env.example
|-- k8s/                Kubernetes manifests (namespace, RBAC, config, Postgres, Redis, backend, green, frontend, HPA/PDB)
|-- gitops/             Argo CD AppProject and Application
|-- monitoring/         Prometheus and Grafana values, dashboard JSON
|-- scripts/            start-cluster.sh (cold-start repair)
|-- .github/workflows/  CI pipeline (ci.yml)
|-- docs/               phase write-ups, incident records, evidence files
|-- ansible/, terraform/  Track B placeholders (not used)
```

## 4. Local Deployment (Docker Compose)

See [`docker/README.md`](docker/README.md).

```bash
cd docker
cp .env.example .env
docker compose up -d --build
docker compose ps
curl http://localhost:5000/health
curl http://localhost:5000/ready
```

Images use fixed tags (shopflow-api:1.0.1, shopflow-frontend:1.0.0, postgres:16-alpine, redis:7-alpine), run as non-root,
and have health checks. Details and the problems found are in [`docs/phase3-notes.md`](docs/phase3-notes.md).

## 5. Kubernetes Deployment (Minikube)

```bash
./scripts/start-cluster.sh          # after a PC restart (fixes DNS, waits for Postgres, restarts app pods)
# first time only:
minikube start --driver=docker --cpus=2 --memory=3072
minikube addons enable metrics-server
eval $(minikube docker-env)         # build images inside Minikube
docker build -t shopflow-api:1.0.1 application/backend
docker build -t shopflow-api:1.0.2 application/backend     # green; same source, APP_VERSION set in the manifest
docker build -t shopflow-frontend:1.0.0 application/frontend
kubectl create namespace shopflow
PW=$(openssl rand -hex 12)          # the password never goes into Git
kubectl create secret generic shopflow-secret -n shopflow \
  --from-literal=POSTGRES_PASSWORD="$PW" \
  --from-literal=DATABASE_URL="postgresql+psycopg2://shopflow:${PW}@postgres:5432/shopflow"
unset PW
kubectl apply -f k8s/
kubectl exec -n shopflow deploy/backend -- flask --app app seed
minikube service frontend -n shopflow --url
```

What is deployed: namespace, ConfigMap, Secret (created by hand), PostgreSQL StatefulSet with a 1Gi PersistentVolumeClaim,
Redis, backend (2 replicas) and frontend (2 replicas) Deployments with readiness and liveness probes, CPU and memory
requests and limits, standard labels, a HorizontalPodAutoscaler (2-4 pods at 70% CPU) and a PodDisruptionBudget for the
backend. Full notes: [`docs/phase5-notes.md`](docs/phase5-notes.md).

### Public frontend on Vercel

The static frontend page is also deployed on Vercel: https://shopflow-frontend-orpin.vercel.app/

The backend, database and cache run on the local Minikube cluster, which is not reachable from the internet, so the Vercel
page loads but shows "Unable to load products" unless a temporary tunnel to the backend is connected during a demo.

## 6. CI/CD

Workflow: [`.github/workflows/ci.yml`](.github/workflows/ci.yml), run on every pull request and push to main.

| Job | What it does |
|---|---|
| lint-and-test | flake8, hadolint (both Dockerfiles), pytest smoke tests |
| dependency-scan | pip-audit on runtime requirements |
| secret-scan | Gitleaks over the full Git history |
| build-and-scan-images | builds both images, Trivy scan (HIGH and CRITICAL, fixable) |

The image build waits for the other jobs, and any failed gate fails the pipeline. All four checks are required on `main`.
Third-party actions are pinned to commit SHAs. Failures that were found and fixed (a vulnerable Flask, 41 CVEs in the nginx
base image, a compromised Trivy action tag) are documented in [`docs/phase4-notes.md`](docs/phase4-notes.md).

## 7. Branching Strategy

- `main` is protected: changes arrive only through pull requests, and all CI checks must pass.
- Branch names: `feature/<name>`, `fix/<name>`, `docs/<name>`, `change/<name>`, `release/<name>`, `revert/<name>`, `test/<name>`.
- Commit messages are short and imperative with a prefix (for example `docs:`, `ci:`, `k8s:`, `fix:`).
- A direct push to `main` is rejected (GH013), shown in [`docs/phase2-notes.md`](docs/phase2-notes.md), which also records an
  intentional merge conflict and how it was resolved.

## 8. Monitoring & Logging

**Monitoring (done):** Prometheus (lean install, no Alertmanager or node-exporter) scrapes the backend `/metrics`
(prometheus-flask-exporter), kube-state-metrics and cAdvisor. Four alert rules: BackendHighErrorRate,
BackendHighLatency, PodRestartingFrequently, DeploymentReplicasUnavailable. A 10-panel Grafana dashboard is in
`monitoring/shopflow-dashboard.json`. Notes: [`docs/phase9-notes.md`](docs/phase9-notes.md).

**Honest status:** Grafana 13 could not run reliably in 3.8 GB of memory shared with the whole cluster (very slow start,
killed by probes), so its configuration and dashboard are in Git but Prometheus is the working monitoring system.

**Logging (done):** Loki (single binary, filesystem storage) receives the logs of every pod in the `shopflow` namespace from
Grafana Alloy, with the labels `app`, `pod` and `container`. Because Grafana could not run reliably on this machine, logs are
searched with LogQL through Loki's HTTP API. Queries and results: [`docs/phase10-notes.md`](docs/phase10-notes.md) and
`docs/evidence/loki-query*.txt`. Together they cost about 190 MiB of memory.

## 9. Security

Pipeline scanning (section 6), non-root containers, dropped capabilities and seccomp RuntimeDefault, dedicated service
accounts with no API token mounted, a read-only RBAC role that cannot read Secrets, and no credentials in Git (checked by
Gitleaks). Findings and limits (Secrets are base64, not encrypted, on Minikube): [`docs/phase11-notes.md`](docs/phase11-notes.md).

## 10. GitOps (ArgoCD)

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.4/manifests/core-install.yaml
kubectl apply -f gitops/project.yaml -f gitops/application.yaml
kubectl get application shopflow -n argocd
```

Argo CD core (no UI, chosen for the memory limit) syncs `k8s/` from `main` with automated sync and self-heal (prune off).
Drift detection, self-healing, a Git change and a `git revert` rollback were demonstrated: [`docs/phase12-notes.md`](docs/phase12-notes.md).

## 11. Deployment Strategy (Blue-Green / Canary)

Blue-green: `backend` (blue) and `backend-green` run side by side, and traffic is switched by changing the selector of the
`backend` Service through a pull request. The new version was validated before the switch, the switch caused no failed
requests, and a deliberate failure was rolled back: [`docs/phase13-notes.md`](docs/phase13-notes.md) and
[`docs/incident-2026-10-26-broken-release.md`](docs/incident-2026-10-26-broken-release.md).

## 12. SLIs, SLOs & Error Budget

Availability SLO 99.5% (216 minutes of error budget per 30 days) and latency SLO p95 under 500 ms.
See [`docs/phase14-sre.md`](docs/phase14-sre.md).

## 13. Incident Response / Runbook

Severity levels, ownership and response steps are in [`docs/phase14-sre.md`](docs/phase14-sre.md). Quick runbook:

| Symptom | First checks | Fix |
|---|---|---|
| After a PC restart pods crash-loop or images will not pull | `kubectl get pods -A` | `./scripts/start-cluster.sh` |
| Image pulls fail (name resolution) | `kubectl describe pod` shows lookup errors | set `nameserver 8.8.8.8` in WSL and with `minikube ssh`, delete the stuck pod |
| API returns 500 after a release | `kubectl logs deploy/<backend>`, `git log` on k8s/ | revert the release commit by pull request |
| `/ready` returns 503 | check Redis and Postgres pods | restore the dependency (see failure test 4) |
| HPA shows `<unknown>` or kubectl times out | `kubectl top pods`, wait 2-3 minutes | the machine is overloaded; do not send more commands |

## 14. Failure Testing

Four scenarios (broken release, pod deletion, traffic increase with autoscaling, Redis outage) with measured times:
[`docs/phase15-failure-tests.md`](docs/phase15-failure-tests.md). Raw recordings are in `docs/evidence/`.

## 15. Lessons Learned

- Probes tuned for normal machines kill healthy pods on a small one; raise `timeoutSeconds`.
- Two gunicorn workers made Prometheus counters jump; one worker with threads fixed it.
- A tool can be compromised: pin third-party actions to commit SHAs.
- Start-up order matters (DNS, database, apps); the apps do not wait for their dependencies yet.
- A cache outage should degrade the API, not remove every pod from service.
- A protected branch with mandatory CI makes rollback slow; write a break-glass procedure.
- Known limits: 3.8 GB machine, Grafana not stable, Vercel page needs a tunnel to show data.

## Problems Encountered

Phase notes with the issues found and their fixes: [Phase 1](docs/phase1-notes.md), [Phase 3](docs/phase3-notes.md),
[Phase 4](docs/phase4-notes.md), [Phase 5](docs/phase5-notes.md), [Phase 9](docs/phase9-notes.md), [Phase 10](docs/phase10-notes.md),
[Phase 11](docs/phase11-notes.md), [Phase 12](docs/phase12-notes.md), [Phase 13](docs/phase13-notes.md).
