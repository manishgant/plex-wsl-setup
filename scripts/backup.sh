#!/bin/bash
# Plex WSL Backup Script - Configuration and Full Backup Options with Compression
# Usage: ./scripts/backup.sh [config|full] [backup_location]
#   config          - Backup only configuration files (fast, small)
#   full            - Backup config + Plex database + metadata (compressed)
#   backup_location - Optional: Where to store backups (default: ./backups/)
#
# Examples:
#   ./scripts/backup.sh config                          # Quick config backup to ./backups/
#   ./scripts/backup.sh full                            # Full backup to ./backups/
#   ./scripts/backup.sh full /mnt/e/Plex/Backups        # Full backup to external drive
#   ./scripts/backup.sh config /media/external/plex     # Backup to external drive

set -e

# Find project root (parent of scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DATE=$(date +%Y%m%d_%H%M%S)

# Parse arguments
BACKUP_TYPE="${1:-config}"  # Default to config if no argument provided
BACKUP_DIR="${2:-$PROJECT_ROOT/backups}"  # Default to ./backups/ if not specified

# Compression settings
TAR_FLAGS="-czf"  # Create gzip compressed archive
COMPRESS_LEVEL="--gzip"  # Use gzip compression

# Validate backup type
if [[ "$BACKUP_TYPE" != "config" && "$BACKUP_TYPE" != "full" ]]; then
    echo "Usage: $0 [config|full] [backup_location]"
    echo ""
    echo "Arguments:"
    echo "  config          - Backup configuration only (fast)"
    echo "  full            - Backup config + database + metadata (compressed)"
    echo "  backup_location - Optional: Where to store backups"
    echo "                    Default: ./backups/"
    echo ""
    echo "Examples:"
    echo "  $0 config                                    # Config backup locally"
    echo "  $0 full                                      # Full backup locally"
    echo "  $0 full /mnt/e/Plex/Backups                  # Full backup to external drive"
    echo "  $0 config /media/external/plex-backup        # Config backup to external drive"
    echo ""
    exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "=========================================="
echo "Plex WSL Backup - ${BACKUP_TYPE^^} MODE"
echo "=========================================="
echo ""
echo "Backup Location: $BACKUP_DIR"
echo ""

# Create backup directory (will be compressed later)
SNAPSHOT_DIR="$BACKUP_DIR/${BACKUP_TYPE}_$DATE"
mkdir -p "$SNAPSHOT_DIR"

echo "Destination: $SNAPSHOT_DIR"
echo "Compression: Enabled (gzip -9)"
echo ""

# ============================================================================
# CONFIGURATION BACKUP (Always included)
# ============================================================================

echo "--- CONFIGURATION FILES ---"

# 1. Backup docker-compose.yml
echo "[1] docker-compose.yml..."
cp "$SCRIPT_DIR/docker-compose.yml" "$SNAPSHOT_DIR/"

# 2. Backup .env file if it exists
if [ -f "$SCRIPT_DIR/.env" ]; then
    echo "[2] .env file..."
    cp "$SCRIPT_DIR/.env" "$SNAPSHOT_DIR/"
fi

# 3. Backup Preferences.xml
echo "[3] Plex Preferences.xml..."
PREF_FILE="$SCRIPT_DIR/config/plex/Library/Application Support/Plex Media Server/Preferences.xml"
if [ -f "$PREF_FILE" ]; then
    cp "$PREF_FILE" "$SNAPSHOT_DIR/Preferences.xml"
fi

# 4. Backup .wslconfig from Windows
echo "[4] .wslconfig..."
WSLCONFIG_PATH="/mnt/c/Users/$(whoami)/.wslconfig"
if [ -f "$WSLCONFIG_PATH" ]; then
    cp "$WSLCONFIG_PATH" "$SNAPSHOT_DIR/.wslconfig"
    echo "    ✓ Backed up from current user"
else
    echo "    ⚠ Not found (may need manual backup)"
fi

# 5. Backup Windows PowerShell scripts
if [ -f "$SCRIPT_DIR/fix-plex-network.ps1" ]; then
    echo "[5] PowerShell scripts..."
    cp "$SCRIPT_DIR/fix-plex-network.ps1" "$SNAPSHOT_DIR/"
