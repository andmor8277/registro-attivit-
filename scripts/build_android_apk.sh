#!/bin/bash
# Script per compilare l'app Android di The Home of Football (THOF)
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "=== 1. Compilazione Web App & Sync Capacitor ==="
cd frontend
VITE_API_URL=https://thof.crickethouse.mywire.org/api npm run cap:sync
cd "$ROOT_DIR"

CONTAINER_BIN=""
if command -v docker >/dev/null 2>&1; then
    CONTAINER_BIN="docker"
elif command -v podman >/dev/null 2>&1; then
    CONTAINER_BIN="podman"
else
    echo "Errore: né Docker né Podman sono installati." >&2
    exit 1
fi

echo "=== 2. Verifica Builder ($CONTAINER_BIN) ==="
if ! $CONTAINER_BIN image inspect thof-android-builder:latest >/dev/null 2>&1; then
    echo "Costruzione immagine builder ($CONTAINER_BIN)..."
    $CONTAINER_BIN build -t thof-android-builder scripts/android
fi

echo "=== 3. Compilazione APK con Gradle ==="
VERSION_CODE=$(git rev-list --count HEAD 2>/dev/null || echo 1)
VERSION_NAME=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "1.0")
[ -z "$VERSION_NAME" ] && VERSION_NAME="1.0"

echo "Versione: $VERSION_NAME (build $VERSION_CODE)"

VOLUME_FLAGS=""
USERNS_FLAGS=""
if [ "$CONTAINER_BIN" = "podman" ]; then
    VOLUME_FLAGS=":z"
    USERNS_FLAGS="--userns=keep-id"
fi

$CONTAINER_BIN run --rm $USERNS_FLAGS \
    -v "$ROOT_DIR/frontend:/frontend${VOLUME_FLAGS}" \
    -w /frontend/android \
    -e GRADLE_USER_HOME=/tmp/.gradle \
    thof-android-builder bash -c "./gradlew assembleDebug -PcustomVersionCode=$VERSION_CODE -PcustomVersionName=$VERSION_NAME --no-daemon"

# Ripristina la proprietà dei file all'utente host (evita conflitti EACCES al prossimo cap sync)
if [ "$CONTAINER_BIN" = "docker" ]; then
    $CONTAINER_BIN run --rm -v "$ROOT_DIR/frontend/android:/android" alpine chown -R $(id -u):$(id -g) /android 2>/dev/null || true
fi

OUTPUT_APK="$ROOT_DIR/frontend/android/app/build/outputs/apk/debug/app-debug.apk"
DEST_DIR="$ROOT_DIR/releases/apk"
DEST_APK="$DEST_DIR/thof.apk"

if [ -f "$OUTPUT_APK" ]; then
    mkdir -p "$DEST_DIR"
    cp "$OUTPUT_APK" "$DEST_APK"
    chmod 644 "$DEST_APK"
    echo ""
    echo "=========================================================="
    echo "✅ APK Android compilato con successo!"
    echo "Percorso: $DEST_APK"
    echo "Dimensione: $(du -h "$DEST_APK" | cut -f1)"
    
    # Se la chiavetta USB è collegata, copia anche lì per comodità
    CURRENT_USER="${USER:-$(whoami)}"
    for USB_ROOT in "/run/media/${CURRENT_USER}/Ventoy" "/run/media/${CURRENT_USER}"/*; do
        if [ -d "${USB_ROOT}/registro_presenze" ]; then
            USB_DEST="${USB_ROOT}/registro_presenze/releases/apk"
            mkdir -p "$USB_DEST"
            cp "$DEST_APK" "$USB_DEST/thof.apk"
            echo "Copiato anche sulla chiavetta USB: $USB_DEST/thof.apk"
            break
        fi
    done
    echo "=========================================================="
    echo "Puoi trasferire questo file sul tuo smartphone Android e installarlo."
fi
