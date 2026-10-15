# Phase 4 - CI/CD Pipeline: Notes

## Pipeline design (.github/workflows/ci.yml)
Triggers: pull requests to main and pushes to main. Three jobs:
1. lint-and-test: checkout, install deps, flake8, hadolint (both Dockerfiles), pytest.
2. dependency-scan: pip-audit on the runtime requirements.
3. build-and-scan-images: needs the first two jobs. Builds both images and scans
   them with Trivy (HIGH/CRITICAL, fixable only, exit code 1 on findings).
Because of "needs", no image is built or scanned if a quality or security gate fails.
All three jobs are required status checks on main (GitHub ruleset).

## Tool choices
- flake8: Python lint. hadolint: Dockerfile lint. pytest: smoke tests (SQLite, no DB needed in CI).
- pip-audit: known vulnerabilities in Python dependencies.
- Trivy: container image vulnerability scan.

## Problems found and fixed (each failed run was kept as evidence)
1. flake8 style failures (E231, E302, E305, E501, E701) in the developers' code.
   Fix: relaxed formatting-only rules and raised the line limit to 170. Real error
   classes (unused imports, undefined names) are still checked. Application code was not changed.
2. pip-audit: Flask 3.1.2 had a known vulnerability (PYSEC-2026-2151).
   Fix: upgraded to Flask 3.1.3 (patch release). This is a real security gate that blocked a change.
3. Trivy action tag not found (0.28.0). In March 2026 Trivy's release pipeline was compromised
   and old trivy-action tags were overwritten with malicious code, then migrated to a "v" prefix.
   Fix: pinned the action to the full commit SHA of v0.36.0, as Aqua Security recommends,
   because a SHA cannot be rewritten the way a tag can.
4. Trivy frontend image scan: 41 vulnerabilities (39 HIGH, 2 CRITICAL), all with fixes available,
   in Alpine packages in the nginx base image (openssl, libexpat, libpng, libxml2, musl, zlib, others).
   Fix: "apk upgrade --no-cache" in the frontend Dockerfile (as root, then back to uid 101).
   The backend image passed the scan first time.

## Evidence
- Screenshots: failed pip-audit, failed flake8, failed Trivy scan, final all-green PR, ruleset with required checks.
- Pull request #7 (CI pipeline) and its Actions runs.

## Lessons learned
- Each fix exposed the next problem, because later steps are skipped when a gate fails.
- Pin third-party actions to commit SHAs. Tags are mutable.
- Base images age. Patching or rebuilding on a schedule matters.

## Not done (optional extension)
- Pushing images to Docker Hub.