fi

# 6. Save network configuration
echo "[6] Network configuration..."
WSL_IP=$(ip addr show eth0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)
PORTPROXY_INFO=""
if command -v powershell.exe &> /dev/null; then
    PORTPROXY_INFO=$(powershell.exe -Command "netsh interface portproxy show all" 2>/dev/null | grep "32400" || echo "Run: netsh interface portproxy show all")
fi

cat > "$SNAPSHOT_DIR/network.config" << EOF
# Plex WSL Network Configuration
# Backup Type: ${BACKUP_TYPE^^}
# Created: $DATE

WSL_IP=$WSL_IP

## Port Proxy Rules:
$PORTPROXY_INFO

## Setup Commands (PowerShell Admin):
\$wslIp = (wsl hostname -I).Trim().Split()[0]
netsh interface portproxy add v4tov4 listenport=32400 listenaddress=0.0.0.0 connectport=32400 connectaddress=\$wslIp
netsh interface portproxy add v4tov4 listenport=32469 listenaddress=0.0.0.0 connectport=32469 connectaddress=\$wslIp
EOF

# 7. Save Plex environment info
cat > "$SNAPSHOT_DIR/plex.env" << EOF
# Plex Environment - $DATE
NETWORK_MODE=host
TZ=America/Los_Angeles
EOF

echo ""

# ============================================================================
# FULL BACKUP - Database, Metadata, and Media Assets (COMPRESSED)
# ============================================================================

