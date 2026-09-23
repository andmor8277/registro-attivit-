#!/usr/bin/env bash
# ==============================================================================
# THOF - Automated PostgreSQL Backup Script
# Creates a compressed pg_dump and manages retention.
# Recommended cron: 0 3 * * * /opt/registro_presenze/scripts/backup_db.sh >> /var/log/thof_backup.log 2>&1
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKUP_DIR="${PROJECT_DIR}/backups"
RETENTION_DAYS=14
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/registro_backup_${TIMESTAMP}.sql.gz"

mkdir -p "${BACKUP_DIR}"

# Load DB credentials from .env if present
if [ -f "${PROJECT_DIR}/.env" ]; then
    export $(grep -E '^(DB_USER|DB_NAME|DB_PASSWORD)=' "${PROJECT_DIR}/.env" | xargs)
fi

DB_USER="${DB_USER:-registro_user}"
DB_NAME="${DB_NAME:-registro}"

# Detect postgres container name
CONTAINER_NAME=$(docker ps --filter "name=db" --filter "status=running" --format "{{.Names}}" | head -n 1)

if [ -z "${CONTAINER_NAME}" ]; then
    echo "[$(date -Iseconds)] [ERROR] Nessun container PostgreSQL in esecuzione trovato."
    exit 1
fi

echo "[$(date -Iseconds)] [INFO] Avvio backup per il database '${DB_NAME}' dal container '${CONTAINER_NAME}'..."

# Dump and compress
docker exec -i "${CONTAINER_NAME}" pg_dump -U "${DB_USER}" -d "${DB_NAME}" | gzip -9 > "${BACKUP_FILE}"

FILE_SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
echo "[$(date -Iseconds)] [SUCCESS] Backup completato: ${BACKUP_FILE} (Dimensione: ${FILE_SIZE})"

# Retention policy: remove backups older than RETENTION_DAYS
DELETED_COUNT=$(find "${BACKUP_DIR}" -name "registro_backup_*.sql.gz" -type f -mtime +"${RETENTION_DAYS}" -print -delete | wc -l)
if [ "${DELETED_COUNT}" -gt 0 ]; then
    echo "[$(date -Iseconds)] [INFO] Rimossi ${DELETED_COUNT} vecchi backup (retention: ${RETENTION_DAYS} giorni)."
fi

exit 0
