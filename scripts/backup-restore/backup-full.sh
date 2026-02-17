#!/bin/bash
# Plex Full Backup Wrapper
# This is a convenience script that calls backup.sh with 'full' argument

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/backup.sh" full "$@"