if [ "$BACKUP_TYPE" == "full" ]; then
    echo "--- FULL BACKUP (Compressed) ---"
    
    PLEX_CONFIG="$SCRIPT_DIR/config/plex"
    
    if [ ! -d "$PLEX_CONFIG" ]; then
        echo "ERROR: Plex config directory not found at $PLEX_CONFIG"
        echo "Please update PLEX_CONFIG_PATH in this script"
        exit 1
    fi
    
    # Calculate size first
    echo "[7] Calculating Plex data size..."
    PLEX_SIZE=$(du -sh "$PLEX_CONFIG" 2>/dev/null | cut -f1)
    echo "    Plex config size: $PLEX_SIZE"
    echo ""
    
    # Create compressed archives for Plex components
    
    echo "[8] Compressing Plex database..."
    DB_PATH="$PLEX_CONFIG/Library/Application Support/Plex Media Server/Plug-in Support/Databases"
    if [ -d "$DB_PATH" ]; then
        tar -czf "$SNAPSHOT_DIR/plex-database.tar.gz" -C "$PLEX_CONFIG/Library/Application Support/Plex Media Server/Plug-in Support" Databases/
        echo "    ✓ Database compressed ($(du -sh "$SNAPSHOT_DIR/plex-database.tar.gz" | cut -f1))"
    fi
    
    echo "[9] Compressing Plex metadata (this may take a while)..."
    META_PATH="$PLEX_CONFIG/Library/Application Support/Plex Media Server/Metadata"
    if [ -d "$META_PATH" ]; then
        tar -czf "$SNAPSHOT_DIR/plex-metadata.tar.gz" -C "$PLEX_CONFIG/Library/Application Support/Plex Media Server" Metadata/
        echo "    ✓ Metadata compressed ($(du -sh "$SNAPSHOT_DIR/plex-metadata.tar.gz" | cut -f1))"
    fi
    
    echo "[10] Compressing Plex media assets..."
    MEDIA_PATH="$PLEX_CONFIG/Library/Application Support/Plex Media Server/Media"
    if [ -d "$MEDIA_PATH" ]; then
        tar -czf "$SNAPSHOT_DIR/plex-media.tar.gz" -C "$PLEX_CONFIG/Library/Application Support/Plex Media Server" Media/
        echo "    ✓ Media assets compressed ($(du -sh "$SNAPSHOT_DIR/plex-media.tar.gz" | cut -f1))"
    fi
    
    echo "[11] Compressing Plex Plug-ins..."
    PLUGINS_PATH="$PLEX_CONFIG/Library/Application Support/Plex Media Server/Plug-ins"
    if [ -d "$PLUGINS_PATH" ]; then
        tar -czf "$SNAPSHOT_DIR/plex-plugins.tar.gz" -C "$PLEX_CONFIG/Library/Application Support/Plex Media Server" Plug-ins/
        echo "    ✓ Plug-ins compressed ($(du -sh "$SNAPSHOT_DIR/plex-plugins.tar.gz" | cut -f1))"
    fi
    
    echo "[12] Compressing additional Plex config files..."
    PMS_PATH="$PLEX_CONFIG/Library/Application Support/Plex Media Server"
    if [ -d "$PMS_PATH" ]; then
        # Find and compress XML config files
        find "$PMS_PATH" -maxdepth 2 -name "*.xml" -print0 2>/dev/null | tar -czf "$SNAPSHOT_DIR/plex-configs.tar.gz" --null -T - 2>/dev/null || true
        if [ -f "$SNAPSHOT_DIR/plex-configs.tar.gz" ]; then
            echo "    ✓ Config files compressed ($(du -sh "$SNAPSHOT_DIR/plex-configs.tar.gz" | cut -f1))"
        fi
    fi
    
    # Backup *arr apps configurations (compressed)
    echo ""
    echo "--- BACKING UP *ARR APPLICATIONS (Compressed) ---"
    
    if [ -d "$SCRIPT_DIR/config/sonarr" ]; then
        echo "[13] Compressing Sonarr config..."
        tar -czf "$SNAPSHOT_DIR/sonarr.tar.gz" -C "$SCRIPT_DIR/config" sonarr/
        echo "    ✓ Sonarr compressed ($(du -sh "$SNAPSHOT_DIR/sonarr.tar.gz" | cut -f1))"
    fi
    
    if [ -d "$SCRIPT_DIR/config/radarr" ]; then
        echo "[14] Compressing Radarr config..."
        tar -czf "$SNAPSHOT_DIR/radarr.tar.gz" -C "$SCRIPT_DIR/config" radarr/
        echo "    ✓ Radarr compressed ($(du -sh "$SNAPSHOT_DIR/radarr.tar.gz" | cut -f1))"
    fi
    
    if [ -d "$SCRIPT_DIR/config/prowlarr" ]; then
        echo "[15] Compressing Prowlarr config..."
        tar -czf "$SNAPSHOT_DIR/prowlarr.tar.gz" -C "$SCRIPT_DIR/config" prowlarr/
        echo "    ✓ Prowlarr compressed ($(du -sh "$SNAPSHOT_DIR/prowlarr.tar.gz" | cut -f1))"
    fi
    
    if [ -d "$SCRIPT_DIR/config/overseerr" ]; then
        echo "[16] Compressing Overseerr config..."
        tar -czf "$SNAPSHOT_DIR/overseerr.tar.gz" -C "$SCRIPT_DIR/config" overseerr/
        echo "    ✓ Overseerr compressed ($(du -sh "$SNAPSHOT_DIR/overseerr.tar.gz" | cut -f1))"
    fi
    
    if [ -d "$SCRIPT_DIR/config/tautulli" ]; then
        echo "[17] Compressing Tautulli config..."
        tar -czf "$SNAPSHOT_DIR/tautulli.tar.gz" -C "$SCRIPT_DIR/config" tautulli/
        echo "    ✓ Tautulli compressed ($(du -sh "$SNAPSHOT_DIR/tautulli.tar.gz" | cut -f1))"
    fi
    
    if [ -d "$SCRIPT_DIR/config/flaresolverr" ]; then
        echo "[18] Compressing FlareSolverr config..."
        tar -czf "$SNAPSHOT_DIR/flaresolverr.tar.gz" -C "$SCRIPT_DIR/config" flaresolverr/
        echo "    ✓ FlareSolverr compressed ($(du -sh "$SNAPSHOT_DIR/flaresolverr.tar.gz" | cut -f1))"
    fi
    
    echo ""
fi

# ============================================================================
# CREATE RESTORE SCRIPT
# ============================================================================

echo "--- CREATING RESTORE SCRIPT ---"

if [ "$BACKUP_TYPE" == "full" ]; then
    # Full restore script for compressed backups
    cat > "$SNAPSHOT_DIR/restore.sh" << 'RESTORE_FULL'
