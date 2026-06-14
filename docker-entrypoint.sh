#!/bin/bash
set -e

# Ensure runtime directories exist (they're excluded from the image).
mkdir -p /app/tmp/pids /app/log

# Remove a stale Puma server.pid if it exists, so the server can restart.
rm -f /app/tmp/pids/server.pid

# Wait for PostgreSQL to accept connections before doing anything DB-related.
if [ -n "$DATABASE_HOST" ]; then
  echo "Waiting for PostgreSQL at ${DATABASE_HOST}:${DATABASE_PORT:-5432}..."
  until pg_isready -h "$DATABASE_HOST" -p "${DATABASE_PORT:-5432}" -U "${DATABASE_USER:-postgres}" >/dev/null 2>&1; do
    sleep 1
  done
  echo "PostgreSQL is ready."
fi

# Prepare the database (create + migrate + seed if needed). Safe to run on
# every boot: db:prepare is idempotent.
if [ "${SKIP_DB_PREPARE}" != "true" ]; then
  bundle exec rails db:prepare
fi

# Hand off to the container's main process (CMD).
exec "$@"
