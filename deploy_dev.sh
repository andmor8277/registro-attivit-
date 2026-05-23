#!/bin/bash
# Deploy script - tar+ssh sync + rebuild on Dev LXC (192.168.178.133)
# Server dev NON ha accesso a internet → usa tar pipe via SSH

set -e
SSH_KEY="${SSH_KEY:-~/.ssh/id_ed25519_dev}"
SSH="ssh -i $SSH_KEY"
REMOTE="root@192.168.178.133"
REMOTE_PATH="/opt/registro_presenze"
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"

echo "=== Deploying to Dev LXC (192.168.178.133) ==="

# Sync files via tar pipe over SSH (no rsync needed on remote)
echo "Syncing files via tar+ssh..."
tar -cz \
  --exclude='node_modules' \
  --exclude='dist' \
  --exclude='__pycache__' \
  --exclude='.env' \
  --exclude='uploads' \
  --exclude='.git' \
  --exclude='*.pyc' \
  --exclude='session-ses_*.md' \
  --exclude='SESSION_SUMMARY.md' \
  --exclude='AGENTS.md' \
  -C "$PROJECT_ROOT" . | $SSH $REMOTE "tar -xzf - -C $REMOTE_PATH"

# Run database migrations
echo "Running database migrations..."
$SSH $REMOTE "cd $REMOTE_PATH && docker compose cp migrations/add_stagione_fields.sql db:/tmp/add_stagione_fields.sql && docker compose exec -T db sh -c \"psql -U \\\$POSTGRES_USER -d \\\$POSTGRES_DB -f /tmp/add_stagione_fields.sql\"" 2>/dev/null || true
$SSH $REMOTE "cd $REMOTE_PATH && docker compose cp migrations/add_payment_fields.sql db:/tmp/add_payment_fields.sql && docker compose exec -T db sh -c \"psql -U \\\$POSTGRES_USER -d \\\$POSTGRES_DB -f /tmp/add_payment_fields.sql\"" 2>/dev/null || true
$SSH $REMOTE "cd $REMOTE_PATH && docker compose cp migrations/drop_telefono_column.sql db:/tmp/drop_telefono_column.sql && docker compose exec -T db sh -c \"psql -U \\\$POSTGRES_USER -d \\\$POSTGRES_DB -f /tmp/drop_telefono_column.sql\"" 2>/dev/null || true

# Stop existing containers
echo "Stopping containers..."
$SSH $REMOTE "cd $REMOTE_PATH && docker compose down"

# Force rebuild without cache
# VITE_API_URL=/api → frontend usa nginx interno che proxya al backend locale (no CORS)
echo "Building containers (no cache)..."
$SSH $REMOTE "cd $REMOTE_PATH && VITE_API_URL=/api docker compose build --no-cache"

# Start containers
echo "Starting containers..."
$SSH $REMOTE "cd $REMOTE_PATH && docker compose up -d"

# Wait for services
echo "Waiting for services..."
sleep 5

# Verify
echo "Container status:"
$SSH $REMOTE "cd $REMOTE_PATH && docker compose ps"

echo ""
echo "=== Deploy Dev complete! ==="
echo "Frontend: http://192.168.178.133:3000"
echo "Backend:  http://192.168.178.133:8000"
