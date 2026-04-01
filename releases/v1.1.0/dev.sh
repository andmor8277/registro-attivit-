#!/bin/bash
# Development script - avvia server di sviluppo locale con backend reale

echo "=== Registro Presenze - Sviluppo Locale ==="

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Controlla se Node.js è disponibile
if ! command -v node &> /dev/null; then
    echo "❌ Node.js non trovato. Installa Node.js per sviluppare il frontend."
    exit 1
fi

# Controlla se Python è disponibile
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 non trovato. Installa Python per avviare il backend."
    exit 1
fi

# Avvia backend in background
echo "🔧 Avvio Backend Server..."
cd "$SCRIPT_DIR/backend"
python3 -m uvicorn app.main:app --host 127.0.0.1 --port 8000 &
BACKEND_PID=$!
sleep 2

# Verifica che il backend sia partito
if ! kill -0 $BACKEND_PID 2>/dev/null; then
    echo "❌ Errore nell'avvio del backend"
    exit 1
fi

cd "$SCRIPT_DIR/frontend"

# Installa dipendenze se necessario
if [ ! -d "node_modules" ]; then
    echo "📦 Installazione dipendenze frontend..."
    npm install
fi

echo ""
echo "🚀 Avvio server di sviluppo frontend..."
echo "   Frontend: http://localhost:5173"
echo "   Backend:  http://localhost:8000"
echo "   Database: PostgreSQL locale (127.0.0.1:5432)"
echo ""
echo "   Premi Ctrl+C per fermare"
echo ""

# Cattura Ctrl+C e termina anche il backend
trap "kill $BACKEND_PID 2>/dev/null; exit" SIGINT SIGTERM

npm run dev
