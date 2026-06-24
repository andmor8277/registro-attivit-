#!/bin/bash
set -e

echo "=== Avvio Ambiente Dev ==="

# Carica variabili d'ambiente
if [ -f /home/andrea/registro_presenze/.env ]; then
    set -a
    source /home/andrea/registro_presenze/.env
    set +a
fi

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
    psql -h /tmp/pgsocket -p 5433 -d postgres -c "CREATE USER registro_user WITH PASSWORD '${DB_PASSWORD:-postgres}' CREATEDB SUPERUSER;" 2>/dev/null || true
    psql -h /tmp/pgsocket -p 5433 -d postgres -c "CREATE DATABASE registro OWNER registro_user;" 2>/dev/null || true
fi

# Carica dati da production solo se il DB è vuoto (prima esecuzione)
ROWS=$(psql -h /tmp/pgsocket -p 5433 -d registro -t -c "SELECT COUNT(*) FROM persone" 2>/dev/null || echo "0")
if [ "$ROWS" = "0" ] || [ -z "$ROWS" ]; then
    echo "   Carico dati da production..."
    if ssh -o ConnectTimeout=5 root@192.168.178.132 "docker exec registro_presenze-db-1 psql -U registro_user -d registro -c 'SELECT 1'" > /dev/null 2>&1; then
        echo "      Dump completo schema + dati..."
        ssh root@192.168.178.132 "docker exec registro_presenze-db-1 pg_dump -U registro_user -d registro --no-owner --no-acl" 2>/dev/null | psql -h /tmp/pgsocket -p 5433 -d registro 2>/dev/null || true
    fi
fi

# 3. Avvia backend in tmux
echo "3. Avvio Backend (porta 8000)..."
tmux kill-session -t registro_backend 2>/dev/null || true
tmux new-session -d -s registro_backend \
  'set -a && source /home/andrea/registro_presenze/.env && set +a && export DATABASE_URL="postgresql://registro_user:'${DB_PASSWORD:-postgres}'@/registro?host=/tmp/pgsocket&port=5433" && cd /home/andrea/registro_presenze/backend && python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000'

# 4. Avvia frontend in tmux
echo "4. Avvio Frontend (porta 5173)..."
tmux kill-session -t registro_frontend 2>/dev/null || true
tmux new-session -d -s registro_frontend \
  'cd /home/andrea/registro_presenze/frontend && npm run dev'

sleep 2
echo ""
echo "=== Dev avviato! ==="
echo "Frontend: http://localhost:5173"
echo "Backend:  http://localhost:8000"
echo ""
echo "Sessioni tmux: registro_backend, registro_frontend"
echo "Log backend:   tmux attach -t registro_backend"
echo "Log frontend:  tmux attach -t registro_frontend"
echo "Per fermare:   tmux kill-session -t registro_backend -t registro_frontend"
