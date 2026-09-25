#!/usr/bin/env bash
# ==============================================================================
# THOF - Setup Automatic Daily Offsite Backup Cron Job
# Installs a cron entry to run every night at 03:00 AM
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SCRIPT="${SCRIPT_DIR}/backup_offsite_github.sh"
LOG_FILE="/var/log/thof_backup_offsite.log"
CRON_SCHEDULE="0 3 * * *"

if [ ! -f "${BACKUP_SCRIPT}" ]; then
    echo "❌ [ERRORE] Script non trovato: ${BACKUP_SCRIPT}"
    exit 1
fi

chmod +x "${BACKUP_SCRIPT}"

CRON_CMD="${CRON_SCHEDULE} ${BACKUP_SCRIPT} >> ${LOG_FILE} 2>&1"

# Rimuove il vecchio backup_db.sh non cifrato se presente
CURRENT_CRON=$(crontab -l 2>/dev/null | grep -v 'backup_db.sh' || true)

if echo "${CURRENT_CRON}" | grep -F "${BACKUP_SCRIPT}" >/dev/null 2>&1; then
    echo "ℹ️ Il cron job di backup è già presente nel crontab:"
    echo "${CURRENT_CRON}" | grep -F "${BACKUP_SCRIPT}"
else
    echo "⚙️ Configurazione nuovo cron job di backup automatico (ore 03:00 ogni notte)..."
    (echo "${CURRENT_CRON}"; echo "${CRON_CMD}") | crontab -
    echo "✅ Cron job installato con successo!"
fi

echo ""
echo "Orario esecuzione: Ogni notte alle 03:00"
echo "Log salvato in:    ${LOG_FILE}"
echo "Script eseguito:   ${BACKUP_SCRIPT}"
