git add README.md
git commit -m "docs: remove duplicate branching strategy heading"
git push -u origin fix/readme-duplicate-section# ShopFlow DevOps - Version A

ShopFlow is a small e-commerce application (Flask API + PostgreSQL + Redis +
static frontend). This repository takes it through a full DevOps lifecycle:
containerization, CI, Kubernetes deployment on Minikube, infrastructure
automation, observability, security and reliability practices.

**Track:** A — Local (Minikube). Fully acceptable per the assignment; the
AWS EC2 extension (Track B) is not attempted in this submission.

## 1. Project Overview

_TODO: one paragraph — what ShopFlow does, what this repo demonstrates._

## 2. Environment

| Tool | Version |
|---|---|
| OS | Ubuntu 24.04 (WSL2) |
| Docker | `docker --version` |
| Kubernetes | Minikube, `minikube version` |
| Helm | `helm version --short` |

## 3. Repository Structure

```
shopflow-devops/
├── application/        # Flask backend + static frontend source
│   ├── backend/
│   └── frontend/
├── docker/              # Dockerfiles live with their app; compose + docs here
├── k8s/                 # Kubernetes manifests
├── monitoring/           # Prometheus / Grafana / logging config
├── ansible/              # (Track B) host configuration
├── terraform/             # (Track B) EC2 provisioning
├── scripts/              # operational bash scripts
├── .github/workflows/     # CI pipeline
├── docs/                 # phase-by-phase write-ups, runbook, SLOs
└── architecture-diagram.png
```

## 4. Local Deployment (Docker Compose)

See [`docker/README.md`](docker/README.md).

```bash
cd docker
docker compose up --build
docker compose ps
curl http://localhost:5000/health
curl http://localhost:5000/metrics
```

## 5. Kubernetes Deployment (Minikube)

_TODO — filled in during Phase 5._

## 6. CI/CD

_TODO — filled in during Phase 4._

## 7. Branching Strategy

## Branching Strategy

- main: always deployable, protected, changes only via pull request
- feature/<name>: new work (e.g. feature/add-dockerfile-healthcheck)
- fix/<name>: bug fixes
- Commits use short imperative messages (e.g. "Add healthcheck to backend")
- Every PR needs to pass CI (from Phase 4) before merging

## 8. Monitoring & Logging

_TODO — filled in during Phases 9–10._

## 9. Security

_TODO — filled in during Phase 11._

## 10. GitOps (ArgoCD)

_TODO — filled in during Phase 12._

## 11. Deployment Strategy (Blue-Green / Canary)

_TODO — filled in during Phase 13._

## 12. SLIs, SLOs & Error Budget

_TODO — filled in during Phase 14._

## 13. Incident Response / Runbook

_TODO — filled in during Phase 14-15, see also [`docs/runbook.md`](docs/runbook.md)._

## 14. Failure Testing

_TODO — filled in during Phase 15, see [`docs/failure-testing.md`](docs/failure-testing.md)._

## 15. Lessons Learned

_TODO._

## Problems Encountered

See [`docs/phase1-notes.md`](docs/phase1-notes.md) for issues found while
inspecting and running the starter application, and how they were resolved.
