#!/usr/bin/env bash
# ==============================================================================
# THOF - Pubblicazione APK su GitHub Releases
# ==============================================================================
# L'app Android non passa dal Play Store: l'APK finisce in un repository pubblico
# di soli rilasci (andmor8277/thof-releases) e da lì l'app stessa lo legge per
# avvisare l'utente che c'è una nuova versione (frontend/src/core/appUpdate.js).
#
# Cosa fa:
#   1. crea il repository di rilasci se non esiste (pubblico: serve all'app non autenticata)
#   2. crea o aggiorna la release del tag corrente
#   3. carica THOF.apk come asset (sostituendolo se già presente)
#   4. scrive version.json nel branch: è il fallback quando le API GitHub sono
#      in rate limit (60 req/ora per IP) e l'app lo usa per decidere l'avviso
#
# Uso:
#   ./scripts/publish_android_apk.sh                  # pubblica releases/apk/thof.apk
#   ./scripts/publish_android_apk.sh --dry-run        # mostra solo cosa farebbe
#   ./scripts/publish_android_apk.sh --notes "Fix registro presenze"
#   ./scripts/publish_android_apk.sh --apk /percorso/del.file.apk --force
#   ./scripts/publish_android_apk.sh --tag v0.0.1-test   # rilascio di prova, non consuma il tag
#
# Nota: la versione pubblicata viene dai tag git (come build_android_apk.sh).
# Per un rilascio nuovo fare quindi: ./release.sh minor "desc" e poi la build.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

REPO_OWNER="andmor8277"
REPO_NAME="thof-releases"
APK_ASSET_NAME="THOF.apk"
API="https://api.github.com"

APK_PATH="${PROJECT_DIR}/releases/apk/thof.apk"
NOTES=""
DRY_RUN=0
FORCE=0
TAG_OVERRIDE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --apk)    APK_PATH="${2:-}"; shift 2 ;;
        --notes)  NOTES="${2:-}"; shift 2 ;;
        --tag)    TAG_OVERRIDE="${2:-}"; shift 2 ;;
        --dry-run|-n) DRY_RUN=1; shift ;;
        --force)  FORCE=1; shift ;;
        -h|--help) sed -n '2,26p' "$0"; exit 0 ;;
        *) echo "Argomento non valido: $1" >&2; exit 2 ;;
    esac
done

# ------------------------------------------------------------------ token GitHub
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
if [ -z "${GITHUB_TOKEN}" ] && [ -f "$HOME/.git-credentials" ]; then
    GITHUB_TOKEN=$(grep "github.com" "$HOME/.git-credentials" | sed -n 's/.*:\(.*\)@github\.com.*/\1/p' | head -n 1)
fi
if [ -z "${GITHUB_TOKEN}" ]; then
    echo "❌ [ERRORE] Nessun token GitHub in GITHUB_TOKEN o ~/.git-credentials." >&2
    exit 1
fi

# ------------------------------------------------------------------ versione
cd "${PROJECT_DIR}"
VERSION_NAME=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "")
VERSION_CODE=$(git rev-list --count HEAD 2>/dev/null || echo "")
if [ -z "${VERSION_NAME}" ] || [ -z "${VERSION_CODE}" ]; then
    echo "❌ [ERRORE] Impossibile determinare versione da git (tag o conteggio commit)." >&2
    exit 1
fi
TAG_NAME="v${VERSION_NAME}"

# Tag esplicito per rilasci di prova o pre-rilasci: la versione pubblicata prende da lì,
# così si può collaudare la catena senza consumare il tag del prossimo rilascio vero.
if [ -n "${TAG_OVERRIDE}" ]; then
    VERSION_NAME="${TAG_OVERRIDE#v}"
    TAG_NAME="v${VERSION_NAME}"
fi

# ------------------------------------------------------------------ APK
if [ ! -f "${APK_PATH}" ]; then
    echo "❌ [ERRORE] APK non trovato: ${APK_PATH}" >&2
    echo "   Compilare prima con ./scripts/build_android_apk.sh" >&2
    exit 1
fi
APK_SIZE_BYTES=$(stat -c%s "${APK_PATH}" 2>/dev/null || stat -f%z "${APK_PATH}")
APK_SIZE_MB=$(awk -v b="${APK_SIZE_BYTES}" 'BEGIN{printf "%.1f", b/1048576}')
if [ "${APK_SIZE_BYTES}" -lt 1048576 ]; then
    echo "❌ [ERRORE] APK troppo piccolo (${APK_SIZE_MB} MB): probabilmente è un build fallita." >&2
    exit 1
