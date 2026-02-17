# Windows to Docker Plex Migration Guide

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Pre-Migration Checklist](#pre-migration-checklist)
3. [Windows Plex Data Backup](#windows-plex-data-backup)
4. [WSL Setup](#wsl-setup)
5. [Data Migration](#data-migration)
6. [Post-Migration Configuration](#post-migration-configuration)
7. [Verification](#verification)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Windows Side
- Windows 10/11 with WSL2 installed
- Administrator access
- Existing Plex installation on Windows
- NVIDIA GPU with latest drivers installed

### WSL Side
- Fedora 43 recommended
- Sufficient disk space (Plex metadata can be 50GB+)
- Docker and Docker Compose
- NVIDIA Container Toolkit (for GPU transcoding)

---

## Pre-Migration Checklist

### 1. Document Current Setup
```powershell
# Run in PowerShell as Administrator
# Get Plex version
Get-ItemProperty "HKLM:\Software\Plex, Inc.\Plex Media Server" | Select DisplayVersion

# Note your:
# - Plex libraries and paths
# - Current server name
# - Remote access settings
# - Any custom transcoder settings
```

### 2. Disable Emptying Trash
In Plex Web:
1. Settings → Library → Disable "Empty trash automatically after every scan"
2. This prevents accidental deletion during migration

### 3. Disable Scheduled Tasks
1. Settings → Scheduled Tasks → Disable all automatic tasks
2. Prevents conflicts during migration

---

## Windows Plex Data Backup

### Location of Plex Data on Windows
```
%LOCALAPPDATA%\Plex Media Server\
```

### What to Backup

1. **Plex Database (Critical)**
   ```
   %LOCALAPPDATA%\Plex Media Server\Plug-in Support\Databases\
   ```

2. **Plex Preferences (Critical)**
   ```
   %LOCALAPPDATA%\Plex Media Server\Preferences.xml
   ```

3. **Metadata (Optional but recommended)**
   ```
   %LOCALAPPDATA%\Plex Media Server\Metadata\
   ```

4. **Media Assets (Optional)**
   ```
   %LOCALAPPDATA%\Plex Media Server\Media\
   ```

5. **Plug-ins (If you use any)**
   ```
   %LOCALAPPDATA%\Plex Media Server\Plug-ins\
   ```

### PowerShell Backup Script
```powershell
# Run as Administrator
$PlexDataPath = "$env:LOCALAPPDATA\Plex Media Server"
$BackupPath = "C:\PlexBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

# Stop Plex service
Stop-Service "PlexService" -ErrorAction SilentlyContinue
Get-Process "Plex Media Server" | Stop-Process -Force -ErrorAction SilentlyContinue

# Create backup directory
New-Item -ItemType Directory -Path $BackupPath -Force

# Backup critical files
Copy-Item -Path "$PlexDataPath\Plug-in Support\Databases" -Destination "$BackupPath\Databases" -Recurse
Copy-Item -Path "$PlexDataPath\Preferences.xml" -Destination "$BackupPath\Preferences.xml"
Copy-Item -Path "$PlexDataPath\Metadata" -Destination "$BackupPath\Metadata" -Recurse
Copy-Item -Path "$PlexDataPath\Media" -Destination "$BackupPath\Media" -Recurse
Copy-Item -Path "$PlexDataPath\Plug-ins" -Destination "$BackupPath\Plug-ins" -Recurse

Write-Host "Backup complete at: $BackupPath"
```

---

## WSL Setup

### 1. Enable WSL and Install Fedora 43

```powershell
# Run in PowerShell as Administrator

# Enable WSL
wsl --install

# Set WSL default version to 2
wsl --set-default-version 2

# Install Fedora 43 (officially supported)
wsl --install -d FedoraLinux-43

# Restart required after installation
```

### 2. Configure WSL Resources

Create/edit `.wslconfig` in Windows user profile:
```ini
# C:\Users\YourUsername\.wslconfig
[wsl2]
memory=16GB
processors=8
swap=8GB
localhostForwarding=true

# GPU support (if available)
[nvidia]
cuda=true
```

### 3. Mount Windows Drives in WSL

```bash
# In WSL Fedora
# Windows drives are automatically mounted at /mnt/
# C: drive → /mnt/c/
# D: drive → /mnt/d/
# etc.

# Verify mounts
ls -la /mnt/
```

---

## Data Migration

### 1. Copy Plex Data to WSL

```bash
# In WSL
# Create migration directory
mkdir -p ~/plex-migration

# Copy from Windows backup (adjust path as needed)
cp -r /mnt/c/PlexBackup_* ~/plex-migration/

# Verify copy
ls -la ~/plex-migration/
```

### 2. Prepare Docker Environment

```bash
# Navigate to plex-service directory
cd ~/plex-service

# Run setup (creates directories, installs Docker)
chmod +x scripts/setup/setup.sh
./scripts/setup/setup.sh
```

### 3. Migrate Plex Configuration

```bash
# Before starting Plex container, copy data
# IMPORTANT: Do this BEFORE first container start

# Stop Plex container if running
docker-compose stop plex

# Copy database
cp -r ~/plex-migration/Databases/* ~/docker/config/plex/Library/Application\ Support/Plex\ Media\ Server/Plug-in\ Support/Databases/

# Copy preferences
cp ~/plex-migration/Preferences.xml ~/docker/config/plex/Library/Application\ Support/Plex\ Media\ Server/

# Copy metadata (optional but recommended)
cp -r ~/plex-migration/Metadata/* ~/docker/config/plex/Library/Application\ Support/Plex\ Media\ Server/Metadata/

# Copy media assets (optional)
cp -r ~/plex-migration/Media/* ~/docker/config/plex/Library/Application\ Support/Plex\ Media\ Server/Media/

# Fix permissions
sudo chown -R 1000:1000 ~/docker/config/plex/
sudo chmod -R 755 ~/docker/config/plex/
```

### 4. Update Library Paths

The migration process will require updating library paths in Plex:

**Old Windows paths:**
- `C:\Users\YourName\Videos\TV Shows`
- `C:\Users\YourName\Videos\Movies`

**New Docker paths:**
- `/tv`
- `/movies`

**Steps:**
1. Start Plex container: `docker-compose up -d plex`
2. Access Plex Web: http://localhost:32400/web
3. Settings → Libraries → Edit each library
4. Update folder paths to new Docker paths
5. Plex will scan and match existing metadata

---

## Post-Migration Configuration

### 1. Re-enable Features

After successful migration:
1. Re-enable "Empty trash automatically after every scan"
2. Re-enable scheduled tasks
3. Configure remote access
4. Re-claim the server (if needed)

### 2. Configure *arr Stack

**Prowlarr** (http://localhost:9696):
1. Add indexers
2. Configure apps (Sonarr/Radarr)

**Sonarr** (http://localhost:8989):
1. Add root folder: `/data/tv`
2. Configure download client
3. Configure indexers via Prowlarr sync

**Radarr** (http://localhost:7878):
1. Add root folder: `/data/movies`
2. Configure download client
3. Configure indexers via Prowlarr sync

**Overseerr** (http://localhost:5055):
1. Connect to Plex
2. Configure Sonarr/Radarr
3. Set up users and requests

**Tautulli** (http://localhost:8181):
1. Connect to Plex
2. Configure notification agents
3. Restore from backup if applicable

---

## Verification

### 1. Test GPU Transcoding

```bash
# Enter Plex container
docker exec -it plex /bin/bash

# Check NVIDIA drivers
nvidia-smi

# Check if Plex sees GPU
# Look for "Encoder" and "Decoder" capabilities
```

### 2. Verify Hardware Transcoding in Plex

1. Play any media in Plex Web
2. Click settings (gear icon) → Quality → Convert
3. Check Plex Dashboard (Tautulli or Plex Web → Activity → Dashboard)
4. Stream should show "hw" (hardware) next to transcoding

### 3. Test All Services

```bash
# Check all containers are running
docker-compose ps

# Check logs
docker-compose logs plex
docker-compose logs sonarr
docker-compose logs radarr

# Test endpoints
curl -s http://localhost:32400/identity | grep Media
curl -s http://localhost:8989/sonarr/api/v3/health
curl -s http://localhost:7878/radarr/api/v3/health
curl -s http://localhost:9696/prowlarr/api/v1/health
curl -s http://localhost:5055/api/v1/status
curl -s http://localhost:8181/status
```

---

## Troubleshooting

### GPU Not Detected

**Symptoms:** Transcoding shows "(throttled)" or no "hw" indicator

**Solutions:**
```bash
# 1. Verify NVIDIA drivers in WSL
nvidia-smi

# 2. Check NVIDIA Container Toolkit
docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi

# 3. Verify Plex container has GPU access
docker exec plex nvidia-smi

# 4. Check daemon.json configuration
cat /etc/docker/daemon.json

# 5. Restart Docker
sudo systemctl restart docker

# 6. Verify Plex preferences
# In container: cat "/config/Library/Application Support/Plex Media Server/Preferences.xml" | grep Hardware
```

### Database Migration Issues

**Symptoms:** Plex starts fresh without libraries

**Solutions:**
1. Verify database file permissions: `ls -la config/plex/Library/Application\ Support/Plex\ Media\ Server/Plug-in\ Support/Databases/`
2. Ensure database is not corrupted: `sqlite3 com.plexapp.plugins.library.db ".tables"`
3. Check Plex logs: `docker-compose logs plex | grep -i error`

### Permission Issues

```bash
# Fix permissions
sudo chown -R 1000:1000 config/ data/ downloads/
sudo chmod -R 755 config/ data/ downloads/

# Verify UID/GID match
grep 1000 /etc/passwd
```

### Path Mapping Issues

**Symptoms:** Media not found after migration

**Solutions:**
1. Verify volume mounts in docker-compose.yml
2. Check Windows drive is accessible: `ls -la /mnt/c/`
3. Update library paths in Plex web UI
4. Re-scan libraries

### Network Issues

**Symptoms:** Cannot access services from Windows

**Solutions:**
1. Check Windows Defender Firewall
2. Verify WSL is running: `wsl --status`
3. Try accessing via WSL IP: `ip addr show eth0 | grep "inet "`
4. Use host network mode for Plex if needed

---

## Rollback Procedure

If migration fails, revert to Windows Plex:

1. Stop Docker containers: `docker-compose down`
2. Start Windows Plex service
3. Restore from Windows backup if needed
4. Verify Windows paths still work

---

## Performance Optimization

### WSL Settings
```ini
# .wslconfig - adjust based on your system
[wsl2]
memory=20GB
processors=8
swap=4GB
swapFile=C:\temp\wsl-swap.vhdx
localhostForwarding=true
cuda=true
```

### Docker Optimization
- Use SSD for config and transcode directories
- Allocate sufficient RAM for metadata caching
- Enable automatic updates for containers

### Plex Optimization
- Disable "Generate video preview thumbnails" initially
- Set transcode directory to fast SSD
- Adjust "Transcoder quality" based on GPU capability
- Enable "Use hardware acceleration when available"

---

## Maintenance Commands

```bash
# Update all containers
docker-compose pull
docker-compose up -d

# View logs
docker-compose logs -f [service_name]

# Backup Plex config
tar -czvf plex-backup-$(date +%Y%m%d).tar.gz config/plex/

# Clean up old images
docker system prune -a

# Check disk usage
du -sh config/*
du -sh data/*
```

---

## Support Resources

- [LinuxServer.io Documentation](https://docs.linuxserver.io/)
- [Plex Docker Documentation](https://hub.docker.com/r/linuxserver/plex)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)
- [WSL Documentation](https://docs.microsoft.com/en-us/windows/wsl/)

---

**Last Updated:** $(date +%Y-%m-%d)
**Tested on:** Windows 11 + WSL2 + Fedora 43
