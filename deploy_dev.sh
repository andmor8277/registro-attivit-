#!/bin/bash
# Deploy script - tar+ssh sync + rebuild on Dev LXC (192.168.178.133)
# Server dev (192.168.178.133) → tar pipe via SSH. NB: il server ora ha accesso a internet, la strategia tar resta comunque valida.

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
  --exclude='.env.dev' \
  --exclude='.env.prod' \
  --exclude='.env.local' \
  --exclude='.env.production' \
  --exclude='.local' \
  --exclude='uploads' \
  --exclude='.git' \
  --exclude='*.pyc' \
  --exclude='session-ses_*.md' \
  --exclude='SESSION_SUMMARY.md' \
  --exclude='SECURITY_TODO.json' \
  --exclude='AGENTS.md' \
  --exclude='backups' \
  --exclude='releases' \
  --exclude='frontend/android' \
  --exclude='*.keystore' \
  --exclude='keystore.properties' \
  --exclude='client_secret_*.json' \
  -C "$PROJECT_ROOT" . | $SSH $REMOTE "tar -xzf - -C $REMOTE_PATH"

# Allinea anche il clone DEV alla versione appena sincronizzata. Il tar esclude .git, quindi senza
# questo il repository remoto resta fermo all'ultimo realinea mentre l'albero di lavoro e' gia' stato
# sovrascritto: li' `git status` mente, e un `git reset --hard` di manutenzione fatto da chiunque
# riporterebbe i file a una versione vecchia senza che nessuno capisca da dove arriva il regresso.
# GIT_TERMINAL_PROMPT=0 perche' un fetch che chiede le credenziali in un deploy non-interactive
# resterebbe appeso per sempre invece di fallire e dirlo.
SYNCED_COMMIT=$(git -C "$PROJECT_ROOT" rev-parse HEAD 2>/dev/null || echo "")
if [ -z "$SYNCED_COMMIT" ]; then
  echo "AVVISO: non leggo l'HEAD locale, il clone DEV resta dove e'"
elif [ -n "$(git -C "$PROJECT_ROOT" status --porcelain 2>/dev/null)" ]; then
  # Non si fa il reset con l'albero locale sporco: i file appena copiati col tar NON sono nel commit
  # target, e un reset --hard li riporterebbe alla versione vecchia, disfacendo in silenzio il
  # deploy che abbiamo appena fatto. Il deploy di codice non commesso resta legittimo, ma lo stato
  # del clone deve essere dichiarato, non silenzioso
  echo "AVVISO: working tree locale sporco, il clone DEV NON viene riallineato (altrimenti il reset"
  echo "       si porterebbe via i file non commessi appena copiati). Dopo il commit, rilancia il"
  echo "       deploy o lancia scripts/realigna_cloni.sh."
else
  echo "Allineo il clone DEV a ${SYNCED_COMMIT:0:7}..."
  if $SSH $REMOTE "cd $REMOTE_PATH && GIT_TERMINAL_PROMPT=0 git fetch --prune origin '+refs/heads/*:refs/remotes/origin/*' && git reset --hard $SYNCED_COMMIT" >/dev/null 2>&1; then
    echo "  clone DEV allineato"
  else
    echo "AVVISO: fetch/reset fallito (GitHub raggiungibile? credenziali?), il clone DEV resta vecchio."
    echo "       Dopo, sistemare a mano con scripts/realigna_cloni.sh."
  fi
fi

# Run database migrations
echo "Running database migrations..."
$SSH $REMOTE "cd $REMOTE_PATH && docker compose cp migrations/add_stagione_fields.sql db:/tmp/add_stagione_fields.sql && docker compose exec -T db sh -c \"psql -U \\\$POSTGRES_USER -d \\\$POSTGRES_DB -f /tmp/add_stagione_fields.sql\"" 2>/dev/null || true
$SSH $REMOTE "cd $REMOTE_PATH && docker compose cp migrations/add_payment_fields.sql db:/tmp/add_payment_fields.sql && docker compose exec -T db sh -c \"psql -U \\\$POSTGRES_USER -d \\\$POSTGRES_DB -f /tmp/add_payment_fields.sql\"" 2>/dev/null || true
$SSH $REMOTE "cd $REMOTE_PATH && docker compose cp migrations/drop_telefono_column.sql db:/tmp/drop_telefono_column.sql && docker compose exec -T db sh -c \"psql -U \\\$POSTGRES_USER -d \\\$POSTGRES_DB -f /tmp/drop_telefono_column.sql\"" 2>/dev/null || true
$SSH $REMOTE "cd $REMOTE_PATH && docker compose cp migrations/add_mister_manuale.sql db:/tmp/add_mister_manuale.sql && docker compose exec -T db sh -c \"psql -U \\\$POSTGRES_USER -d \\\$POSTGRES_DB -f /tmp/add_mister_manuale.sql\"" 2>/dev/null || true

# Stop existing containers
echo "Stopping containers..."
$SSH $REMOTE "cd $REMOTE_PATH && docker compose -f docker-compose.yml -f docker-compose.dev.yml down"

# Force rebuild without cache
# VITE_API_URL=/api → frontend usa nginx interno che proxya al backend locale (no CORS)
echo "Building containers (no cache)..."
$SSH $REMOTE "cd $REMOTE_PATH && docker compose -f docker-compose.yml -f docker-compose.dev.yml build --no-cache"

# Start containers
echo "Starting containers..."
$SSH $REMOTE "cd $REMOTE_PATH && docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d"

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