#!/bin/bash
# Plex WSL FULL Restore Script (compressed backup)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=========================================="
echo "Plex WSL FULL Restore (Compressed)"
echo "WARNING: This will overwrite existing Plex data!"
echo "=========================================="
echo ""

read -p "Are you sure you want to restore? This will REPLACE current Plex database! (yes/no): " confirm
if [[ $confirm != "yes" ]]; then
    echo "Restore cancelled."
    exit 0
fi

echo ""
echo "Stopping Plex container..."
cd "$PROJECT_ROOT"
docker compose stop plex

echo ""
echo "[1/6] Restoring configuration files..."
cp "$SCRIPT_DIR/docker-compose.yml" "$PROJECT_ROOT/"
[ -f "$SCRIPT_DIR/.env" ] && cp "$SCRIPT_DIR/.env" "$PROJECT_ROOT/"

echo "[2/6] Extracting Plex database..."
if [ -f "$SCRIPT_DIR/plex-database.tar.gz" ]; then
    mkdir -p "$PROJECT_ROOT/config/plex/Library/Application Support/Plex Media Server/Plug-in Support"
    tar -xzf "$SCRIPT_DIR/plex-database.tar.gz" -C "$PROJECT_ROOT/config/plex/Library/Application Support/Plex Media Server/Plug-in Support/"
    echo "    ✓ Database extracted"
fi

echo "[3/6] Extracting Plex metadata..."
if [ -f "$SCRIPT_DIR/plex-metadata.tar.gz" ]; then
    mkdir -p "$PROJECT_ROOT/config/plex/Library/Application Support/Plex Media Server"
    tar -xzf "$SCRIPT_DIR/plex-metadata.tar.gz" -C "$PROJECT_ROOT/config/plex/Library/Application Support/Plex Media Server/"
    echo "    ✓ Metadata extracted"
fi

echo "[4/6] Extracting Plex media assets..."
if [ -f "$SCRIPT_DIR/plex-media.tar.gz" ]; then
    mkdir -p "$PROJECT_ROOT/config/plex/Library/Application Support/Plex Media Server"
    tar -xzf "$SCRIPT_DIR/plex-media.tar.gz" -C "$PROJECT_ROOT/config/plex/Library/Application Support/Plex Media Server/"
    echo "    ✓ Media assets extracted"
fi

echo "[5/6] Restoring Preferences.xml..."
if [ -f "$SCRIPT_DIR/Preferences.xml" ]; then
    cp "$SCRIPT_DIR/Preferences.xml" "$PROJECT_ROOT/config/plex/Library/Application Support/Plex Media Server/"
fi

echo ""
echo "[6/6] Extracting *arr applications..."

# Restore Sonarr
if [ -f "$SCRIPT_DIR/sonarr.tar.gz" ]; then
    echo "  → Extracting Sonarr..."
    rm -rf "$PROJECT_ROOT/config/sonarr"
    tar -xzf "$SCRIPT_DIR/sonarr.tar.gz" -C "$PROJECT_ROOT/config/"
fi

# Restore Radarr
if [ -f "$SCRIPT_DIR/radarr.tar.gz" ]; then
    echo "  → Extracting Radarr..."
    rm -rf "$PROJECT_ROOT/config/radarr"
    tar -xzf "$SCRIPT_DIR/radarr.tar.gz" -C "$PROJECT_ROOT/config/"
fi

# Restore Prowlarr
if [ -f "$SCRIPT_DIR/prowlarr.tar.gz" ]; then
    echo "  → Extracting Prowlarr..."
    rm -rf "$PROJECT_ROOT/config/prowlarr"
    tar -xzf "$SCRIPT_DIR/prowlarr.tar.gz" -C "$PROJECT_ROOT/config/"
fi

# Restore Overseerr
if [ -f "$SCRIPT_DIR/overseerr.tar.gz" ]; then
    echo "  → Extracting Overseerr..."
    rm -rf "$PROJECT_ROOT/config/overseerr"
    tar -xzf "$SCRIPT_DIR/overseerr.tar.gz" -C "$PROJECT_ROOT/config/"
fi

# Restore Tautulli
if [ -f "$SCRIPT_DIR/tautulli.tar.gz" ]; then
    echo "  → Extracting Tautulli..."
    rm -rf "$PROJECT_ROOT/config/tautulli"
    tar -xzf "$SCRIPT_DIR/tautulli.tar.gz" -C "$PROJECT_ROOT/config/"
