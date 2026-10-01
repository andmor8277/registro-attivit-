#!/usr/bin/env bash
# ==============================================================================
# The Home of Football (THOF) - Sincronizzazione automatica su Chiavetta USB
# ==============================================================================
set -euo pipefail

# Risolvi sempre la vera directory radice del repository Git
SCRIPT_REAL="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_REAL}")" && pwd)"
if git -C "${SCRIPT_DIR}" rev-parse --show-toplevel >/dev/null 2>&1; then
    PROJECT_DIR="$(git -C "${SCRIPT_DIR}" rev-parse --show-toplevel)"
else
    PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

QUIET=false
if [ "${1:-}" = "--quiet" ] || [ "${1:-}" = "-q" ]; then
    QUIET=true
    shift || true
fi

# Colori per output (solo se interattivo)
if [ -t 1 ] && [ "$QUIET" = false ]; then
    GREEN="\033[1;32m"
    BLUE="\033[1;34m"
    YELLOW="\033[1;33m"
    RED="\033[1;31m"
    RESET="\033[0m"
else
    GREEN=""
    BLUE=""
    YELLOW=""
    RED=""
    RESET=""
fi

log_info() {
    if [ "$QUIET" = false ]; then
        echo -e "${BLUE}[$(date +'%H:%M:%S')] [INFO]${RESET} $1"
    fi
}

log_success() {
    if [ "$QUIET" = false ]; then
        echo -e "${GREEN}[$(date +'%H:%M:%S')] [SUCCESS]${RESET} $1"
    fi
}

log_warn() {
    if [ "$QUIET" = false ]; then
        echo -e "${YELLOW}[$(date +'%H:%M:%S')] [WARN]${RESET} $1"
    fi
}

log_error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] [ERROR]${RESET} $1" >&2
}

# Funzione per rilevare automaticamente il percorso della chiavetta USB
detect_usb() {
    # 1. Se passato come primo parametro
    if [ -n "${1:-}" ] && [ -d "$1" ]; then
        echo "$1"
        return 0
    fi

    # 2. Cerca se registro_presenze esiste già su un volume rimovibile
    local cand
    for cand in $(lsblk -r -n -o RM,MOUNTPOINT 2>/dev/null | awk '$1=="1" && $2!="" {print $2}'); do
        if [ -d "$cand/registro_presenze" ] && [ -w "$cand/registro_presenze" ]; then
            echo "$cand"
            return 0
        fi
    done

    # 3. Cerca il primo volume rimovibile con permessi di scrittura
    for cand in $(lsblk -r -n -o RM,MOUNTPOINT 2>/dev/null | awk '$1=="1" && $2!="" {print $2}'); do
        if [ -w "$cand" ]; then
            echo "$cand"
            return 0
        fi
    done

    # 4. Fallback su directory tipiche di montaggio Linux (/run/media/$USER o /media/$USER)
    local current_user="${USER:-$(whoami)}"
    for cand in /run/media/"$current_user"/* /media/"$current_user"/* /media/*; do
        if [ -d "$cand" ] && [ -w "$cand" ]; then
            echo "$cand"
            return 0
        fi
    done

    return 1
}

USB_ROOT="$(detect_usb "${1:-}")" || {
    if [ "$QUIET" = false ]; then
        log_warn "Nessuna chiavetta USB rilevata con permessi di scrittura."
        log_info "Collega la chiavetta USB e riprova, oppure specifica il percorso: $0 /percorso/usb"
    fi
    exit 0
}

TARGET_DIR="${USB_ROOT}/registro_presenze"

log_info "Chiavetta USB rilevata: ${USB_ROOT}"
log_info "Origine progetto: ${PROJECT_DIR}"
log_info "Destinazione progetto: ${TARGET_DIR}"

# Crea la cartella di destinazione se non esiste
mkdir -p "${TARGET_DIR}"

log_info "Sincronizzazione incrementale in corso..."

rsync -rtvL --delete \
    --modify-window=2 \
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
    "${PROJECT_DIR}/" "${TARGET_DIR}/" > /dev/null

# Ottimizzazione specifica Git per exFAT:
if [ -d "${TARGET_DIR}/.git" ]; then
    git -C "${TARGET_DIR}" config core.filemode false
    git -C "${TARGET_DIR}" config core.ignorecase true
fi

LAST_COMMIT=$(git -C "${PROJECT_DIR}" log -1 --pretty=format:"%h - %s (%cr)" 2>/dev/null || echo "N/D")

log_success "Sincronizzazione completata su USB con successo!"
log_info "Ultimo commit sincronizzato: ${LAST_COMMIT}"

# Notifica desktop se disponibile
if command -v notify-send >/dev/null 2>&1 && [ -n "${DISPLAY:-${WAYLAND_DISPLAY:-}}" ]; then
    notify-send -a "THOF" "THOF: USB Sincronizzata" "Progetto sincronizzato su ${USB_ROOT}\n${LAST_COMMIT}" 2>/dev/null || true
fi

exit 0
