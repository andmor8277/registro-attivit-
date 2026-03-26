#!/bin/bash
# Deploy script - pull latest changes and rebuild on LXC

set -e

echo "=== Deploying to LXC ==="

# Pull latest changes on LXC
ssh root@192.168.178.132 "cd /opt/registro_presenze && git pull origin master"

# Run database migrations
echo "Checking database migrations..."
ssh root@192.168.178.132 "cd /opt/registro_presenze && docker compose exec -T db psql -U postgres -d registro_presenze -c \"SELECT column_name FROM information_schema.columns WHERE table_name = 'categorie' AND column_name = 'stagione'\" | grep -q stagione || docker compose exec -T db psql -U postgres -d registro_presenze -f /opt/registro_presenze/migrations/add_stagione_fields.sql"

# Rebuild and restart containers
ssh root@192.168.178.132 "cd /opt/registro_presenze && docker compose build && docker compose up -d"

echo "=== Deploy complete! ==="
echo "Frontend: https://presenzored.crickethouse.mywire.org"
echo "Backend:  http://192.168.178.132:8000"
