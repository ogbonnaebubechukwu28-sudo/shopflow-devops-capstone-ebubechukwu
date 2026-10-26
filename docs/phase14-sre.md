# Phase 14 - SRE: SLIs, SLOs, Error Budget, Incidents

## Service level indicators (SLIs)
1. Availability SLI: share of backend requests that do not return 5xx.
   PromQL: 1 - (sum(rate(flask_http_request_total{namespace='shopflow',status=~'5..'}[30d])) / sum(rate(flask_http_request_total{namespace='shopflow'}[30d])))
2. Latency SLI: 95th percentile request duration.
   PromQL: histogram_quantile(0.95, sum by (le) (rate(flask_http_request_duration_seconds_bucket{namespace='shopflow'}[5m])))
   Indicative measurement: in the load test the mean time per request was about 20 ms (120 s / 5,890 requests per worker).

## Service level objectives (SLOs), 30-day window
1. Availability SLO: 99.5% of requests succeed.
2. Latency SLO: p95 below 500 ms in 99% of 5-minute windows.

## Error budget
- Availability 99.5% over 30 days = 0.5% of 43,200 minutes = 216 minutes of full outage.
- The 2026-10-26 broken release (about 9 minutes) used about 4.2% of the monthly budget.
- The Redis dependency test (about 1.5 minutes) used under 1%.
- Policy: if more than 50% of the budget is spent in a window, risky releases pause and reliability work comes first.
  If the budget is exhausted, only fixes and rollbacks ship.

## Alerting link
BackendHighErrorRate (5xx above 5% for 2 min) and BackendHighLatency (p95 above 1 s for 5 min) are symptom alerts.
A production version would use burn-rate alerts against the SLO (fast burn pages, slow burn tickets).

## Incident severity levels
- SEV-1: complete outage, data loss or security breach. Respond immediately, rollback first.
- SEV-2: a core function fails for many users (for example /api/products returning 500). Respond within 15 minutes.
- SEV-3: partial degradation or a single component down with a workaround (for example one pod restarting).
- SEV-4: cosmetic issue or a risk found in testing. Track as a ticket.
Examples: the 2026-10-26 release was SEV-2; the Redis outage test was SEV-2; the pod deletion test was SEV-4.

## Ownership and on-call
- This project has one owner (the student), who is primary on-call for every service.
- In a team: a primary and a secondary on-call, an incident commander for SEV-1 and SEV-2, and a named owner per service
  (backend, database, platform). Handover happens at fixed times with a short note.

## Incident response steps
1. Detect (alert, probe failure or user report) and acknowledge.
2. Assess severity and decide the first action. Prefer rollback or the known-good version over live debugging.
3. Mitigate and verify with a watcher that records timestamps.
4. Communicate status to stakeholders.
5. Investigate the root cause after service is restored.
6. Write the post-incident record in the format symptom, detection, investigation, root cause, mitigation, recovery, prevention.

## Post-incident actions (from our own incidents)
- Readiness: make Redis optional so a cache outage does not remove healthy pods.
- Releases: smoke-test the new colour before switching, and never change the colour serving traffic.
- Observability: keep Prometheus alerting during releases and tests.
- Recovery speed: document a break-glass rollback because protected branches and CI delay fixes.
- Start-up: wait-for-dependency logic in the app or init containers, and a start script that orders the cluster start.