fi

# Restore FlareSolverr
if [ -f "$SCRIPT_DIR/flaresolverr.tar.gz" ]; then
    echo "  → Extracting FlareSolverr..."
    rm -rf "$PROJECT_ROOT/config/flaresolverr"
    tar -xzf "$SCRIPT_DIR/flaresolverr.tar.gz" -C "$PROJECT_ROOT/config/"
fi

echo ""
echo "Setting correct permissions..."
sudo chown -R 1000:1000 "$PROJECT_ROOT/config/" 2>/dev/null || true

echo ""
echo "=========================================="
echo "✓ FULL RESTORE COMPLETE"
echo "=========================================="
echo ""
echo "Restored applications:"
echo "  • Plex (with database and metadata)"
echo "  • Sonarr"
echo "  • Radarr"
echo "  • Prowlarr"
echo "  • Overseerr"
echo "  • Tautulli"
echo "  • FlareSolverr"
echo ""
echo "Next steps:"
echo "1. Update Windows portproxy (PowerShell Admin):"
echo "   .\\fix-plex-network.ps1"
echo ""
echo "2. Start all containers:"
echo "   cd /opt/plex-service && docker compose up -d"
echo ""
echo "3. Verify access at your configured URLs"
echo ""
RESTORE_FULL

else
    # Config-only restore script
    cat > "$SNAPSHOT_DIR/restore.sh" << 'RESTORE_CONFIG'
#!/bin/bash
# Plex WSL Configuration Restore Script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=========================================="
echo "Plex WSL Configuration Restore"
echo "=========================================="
echo ""

# Restore docker-compose.yml
if [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    echo "[1/3] Restoring docker-compose.yml..."
    cp "$SCRIPT_DIR/docker-compose.yml" "$PROJECT_ROOT/"
fi

# Restore .env
if [ -f "$SCRIPT_DIR/.env" ]; then
    echo "[2/3] Restoring .env file..."
    cp "$SCRIPT_DIR/.env" "$PROJECT_ROOT/"
fi

# Restore Preferences.xml
echo "[3/3] Restoring Plex Preferences.xml..."
PREF_DEST="$PROJECT_ROOT/config/plex/Library/Application Support/Plex Media Server/Preferences.xml"
if [ -f "$SCRIPT_DIR/Preferences.xml" ]; then
    [ -f "$PREF_DEST" ] && cp "$PREF_DEST" "$PREF_DEST.backup.$(date +%Y%m%d%H%M%S)"
    cp "$SCRIPT_DIR/Preferences.xml" "$PREF_DEST"
fi

echo ""
echo "=========================================="
echo "✓ CONFIGURATION RESTORED"
echo "=========================================="
echo ""
echo "Manual steps:"
echo "1. Copy .wslconfig to Windows (if backed up):"
echo "   cp \"$SCRIPT_DIR/.wslconfig\" /mnt/c/Users/YOUR_USERNAME/"
echo ""
echo "2. Run PowerShell script (as Admin):"
echo "   .\\fix-plex-network.ps1"
echo ""
echo "3. Restart Plex:"
echo "   cd /opt/plex-service && docker compose restart plex"
echo ""
RESTORE_CONFIG
fi

chmod +x "$SNAPSHOT_DIR/restore.sh"

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "=========================================="
echo "✓ BACKUP COMPLETE"
echo "=========================================="
echo ""
echo "Type: ${BACKUP_TYPE^^}"
echo "Location: $SNAPSHOT_DIR"
echo ""
echo "Files backed up:"
ls -lh "$SNAPSHOT_DIR/" 2>/dev/null | tail -n +2 | awk '{printf "  %-40s %s\n", $9, $5}'

if [ "$BACKUP_TYPE" == "full" ]; then
    BACKUP_SIZE=$(du -sh "$SNAPSHOT_DIR" | cut -f1)
    echo ""
    echo "Total backup size (compressed): $BACKUP_SIZE"
fi

echo ""
echo "To restore:"
echo "  $SNAPSHOT_DIR/restore.sh"
echo ""
