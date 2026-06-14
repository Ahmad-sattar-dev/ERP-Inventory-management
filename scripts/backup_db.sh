#!/usr/bin/env bash
# Nightly Postgres backup for the single-EC2 deployment.
#
# Dumps the production database from the `db` container, compresses it, keeps a
# local copy, and (optionally) uploads to S3. Schedule via cron, e.g.:
#   0 3 * * * /home/ubuntu/ERP-Inventory-management/scripts/backup_db.sh >> /var/log/erp-backup.log 2>&1
#
# Requires: docker compose, and (for S3) the AWS CLI with an instance role or
# credentials. Set BACKUP_S3_BUCKET to enable the upload.

set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$APP_DIR"

# Load DB settings from the production env file.
set -a; source .env.production; set +a

BACKUP_DIR="${BACKUP_DIR:-/mnt/data/backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-14}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
FILE="${BACKUP_DIR}/${DATABASE_NAME}_${TIMESTAMP}.sql.gz"

mkdir -p "$BACKUP_DIR"

echo "[$(date -Is)] Dumping ${DATABASE_NAME} -> ${FILE}"
docker compose -f docker-compose.prod.yml exec -T db \
  pg_dump -U "$DATABASE_USER" "$DATABASE_NAME" | gzip > "$FILE"

# Optional off-box copy to S3.
if [ -n "${BACKUP_S3_BUCKET:-}" ]; then
  echo "[$(date -Is)] Uploading to s3://${BACKUP_S3_BUCKET}/"
  aws s3 cp "$FILE" "s3://${BACKUP_S3_BUCKET}/$(basename "$FILE")"
fi

# Prune old local backups.
find "$BACKUP_DIR" -name "${DATABASE_NAME}_*.sql.gz" -mtime "+${RETENTION_DAYS}" -delete

echo "[$(date -Is)] Backup complete."
