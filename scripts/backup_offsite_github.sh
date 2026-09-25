#!/usr/bin/env bash
# ==============================================================================
# THOF - Automated Encrypted Offsite Backup to GitHub
# 
# 1. Dumps PostgreSQL database
# 2. Archives uploaded files (logos, sponsors, attachments)
# 3. Encrypts both with OpenSSL AES-256-CBC using ENCRYPTION_KEY
# 4. Uploads encrypted assets to private GitHub repository (andmor8277/thof-backups)
# 5. Prunes backups older than RETENTION_DAYS
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKUP_DIR="${PROJECT_DIR}/backups"
REPO_OWNER="andmor8277"
REPO_NAME="thof-backups"
RETENTION_DAYS="${RETENTION_DAYS:-14}"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DATE_READABLE=$(date +"%Y-%m-%d %H:%M:%S")
TAG_NAME="backup-${TIMESTAMP}"
TMP_DIR=$(mktemp -d "/tmp/thof_backup_${TIMESTAMP}_XXXXXX")

cleanup() {
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

echo "=========================================================="
echo "🔒 THOF - Avvio Backup Offsite Cifrato su GitHub"
echo "Data: ${DATE_READABLE}"
echo "=========================================================="

# 1. Carica variabili d'ambiente (.env o container)
if [ -z "${ENCRYPTION_KEY:-}" ] && [ -f "${PROJECT_DIR}/.env" ]; then
    ENCRYPTION_KEY=$(grep -E '^ENCRYPTION_KEY=' "${PROJECT_DIR}/.env" | cut -d= -f2- | tr -d '\r"' || echo "")
fi

if [ -z "${DB_USER:-}" ] && [ -f "${PROJECT_DIR}/.env" ]; then
    DB_USER=$(grep -E '^DB_USER=' "${PROJECT_DIR}/.env" | cut -d= -f2- | tr -d '\r"' || echo "")
fi

if [ -z "${DB_NAME:-}" ] && [ -f "${PROJECT_DIR}/.env" ]; then
    DB_NAME=$(grep -E '^DB_NAME=' "${PROJECT_DIR}/.env" | cut -d= -f2- | tr -d '\r"' || echo "")
fi

# Fallback predefiniti per THOF
DB_USER="${DB_USER:-registro_user}"
DB_NAME="${DB_NAME:-registro}"

if [ -z "${ENCRYPTION_KEY}" ]; then
    echo "❌ [ERRORE] ENCRYPTION_KEY non trovata in .env. Impossibile cifrare il backup."
    exit 1
fi

# 2. Rileva Token GitHub
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
if [ -z "${GITHUB_TOKEN}" ]; then
    if [ -f "$HOME/.git-credentials" ]; then
        GITHUB_TOKEN=$(grep "github.com" "$HOME/.git-credentials" | sed -n 's/.*:\(.*\)@github\.com.*/\1/p' | head -n 1)
    fi
fi

if [ -z "${GITHUB_TOKEN}" ]; then
    echo "❌ [ERRORE] Nessun token GitHub trovato in GITHUB_TOKEN o ~/.git-credentials."
    exit 1
fi

# 3. Rileva container Docker
DB_CONTAINER=$(docker ps --filter "name=db" --filter "status=running" --format "{{.Names}}" | head -n 1)
if [ -z "${DB_CONTAINER}" ]; then
    DB_CONTAINER=$(docker ps --filter "name=postgres" --filter "status=running" --format "{{.Names}}" | head -n 1)
fi

if [ -z "${DB_CONTAINER}" ]; then
    echo "❌ [ERRORE] Nessun container PostgreSQL in esecuzione trovato."
    exit 1
fi

BACKEND_CONTAINER=$(docker ps --filter "name=backend" --filter "status=running" --format "{{.Names}}" | head -n 1)

echo "📦 Container Database: ${DB_CONTAINER}"
echo "📦 Container Backend:  ${BACKEND_CONTAINER:-non in esecuzione (solo DB)}"

# 4. Dump Database PostgreSQL
DB_FILE="${TMP_DIR}/thof_db_${TIMESTAMP}.sql.gz"
echo "💾 Esecuzione pg_dump per database '${DB_NAME}'..."
docker exec -i "${DB_CONTAINER}" pg_dump -U "${DB_USER}" -d "${DB_NAME}" | gzip -9 > "${DB_FILE}"
DB_SIZE=$(du -h "${DB_FILE}" | cut -f1)
echo "   Dump DB completato: ${DB_SIZE}"

# 5. Dump Uploads (se il backend o il volume esistono)
UPLOADS_FILE="${TMP_DIR}/thof_uploads_${TIMESTAMP}.tar.gz"
if [ -n "${BACKEND_CONTAINER}" ]; then
    echo "📁 Archiviazione cartella uploads (/app/uploads)..."
    docker exec -i "${BACKEND_CONTAINER}" tar -czf - -C /app/uploads . > "${UPLOADS_FILE}" 2>/dev/null || true
fi

# 6. Cifratura OpenSSL AES-256-CBC
echo "🔐 Cifratura file con AES-256-CBC (chiave server)..."
DB_ENC="${TMP_DIR}/thof_db_${TIMESTAMP}.sql.gz.enc"
openssl enc -aes-256-cbc -salt -pbkdf2 -pass pass:"${ENCRYPTION_KEY}" -in "${DB_FILE}" -out "${DB_ENC}"

UPLOADS_ENC=""
if [ -f "${UPLOADS_FILE}" ] && [ -s "${UPLOADS_FILE}" ]; then
    UPLOADS_ENC="${TMP_DIR}/thof_uploads_${TIMESTAMP}.tar.gz.enc"
    openssl enc -aes-256-cbc -salt -pbkdf2 -pass pass:"${ENCRYPTION_KEY}" -in "${UPLOADS_FILE}" -out "${UPLOADS_ENC}"
fi

# Salva anche una copia locale cifrata in backups/
mkdir -p "${BACKUP_DIR}"
cp "${DB_ENC}" "${BACKUP_DIR}/"
if [ -n "${UPLOADS_ENC}" ]; then
    cp "${UPLOADS_ENC}" "${BACKUP_DIR}/"
fi

# 7. Creazione Release su GitHub (Repository Privato)
echo "☁️ Creazione Release '${TAG_NAME}' su GitHub (${REPO_OWNER}/${REPO_NAME})..."
RELEASE_JSON=$(curl -s -X POST \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases" \
    -d "{
        \"tag_name\": \"${TAG_NAME}\",
        \"name\": \"THOF Backup ${DATE_READABLE}\",
        \"body\": \"Automated encrypted offsite backup\\n- DB Dump size: ${DB_SIZE}\\n- Encrypted with AES-256-CBC\\n- Timestamp: ${TIMESTAMP}\",
        \"draft\": false,
        \"prerelease\": false
    }")

# Estrai ID release
if command -v jq >/dev/null 2>&1; then
    RELEASE_ID=$(echo "${RELEASE_JSON}" | jq -r '.id // empty')
else
    RELEASE_ID=$(echo "${RELEASE_JSON}" | python3 -c "import sys, json; print(json.load(sys.stdin).get('id', ''))")
fi

if [ -z "${RELEASE_ID}" ]; then
    echo "❌ [ERRORE] Creazione release fallita su GitHub. Risposta API:"
    echo "${RELEASE_JSON}"
    exit 1
fi

echo "   Release creata con ID: ${RELEASE_ID}"

# 8. Upload degli asset cifrati
echo "⬆️ Upload dump database cifrato..."
curl -s -X POST \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Content-Type: application/octet-stream" \
    --data-binary @"${DB_ENC}" \
    "https://uploads.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/${RELEASE_ID}/assets?name=thof_db_${TIMESTAMP}.sql.gz.enc" >/dev/null

if [ -n "${UPLOADS_ENC}" ]; then
    echo "⬆️ Upload archivio uploads cifrato..."
    curl -s -X POST \
        -H "Authorization: token ${GITHUB_TOKEN}" \
        -H "Content-Type: application/octet-stream" \
        --data-binary @"${UPLOADS_ENC}" \
        "https://uploads.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/${RELEASE_ID}/assets?name=thof_uploads_${TIMESTAMP}.tar.gz.enc" >/dev/null
fi

echo "✅ Backup offsite caricato con successo su GitHub!"

# 9. Politica di Retention (cancella release e tag più vecchi di RETENTION_DAYS)
echo "🧹 Verifica retention (conservazione ultimi ${RETENTION_DAYS} giorni)..."
RELEASES_LIST=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" \
    "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases?per_page=100")

CUTOFF_DATE=$(date -d "${RETENTION_DAYS} days ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -v -${RETENTION_DAYS}d +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || true)

if [ -n "${CUTOFF_DATE}" ]; then
    if command -v jq >/dev/null 2>&1; then
        OLD_RELEASES=$(echo "${RELEASES_LIST}" | jq -r --arg cutoff "${CUTOFF_DATE}" '.[] | select(.created_at < $cutoff) | "\(.id):\(.tag_name)"')
    else
        OLD_RELEASES=$(echo "${RELEASES_LIST}" | python3 -c "
import sys, json
cutoff = '${CUTOFF_DATE}'
for r in json.load(sys.stdin):
    if r.get('created_at', '') < cutoff:
        print(f\"{r['id']}:{r['tag_name']}\")
")
    fi

    for item in ${OLD_RELEASES}; do
        OLD_ID=$(echo "${item}" | cut -d: -f1)
        OLD_TAG=$(echo "${item}" | cut -d: -f2)
        if [ -n "${OLD_ID}" ]; then
            echo "   Eliminazione vecchio backup: ${OLD_TAG} (ID: ${OLD_ID})..."
            curl -s -X DELETE -H "Authorization: token ${GITHUB_TOKEN}" "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/${OLD_ID}" >/dev/null
            curl -s -X DELETE -H "Authorization: token ${GITHUB_TOKEN}" "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/git/refs/tags/${OLD_TAG}" >/dev/null || true
        fi
    done
fi

# Pulizia locale backups vecchi
find "${BACKUP_DIR}" -name "thof_*.enc" -type f -mtime +"${RETENTION_DAYS}" -delete 2>/dev/null || true

echo "=========================================================="
echo "🎉 Procedura di Backup Offsite completata con successo!"
echo "URL Repository: https://github.com/${REPO_OWNER}/${REPO_NAME}/releases"
echo "=========================================================="
