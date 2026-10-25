# Phase 11 - DevSecOps: Notes

## Security gates in CI (.github/workflows/ci.yml)
- Secret scanning: Gitleaks scans the full Git history on every PR and push. The image build waits for it.
- Dependency scanning: pip-audit on runtime requirements.
- Container image scanning: Trivy on both images (HIGH/CRITICAL, fixable only).
- Lint: hadolint on Dockerfiles, flake8 on Python.

## Findings and how they were addressed
1. Vulnerable dependency (pip-audit): Flask 3.1.2 had PYSEC-2026-2151. Fixed by upgrading to 3.1.3.
   The gate blocked the PR until fixed.
2. Vulnerable base image (Trivy): the nginx-unprivileged:1.27-alpine image carried 41 HIGH/CRITICAL CVEs
   (openssl, libexpat, libpng, libxml2, musl, zlib). All had fixes. Fixed with "apk upgrade --no-cache" at build time.
3. Supply-chain compromise of a CI tool: trivy-action tags were overwritten in March 2026 and the old tag no longer
   resolved. Fixed by pinning third-party actions to full commit SHAs (Trivy v0.36.0, Gitleaks v3.0.0).
   Also moved from gitleaks-action v2 (broken after the Node 20 removal on 16 Sep 2026) to v3.
4. Over-privileged pods: every pod mounted a default Kubernetes API token. Fixed with dedicated ServiceAccounts,
   automountServiceAccountToken false, capabilities dropped (ALL) and seccomp RuntimeDefault.
   Verified: no token directory inside the backend container.
5. Credentials: the database password and DATABASE_URL live in a Kubernetes Secret created with
   "kubectl create secret" from a random value (openssl rand -hex 12). Nothing is stored in Git (confirmed by Gitleaks).
   Known limitation: Kubernetes Secrets are base64-encoded, not encrypted, and etcd encryption is not enabled on Minikube.
   A production fix would be Sealed Secrets or an external secret manager.

## Least privilege and RBAC
- Role shopflow-viewer: read-only on pods, logs, services, configmaps, events, deployments, statefulsets.
  It cannot read Secrets or modify anything. Checked with "kubectl auth can-i".

## Network exposure
- Only the frontend Service is exposed (NodePort). Backend, Postgres and Redis are ClusterIP only.
- NetworkPolicies were not added: the default Minikube network plugin does not enforce them.

## Non-root
- Backend runs as uid 1000, frontend as uid 101, both with allowPrivilegeEscalation false.
no
