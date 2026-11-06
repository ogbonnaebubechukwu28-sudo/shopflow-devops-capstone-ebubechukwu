# Evidence Index

Public links (the repository is public). PR numbers refer to this repository.

| Phase | What it proves | Where |
|---|---|---|
| 1 | Local run, driver mismatch bug fixed | docs/phase1-notes.md |
| 2 | Branches, PRs, merge conflict, branch protection | PR #1 and PR #2, docs/phase2-notes.md, docs/screenshots/ |
| 3 | Hardened images, healthy Compose stack | docs/phase3-notes.md |
| 4 | CI gates that failed, then passed (pip-audit, flake8, Trivy 41 CVEs) | PR #7 and its Actions runs, docs/phase4-notes.md |
| 5 | Kubernetes deployment, probes, HPA, PDB | docs/phase5-notes.md |
| 9 | Prometheus, alerts, metrics bug, incident of 2026-10-21 | docs/phase9-notes.md, docs/incident-2026-10-21-probe-timeouts.txt |
| 10 | Centralized logs searched through Loki | docs/phase10-notes.md, docs/evidence/loki-query*.txt |
| 11 | Hardening, RBAC, Gitleaks | PR #13, docs/phase11-notes.md |
| 12 | Argo CD sync, drift, self-heal, change and revert | PR #14, #15, #16, docs/phase12-notes.md |
| 13 | Blue-green switch, deliberate failure, rollback | PR #18 to #22, docs/phase13-notes.md, docs/incident-2026-10-26-broken-release.md |
| 14 | SLIs, SLOs, error budget, severities | docs/phase14-sre.md |
| 15 | Four failure tests with measurements | docs/phase15-failure-tests.md, docs/evidence/test3-*.txt |

Pull request URL pattern: https://github.com/ogbonnaebubechukwu28-sudo/shopflow-devops-capstone-ebubechukwu/pull/<number>
Pipeline runs: https://github.com/ogbonnaebubechukwu28-sudo/shopflow-devops-capstone-ebubechukwu/actions
Frontend on Vercel: https://shopflow-frontend-orpin.vercel.app/
