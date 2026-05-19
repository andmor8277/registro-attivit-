#!/bin/bash
# Deploy script - rsync local files + rebuild on Dev LXC (192.168.178.133)
# Server dev NON ha accesso a internet/GitHub → usa rsync dal PC locale

set -e
SSH_KEY="${SSH_KEY:-~/.ssh/id_ed25519_dev}"
SSH="ssh -i $SSH_KEY"
RSYNC="rsync -avz --delete -e \"$SSH\""
REMOTE="root@192.168.178.133"
REMOTE_PATH="/opt/registro_presenze/"
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"

echo "=== Deploying to Dev LXC (192.168.178.133) ==="

# Sync local files to remote (skip node_modules, dist, __pycache__, .env, uploads)
echo "Syncing files via rsync..."
$RSYNC \
  --exclude='node_modules' \
  --exclude='dist/' \
  --exclude='__pycache__/' \
  --exclude='.env' \
  --exclude='uploads/' \
  --exclude='.git/' \
  --exclude='*.pyc' \
  "$PROJECT_ROOT/" "$REMOTE:$REMOTE_PATH"

# Run database migrations (copy SQL into container first, then execute)
echo "Running database migrations..."
$SSH $REMOTE 'cd /opt/registro_presenze && docker compose cp migrations/add_stagione_fields.sql db:/tmp/add_stagione_fields.sql && docker compose exec -T db sh -c "psql -U \$POSTGRES_USER -d \$POSTGRES_DB -f /tmp/add_stagione_fields.sql"' 2>/dev/null || true
$SSH $REMOTE 'cd /opt/registro_presenze && docker compose cp migrations/add_payment_fields.sql db:/tmp/add_payment_fields.sql && docker compose exec -T db sh -c "psql -U \$POSTGRES_USER -d \$POSTGRES_DB -f /tmp/add_payment_fields.sql"' 2>/dev/null || true
$SSH $REMOTE 'cd /opt/registro_presenze && docker compose cp migrations/drop_telefono_column.sql db:/tmp/drop_telefono_column.sql && docker compose exec -T db sh -c "psql -U \$POSTGRES_USER -d \$POSTGRES_DB -f /tmp/drop_telefono_column.sql"' 2>/dev/null || true

# Stop existing containers
echo "Stopping containers..."
$SSH $REMOTE "cd $REMOTE_PATH && docker compose down"

# Force rebuild without cache (ensure fresh build)
# VITE_API_URL=/api → frontend usa nginx interno che proxya al backend locale (no CORS issues)
echo "Building containers (no cache)..."
$SSH $REMOTE "cd $REMOTE_PATH && VITE_API_URL=/api docker compose build --no-cache"

# Start containers
echo "Starting containers..."
$SSH $REMOTE "cd $REMOTE_PATH && docker compose up -d"

# Wait for services to be ready
echo "Waiting for services..."
sleep 5

# Verify containers are running
echo "Container status:"
$SSH $REMOTE "cd $REMOTE_PATH && docker compose ps"

echo ""
echo "=== Deploy Dev complete! ==="
echo "Frontend: http://192.168.178.133:3000"
echo "Backend:  http://192.168.178.133:8000"
