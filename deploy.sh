#!/bin/bash
# Deploy script - pull latest changes and rebuild on LXC

set -e

echo "=== Deploying to LXC ==="

# Navigate to project directory
ssh root@192.168.178.132 "cd /opt/registro_presenze"

# Fetch and reset to ensure we have latest
ssh root@192.168.178.132 "cd /opt/registro_presenze && git fetch origin && git reset --hard origin/master"

# Run database migrations
echo "Checking database migrations..."
ssh root@192.168.178.132 "cd /opt/registro_presenze && docker compose exec -T db psql -U \${DB_USER} -d \${DB_NAME} -c \"SELECT column_name FROM information_schema.columns WHERE table_name = 'categorie' AND column_name = 'stagione'\" | grep -q stagione || docker compose exec -T db psql -U \${DB_USER} -d \${DB_NAME} -f /opt/registro_presenze/migrations/add_stagione_fields.sql"
ssh root@192.168.178.132 "cd /opt/registro_presenze && docker compose exec -T db psql -U \${DB_USER} -d \${DB_NAME} -c \"SELECT column_name FROM information_schema.columns WHERE table_name = 'persone' AND column_name = 'totale_da_pagare'\" | grep -q totale_da_pagare || docker compose exec -T db psql -U \${DB_USER} -d \${DB_NAME} -f /opt/registro_presenze/migrations/add_payment_fields.sql"

# Stop existing containers
echo "Stopping containers..."
ssh root@192.168.178.132 "cd /opt/registro_presenze && docker compose down"

# Force rebuild without cache (ensure fresh build)
echo "Building containers (no cache)..."
ssh root@192.168.178.132 "cd /opt/registro_presenze && docker compose build --no-cache"

# Start containers
echo "Starting containers..."
ssh root@192.168.178.132 "cd /opt/registro_presenze && docker compose up -d"

# Wait for services to be ready
echo "Waiting for services..."
sleep 5

# Verify containers are running
echo "Container status:"
ssh root@192.168.178.132 "cd /opt/registro_presenze && docker compose ps"

echo ""
echo "=== Deploy complete! ==="
echo "Frontend: https://thof.crickethouse.mywire.org"
echo "Backend:  http://192.168.178.132:8000"
