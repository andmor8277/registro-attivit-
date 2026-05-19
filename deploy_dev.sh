#!/bin/bash
# Deploy script - pull latest changes and rebuild on Dev LXC (192.168.178.133)

set -e
SSH_KEY="${SSH_KEY:-~/.ssh/id_ed25519_dev}"
SSH="ssh -i $SSH_KEY"

echo "=== Deploying to Dev LXC (192.168.178.133) ==="

# Navigate to project directory
$SSH root@192.168.178.133 "cd /opt/registro_presenze"

# Fetch and reset to ensure we have latest
$SSH root@192.168.178.133 "cd /opt/registro_presenze && git fetch origin && git reset --hard origin/master"

# Run database migrations (copy SQL into container first, then execute)
echo "Running database migrations..."
$SSH root@192.168.178.133 'cd /opt/registro_presenze && docker compose cp migrations/add_stagione_fields.sql db:/tmp/add_stagione_fields.sql && docker compose exec -T db sh -c "psql -U \$POSTGRES_USER -d \$POSTGRES_DB -f /tmp/add_stagione_fields.sql"' 2>/dev/null || true
$SSH root@192.168.178.133 'cd /opt/registro_presenze && docker compose cp migrations/add_payment_fields.sql db:/tmp/add_payment_fields.sql && docker compose exec -T db sh -c "psql -U \$POSTGRES_USER -d \$POSTGRES_DB -f /tmp/add_payment_fields.sql"' 2>/dev/null || true
$SSH root@192.168.178.133 'cd /opt/registro_presenze && docker compose cp migrations/drop_telefono_column.sql db:/tmp/drop_telefono_column.sql && docker compose exec -T db sh -c "psql -U \$POSTGRES_USER -d \$POSTGRES_DB -f /tmp/drop_telefono_column.sql"' 2>/dev/null || true

# Stop existing containers
echo "Stopping containers..."
$SSH root@192.168.178.133 "cd /opt/registro_presenze && docker compose down"

# Force rebuild without cache (ensure fresh build)
# VITE_API_URL=/api → frontend usa nginx interno che proxya al backend locale (no CORS issues)
echo "Building containers (no cache)..."
$SSH root@192.168.178.133 "cd /opt/registro_presenze && VITE_API_URL=/api docker compose build --no-cache"

# Start containers
echo "Starting containers..."
$SSH root@192.168.178.133 "cd /opt/registro_presenze && docker compose up -d"

# Wait for services to be ready
echo "Waiting for services..."
sleep 5

# Verify containers are running
echo "Container status:"
$SSH root@192.168.178.133 "cd /opt/registro_presenze && docker compose ps"

echo ""
echo "=== Deploy Dev complete! ==="
echo "Frontend: http://192.168.178.133:3000"
echo "Backend:  http://192.168.178.133:8000"
