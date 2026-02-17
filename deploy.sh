#!/bin/bash
# deploy.sh - Deploy Plex configuration from repo to execution location
# Usage: ./deploy.sh
# This script copies configuration from the git repo to /opt/plex-service

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="/opt/plex-service"
BACKUP_DIR="$DEPLOY_DIR/.deploy-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "=== Plex Configuration Deployment ==="
echo "From: $REPO_DIR"
echo "To: $DEPLOY_DIR"
echo ""

# Check if deploy directory exists
if [ ! -d "$DEPLOY_DIR" ]; then
    echo "Error: Deploy directory $DEPLOY_DIR does not exist!"
    exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Create backup of current deployment
echo "Creating backup of current deployment..."
BACKUP_PATH="$BACKUP_DIR/pre-deploy-$TIMESTAMP.tar.gz"
tar -czf "$BACKUP_PATH" -C "$DEPLOY_DIR" \
    --exclude='.deploy-backups' \
    --exclude='config' \
    --exclude='*.log' \
    --exclude='.git' \
    . 2>/dev/null || echo "Some files excluded from backup"
echo "Backup created: $BACKUP_PATH"
echo ""

# Files to deploy (configuration only, not data)
DEPLOY_FILES=(
    "docker-compose.yml"
    "backup-full.sh"
    "plex-wsl-startup.sh"
    "wsl-network-setup.sh"
    "setup.sh"
    "verify.sh"
    "README.md"
    ".env.example"
)

echo "Deploying documentation..."
if [ -d "$REPO_DIR/docs" ]; then
    mkdir -p "$DEPLOY_DIR/docs"
    cp -r "$REPO_DIR/docs/"* "$DEPLOY_DIR/docs/"
    echo "  ✓ docs/"
fi

echo "Deploying configuration files..."
for file in "${DEPLOY_FILES[@]}"; do
    if [ -f "$REPO_DIR/$file" ]; then
        cp "$REPO_DIR/$file" "$DEPLOY_DIR/$file"
        echo "  ✓ $file"
    else
        echo "  ⚠ $file (not found in repo)"
    fi
done

echo ""
echo "Setting executable permissions..."
chmod +x "$DEPLOY_DIR/backup-full.sh" \
    "$DEPLOY_DIR/plex-wsl-startup.sh" \
    "$DEPLOY_DIR/wsl-network-setup.sh" \
    "$DEPLOY_DIR/setup.sh" \
    "$DEPLOY_DIR/verify.sh" 2>/dev/null || true

echo ""
echo "Deploying to $DEPLOY_DIR and recreating containers..."
cd "$DEPLOY_DIR"

# Check if docker-compose.yml changed
if git diff --quiet docker-compose.yml 2>/dev/null; then
    echo "No changes to docker-compose.yml, restarting containers..."
    docker compose restart
else
    echo "docker-compose.yml changed, recreating containers with new configuration..."
    docker compose down
    docker compose up -d
fi

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Next steps:"
echo "1. Review running containers: cd $DEPLOY_DIR && docker compose ps"
echo "2. Check Plex logs: cd $DEPLOY_DIR && docker compose logs plex"
echo "3. Verify GPU: docker inspect plex --format '{{json .HostConfig.DeviceRequests}}'"
echo "4. To rollback: tar -xzf $BACKUP_PATH -C $DEPLOY_DIR && cd $DEPLOY_DIR && docker compose down && docker compose up -d"
echo ""
echo "Backup location: $BACKUP_PATH"
