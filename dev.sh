#!/bin/bash
# Development script - avvia server di sviluppo locale con mock API

echo "=== Registro Presenze - Sviluppo Locale ==="

# Controlla se Node.js è disponibile
if ! command -v node &> /dev/null; then
    echo "❌ Node.js non trovato. Installa Node.js per sviluppare il frontend."
    exit 1
fi

SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR/frontend"

# Installa dipendenze se necessario
if [ ! -d "node_modules" ]; then
    echo "📦 Installazione dipendenze frontend..."
    npm install
fi

# Avvia mock server in background
echo "🔧 Avvio Mock API Server..."
node "$SCRIPT_DIR/mock-server.js" &
MOCK_PID=$!
sleep 1

echo ""
echo "🚀 Avvio server di sviluppo frontend..."
echo "   Frontend: http://localhost:5173"
echo "   API Mock: http://localhost:8000"
echo ""
echo "   Login: admin / admin123"
echo ""
echo "   Premi Ctrl+C per fermare"
echo ""

# Cattura Ctrl+C e termina anche il mock server
trap "kill $MOCK_PID 2>/dev/null; exit" SIGINT SIGTERM

npm run dev
