#!/bin/bash
# Script per eseguire la migrazione del database sul server LXC

set -e

MIGRATION_FILE="migrations/add_stagione_fields.sql"

echo "Esecuzione migrazione database..."
echo ""

# Leggi l'anno della stagione corrente
read -p "Inserisci l'anno di inizio della stagione corrente (es. 2025): " STAGIONE_ANNO

# Sostituisci il placeholder con l'anno inserito
sed "s/2025/$STAGIONE_ANNO/g" "$MIGRATION_FILE" > /tmp/migration_temp.sql

# Esegui la migrazione
echo "Connessione al database..."
PGPASSWORD=$(grep -oP '(?<=POSTGRES_PASSWORD=)\S+' .env 2>/dev/null || echo "")

# Se non c'è .env, chiedi le credenziali
if [ -z "$PGPASSWORD" ]; then
    read -sp "Password PostgreSQL: " PGPASSWORD
    echo ""
fi

psql -h localhost -U postgres -d registro_presenze -f /tmp/migration_temp.sql

echo ""
echo "Migrazione completata!"
rm /tmp/migration_temp.sql
