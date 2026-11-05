# Phase 10 - Centralized Logging (Loki + Alloy)

## What was built
- Loki 3.7.8 (Helm chart grafana-community/loki 18.17.1) in single-binary ("Monolithic") mode with filesystem storage
  and a 2Gi PersistentVolumeClaim. monitoring/loki-values.yaml disables the gateway, chunk and result caches, canary,
  object store and rules sidecar so that it fits a 3.8 GB machine. Memory limit 512Mi.
- Grafana Alloy v1.21.1 (monitoring/alloy.yaml, our own manifest, because no Alloy chart was available in the maintained
  repository). One Deployment that tails the logs of every pod in the shopflow namespace through the Kubernetes API
  (loki.source.kubernetes), so no host paths or privileged DaemonSet are needed, and pushes them to Loki.
  Labels added: namespace, pod, container, app.
- Alloy runs with a read-only ClusterRole (get, list, watch on pods, pods/log, namespaces).

## Why no Grafana UI
Grafana 13 could not stay up on this hardware (see docs/phase9-notes.md), so logs are searched with LogQL through Loki's
HTTP API (kubectl port-forward svc/loki 3100:3100, then curl). If Grafana is running, add a Loki data source with the URL
http://loki.monitoring.svc.cluster.local:3100 and use Explore.

## Verification (outputs in docs/evidence/loki-query*.txt)
1. Text search across all backend pods: {namespace="shopflow", app="backend"} |= "shopflow-log-test" returned three
   requests handled by two different pods (backend-...-d24xn and backend-...-st822).
2. Filter by status: |~ "\" 404 " returned the three 404 lines.
3. Aggregate: sum by (app) (count_over_time({namespace="shopflow"}[30m])) returned backend 572, backend-green 284,
   frontend 566. Postgres and Redis are absent only because they logged nothing in that 30 minute window.
4. Single application: {namespace="shopflow", app="postgres"} returned the Postgres start-up and checkpoint lines.
Available labels: app, container, instance, job, namespace, pod, service_name. Values of app: backend, backend-green,
frontend, postgres, redis.

## Resource cost (measured with kubectl top)
Loki 121-148 MiB, Alloy 45 MiB. Node memory available after installing both: about 1.8 GB of 3.8 GB.

## Limits and next steps
- No log retention policy was configured and storage is 2Gi, so old logs would eventually fill the volume.
- Alloy reads logs through the Kubernetes API, which adds load to an API server that was already fragile on this machine.
- The ClusterRole is cluster-wide although only the shopflow namespace is read. A Role and RoleBinding in that namespace
  would be tighter.
- Only the shopflow namespace is collected (argocd and monitoring logs are not).
- Alerts on log patterns (Loki ruler) and a Grafana log dashboard were not built.
