# Phase 15 - Failure Testing

Four scenarios. Times are UTC. "Measured" means a command or log recorded it. "Estimated" means inferred.

## Test 1: broken release and rollback
Full record: docs/incident-2026-10-26-broken-release.md.
Summary: SIMULATE_FAILURE=true on the live green version made /api/products return 500 (first FAIL 64 s after merge).
Recovered by PR #21 (fix green) and PR #22 (traffic back to blue). Outage at least 7 min 24 s.

## Test 2: delete a backend pod
- Symptom: none visible. One of two backend pods was deleted at 07:51:41.
- Detection: kubectl get pods (the controller reacted at once).
- Investigation: replacement pod created 07:51:41, Ready 07:51:55. The other replica showed 1/1 in all 12 samples (07:51:53-07:52:52).
- Root cause: deliberate deletion.
- Mitigation / recovery: automatic. The Deployment controller recreated the pod. Time to Ready: 14 s (measured).
- Prevention / note: two replicas plus a PodDisruptionBudget keep capacity. No request watcher ran, so "zero failed requests" is not claimed.

## Test 3: increased traffic
- Run 1: 4 parallel request loops. HPA reported CPU 216% of request (target 70%) and scaled the backend 2 to 4 pods, with the
  condition ScalingLimited (wanted more than the maximum of 4). The load generator printed two HTTP 500 errors. Cause not
  established: those pods were removed on scale-down and their logs were lost. Not reproduced.
- Run 2 (measured, docs/evidence/test3-load-run2.log): 4 workers for 120 s sent 23,561 requests (about 196 per second) with 0 failures.
  HPA scaled 2 to 4 again. All four pods reported 0 responses with status 500. CPU returned to 5% after the load.
- Scale-down is delayed by the HPA stabilisation window (about 5 min), as designed.
- Finding: HPA events show intermittent metrics API failures (Unauthorized, unable to handle the request, no metrics returned).
  The Minikube metrics-server is unreliable on this 3.8 GB machine, so autoscaling can be blind at times.
- Prevention: raise maxReplicas or the CPU request if capacity is needed, keep Prometheus running during tests so per-pod
  errors are recorded, and use a metrics source that survives restarts.

## Test 4: dependency unavailable (Redis)
- Action: automatic sync was frozen, then Redis was scaled to 0 at 08:01:44.
- Symptom: every backend pod became 0/1 (readiness returned 503, first logged 08:02:15) and the backend Service had no endpoints,
  so the API was unreachable through the Service. Estimated full unavailability: about 90 seconds (no request watcher ran).
- Detection: readiness probe failures and an empty Endpoints list. No alert, because Prometheus was off.
- Investigation: kubectl logs showed GET /ready 503. Inside a pod GET /api/products still returned 200, because that endpoint
  does not use Redis.
- Root cause: /ready treats the cache as mandatory. A cache outage removed healthy pods from service.
- Mitigation / recovery: Redis scaled back to 1 at 08:03:41 and Ready 10 s later. Backends returned to 1/1. Automatic sync was re-enabled.
- Prevention: make /ready report "degraded" (HTTP 200) when only the cache is down, and keep the cache optional in the code.
  Run Redis with persistence or a replica if it becomes critical.

## Cross-cutting lessons
- Add alert coverage during every test (Prometheus on) and record watcher output to files.
- A protected branch plus mandatory CI means a rollback takes minutes. Document a break-glass procedure.
- Start-up ordering (DNS, then database, then apps) caused repeated crash loops. See scripts/start-cluster.sh and the init-container idea.
