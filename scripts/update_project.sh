#!/usr/bin/env bash
# ==============================================================================
# The Home of Football (THOF) - Aggiornamento Progetto all'Ultimo Commit
# ==============================================================================
# Uso:
#   ./scripts/update_project.sh             # Aggiorna da GitHub (o da USB se offline)
#   ./scripts/update_project.sh --from-usb  # Forza aggiornamento direttamente dalla chiavetta USB
# ==============================================================================
set -euo pipefail

SCRIPT_REAL="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_REAL}")" && pwd)"
if git -C "${SCRIPT_DIR}" rev-parse --show-toplevel >/dev/null 2>&1; then
    PROJECT_DIR="$(git -C "${SCRIPT_DIR}" rev-parse --show-toplevel)"
else
    PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

# Colori output
if [ -t 1 ]; then
    GREEN="\033[1;32m"
    BLUE="\033[1;34m"
    YELLOW="\033[1;33m"
    RED="\033[1;31m"
    BOLD="\033[1m"
    RESET="\033[0m"
else
    GREEN=""
    BLUE=""
    YELLOW=""
    RED=""
    BOLD=""
    RESET=""
fi

log_info()    { echo -e "${BLUE}[$(date +'%H:%M:%S')] [INFO]${RESET} $1"; }
log_success() { echo -e "${GREEN}[$(date +'%H:%M:%S')] [SUCCESS]${RESET} $1"; }
log_warn()    { echo -e "${YELLOW}[$(date +'%H:%M:%S')] [WARN]${RESET} $1"; }
log_error()   { echo -e "${RED}[$(date +'%H:%M:%S')] [ERROR]${RESET} $1" >&2; }

FORCE_USB=false
if [ "${1:-}" = "--from-usb" ] || [ "${1:-}" = "-u" ]; then
    FORCE_USB=true
fi

cd "${PROJECT_DIR}"

if [ ! -d ".git" ]; then
    log_error "Nessun repository Git trovato in ${PROJECT_DIR}."
    exit 1
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
INITIAL_COMMIT=$(git rev-parse HEAD)
log_info "Cartella progetto: ${PROJECT_DIR}"
log_info "Branch corrente: ${BOLD}${CURRENT_BRANCH}${RESET}"
log_info "Commit attuale: $(git log -1 --pretty=format:'%h ("%s")' HEAD)"

