#!/bin/bash
# Plex Backup Restore Script
# Usage: ./scripts/restore.sh /path/to/backup

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_PATH="${1:-}"

if [ -z "$BACKUP_PATH" ]; then
    echo "Usage: $0 /path/to/backup"
    echo ""
    echo "Example:"
    echo "  $0 /mnt/e/Plex/Backups/full_20260217_023537"
    echo "  $0 ./backups/full_latest"
    exit 1
fi

if [ ! -d "$BACKUP_PATH" ]; then
    echo "Error: Backup directory not found: $BACKUP_PATH"
    exit 1
fi

if [ ! -f "$BACKUP_PATH/restore.sh" ]; then
    echo "Error: No restore.sh found in backup: $BACKUP_PATH"
    exit 1
fi

echo "Restoring from backup: $BACKUP_PATH"
echo ""

# Run the restore script from the backup
bash "$BACKUP_PATH/restore.sh"
