#!/bin/bash
# Release Script - Crea una nuova release con cartella versionata
# Usage: ./release.sh [major|minor] [messaggio]
# Esempi:
#   ./release.sh minor "Aggiunta funzione X"  -> v1.1.0
#   ./release.sh major "Nuova major release"   -> v2.0.0

set -e

# Leggi l'ultima versione dal CHANGELOG
get_last_version() {
    local last_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
    echo "${last_tag#v}"
}

# Calcola la nuova versione
calculate_version() {
    local release_type=$1
    local current=$2
    
    local major=$(echo $current | cut -d. -f1)
    local minor=$(echo $current | cut -d. -f2)
    local patch=$(echo $current | cut -d. -f3)
    
    if [ "$release_type" = "major" ]; then
        echo "$((major + 1)).0.0"
    else
        echo "$major.$((minor + 1)).0"
    fi
}

if [ -z "$1" ]; then
    echo "Usage: ./release.sh [major|minor] [messaggio]"
    echo ""
    echo "Esempi:"
    echo "  ./release.sh minor 'Aggiunta lavagna tattica'  -> Crea v1.1.0"
    echo "  ./release.sh major 'Release major'              -> Crea v2.0.0"
    echo ""
    echo "Senza parametri mostra l'ultima versione:"
    get_last_version
    exit 1
fi

RELEASE_TYPE=$1
MESSAGE=${2:-"Nuova release"}
CURRENT_VERSION=$(get_last_version)
NEW_VERSION=$(calculate_version "$RELEASE_TYPE" "$CURRENT_VERSION")
DATE=$(date +%Y-%m-%d)

echo "🚀 Creando release v$NEW_VERSION (type: $RELEASE_TYPE)..."

# Crea la cartella della release
mkdir -p releases/v$NEW_VERSION

# Copia i file sorgente (no node_modules, no dist, no __pycache__, no secrets)
echo "📦 Copiando file..."
rm -rf releases/v$NEW_VERSION/*

# Backend
mkdir -p releases/v$NEW_VERSION/backend
cp -r backend/app releases/v$NEW_VERSION/backend/
cp backend/requirements.txt releases/v$NEW_VERSION/backend/
cp backend/migrations releases/v$NEW_VERSION/backend/ -rf

# Frontend
mkdir -p releases/v$NEW_VERSION/frontend
cp -r frontend/src releases/v$NEW_VERSION/frontend/
cp -r frontend/public releases/v$NEW_VERSION/frontend/ 2>/dev/null || true
cp frontend/index.html releases/v$NEW_VERSION/frontend/
cp frontend/vite.config.js releases/v$NEW_VERSION/frontend/
cp frontend/package.json releases/v$NEW_VERSION/frontend/
cp frontend/nginx.conf releases/v$NEW_VERSION/frontend/ 2>/dev/null || true

# Root files
cp docker-compose.yml releases/v$NEW_VERSION/
cp start_dev.sh releases/v$NEW_VERSION/ 2>/dev/null || true
cp deploy.sh releases/v$NEW_VERSION/
cp README.md releases/v$NEW_VERSION/

# Copia il CHANGELOG nella release
cp CHANGELOG.md releases/v$NEW_VERSION/

# GitHub Actions (per automazione)
mkdir -p releases/v$NEW_VERSION/.github
cp -r .github/workflows releases/v$NEW_VERSION/.github/ 2>/dev/null || true

# Aggiorna il CHANGELOG con la nuova versione
echo "" >> CHANGELOG.md
echo "## [$NEW_VERSION] - $DATE" >> CHANGELOG.md
echo "" >> CHANGELOG.md
echo "### Added" >> CHANGELOG.md
echo "- $MESSAGE" >> CHANGELOG.md

# Commit della release
git add -f releases/v$NEW_VERSION
git add CHANGELOG.md
git commit -m "Release v$NEW_VERSION - $MESSAGE"

# Crea il tag
git tag -a v$NEW_VERSION -m "v$NEW_VERSION - $MESSAGE"

# Push
echo "⬆️ Pushando su GitHub..."
git push origin master
git push origin v$NEW_VERSION

echo ""
echo "✅ Release v$NEW_VERSION completata!"
echo ""
echo "Prossimi passi:"
echo "1. Vai su https://github.com/andmor8277/registro-attivit-/releases"
echo "2. Crea una nuova release con tag v$NEW_VERSION"
echo "3. Per rollback: scarica la cartella releases/v$NEW_VERSION/"
