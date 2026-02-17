# Plex WSL Service - Development Workflow

This repository contains the configuration for Plex Media Server running on WSL2.

## Workflow

**Important:** All changes must be made in this repository first, then deployed to `/opt/plex-service`.

### Directory Structure

- `~/develop/plex-service/` - **Git repository** (make all changes here)
- `/opt/plex-service/` - **Execution location** (deployed from repo, do not edit directly)

### Making Changes

1. **Edit files in this repo:**
   ```bash
   cd ~/develop/plex-service
   # Edit docker-compose.yml, scripts, etc.
   ```

2. **Commit your changes:**
   ```bash
   git add .
   git commit -m "Description of changes"
   ```

3. **Deploy to execution location:**
   ```bash
   ./deploy.sh
   ```

4. **Apply changes (if needed):**
   ```bash
   cd /opt/plex-service
   docker compose restart plex  # If docker-compose.yml changed
   ```

### Restoring Working Configuration

If something breaks, restore the working tagged version:

```bash
cd ~/develop/plex-service
git checkout working-config
./deploy.sh
```

### Backup

To backup the current Plex configuration:

```bash
cd /opt/plex-service
./backup-config.sh
```

## Tags

- `working-config` - Working Plex configuration with remote access enabled

## Network Setup

After WSL restart, update Windows port forwarding:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\YOUR_WINDOWS_USER\Documents\update-port-forwarding.ps1"
```

Or use the WSL startup script which is automatically run when WSL starts.
