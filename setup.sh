#!/bin/bash
# Setup script - configura l'ambiente di sviluppo locale

echo "=== Registro Presenze - Setup Locale ==="

cd "$(dirname "$0")"

# Setup frontend
echo "📦 Setup Frontend..."
cd frontend
npm install
cd ..

# Verifica .env
if [ ! -f "frontend/.env" ]; then
    echo "⚠️  Creazione .env per sviluppo locale..."
    cat > frontend/.env << 'ENVEOF'
VITE_API_URL=http://192.168.178.132:8000
ENVEOF
    echo "   ✅ .env creato (punta al server LXC)"
fi

echo ""
echo "=== Setup Completo! ==="
echo ""
echo "Per avviare lo sviluppo:"
echo "   ./dev.sh"
echo ""
echo "Per deploy sul server:"
echo "   ./deploy.sh"
echo ""
