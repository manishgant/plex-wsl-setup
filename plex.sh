#!/bin/bash
# Plex Management Wrapper
# Usage: ./plex.sh <command>
#
# Commands:
#   setup           - Initial Docker/Fedora setup and configuration
#   verify          - Verify Plex stack is running correctly
#   migrate         - Migrate from Windows Plex to WSL2
#   restore         - Restore from backup
#   backup          - Backup configuration (config|full)
#   backup-full     - Full backup (config + database)
#   start           - Start Plex containers
#   stop            - Stop Plex containers
#   restart         - Restart Plex containers
#   logs            - View Plex logs
#   network         - Setup WSL network for Plex access
#   help            - Show this help message

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

COMMAND="${1:-help}"

show_help() {
    cat << EOF
Plex WSL Management

Usage: ./plex.sh <command>

Commands:
  setup           Initial Docker/Fedora setup and configuration
  verify          Verify Plex stack is running correctly
  deploy          Deploy configuration to /opt/plex-service
  migrate         Migrate from Windows Plex to WSL2
  restore         Restore from backup
  backup [type]   Backup configuration (config|full, default: config)
  backup-full     Full backup (config + database)
  update          Pull latest images and recreate containers
  start           Start Plex containers
  stop            Stop Plex containers
  restart         Restart Plex containers
  logs            View Plex logs (follows with -f)
  network         Setup WSL network for Plex access
  help            Show this help message

Examples:
  ./plex.sh setup
  ./plex.sh verify
  ./plex.sh deploy
  ./plex.sh update
  ./plex.sh migrate
  ./plex.sh restore /path/to/backup.tar.gz
  ./plex.sh backup config
  ./plex.sh backup full <your backup path>
  ./plex.sh network
  ./plex.sh logs -f

EOF
}

case "$COMMAND" in
    setup)
        echo "=== Running Plex Setup ==="
        ./scripts/setup/setup.sh
        ;;
    verify)
        echo "=== Verifying Plex Stack ==="
        ./scripts/setup/verify.sh
        ;;
    deploy)
        echo "=== Deploying to /opt/plex-service ==="
        ./scripts/deploy/deploy.sh
        ;;
    migrate)
        echo "=== Migrating from Windows Plex ==="
        ./scripts/migrate/fresh-install-restore.sh migrate
        ;;
    restore)
        BACKUP_PATH="${2:-}"
        if [ -z "$BACKUP_PATH" ]; then
            echo "Usage: ./plex.sh restore <backup_path>"
            echo "Example: ./plex.sh restore /mnt/e/Plex/Backups/backup-latest.tar.gz"
            exit 1
        fi
        echo "=== Restoring from Backup: $BACKUP_PATH ==="
        ./scripts/migrate/fresh-install-restore.sh restore "$BACKUP_PATH"
        ;;
    backup)
        BACKUP_TYPE="${2:-config}"
        BACKUP_DIR="${3:-}"
        echo "=== Backing up ($BACKUP_TYPE) ==="
        if [ -n "$BACKUP_DIR" ]; then
            ./scripts/backup-restore/backup.sh "$BACKUP_TYPE" "$BACKUP_DIR"
        else
            ./scripts/backup-restore/backup.sh "$BACKUP_TYPE"
        fi
        ;;
    backup-full)
        BACKUP_DIR="${2:-}"
        echo "=== Full Backup ==="
        if [ -n "$BACKUP_DIR" ]; then
            ./scripts/backup-restore/backup-full.sh "$BACKUP_DIR"
        else
            ./scripts/backup-restore/backup-full.sh
        fi
        ;;
    update)
        echo "=== Updating Plex & *arr Stack ==="
        docker compose pull
        docker compose up -d
        echo "=== Update Complete ==="
        echo "Check logs: ./plex.sh logs"
        ;;
    start)
        echo "=== Starting Plex Containers ==="
        docker compose up -d
        ;;
    stop)
        echo "=== Stopping Plex Containers ==="
        docker compose down
        ;;
    restart)
        echo "=== Restarting Plex Containers ==="
        docker compose restart
        ;;
    logs)
        docker compose logs -f "${2:-plex}"
        ;;
    network)
        echo "=== Setting up WSL Network ==="
        source ./scripts/wsl/plex-wsl-startup.sh
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Unknown command: $COMMAND"
        echo ""
        show_help
        exit 1
        ;;
esac
