#!/bin/bash
# Development script - avvia server di sviluppo locale

echo "=== Registro Presenze - Sviluppo Locale ==="

# Controlla se Node.js è disponibile
if ! command -v node &> /dev/null; then
    echo "❌ Node.js non trovato. Installa Node.js per sviluppare il frontend."
    exit 1
fi

# Controlla se npm è disponibile
if ! command -v npm &> /dev/null; then
    echo "❌ npm non trovato."
    exit 1
fi

cd "$(dirname "$0")/frontend"

# Installa dipendenze se necessario
if [ ! -d "node_modules" ]; then
    echo "📦 Installazione dipendenze frontend..."
    npm install
fi

echo "🚀 Avvio server di sviluppo frontend..."
echo "   URL: http://localhost:5173"
echo "   Backend: http://192.168.178.132:8000"
echo ""
echo "   Premi Ctrl+C per fermare"
echo ""

npm run dev