fi

# ------------------------------------------------------------------ note di rilascio
if [ -z "${NOTES}" ]; then
    PREV_TAG=$(git describe --tags --abbrev=0 "HEAD^" 2>/dev/null || echo "")
    if [ -n "${PREV_TAG}" ]; then
        NOTES=$(git log --pretty=format:'- %s' "${PREV_TAG}..HEAD" 2>/dev/null || echo "")
    else
        NOTES=$(git log --max-count=15 --pretty=format:'- %s' HEAD 2>/dev/null || echo "")
    fi
    # Se il tag corrente punta già a HEAD non c'è nulla di nuovo tra i commit: meglio
    # un testo onesto che una lista vuota che sembra un rilascio fantasma.
    if [ -z "${NOTES}" ]; then
        NOTES="- Aggiornamenti generali e di stabilità"
    fi
fi

RELEASE_NAME="The Home of Football ${TAG_NAME}"

echo "=========================================================="
echo "📦 THOF - Pubblicazione APK su GitHub Releases"
echo "   Repo      : ${REPO_OWNER}/${REPO_NAME}"
echo "   Tag       : ${TAG_NAME}  (versionCode ${VERSION_CODE})"
echo "   APK       : ${APK_PATH} (${APK_SIZE_MB} MB)"
echo "   Note      : $(echo "${NOTES}" | head -1)$( [ "$(echo "${NOTES}" | wc -l)" -gt 1 ] && echo " …" )"
[ "${DRY_RUN}" -eq 1 ] && echo "   MODALITÀ  : dry-run (nessuna scrittura)"
echo "=========================================================="

# ------------------------------------------------------------------ helper API
# gh_api METHOD ENDPOINT [json]  -> stampa "corpo\nSTATUS"
gh_api() {
    local method="$1" endpoint="$2" data="${3:-}"
    local args=(-s -w $'\n%{http_code}' -X "${method}" "${API}${endpoint}"
                -H "Authorization: Bearer ${GITHUB_TOKEN}"
                -H "Accept: application/vnd.github+json"
                -H "User-Agent: thof-publish")
    if [ -n "${data}" ]; then
        args+=(-H "Content-Type: application/json" -d "${data}")
    fi
    curl "${args[@]}"
}

json_get() {  # json_get '<json>' '<percorso python>'
    python3 - "$1" "$2" <<'PY' 2>/dev/null || true
import json, sys
raw, path = sys.argv[1], sys.argv[2]
try:
    obj = json.loads(raw)
except Exception:
    sys.exit(0)
for part in path.split('.'):
    if obj is None:
        break
    if part.isdigit():
        try:
            obj = obj[int(part)]
        except (IndexError, ValueError, TypeError):
            obj = None
    else:
        obj = obj.get(part) if isinstance(obj, dict) else None
print('' if obj is None else (json.dumps(obj) if isinstance(obj, (dict, list)) else obj))
PY
}

split_response() {  # pone RESP_BODY e RESP_STATUS
    local out="$1"
    RESP_STATUS="${out##*$'\n'}"
    RESP_BODY="${out%$'\n'*}"
}

# ------------------------------------------------------------------ 1) repo
split_response "$(gh_api GET "/repos/${REPO_OWNER}/${REPO_NAME}")"
case "${RESP_STATUS}" in
    200) echo "✓ Repository ${REPO_OWNER}/${REPO_NAME} esistente" ;;
    404)
        if [ "${DRY_RUN}" -eq 1 ]; then
            echo "• [dry-run] creerebbe il repository pubblico ${REPO_OWNER}/${REPO_NAME}"
        else
            echo "• Creo il repository pubblico ${REPO_OWNER}/${REPO_NAME}..."
            payload=$(python3 - "${REPO_NAME}" <<'PY'
import json, sys
readme = (
    "# THOF Releases\n\n"
    "Repository di soli rilasci APK di The Home of Football.\n"
    "L'app legge le release (e `version.json` come fallback) per avvisare gli utenti\n"
    "quando esiste una versione più recente della propria.\n\n"
    "Non modificare `version.json` a mano: lo scrive `scripts/publish_android_apk.sh`.\n"
)
print(json.dumps({
    "name": sys.argv[1],
    "private": False,
    "description": "Rilasci APK Android di The Home of Football (THOF), letti dall'app per l'aggiornamento",
    "has_issues": False,
    "has_wiki": False,
    "auto_init": True,
    "readme": readme,
}))
PY
)
            split_response "$(gh_api POST "/user/repos" "${payload}")"
            if [ "${RESP_STATUS}" != "201" ]; then
                echo "❌ [ERRORE] Creazione repository fallita (${RESP_STATUS}): $(json_get "${RESP_BODY}" 'message')" >&2
                exit 1
            fi
            echo "✓ Repository creato (pubblico: l'app lo legge senza autenticazione)"
        fi
        ;;
    *)  echo "❌ [ERRORE] Impossibile leggere il repository (${RESP_STATUS}): $(json_get "${RESP_BODY}" 'message')" >&2
        exit 1 ;;
