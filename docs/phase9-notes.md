# Phase 9 - Monitoring (Prometheus and Grafana): Notes

## What was built
- Prometheus (Helm chart prometheus-community/prometheus 29.34.0, lean values in monitoring/prometheus-values.yaml):
  Alertmanager, Pushgateway and node-exporter disabled to fit a 3.8 GB machine. kube-state-metrics kept.
- Backend pods are discovered through prometheus.io annotations and scraped on /metrics (prometheus-flask-exporter).
- Container CPU and memory come from kubelet cAdvisor metrics.
- Four alert rules: BackendHighErrorRate (5xx > 5%), BackendHighLatency (p95 > 1s),
  PodRestartingFrequently (more than 2 restarts in 15 min), DeploymentReplicasUnavailable.
- Grafana (grafana-community/grafana 13.7.0) with a provisioned Prometheus data source and a 10-panel
  dashboard (monitoring/shopflow-dashboard.json): request rate, 5xx ratio, latency, restarts, CPU, memory,
  replica health, firing alerts.

## Finding 1: metrics were wrong with two gunicorn workers
- Each worker kept its own counters, so one pod's request counter alternated 108, 136, 108, 136 between scrapes.
- Fix: entrypoint.sh now runs "gunicorn --workers 1 --threads 4". After the change the counter was stable (9.0 on 8 reads).
- Image bumped to shopflow-api:1.0.1 and rolled out with zero downtime (rolling update).

## Finding 2: incident 2026-10-21 (probe timeouts)
- Postgres, Redis, frontends and a backend pod were restarted by Kubernetes at the same time (liveness probe timeouts)
  while the node was busy pulling images. Postgres rejected connections while restarting, so /ready returned 503 and
  /api/products returned 500. The HPA scaled the backend from 2 to 4 and back. All four alerts fired.
- Evidence: docs/incident-2026-10-21-probe-timeouts.txt, Prometheus alert screenshots.
- Fix: probe timeoutSeconds raised to 5 and failureThreshold to 5 on Postgres, Redis and backend.

## Finding 3: cold start after a PC shutdown
- After a full shutdown the backend crash-looped (could not resolve host "postgres") and nginx exited
  (host not found in upstream "backend"), because cluster DNS was not ready when they started.
- Mitigation: scripts/start-cluster.sh resets DNS, waits for Postgres and restarts the app pods.
- Proper fix (planned): an init container that waits for the database, and a retry loop in the entrypoint.

## Finding 4: Grafana could not run reliably on this hardware
- The WSL VM has 3.87 GB of memory shared by Minikube (3 GB), Prometheus, the app and Grafana.
- The Grafana 13 image is 1.37 GB (14 minutes 36 seconds to download). Start-up needed 6+ minutes just to load plugins,
  logged "database is locked (SQLITE_BUSY)", and stalled: port 3000 opened but /api/health timed out.
- It was killed by liveness probes on three attempts (different CPU limits and delays), and its load also caused restarts
  of Prometheus components and the app (kube-state-metrics reached 44 restarts).
- Decision: run Prometheus as the monitoring system and keep Grafana configuration and the dashboard JSON in Git.
  Grafana is scaled to 0 (kubectl scale deploy/grafana -n monitoring --replicas=0). Prometheus Graph and Alerts pages
  show the same queries as the dashboard.
- Other DNS findings: WSL and the Minikube node need "nameserver 8.8.8.8" set after every restart or image pulls fail.

## Evidence
- Screenshots: Prometheus targets, alerts, graphs (request rate, restarts, memory, CPU, replicas).
- Files: monitoring/, docs/incident-2026-10-21-probe-timeouts.txt, scripts/start-cluster.sh.
