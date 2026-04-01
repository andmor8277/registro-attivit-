#!/bin/bash
# Release Script - Crea una nuova release con cartella versionata

set -e

if [ -z "$1" ]; then
    echo "Usage: ./release.sh <versione> [messaggio]"
    echo "Esempio: ./release.sh v1.1.0 'Aggiunta funzione X'"
    exit 1
fi

VERSION=$1
MESSAGE=${2:-"Nuova release"}
DATE=$(date +%Y-%m-%d)

echo "🚀 Creando release $VERSION..."

# Crea la cartella della release
mkdir -p releases/$VERSION

# Copia i file
echo "📦 Copiando file..."
cp -r backend frontend docker-compose.yml dev.sh deploy.sh README.md CHANGELOG.md migrations releases/$VERSION/

# Aggiorna CHANGELOG con la nuova versione
echo "📝 Aggiornando CHANGELOG..."
# Il changelog viene aggiornato automaticamente con git-chglog o manualmente

# Commit della release
git add releases/$VERSION
git commit -m "Release $VERSION - $MESSAGE"

# Crea il tag
git tag -a $VERSION -m "$VERSION - $MESSAGE"

# Push
echo "⬆️ Pushando su GitHub..."
git push origin master
git push origin $VERSION

echo "✅ Release $VERSION completata!"
echo ""
echo "Prossimi passi:"
echo "1. Vai su https://github.com/andmor8277/registro-attivit-/releases"
echo "2. Crea una nuova release con tag $VERSION"
echo "3. Per rollback: copia la cartella releases/$VERSION sul server"
