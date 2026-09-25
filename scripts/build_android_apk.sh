#!/bin/bash
# Script per compilare l'app Android di The Home of Football (THOF)
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "=== 1. Compilazione Web App & Sync Capacitor ==="
cd frontend
VITE_API_URL=https://thof.crickethouse.mywire.org/api npm run cap:sync
cd "$ROOT_DIR"

echo "=== 2. Verifica Docker Builder ==="
if ! docker image inspect thof-android-builder:latest >/dev/null 2>&1; then
    echo "Costruzione immagine Docker builder..."
    docker build -t thof-android-builder scripts/android
fi

echo "=== 3. Compilazione APK con Gradle ==="
VERSION_CODE=$(git rev-list --count HEAD 2>/dev/null || echo 1)
VERSION_NAME=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "1.0")
[ -z "$VERSION_NAME" ] && VERSION_NAME="1.0"

echo "Versione: $VERSION_NAME (build $VERSION_CODE)"

docker run --rm \
    -v "$ROOT_DIR/frontend:/frontend" \
    -w /frontend/android \
    -e GRADLE_USER_HOME=/tmp/.gradle \
    thof-android-builder bash -c "./gradlew assembleDebug -PcustomVersionCode=$VERSION_CODE -PcustomVersionName=$VERSION_NAME --no-daemon && chown -R $(id -u):$(id -g) /frontend/android"

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
    echo "=========================================================="
    echo "Puoi trasferire questo file sul tuo smartphone Android e installarlo."
fi
