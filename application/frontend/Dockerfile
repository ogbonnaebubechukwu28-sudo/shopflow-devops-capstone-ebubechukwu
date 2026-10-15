# nginx-unprivileged runs as a non-root user and binds to port 8080 by
# default instead of 80.
FROM nginxinc/nginx-unprivileged:1.27-alpine

# The base image's Alpine packages lag behind security fixes (Trivy found
# 41 HIGH/CRITICAL CVEs, all with fixes available). Patch them at build time,
# then drop back to the unprivileged user.
USER root
# hadolint ignore=DL3017
RUN apk upgrade --no-cache
USER 101

COPY nginx.conf /etc/nginx/nginx.conf
COPY index.html /usr/share/nginx/html/index.html

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -q -O- http://127.0.0.1:8080/ >/dev/null || exit 1
