#!/bin/sh
# Creates tables on every start (idempotent: db.create_all() only adds
# missing tables) and optionally seeds sample data, before handing off to
# gunicorn. SEED_DB is meant for local/dev use only (docker-compose sets
# it); leave it unset/false in Kubernetes.
set -e

flask --app app init-db

if [ "${SEED_DB:-false}" = "true" ]; then
  flask --app app seed
fi

exec gunicorn --bind 0.0.0.0:5000 --workers 2 --access-logfile - --error-logfile - app:app
