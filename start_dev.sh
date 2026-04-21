#!/bin/bash
set -e

echo "=== Avvio Ambiente Dev ==="

# 1. Avvia PostgreSQL se non è già in esecuzione
if ! pg_isready -h /tmp/pgsocket -p 5433 > /dev/null 2>&1; then
    echo "1. Avvio PostgreSQL..."
    mkdir -p /tmp/pgsocket /tmp/pgdata
    if [ ! -d "/tmp/pgdata/base" ]; then
        initdb -D /tmp/pgdata > /dev/null 2>&1
    fi
    pg_ctl -D /tmp/pgdata -o "-p 5433 -k /tmp/pgsocket" -l /tmp/pg.log start 2>/dev/null || \
    pg_ctl -D /tmp/pgdata -l /tmp/pg.log start
    sleep 2
fi

# 2. Verifica/crea utente e database
echo "2. Verifico database..."
if ! psql -h /tmp/pgsocket -p 5433 -d postgres -c "SELECT 1 FROM pg_database WHERE datname='registro'" | grep -q 1; then
    echo "   Creo database e utente..."
    psql -h /tmp/pgsocket -p 5433 -d postgres -c "CREATE USER registro_user WITH PASSWORD 'Redtigers_greta2009' CREATEDB SUPERUSER;" 2>/dev/null || true
    psql -h /tmp/pgsocket -p 5433 -d postgres -c "CREATE DATABASE registro OWNER registro_user;" 2>/dev/null || true
fi

# Carica dati da production se il DB è vuoto
ROWS=$(psql -h /tmp/pgsocket -p 5433 -d registro -t -c "SELECT COUNT(*) FROM persone" 2>/dev/null || echo "0")
if [ "$ROWS" = "0" ] || [ -z "$ROWS" ]; then
    echo "   Carico dati da production..."
    if ssh -o ConnectTimeout=5 root@192.168.178.132 "docker exec registro_presenze-db-1 psql -U registro_user -d registro -c 'SELECT 1'" > /dev/null 2>&1; then
        echo "      Caricando tabelle..."
        ssh root@192.168.178.132 "docker exec registro_presenze-db-1 pg_dump -U registro_user -d registro -t categorie -t societa -t utenti -t codici -t gruppi -t persone -t registro --data-only" 2>/dev/null | psql -h /tmp/pgsocket -p 5433 -d registro 2>/dev/null || true
    fi
fi

# 3. Avvia backend
echo "3. Avvio Backend (porta 8000)..."
cd /home/andrea/registro_presenze/backend
export DATABASE_URL="postgresql://registro_user:Redtigers_greta2009@/registro?host=/tmp/pgsocket&port=5433"
pkill -f "uvicorn.*8000" 2>/dev/null || true
python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000 &
BACKEND_PID=$!

# 4. Avvia frontend
echo "4. Avvio Frontend (porta 5173)..."
cd /home/andrea/registro_presenze/frontend
pkill -f "vite.*5173" 2>/dev/null || true
npm run dev &
FRONTEND_PID=$!

echo ""
echo "=== Dev avviato! ==="
echo "Frontend: http://localhost:5173"
echo "Backend:  http://localhost:8000"
echo ""
echo "PIDs: backend=$BACKEND_PID frontend=$FRONTEND_PID"
echo "Per fermare: kill $BACKEND_PID $FRONTEND_PID"
