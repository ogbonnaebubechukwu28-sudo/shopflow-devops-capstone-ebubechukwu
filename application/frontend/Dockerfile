# syntax=docker/dockerfile:1
# nginx-unprivileged runs as a non-root user and binds to port 8080 by
# default instead of 80, so no extra USER/permission setup is needed.
FROM nginxinc/nginx-unprivileged:1.27-alpine

COPY nginx.conf /etc/nginx/nginx.conf
COPY index.html /usr/share/nginx/html/index.html

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -q -O- http://localhost:8080/ >/dev/null || exit 1