esac

# ------------------------------------------------------------------ 2) release
split_response "$(gh_api GET "/repos/${REPO_OWNER}/${REPO_NAME}/releases/tags/${TAG_NAME}")"
RELEASE_ID=""
UPLOAD_URL=""
if [ "${RESP_STATUS}" = "200" ]; then
    RELEASE_ID=$(json_get "${RESP_BODY}" 'id')
    UPLOAD_URL=$(json_get "${RESP_BODY}" 'upload_url')
    UPLOAD_URL="${UPLOAD_URL%%\{*}"
    if [ "${FORCE}" -eq 1 ]; then
        echo "• Release ${TAG_NAME} già esistente: --force, la aggiorno e ricambio l'asset"
    else
        echo "❌ [ERRORE] La release ${TAG_NAME} esiste già (id ${RELEASE_ID})." >&2
        echo "   O fai un nuovo tag (./release.sh minor \"desc\") o usi --force per sostituirla." >&2
        exit 1
    fi
fi

if [ "${DRY_RUN}" -eq 1 ]; then
    echo "• [dry-run] creerebbe/aggiornerebbe la release ${TAG_NAME} con l'asset ${APK_ASSET_NAME}"
    echo "• [dry-run] scriverebbe version.json nel branch"
    echo "✓ Dry-run completato, nessuna scrittura su GitHub"
    exit 0
fi

