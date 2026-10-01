#!/usr/bin/env bash
# ==============================================================================
# The Home of Football (THOF) - Setup/Copia Progetto da USB a Nuova Postazione
# ==============================================================================
# Uso su una nuova postazione:
#   cd /run/media/TUO_UTENTE/.../registro_presenze
#   ./scripts/clone_from_usb.sh [cartella_destinazione]
# Esempio:
#   ./scripts/clone_from_usb.sh ~/registro_presenze
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USB_PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

DEST_DIR="${1:-$HOME/registro_presenze}"

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

echo -e "${BOLD}==============================================================================${RESET}"
echo -e "${BOLD} THOF - Installazione/Sincronizzazione su Nuova Postazione${RESET}"
echo -e "${BOLD}==============================================================================${RESET}"
log_info "Sorgente (USB): ${USB_PROJECT_DIR}"
log_info "Destinazione locale: ${DEST_DIR}"

if [ -d "${DEST_DIR}/.git" ]; then
    log_warn "La directory di destinazione esiste già ed è un repository Git."
    read -p "Vuoi aggiornare i file dalla USB verso ${DEST_DIR}? (s/N): " -r CONFIRM
    if [[ ! "$CONFIRM" =~ ^[sSyY]$ ]]; then
        log_info "Operazione annullata."
        exit 0
    fi
fi

mkdir -p "${DEST_DIR}"

log_info "Copia file di progetto e repository da USB alla postazione locale..."
rsync -rtvh --progress \
    --exclude='node_modules' \
    --exclude='.venv' \
    --exclude='/frontend/dist' \
    --exclude='/frontend/android/.gradle' \
    --exclude='/frontend/android/build' \
    --exclude='/frontend/android/app/build' \
    --exclude='/backend/app/**/__pycache__' \
    --exclude='/backend/*.pyc' \
    --exclude='/backups/*.sql.gz' \
    --exclude='/releases/apk' \
    --exclude='*.log' \
    --exclude='.git/index.lock' \
    --exclude='.git/config.lock' \
    "${USB_PROJECT_DIR}/" "${DEST_DIR}/"

cd "${DEST_DIR}"

# Ripristina filemode nativo per Linux/SSD
if [ -d ".git" ]; then
    git config core.filemode true
    log_info "Configurato Git nativo (core.filemode=true)"
fi

# Installa git hooks
if [ -f "scripts/install-hooks.sh" ]; then
    log_info "Installazione Git hooks (pre-commit e post-commit per sync USB)..."
    ./scripts/install-hooks.sh >/dev/null 2>&1 || true
fi

# Crea symlink comodi nella root del progetto
ln -sf scripts/sync_to_usb.sh sync_to_usb.sh
ln -sf scripts/update_project.sh aggiorna_progetto.sh

# Controllo dipendenze frontend
if [ ! -d "frontend/node_modules" ]; then
    if command -v npm >/dev/null 2>&1; then
        echo ""
        log_warn "La cartella 'frontend/node_modules' non è ancora presente."
        read -p "Vuoi installare le dipendenze npm adesso? (S/n): " -r RUN_NPM
        if [[ "$RUN_NPM" =~ ^[sSyY]?$ ]]; then
            log_info "Esecuzione npm install in frontend..."
            cd frontend && npm install && cd ..
            log_success "Dipendenze frontend installate!"
        fi
    else
        log_warn "npm non trovato su questo sistema. Ricordati di installare Node.js / npm per lo sviluppo frontend."
    fi
fi

echo ""
echo -e "${BOLD}==============================================================================${RESET}"
log_success "Installazione completata con successo in: ${DEST_DIR}"
echo -e "Per lavorare sul progetto:"
echo -e "  1) cd ${DEST_DIR}"
echo -e "  2) ./start_dev.sh                # Per avviare l'ambiente di sviluppo"
echo -e "  3) ./aggiorna_progetto.sh        # Per scaricare gli ultimi commit da GitHub/USB"
echo -e "  4) ./sync_to_usb.sh              # Per sincronizzare manualmente sulla USB (avviene anche al commit)"
echo -e "${BOLD}==============================================================================${RESET}"

exit 0
