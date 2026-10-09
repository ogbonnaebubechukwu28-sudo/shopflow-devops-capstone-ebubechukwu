# Phase 3 - Docker Engineering: Notes

## What the starter provided
- Backend Dockerfile (python:3.12-slim, non-root appuser, HEALTHCHECK, gunicorn entrypoint).
- Frontend Dockerfile (nginxinc/nginx-unprivileged:1.27-alpine, port 8080).
- docker-compose.yml with frontend, backend, Postgres 16 and Redis 7.

## Improvements made
1. Removed pytest from runtime requirements.txt and moved it to requirements-dev.txt,
   so test tooling is not baked into the production image.
2. Backend Dockerfile: removed the unused "AS base" stage, created the non-root user
   before copying files and used COPY --chown, which avoids a separate chown -R layer.
   Added OCI labels (title, version).
3. Frontend: fixed a failing health check (see Problem below).
4. docker-compose.yml: frontend now waits for a healthy backend
   (depends_on with condition: service_healthy).
5. Created docker/.env from .env.example for POSTGRES_PASSWORD. The real .env is
   git-ignored and is never committed.

## Requirements checklist
- Image tags, not latest: shopflow-api:1.0.0, shopflow-frontend:1.0.0,
  postgres:16-alpine, redis:7-alpine.
- Non-root: backend runs as appuser (uid 1000, verified with "docker compose exec backend id");
  frontend uses nginx-unprivileged.
- Environment variables: DATABASE_URL, REDIS_URL, PORT, SEED_DB and POSTGRES_PASSWORD.
- Health checks: Dockerfile HEALTHCHECK on backend (/health) and frontend,
  plus pg_isready for Postgres and redis-cli ping for Redis.
- Small images: slim/alpine bases, no pip cache, no dev dependencies.
  shopflow-api 237MB, shopflow-frontend 73.7MB.
- .dockerignore present for backend and frontend.
- Full stack runs with docker compose up -d --build.

## Problem: frontend container showed "unhealthy" while the site worked
- Symptom: curl localhost:8080 returned 200, but docker compose ps showed (unhealthy).
- Diagnosis: inside the container, wget http://localhost:8080/ was "Connection refused",
  but wget http://127.0.0.1:8080/ worked.
- Cause: nginx has "listen 8080;" which is IPv4 only. In the Alpine image,
  localhost resolved to IPv6 (::1), where nothing was listening.
- Fix: changed the HEALTHCHECK URL to http://127.0.0.1:8080/. All containers then
  reported healthy.

## Application test
- GET /health returns {"status":"healthy"}
- GET /ready returns database ok, redis ok
- GET /api/products returns the seeded products
- Frontend returns HTTP 200 on port 8080 and the app loads in the browser.

## Workflow
- Changes were made on feature/docker-hardening and merged through a pull request,
  as main is protected.

## Evidence: docker images
postgres:16-alpine                                                                                    721873c34ceb        420MB          117MB   U    
redis:7-alpine                                                                                        858f009f9709       57.8MB         16.7MB   U    
shopflow-api:1.0.0                                                                                    78725d362d38        237MB         56.8MB   U    
shopflow-frontend:1.0.0                                                                               2524c1fa04e7       73.7MB           21MB   U    
## Evidence: docker compose ps
NAME                IMAGE                     COMMAND                  SERVICE    CREATED          STATUS                    PORTS
docker-backend-1    shopflow-api:1.0.0        "./entrypoint.sh"        backend    22 minutes ago   Up 22 minutes (healthy)   0.0.0.0:5000->5000/tcp, [::]:5000->5000/tcp
docker-cache-1      redis:7-alpine            "docker-entrypoint.s…"   cache      9 hours ago      Up 8 hours (healthy)      6379/tcp
docker-db-1         postgres:16-alpine        "docker-entrypoint.s…"   db         9 hours ago      Up 8 hours (healthy)      5432/tcp
docker-frontend-1   shopflow-frontend:1.0.0   "/docker-entrypoint.…"   frontend   22 minutes ago   Up 22 minutes (healthy)   0.0.0.0:8080->8080/tcp, [::]:8080->8080/tcp
