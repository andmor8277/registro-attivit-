#!/bin/bash
cd /home/andrea/registro_presenze
export DATABASE_URL="postgresql://andrea:andrea@/registro?host=/tmp/pgsocket&port=5433"
export ENCRYPTION_KEY="5DSqiSp+zs0pBlg7+vR46AYjJV70DMWnLRuZCUabd0c="

# Kill existing processes
pkill -f "uvicorn.*8000" 2>/dev/null || true
pkill -f "vite.*5173" 2>/dev/null || true
sleep 1

# Start backend
cd /home/andrea/registro_presenze/backend
python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000 &
BACKEND_PID=$!

# Start frontend
cd /home/andrea/registro_presenze/frontend
npm run dev &
FRONTEND_PID=$!

echo "Started: Backend=$BACKEND_PID Frontend=$FRONTEND_PID"