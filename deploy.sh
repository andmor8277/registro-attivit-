#!/bin/bash
# Deploy script - pull latest changes and rebuild on LXC

set -e

echo "=== Deploying to LXC ==="

# Pull latest changes on LXC
ssh root@192.168.178.132 "cd /opt/registro_presenze && git pull origin master"

# Rebuild and restart containers
ssh root@192.168.178.132 "cd /opt/registro_presenze && docker compose build && docker compose up -d"

echo "=== Deploy complete! ==="
echo "Frontend: http://192.168.178.132:3000"
echo "Backend:  http://192.168.178.132:8000"
