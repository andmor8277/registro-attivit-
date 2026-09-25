#!/usr/bin/env bash
# ==============================================================================
# THOF - Disaster Recovery / Restore from Encrypted GitHub Backup
# 
# Usage:
#   ./scripts/restore_offsite_github.sh                # Ripristina l'ultimo backup disponibile
#   ./scripts/restore_offsite_github.sh backup-TAG     # Ripristina un backup specifico
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_OWNER="andmor8277"
REPO_NAME="thof-backups"

TARGET_TAG="${1:-}"

TMP_DIR=$(mktemp -d "/tmp/thof_restore_XXXXXX")
cleanup() {
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

echo "=========================================================="
echo "🔄 THOF - Disaster Recovery / Ripristino da GitHub"
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
    echo "❌ [ERRORE] ENCRYPTION_KEY non trovata in .env. Impossibile decifrare il backup."
    exit 1
fi

# 2. Token GitHub
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
if [ -z "${GITHUB_TOKEN}" ]; then
    if [ -f "$HOME/.git-credentials" ]; then
        GITHUB_TOKEN=$(grep "github.com" "$HOME/.git-credentials" | sed -n 's/.*:\(.*\)@github\.com.*/\1/p' | head -n 1)
    fi
fi

if [ -z "${GITHUB_TOKEN}" ]; then
    echo "❌ [ERRORE] Token GitHub non trovato."
    exit 1
fi

# 3. Rileva container Docker
DB_CONTAINER=$(docker ps --filter "name=db" --filter "status=running" --format "{{.Names}}" | head -n 1)
if [ -z "${DB_CONTAINER}" ]; then
    DB_CONTAINER=$(docker ps --filter "name=postgres" --filter "status=running" --format "{{.Names}}" | head -n 1)
fi

if [ -z "${DB_CONTAINER}" ]; then
    echo "❌ [ERRORE] Container PostgreSQL non trovato o non in esecuzione."
    exit 1
fi

BACKEND_CONTAINER=$(docker ps --filter "name=backend" --filter "status=running" --format "{{.Names}}" | head -n 1)

# 4. Ottieni info sulla release da scaricare
if [ -z "${TARGET_TAG}" ]; then
    echo "🔍 Ricerca ultimo backup disponibile su GitHub..."
    RELEASE_DATA=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" \
        "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest")
else
    echo "🔍 Ricerca backup con tag '${TARGET_TAG}' su GitHub..."
    RELEASE_DATA=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" \
        "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/tags/${TARGET_TAG}")
fi

if command -v jq >/dev/null 2>&1; then
    TAG=$(echo "${RELEASE_DATA}" | jq -r '.tag_name // empty')
else
    TAG=$(echo "${RELEASE_DATA}" | python3 -c "import sys, json; print(json.load(sys.stdin).get('tag_name', ''))")
fi

if [ -z "${TAG}" ] || [ "${TAG}" = "null" ]; then
    echo "❌ [ERRORE] Nessun backup trovato su GitHub."
    exit 1
fi

echo "📦 Backup selezionato: ${TAG}"

# 5. Scarica gli asset
echo "⬇️ Download degli asset cifrati da GitHub..."
if command -v jq >/dev/null 2>&1; then
    ASSETS=$(echo "${RELEASE_DATA}" | jq -r '.assets[] | "\(.id):\(.name)"')
else
    ASSETS=$(echo "${RELEASE_DATA}" | python3 -c "
import sys, json
for a in json.load(sys.stdin).get('assets', []):
    print(f\"{a['id']}:{a['name']}\")
")
fi

DB_ASSET_ID=""
DB_ASSET_NAME=""
UPLOADS_ASSET_ID=""
UPLOADS_ASSET_NAME=""

for a in ${ASSETS}; do
    A_ID=$(echo "${a}" | cut -d: -f1)
    A_NAME=$(echo "${a}" | cut -d: -f2)
    if [[ "${A_NAME}" == thof_db_*.enc ]]; then
        DB_ASSET_ID="${A_ID}"
        DB_ASSET_NAME="${A_NAME}"
    elif [[ "${A_NAME}" == thof_uploads_*.enc ]]; then
        UPLOADS_ASSET_ID="${A_ID}"
        UPLOADS_ASSET_NAME="${A_NAME}"
    fi
done

if [ -z "${DB_ASSET_ID}" ]; then
    echo "❌ [ERRORE] Asset database non trovato in questo backup."
    exit 1
fi

echo "   Scaricamento ${DB_ASSET_NAME}..."
curl -s -L -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/octet-stream" \
    "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/assets/${DB_ASSET_ID}" \
    -o "${TMP_DIR}/${DB_ASSET_NAME}"

if [ -n "${UPLOADS_ASSET_ID}" ]; then
    echo "   Scaricamento ${UPLOADS_ASSET_NAME}..."
    curl -s -L -H "Authorization: token ${GITHUB_TOKEN}" \
        -H "Accept: application/octet-stream" \
        "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/assets/${UPLOADS_ASSET_ID}" \
        -o "${TMP_DIR}/${UPLOADS_ASSET_NAME}"
fi

# 6. Decifratura OpenSSL
echo "🔓 Decifratura file con AES-256-CBC..."
DB_DECRYPTED="${TMP_DIR}/thof_db.sql.gz"
openssl enc -d -aes-256-cbc -salt -pbkdf2 -pass pass:"${ENCRYPTION_KEY}" \
    -in "${TMP_DIR}/${DB_ASSET_NAME}" -out "${DB_DECRYPTED}"

# 7. Ripristino Database
echo "⚠️ ATTENZIONE: Il ripristino sovrascriverà i dati del database attuale '${DB_NAME}'."
read -p "Continuare con il ripristino? (s/N): " -r CONFIRM
if [[ ! "${CONFIRM}" =~ ^[sSyY]$ ]]; then
    echo "Operazione annullata dall'utente."
    exit 0
fi

echo "💾 Ripristino del database in corso..."
gunzip -c "${DB_DECRYPTED}" | docker exec -i "${DB_CONTAINER}" psql -U "${DB_USER}" -d "${DB_NAME}"

# 8. Ripristino Uploads
if [ -n "${UPLOADS_ASSET_ID}" ] && [ -n "${BACKEND_CONTAINER}" ]; then
    echo "📁 Decifratura e ripristino cartella uploads (/app/uploads)..."
    UPLOADS_DECRYPTED="${TMP_DIR}/thof_uploads.tar.gz"
    openssl enc -d -aes-256-cbc -salt -pbkdf2 -pass pass:"${ENCRYPTION_KEY}" \
        -in "${TMP_DIR}/${UPLOADS_ASSET_NAME}" -out "${UPLOADS_DECRYPTED}"
    docker exec -i "${BACKEND_CONTAINER}" tar -xzf - -C /app/uploads < "${UPLOADS_DECRYPTED}"
fi

echo "=========================================================="
echo "✅ Ripristino completato con successo da '${TAG}'!"
echo "=========================================================="
