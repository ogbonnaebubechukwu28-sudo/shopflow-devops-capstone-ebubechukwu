# Phase 13 - Deployment Strategy: Blue-Green

## Design
- Blue: Deployment "backend" (image shopflow-api:1.0.1, 2 replicas, HPA + PDB). Reports application version 1.0.0
  because the image predates the version hook.
- Green: Deployment "backend-green" (shopflow-api:1.0.2, APP_VERSION=1.0.2, 1 replica) with its own test Service "backend-green".
- The live Service "backend" selects the colour. Switching traffic is a one-line change of its selector
  (app.kubernetes.io/name: backend or backend-green), made through a pull request and applied by Argo CD.
  kubectl patch is not used because Argo CD self-heal would revert it.
- Two test hooks were added to the app: APP_VERSION (shown by GET /) and SIMULATE_FAILURE=true (GET /api/products returns 500).
  Both are off or neutral by default.

## What was demonstrated
1. Deploy new version: PR #18 added green. Argo CD created it with no traffic.
2. Validate: green was tested through the backend-green Service before any traffic moved
   (GET / reported 1.0.2 and /ready reported database ok, redis ok).
3. Traffic progression: PR #19 (merged 07:15:33 UTC) switched the selector to green. A watcher polling the live Service
   every 2 seconds saw 60 responses from 1.0.0 followed immediately by 1.0.2, with no failed request.
4. Deliberate failure: PR #20 (07:24:41 UTC) set SIMULATE_FAILURE=true on green. See incident file.
5. Rollback: PR #21 fixed green and PR #22 switched traffic back to blue. Blue had never stopped running.

## Limits
- No traffic splitting (this is blue-green, not canary): all users move at once.
- The HPA and PDB target blue only, so green runs a fixed single replica.
- Green was replaced in place when the bad change was applied. A production process would deploy the bad version
  to the idle colour first, test it, and switch only if the test passed.
