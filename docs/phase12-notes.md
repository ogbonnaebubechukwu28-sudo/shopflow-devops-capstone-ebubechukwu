# Phase 12 - GitOps with ArgoCD: Notes

## Installation
- Argo CD v3.5.4 "core" install (manifests/core-install.yaml), pinned to a tag published 2026-10-06 (19 days before use).
- Core mode runs only the application controller, repo server, Redis and ApplicationSet controller. No UI, API server or
  Dex login. Chosen because the machine has 3.8 GB of RAM and Grafana had already shown it cannot run heavy components.
  Limitation: everything is verified with kubectl instead of the Argo CD UI.
- Monitoring was scaled to zero during installation to keep the node stable.

## GitOps layout
- k8s/ is the desired state (namespace, RBAC, config, Postgres, Redis, backend, frontend, HPA, PDB).
- gitops/project.yaml: AppProject "shopflow", restricted to this repository, the shopflow namespace and only Namespace
  as a cluster-scoped resource. (The core install does not create the "default" project, so the Application was
  initially Unknown with "project default does not exist".)
- gitops/application.yaml: Application "shopflow", source path k8s on main, destination namespace shopflow.
  ignoreDifferences on the backend Deployment replicas, because the HPA changes them.
- The Secret is created with kubectl and is not in Git, so it is not managed (or pruned) by Argo CD.

## Sync, drift detection and self-healing
- First sync: 17 resources reported OutOfSync only because they had been created with kubectl apply and lacked Argo CD's
  tracking annotation. After the sync: Synced / Healthy, no pod restarts.
- Drift: kubectl scale deploy/frontend --replicas=1 made the Application OutOfSync (Deployment/frontend).
- Self-heal: syncPolicy.automated (prune false, selfHeal true) restored the frontend to 2 replicas without manual action.
  prune is off on purpose, so nothing is deleted from the cluster just because it disappears from Git.

## Change and rollback through Git
- PR #15 lowered the HPA maxReplicas from 4 to 3. Argo CD applied it (kubectl get hpa showed MAXPODS 3) with no kubectl apply.
- PR #16 was a git revert of that commit. Argo CD returned to commit be2329c, Synced, and MAXPODS went back to 4.
- Rollback is a normal, reviewed, CI-checked Git change, and the history is in git log and the Application status.

## Observations
- Postgres and Redis restarted again (27 and 17 restarts in total) during the ArgoCD install and after the laptop resumed
  from idle. Same cause as the 2026-10-21 incident: probes time out when the node stalls.
- The backend briefly went to 4 pods with two in CrashLoopBackOff, then recovered by itself.

## Evidence
- Screenshots phase12-01 to phase12-06 and the git log of PRs #14, #15 and #16.
