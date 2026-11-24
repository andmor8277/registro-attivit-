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
#
# Un solo ramo, non due. Il codice faceva `if command -v jq` e poi una copia della stessa lettura in
# python3: su PROD `jq` NON e' installato (verificato 24/11/2026), quindi il ramo jq non e' mai stato
# eseguito da nessuno su nessuna macchina. Due implementazioni della stessa regola, una mai provata,
# e' la classe di divergenza che questo progetto registra gia' per i PDF e per i ruoli.
RELEASE_ID=$(echo "${RELEASE_JSON}" | python3 -c "import sys, json; print(json.load(sys.stdin).get('id', ''))")

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
#
# Perche' questa parte e' stata riscritta (24/11/2026). Il cron delle 03:00, per circa 60 giorni, ha
# cancellato ogni notte LA RELEASE CHE AVEVA APPENA CREATO, e il log chiudeva con "🎉 Procedura di
# Backup Offsite completata con successo". Misurato su andmor8277/thof-backups:
#     backup-20261124_123319   creata=2026-09-25T07:27:04   pubbl=2026-11-24T12:33:20
# Il campo confrontato era `created_at`, che su quelle release e' di settembre: "vecchio di 60
# giorni" -> cancellata ogni notte. In sei mesi la storia offsite e' scesa a UNA release. Nessuna
# asserzione, nessun avviso, nessun rosso: il log diceva successo.
#
# La regola vive in scripts/lib/selezione_retention.py (UN solo ramo: `jq` non e' installato su PROD,
# quindi il ramo jq del codice vecchio non era mai stato eseguito da nessuno). Qui sopra restano tre
# cose che lo script deve fare da se':
#   - non cancellare niente se il selettore non capisce (rc!=0), invece di proseguire con la lista
#     vuota come se fosse un verdetto;
#   - dire ad alta voce cosa cancella e cosa conserva, perche' "completato con successo" mentre
#     cancella tutto e' cio' che ha nascosto il difetto;
#   - VERIFICARE A FINE GIRO che il backup di stanotte esista ancora. E' l'asserzione che avrebbe
#     beccato questo difetto in venti secondi sei settimane fa, ed e' l'unica che lo beccherebbe di
#     nuovo se il campo giusto smettesse di essere giusto per un motivo che oggi non immaginiamo.
echo "🧹 Verifica retention (conservazione ultimi ${RETENTION_DAYS} giorni)..."
RELEASES_LIST=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" \
    "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases?per_page=100")

CUTOFF_DATE=$(date -d "${RETENTION_DAYS} days ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -v -${RETENTION_DAYS}d +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || true)

# Il selettore fallisce in direzione sicura: nessun output = nessun backup cancellato.
DA_POTARE=""
POTANDA="${TMP_DIR}/da_potare.tsv"
if SELEZIONE_ERR=$(python3 "${SCRIPT_DIR}/lib/selezione_retention.py" \
        --cutoff "${CUTOFF_DATE}" --keep "${RELEASE_ID}" <<< "${RELEASES_LIST}" 2>&1 >"${POTANDA}"); then
    DA_POTARE=$(cat "${POTANDA}")
    echo "   $(head -1 <<<"${SELEZIONE_ERR}")"
else
    RC_SELEZIONE=$?
    echo "⚠️  [ATTENZIONE] Retention SALTATA (rc=${RC_SELEZIONE}): nessun backup cancellato."
    echo "   ${SELEZIONE_ERR}"
    echo "   E' la direzione voluta: quando il selettore non capisce, i backup restano tutti."
fi

POTATI=0; POTATI_TAG=""
if [ -n "${DA_POTARE}" ]; then
    while IFS=$'\t' read -r OLD_ID OLD_TAG; do
        [ -n "${OLD_ID}" ] || continue
        echo "   Eliminazione vecchio backup: ${OLD_TAG} (ID: ${OLD_ID})..."
        # Il codice vecchio buttava via la risposta: un DELETE che non partiva era invisibile, che e'
        # la meta' del motivo per cui nessuno si e' accorto di niente per due mesi.
        # `|| echo ERR-curl` e non basta il curl nudo: lo script e' in `set -euo pipefail`, quindi un
        # errore di rete qui dentro ucciderebbe il cron A META' retention, con alcuni backup gia'
        # cancellati e gli altri no. Meglio un numero che grida che un decesso silenzioso a meta'.
        CODICE=$(curl -s -o /dev/null -w '%{http_code}' -X DELETE \
            -H "Authorization: token ${GITHUB_TOKEN}" \
            "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/${OLD_ID}" 2>/dev/null || echo ERR-curl)
        if [ "${CODICE}" != "204" ] && [ "${CODICE}" != "200" ]; then
            echo "   ⚠️  release ${OLD_TAG}: DELETE ha risposto ${CODICE} (atteso 204)"
        fi
        curl -s -o /dev/null -X DELETE -H "Authorization: token ${GITHUB_TOKEN}" \
            "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/git/refs/tags/${OLD_TAG}" || true
        POTATI=$((POTATI + 1)); POTATI_TAG="${POTATI_TAG} ${OLD_TAG}"
    done <<< "${DA_POTARE}"
fi
echo "   Retention: ${POTATI} release cancellate${POTATI_TAG:+ ->${POTATI_TAG}}"

# 9b. Il backup di stanotte c'e' ancora? Senza questo controllo il cron puo' dichiarare successo
#     mentre ha appena cancellato l'unica copia offsite del database.
# Stesso motivo di sopra: `set -euo pipefail` + una pipe. Se il curl di questo controllo fallisce,
# la pipe esce male e il cron muore DOPO aver gia' caricato il backup: un errore che sembra "il backup
# non c'e'" quando era la rete. `|| true` lascia correre e parla il controllo sotto, che e' quello
# che deve essere rosso o verde.
ESISTE=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" \
    "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/${RELEASE_ID}" 2>/dev/null \
    | python3 -c "
import sys, json
# l'id arriva in argv, non interpolato nel sorgente: un valore vuoto avrebbe dato SyntaxError, e
# un SyntaxError qui e' un 'LEGGO-MALE' che sembra un guasto del backup invece che un bug del test
atteso = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else -1
try:
    r = json.load(sys.stdin)
except Exception:
    print('LEGGO-MALE'); raise SystemExit
print('SI' if r.get('id') == atteso and (r.get('assets') or []) else 'NO')" "${RELEASE_ID}" || true)
if [ "${ESISTE}" != "SI" ]; then
    echo "❌ [ERRORE] Il backup di stanotte (release ${RELEASE_ID}, tag ${TAG_NAME}) NON risulta su GitHub"
    echo "   con i suoi asset: il backup offsite NON c'e'. Non e' un avviso: controllare prima di"
    echo "   fidarsi di questo cron. (E' esattamente il controllo che mancava.)"
    exit 1
fi
echo "   ✅ Verificato: il backup ${TAG_NAME} e' su GitHub con i suoi asset"

# Pulizia locale backups vecchi
find "${BACKUP_DIR}" -name "thof_*.enc" -type f -mtime +"${RETENTION_DAYS}" -delete 2>/dev/null || true

echo "=========================================================="
echo "🎉 Procedura di Backup Offsite completata con successo!"
echo "URL Repository: https://github.com/${REPO_OWNER}/${REPO_NAME}/releases"
echo "=========================================================="