if [ -z "${RELEASE_ID}" ]; then
    payload=$(python3 -c "
import json,sys
print(json.dumps({'tag_name':'${TAG_NAME}','name':sys.argv[1],'body':sys.argv[2],'draft':False,'prerelease':False}))
" "${RELEASE_NAME}" "${NOTES}")
    split_response "$(gh_api POST "/repos/${REPO_OWNER}/${REPO_NAME}/releases" "${payload}")"
    if [ "${RESP_STATUS}" != "201" ]; then
        echo "❌ [ERRORE] Creazione release fallita (${RESP_STATUS}): $(json_get "${RESP_BODY}" 'message')" >&2
        exit 1
    fi
    RELEASE_ID=$(json_get "${RESP_BODY}" 'id')
    UPLOAD_URL=$(json_get "${RESP_BODY}" 'upload_url')
    UPLOAD_URL="${UPLOAD_URL%%\{*}"
    echo "✓ Release ${TAG_NAME} creata (id ${RELEASE_ID})"
else
    payload=$(python3 -c "
import json,sys
print(json.dumps({'name':sys.argv[1],'body':sys.argv[2]}))
" "${RELEASE_NAME}" "${NOTES}")
    split_response "$(gh_api PATCH "/repos/${REPO_OWNER}/${REPO_NAME}/releases/${RELEASE_ID}" "${payload}")"
    echo "✓ Release ${TAG_NAME} aggiornata"
fi

# ------------------------------------------------------------------ 3) asset APK
# Si elimina prima di ricaricare: GitHub non sostituisce un asset omonimo, ne aggiunge
# un secondo (THOF-1.apk) e l'app si ritroverebbe a scaricare il vecchio.
split_response "$(gh_api GET "/repos/${REPO_OWNER}/${REPO_NAME}/releases/${RELEASE_ID}/assets")"
if [ "${RESP_STATUS}" = "200" ]; then
    old_ids=$(python3 -c "
import json,sys
try:
    assets=json.loads(sys.argv[1])
except Exception:
    assets=[]
print(' '.join(str(a['id']) for a in assets if str(a.get('name','')).lower().endswith('.apk')))
" "${RESP_BODY}")
    for aid in ${old_ids}; do
        gh_api DELETE "/repos/${REPO_OWNER}/${REPO_NAME}/releases/assets/${aid}" >/dev/null
        echo "• Rimosso asset precedente (id ${aid})"
    done
fi

echo "• Carico ${APK_ASSET_NAME} (${APK_SIZE_MB} MB)..."
UPLOAD_RESP=$(mktemp)
trap 'rm -f "${UPLOAD_RESP}"' EXIT
upload_status=$(curl -s -o "${UPLOAD_RESP}" -w '%{http_code}' \
    -X POST "${UPLOAD_URL}?name=${APK_ASSET_NAME}" \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "Content-Type: application/vnd.android.package-archive" \
    --data-binary "@${APK_PATH}")
APK_URL=$(python3 -c "
import json
try:
    print(json.load(open('${UPLOAD_RESP}')).get('browser_download_url',''))
except Exception:
    print('')
" 2>/dev/null || echo "")
if [ "${upload_status}" != "201" ]; then
    echo "❌ [ERRORE] Upload APK fallito (HTTP ${upload_status})" >&2
    exit 1
fi
[ -z "${APK_URL}" ] && APK_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download/${TAG_NAME}/${APK_ASSET_NAME}"
echo "✓ APK caricato: ${APK_URL}"

# ------------------------------------------------------------------ 4) version.json
PUBLISHED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
MANIFEST=$(python3 -c "
import json,sys
print(json.dumps({
 'version': sys.argv[1],
 'tagName': sys.argv[2],
 'versionCode': int(sys.argv[3]),
 'releaseName': sys.argv[4],
 'releaseNotes': sys.argv[5],
 'publishedAt': sys.argv[6],
 'apkDownloadUrl': sys.argv[7],
 'apkSizeMb': sys.argv[8],
 'releasePageUrl': sys.argv[9],
}, ensure_ascii=False, indent=2))
" "${VERSION_NAME}" "${TAG_NAME}" "${VERSION_CODE}" "${RELEASE_NAME}" "${NOTES}" "${PUBLISHED_AT}" "${APK_URL}" "${APK_SIZE_MB}" "https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/latest")

split_response "$(gh_api GET "/repos/${REPO_OWNER}/${REPO_NAME}")"
DEFAULT_BRANCH=$(json_get "${RESP_BODY}" 'default_branch')
[ -z "${DEFAULT_BRANCH}" ] && DEFAULT_BRANCH="main"
split_response "$(gh_api GET "/repos/${REPO_OWNER}/${REPO_NAME}/contents/version.json?ref=${DEFAULT_BRANCH}")"
FILE_SHA=""
[ "${RESP_STATUS}" = "200" ] && FILE_SHA=$(json_get "${RESP_BODY}" 'sha')

payload=$(python3 -c "
import json,sys,base64
d={'message':'release '+sys.argv[1],'content':base64.b64encode(sys.argv[2].encode()).decode()}
if sys.argv[3]: d['sha']=sys.argv[3]
print(json.dumps(d))
" "${TAG_NAME}" "${MANIFEST}" "${FILE_SHA}")
split_response "$(gh_api PUT "/repos/${REPO_OWNER}/${REPO_NAME}/contents/version.json?ref=${DEFAULT_BRANCH}" "${payload}")"
if [ "${RESP_STATUS}" != "201" ] && [ "${RESP_STATUS}" != "200" ]; then
    echo "⚠ [ATTENZIONE] version.json non aggiornato (${RESP_STATUS}): $(json_get "${RESP_BODY}" 'message')" >&2
    echo "   L'avviso dentro l'app continuerà a usare le API GitHub; il fallback resta vecchio." >&2
else
    echo "✓ version.json aggiornato su ${REPO_OWNER}/${REPO_NAME}@${DEFAULT_BRANCH}"
fi

echo "=========================================================="
echo "✅ Rilascio ${TAG_NAME} pubblicato"
echo "   Download   : ${APK_URL}"
echo "   Pagina     : https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/latest"
echo "   Prossimo passo: trasferisci l'APK sui telefoni (USB o WhatsApp):"
echo "   solo le installazioni successive a questo file mostreranno l'avviso automatico."
echo "=========================================================="
