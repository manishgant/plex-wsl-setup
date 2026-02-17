#!/bin/bash
# Complete Plex Stack Backup Script
# Backs up everything needed to redeploy on a new system

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${CONFIG_DIR:-/opt/plex-service/config}"
BACKUP_DIR="${BACKUP_DIR:-$SCRIPT_DIR/backups}"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="plex-stack-backup-$DATE"

# Default backup location: /mnt/e/Plex/backups (Windows drive - survives distro reinstall)
if [ -d "/mnt/e/Plex/backups" ]; then
    BACKUP_DIR="/mnt/e/Plex/backups"
fi

echo "=== Plex Stack Backup ==="
echo "Backup location: $BACKUP_DIR"
echo ""

# Create backup directory
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"
mkdir -p "$BACKUP_PATH/config"

echo "Backing up docker-compose.yml..."
cp "$SCRIPT_DIR/docker-compose.yml" "$BACKUP_PATH/"

echo "Backing up environment files..."
cp "$SCRIPT_DIR/.env.example" "$BACKUP_PATH/" 2>/dev/null || true

echo "Backing up config directories..."
# Copy all service configs from /opt/plex-service/config/
for service in plex sonarr radarr prowlarr flaresolverr overseerr tautulli; do
    if [ -d "$CONFIG_DIR/$service" ]; then
        echo "  - $service"
        cp -r "$CONFIG_DIR/$service" "$BACKUP_PATH/config/"
    fi
done

echo "Backing up backup script..."
cp "$SCRIPT_DIR/backup-full.sh" "$BACKUP_PATH/" 2>/dev/null || true

# Create restore script
cat > "$BACKUP_PATH/restore.sh" << 'EOF'
#!/bin/bash
# Restore Plex Stack from Backup
# Run this on a fresh system to restore all configs

set -e

BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${TARGET_DIR:-/opt/plex-service}"

echo "=== Plex Stack Restore ==="
echo "Backup: $BACKUP_DIR"
echo "Target: $TARGET_DIR"
echo ""

# Create target directory
sudo mkdir -p "$TARGET_DIR"

echo "Copying docker-compose.yml..."
cp "$BACKUP_DIR/docker-compose.yml" "$TARGET_DIR/"

echo "Creating config directory..."
sudo mkdir -p "$TARGET_DIR/config"

echo "Restoring configs..."
for dir in "$BACKUP_DIR/config"/*; do
    if [ -d "$dir" ]; then
        service=$(basename "$dir")
        echo "  - $service"
        sudo cp -r "$dir" "$TARGET_DIR/config/"
        sudo chown -R 1000:1000 "$TARGET_DIR/config/$service"
    fi
done

echo ""
echo "=== Restore Complete ==="
echo ""
echo "Next steps:"
echo "1. Set up Docker in WSL2"
echo "2. Set up port forwarding on Windows:"
echo "   netsh interface portproxy add v4tov4 listenport=32400 listenaddress=0.0.0.0 connectport=32400 connectaddress=\$(wsl hostname -I)"
echo ""
echo "3. Start services:"
echo "   cd $TARGET_DIR"
echo "   docker-compose up -d"
echo ""
echo "4. Verify services:"
echo "   docker ps"
echo ""
echo "5. Check remote access in Plex settings"
EOF

chmod +x "$BACKUP_PATH/restore.sh"

# Create README with backup info
cat > "$BACKUP_PATH/README.md" << EOF
# Plex Stack Backup - $DATE

## What's Included

- \`docker-compose.yml\` - Service definitions
- \`config/\` - All service configurations
  - plex/ - Plex Media Server config & database
  - sonarr/ - Sonarr config & database
  - radarr/ - Radarr config & database
  - prowlarr/ - Prowlarr config & database
  - flaresolverr/ - FlareSolverr config
  - overseerr/ - Overseerr config
  - tautulli/ - Tautulli config

## What's NOT Included

- Media files (stored in /mnt/e/Plex/)
- Docker images (will be pulled fresh)
- .env file with secrets (recreate from .env.example)

## Restore

\`\`\`bash
# On new system:
cd /path/to/backup
./restore.sh
\`\`\`

## Post-Restore

1. Update PLEX_CLAIM_TOKEN if needed
2. Configure any new passwords
3. Restart services: \`docker-compose restart\`

## Backup Location

This backup is stored at: $BACKUP_PATH
EOF

echo ""
echo "=== Backup Complete ==="
echo "Location: $BACKUP_PATH"
echo ""
echo "Files backed up:"
ls -la "$BACKUP_PATH/"
echo ""
echo "To restore on new system:"
echo "  1. Copy this folder to new system"
echo "  2. Run: $BACKUP_PATH/restore.sh"
