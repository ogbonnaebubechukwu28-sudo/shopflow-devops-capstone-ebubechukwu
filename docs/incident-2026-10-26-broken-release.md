# Incident 2026-10-26: broken release served to users (deliberate failure test)

Severity: SEV-2 (core endpoint failing for all users, test environment). Detected by: manual watcher, not by an alert.

## Timeline (UTC, Git merge times and watcher output)
- 07:15:33 PR #19 switched live traffic to green (1.0.2). No failed requests.
- 07:24:41 PR #20 merged: SIMULATE_FAILURE=true on green.
- 07:25:43 last successful response. 07:25:45 first FAIL. Failures continued until at least 07:28:50.
- 07:33:09 PR #21 merged (flag disabled on green).
- 07:34:51 PR #22 merged (selector back to blue).
- 07:43:21 watcher confirms OK from blue (1.0.0).

## Symptom
GET /api/products through the live Service returned HTTP 500 for every request. GET /health and /ready still returned 200.

## Detection
A watcher polling the live Service every 2 seconds showed FAIL from 07:25:45. No alert fired because Prometheus is scaled to
zero on this 3.8 GB machine. Time from merge to first visible failure: 64 seconds (Argo CD sync + pod replacement).

## Investigation
- kubectl logs deploy/backend-green: repeated GET /api/products 500 next to kube-probe 200 on /ready and /health.
- Container environment showed SIMULATE_FAILURE=true.
- git log on k8s/45-backend-green.yaml pointed to the commit that changed it.

## Root cause
The configuration flag SIMULATE_FAILURE was set to "true" in Git and rolled out by Argo CD. The readiness probe only tests the
database and Redis, so Kubernetes kept the broken pod in service.

## Mitigation and recovery
1. PR #21 reverted the flag (roll forward). Green healed about a minute after merge.
2. PR #22 reverted the switch, sending traffic to blue (known good, never stopped).
Both changes went through PR and CI checks. Observed outage: at least 7 min 24 s (first FAIL to earliest possible fix),
probably 8-9 minutes. The exact recovery moment was not recorded because the watcher had ended.

## Prevention
- Run Prometheus with the BackendHighErrorRate alert during releases (alerting would detect without a person watching).
- Make readiness check a real endpoint, or run a smoke test on green before the selector switch.
- Deploy a new version to the idle colour first, never change the colour that is serving traffic.
- Document a break-glass rollback for emergencies, because waiting for CI through a protected branch took several minutes.
- Record watcher output to a file during releases so recovery time is exact.
