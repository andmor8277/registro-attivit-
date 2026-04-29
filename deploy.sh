#!/bin/bash
# Deploy script - pull latest changes and rebuild on LXC

set -e

echo "=== Deploying to LXC ==="

# Navigate to project directory
ssh root@192.168.178.132 "cd /opt/registro_presenze"

# Fetch and reset to ensure we have latest
ssh root@192.168.178.132 "cd /opt/registro_presenze && git fetch origin && git reset --hard origin/master"

# Run database migrations (copy SQL into container first, then execute)
echo "Running database migrations..."
ssh root@192.168.178.132 'cd /opt/registro_presenze && docker compose cp migrations/add_stagione_fields.sql db:/tmp/add_stagione_fields.sql && docker compose exec -T db sh -c "psql -U \$POSTGRES_USER -d \$POSTGRES_DB -f /tmp/add_stagione_fields.sql"' 2>/dev/null || true
ssh root@192.168.178.132 'cd /opt/registro_presenze && docker compose cp migrations/add_payment_fields.sql db:/tmp/add_payment_fields.sql && docker compose exec -T db sh -c "psql -U \$POSTGRES_USER -d \$POSTGRES_DB -f /tmp/add_payment_fields.sql"' 2>/dev/null || true
ssh root@192.168.178.132 'cd /opt/registro_presenze && docker compose cp migrations/drop_telefono_column.sql db:/tmp/drop_telefono_column.sql && docker compose exec -T db sh -c "psql -U \$POSTGRES_USER -d \$POSTGRES_DB -f /tmp/drop_telefono_column.sql"' 2>/dev/null || true

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