# Rilevamento chiavetta USB (se presente)
detect_usb() {
    local cand
    for cand in $(lsblk -r -n -o RM,MOUNTPOINT 2>/dev/null | awk '$1=="1" && $2!="" {print $2}'); do
        if [ -d "$cand/registro_presenze/.git" ]; then
            echo "$cand/registro_presenze"
            return 0
        fi
    done
    local current_user="${USER:-$(whoami)}"
    for cand in /run/media/"$current_user"/*/registro_presenze /media/"$current_user"/*/registro_presenze /media/*/registro_presenze; do
        if [ -d "$cand/.git" ]; then
            echo "$cand"
            return 0
        fi
    done
    return 1
}

USB_REPO="$(detect_usb)" || USB_REPO=""

# Gestione modifiche locali non committate
STASHED=false
if ! git diff-index --quiet HEAD --; then
    log_warn "Sono presenti modifiche locali non salvate nel repository."
    STASH_NAME="autostash_update_$(date +'%Y%m%d_%H%M%S')"
    log_info "Salvataggio temporaneo delle modifiche in stash: ${STASH_NAME}..."
    git stash push -m "${STASH_NAME}" --include-untracked >/dev/null
    STASHED=true
fi

# Modalità di aggiornamento: Da USB o da Remote GitHub
PULLED=false

if [ "$FORCE_USB" = true ]; then
    if [ -z "$USB_REPO" ]; then
        log_error "Opzione --from-usb richiesta ma nessuna cartella 'registro_presenze' trovata su USB."
        [ "$STASHED" = true ] && git stash pop >/dev/null || true
        exit 1
    fi
    log_info "Aggiornamento forzato dalla chiavetta USB: ${USB_REPO}..."
    git pull "$USB_REPO" "$CURRENT_BRANCH"
    PULLED=true
else
    # Prova prima con GitHub (remoto configurato)
    REMOTE_URL=$(git remote get-url origin 2>/dev/null || git remote get-url github 2>/dev/null || echo "")
    REMOTE_NAME="origin"
    if ! git remote | grep -q "^origin$"; then
        REMOTE_NAME=$(git remote | head -n 1)
    fi

    ONLINE=false
    if [ -n "$REMOTE_NAME" ]; then
        log_info "Verifica connessione con il remote Git (${REMOTE_NAME})..."
        if git ls-remote --exit-code "$REMOTE_NAME" >/dev/null 2>&1; then
            ONLINE=true
        fi
    fi

    if [ "$ONLINE" = true ]; then
        log_info "Scaricamento ultimi commit da GitHub (${REMOTE_NAME}/${CURRENT_BRANCH})..."
        git fetch "$REMOTE_NAME" "$CURRENT_BRANCH"
        
        BEHIND=$(git rev-list HEAD.."${REMOTE_NAME}/${CURRENT_BRANCH}" --count 2>/dev/null || echo "0")
        if [ "$BEHIND" -gt 0 ]; then
            log_info "Trovati ${BEHIND} nuovi commit da scaricare:"
            git log HEAD.."${REMOTE_NAME}/${CURRENT_BRANCH}" --oneline
            git pull --ff-only "$REMOTE_NAME" "$CURRENT_BRANCH" || git pull --rebase "$REMOTE_NAME" "$CURRENT_BRANCH"
            PULLED=true
        else
            log_info "Il repository locale è già allineato con il remote GitHub."
        fi
    else
        log_warn "Remote GitHub non raggiungibile o offline."
        if [ -n "$USB_REPO" ]; then
            log_info "Chiavetta USB rilevata con repository THOF! Provo ad aggiornare dalla USB..."
            git pull "$USB_REPO" "$CURRENT_BRANCH"
            PULLED=true
        else
            log_warn "Nessuna chiavetta USB con THOF collegata. Impossibile sincronizzare."
        fi
    fi
fi

# Ripristino modifiche locali dallo stash
if [ "$STASHED" = true ]; then
    log_info "Ripristino delle modifiche locali salvate in precedenza..."
    git stash pop >/dev/null || {
        log_warn "Attenzione: c'è stato un conflitto nel ripristino delle modifiche locali. Controlla con 'git status'."
    }
fi

# Verifica e sincronizzazione file di configurazione (.env) dalla USB se presenti
if [ -n "$USB_REPO" ]; then
    log_info "Controllo file di configurazione ambiente (.env) da USB..."
    for env_file in .env .env.dev .env.prod backend/.env frontend/.env frontend/.env.local; do
        if [ -f "${USB_REPO}/${env_file}" ]; then
            if [ ! -f "${PROJECT_DIR}/${env_file}" ]; then
                log_info "Ripristino file mancante: ${env_file} da USB"
                mkdir -p "$(dirname "${PROJECT_DIR}/${env_file}")"
                cp -p "${USB_REPO}/${env_file}" "${PROJECT_DIR}/${env_file}"
            fi
        fi
    done
fi

NEW_COMMIT=$(git rev-parse HEAD)
echo ""
echo -e "${BOLD}==============================================================================${RESET}"
if [ "$INITIAL_COMMIT" != "$NEW_COMMIT" ]; then
    log_success "Progetto aggiornato con successo a un nuovo commit!"
else
    log_success "Progetto già all'ultimo commit!"
fi
echo -e "Commit attuale: ${GREEN}$(git log -1 --pretty=format:'%h - %s (%an, %cr)' HEAD)${RESET}"
echo -e "${BOLD}==============================================================================${RESET}"

# Verifica se package.json è cambiato rispetto all'inizio
if [ "$INITIAL_COMMIT" != "$NEW_COMMIT" ]; then
    if git diff --name-only "$INITIAL_COMMIT" "$NEW_COMMIT" | grep -q "frontend/package.json"; then
        log_warn "frontend/package.json è stato modificato in questo aggiornamento."
        log_info "Si consiglia di eseguire: cd frontend && npm install"
    fi
fi

exit 0
