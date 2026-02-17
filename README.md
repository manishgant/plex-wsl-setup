# Plex WSL2: Complete Media Server Migration & Management

Transform your native Windows Plex setup into a powerful, containerized WSL2-based media server stack with automated backups and one-click disaster recovery.

## What is This?

This project provides a **complete migration path** from native Windows Plex to a modern Docker-based setup running on WSL2, with comprehensive backup and restore capabilities.

### Why Migrate from Windows Plex to WSL2?

- **Better Performance**: Linux containers have lower overhead than Windows services
- **GPU Transcoding**: Full NVIDIA GPU support via WSL2
- **Reliability**: Docker containers are more stable and easier to manage
- **Complete Stack**: Integrated *arr suite (Sonarr, Radarr, Prowlarr, etc.)
- **Easy Recovery**: One-command restore from backup after any failure
- **Media Stays Safe**: Your movies/shows remain on Windows; only the server moves

## The Three Use Cases

### 1. Migration - Moving from Windows Plex
You're currently running Plex natively on Windows and want to migrate to WSL2 without losing your library, watch history, or metadata.

### 2. Backup & Restore - Regular Protection
Your WSL2 setup is working great. You want automated backups so you can restore quickly if something breaks.

### 3. Fresh Install - After Disaster
WSL2 crashed, Windows needs reinstall, or you're setting up a new PC. Your media files are safe (on Windows drive), and you have a backup. Restore everything in 30 minutes.

---

## Quick Start: Choose Your Path

### Path 1: Fresh Setup (New Install)
```bash
# Clone this repository
git clone https://github.com/manishgant/plex-wsl-setup.git /opt/plex-service
cd /opt/plex-service

# Run setup
./setup.sh

# Configure Windows network
# (See Windows Setup section below)
```

### Path 2: Migrate from Windows Plex
See detailed migration guide in `docs/migration/MIGRATION_GUIDE.md`

### Path 3: Restore from Backup
```bash
# Fresh WSL2 install or new PC
./fresh-install-restore.sh /path/to/your/backup

# Example:
./fresh-install-restore.sh /mnt/e/Plex/Backups/full_20260217_023537
```

---

## What's Included?

### Core Media Stack
- **Plex Media Server** - Your media library with GPU transcoding
- **Sonarr** - TV show management and automation
- **Radarr** - Movie management and automation
- **Prowlarr** - Indexer management for Sonarr/Radarr
- **Overseerr** - Beautiful web interface for media requests
- **Tautulli** - Plex statistics and monitoring
- **FlareSolverr** - Bypass Cloudflare protection on indexers

### Key Features
- **Host Network Mode**: All services communicate seamlessly
- **Windows Integration**: Access services via localhost or Windows IP
- **VPN Compatible**: Works with VPNs using dynamic IP assignment
- **GPU Acceleration**: NVIDIA hardware transcoding support
- **Compressed Backups**: 61% space savings with gzip compression

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Windows Host                              │
│  ┌─────────────────────┐    ┌─────────────────────────────────┐ │
│  │     WSL2 (Fedora)   │    │      Windows Applications       │ │
│  │  ┌───────────────┐  │    │  ┌───────────────────────────┐  │ │
│  │  │    Docker     │  │    │  │   qBittorrent             │  │ │
│  │  │ ┌───────────┐ │  │    │  │   Port: 8112              │  │ │
│  │  │ │   Plex    │ │  │◄───┼──┤   (Torrent Client)        │  │ │
│  │  │ │  :32400   │ │  │    │  └───────────────────────────┘  │ │
│  │  │ └─────┬─────┘ │  │    │                                 │ │
│  │  │ ┌─────┴─────┐ │  │    │  ┌───────────────────────────┐  │ │
│  │  │ │  Sonarr   │ │  │    │  │   Port Proxy              │  │ │
│  │  │ │  :8989    │ │  │◄───┼──┤   0.0.0.0:32400           │  │ │
│  │  │ └───────────┘ │  │    │  │   → WSL2:32400            │  │ │
│  │  │ ┌───────────┐ │  │    │  └───────────────────────────┘  │ │
│  │  │ │  Radarr   │ │  │    │                                 │ │
│  │  │ │  :7878    │ │  │    │  ┌───────────────────────────┐  │ │
│  │  │ └───────────┘ │  │    │  │   Windows Firewall        │  │ │
│  │  │ ┌───────────┐ │  │    │  │   (Allows Plex traffic)   │  │ │
│  │  │ │  Overseerr│ │  │    │  └───────────────────────────┘  │ │
│  │  │ │  :5055    │ │  │    │                                 │ │
│  │  │ └───────────┘ │  │    └─────────────────────────────────┘ │
│  │  └───────────────┘  │                                        │
│  └─────────────────────┘                                        │
└────────────────────────────────┬────────────────────────────────┘
                                 │
                                 │ WSL mounts Windows drive
                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│              Windows Drive (Your Media Library)                  │
│  E:\Plex\  (mounted as /mnt/e/Plex in WSL)                       │
│  ├── Movies/                                                     │
│  ├── TV Shows/                                                   │
│  ├── Music/                                                      │
│  └── Downloads/          ◄── Media accessible to both            │
│                             Windows and WSL2                     │
└─────────────────────────────────────────────────────────────────┘
```

### Network Flow (Remote Access)

```
External User                    Your Home Network
     │                                 │
     │  https://your-public-ip:32400   │
     ├────────────────────────────────►│
     │                                 │
     │                           Router (Port Forward)
     │                           32400 → Windows:32400
     │                                 │
     │                           Windows Port Proxy
     │                           0.0.0.0:32400 → WSL2:32400
     │                                 │
     │                                 ▼
     │                          Plex in WSL2
     │                          Serves the content
     │◄────────────────────────────────┤
     │                                 │
```

### Service Communication

```
User Request Flow:

1. User wants to watch "The Matrix"
   └─► Opens Plex app/website

2. Plex checks if movie exists
   └─► Queries its database (in WSL2)

3. If not found, user requests via Overseerr
   └─► Overseerr → Radarr (search for movie)

4. Radarr searches via Prowlarr
   └─► Prowlarr → Indexers → Finds torrent

5. Radarr sends to qBittorrent
   └─► qBittorrent (Windows) downloads to Downloads/

6. Radarr imports to library
   └─► Hardlinks to Movies/ folder
   └─► Notifies Plex to scan

7. Plex updates library
   └─► User can now watch!

All automated - you just click "Request" in Overseerr!
```

---

## Installation

### Step 1: Enable WSL2
```powershell
# Run in PowerShell as Administrator
wsl --install -d FedoraLinux-43
wsl --set-default-version 2
```

### Step 2: Clone Repository
```bash
# In WSL2
git clone https://github.com/manishgant/plex-wsl-setup.git /opt/plex-service
cd /opt/plex-service
```

### Step 3: Configure Environment
```bash
# Copy environment template
cp .env.example .env

# Edit .env and add your Plex claim token
nano .env

# Get claim token from: https://www.plex.tv/claim/
```

### Step 4: Windows Network Setup
```powershell
# Run in PowerShell as Administrator
cd C:\path\to\plex-wsl-setup
.\fix-plex-network.ps1
```

This automatically configures port proxy, firewall rules, and VPN-compatible forwarding.

### Step 5: Start Services
```bash
# In WSL2
cd /opt/plex-service
docker-compose up -d
```

Access your services:
- Plex: http://localhost:32400/web
- Sonarr: http://localhost:8989
- Radarr: http://localhost:7878
- Overseerr: http://localhost:5055

---

## Migration from Native Windows Plex

Already have Plex running on Windows? Migrate without losing anything.

### Migration Process Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    MIGRATION WORKFLOW                            │
└─────────────────────────────────────────────────────────────────┘

PHASE 1: PREPARATION (5 minutes)
┌──────────────┐
│ Windows Plex │
│  (Running)   │
└──────┬───────┘
       │
       ▼ Stop Plex Service
┌──────────────┐
│ Windows Plex │
│  (Stopped)   │ ◄── Prevents data corruption
└──────┬───────┘
       │
       ▼ Document your setup
┌──────────────┐
│ Libraries:   │
│ - E:\Movies  │
│ - E:\TV      │
│ - etc...     │
└──────────────┘

PHASE 2: DATA BACKUP (10 minutes)
┌─────────────────────────────────────┐
│ Windows Plex Data                   │
│ %LOCALAPPDATA%\Plex Media Server\   │
└──────────┬──────────────────────────┘
           │
           ├──► Databases/ ───────┐
           │   (library.db)       │
           │                      │
           ├──► Metadata/ ────────┤ Copy to C:\PlexBackup\
           │   (posters, art)     │
           │                      │
           ├──► Preferences.xml ──┘
           │   (settings)
           │
           └──► Media/ (SKIP!)
               (your actual movies - already on E: drive)

PHASE 3: SETUP WSL2 (15 minutes)
┌─────────────────┐
│ Install WSL2    │
│ Clone this repo │
│ Run setup.sh    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ WSL2 Ready      │
│ Services ready  │
│ but empty       │
└─────────────────┘

PHASE 4: RESTORE DATA (10 minutes)
┌──────────────────┐
│ C:\PlexBackup\   │
└──────┬───────────┘
       │
       ├──► Copy to WSL2:
       │    /opt/plex-service/config/plex/
       │
       ├──► Databases/ → Plug-in Support/
       │
       └──► Metadata/ → Metadata/

PHASE 5: RECONFIGURE (5 minutes)
┌──────────────┐     ┌──────────────┐
│ Plex Web UI  │────►│ Update Paths │
│ (WSL2)       │     │              │
└──────────────┘     │ E:\Movies    │
                     │   ↓          │
                     │ /mnt/e/Movies│
                     └──────────────┘

RESULT:
┌─────────────────────────────────────────┐
│ WSL2 Plex                               │
│ - All watch history preserved ✓        │
│ - All metadata preserved ✓             │
│ - Library paths updated ✓              │
│ - Running better than before! ✓        │
└─────────────────────────────────────────┘
```

### Quick Migration Steps

1. **Stop Windows Plex** to prevent data corruption
2. **Backup Windows data** using provided scripts
3. **Setup WSL2** and install this project
4. **Copy database and metadata** to WSL2
5. **Update library paths** in Plex web interface

Full guide: See `docs/migration/MIGRATION_GUIDE.md`

---

## Backup & Restore System

### Create Your First Backup

```bash
# Quick config backup (fast, config only)
./backup-config.sh config

# Full backup with database and metadata (compressed)
./backup-config.sh full /mnt/e/Plex/Backups
```

### What Gets Backed Up?

```
FULL BACKUP (3-10GB compressed)
┌─────────────────────────────────────────────────────┐
│ WSL2 /opt/plex-service/config/                      │
└──────────┬──────────────────────────────────────────┘
           │
           ├──► plex/                                  │
           │   ├── Database/                           │
           │   │   └── com.plexapp.plugins.library.db  │
           │   │       (All your libraries, watch      │
           │   │        history, user ratings)         │
           │   │                                       │
           │   ├── Metadata/                           │
           │   │   ├── Movies/                         │
           │   │   │   └── poster.jpg                  │
           │   │   ├── TV Shows/                       │
           │   │   └── ... (All artwork & thumbnails) │
           │   │                                       │
           │   └── Preferences.xml                     │
           │       (All your settings)                 │
           │                                           │
           ├──► sonarr/                                │
           │   └── config.xml                          │
           │       (TV shows, quality profiles)        │
           │                                           │
           ├──► radarr/                                │
           │   └── config.xml                          │
           │       (Movies, quality profiles)          │
           │                                           │
           ├──► prowlarr/                              │
           │   └── config.xml                          │
           │       (Indexer settings)                  │
           │                                           │
           ├──► overseerr/                             │
           │   └── db.sqlite                           │
           │       (User requests, settings)           │
           │                                           │
           ├──► tautulli/                              │
           │   └── tautulli.db                         │
           │       (Watch statistics)                  │
           │                                           │
           └──► flaresolverr/                          │
               └── settings.json                       │
                   (Cloudflare bypass settings)        │

WHAT IS NOT BACKED UP ( stays safe on Windows ):
❌ /mnt/e/Plex/Movies/     (Your actual movie files)
❌ /mnt/e/Plex/TV/         (Your actual TV shows)
❌ /mnt/e/Plex/Music/      (Your actual music)

These are on Windows drive and don't need backup!
```

**Full backup includes:**
- Plex Database (library, watch history, ratings)
- Plex Metadata (posters, thumbnails, artwork)
- All *arr app configurations (Sonarr, Radarr, etc.)
- Compressed with gzip (61% space savings)

### Automated Backups

```bash
# Edit crontab for scheduled backups
crontab -e

# Daily config backup at 3 AM
0 3 * * * cd /opt/plex-service && ./backup-config.sh config /mnt/e/Plex/Backups

# Weekly full backup on Sundays at 2 AM
0 2 * * 0 cd /opt/plex-service && ./backup-config.sh full /mnt/e/Plex/Backups
```

### Disaster Recovery

Your WSL2 crashed or you got a new PC? No problem!

#### Disaster Recovery Flow

```
DISASTER SCENARIOS:

Scenario A: WSL2 Corrupted
┌──────────────┐     Disaster     ┌──────────────┐
│   WSL2       │  ─────────────►  │   WSL2       │
│  (Working)   │   WSL won't      │  (Broken)    │
└──────┬───────┘   start          └──────────────┘
       │
       │ Media on E: drive        SAFE ✓
       │ Backups on DrivePool     SAFE ✓
       │
       ▼ Recovery
┌──────────────┐
│  Fresh WSL2  │
│  Install     │
└──────┬───────┘
       │
       ▼ One Command
┌─────────────────────────┐
│ fresh-install-restore.sh│
│ /mnt/e/Plex/Backups/... │
└──────┬──────────────────┘
       │
       ├──► Auto-installs Docker
       ├──► Creates directories
       ├──► Restores all configs
       ├──► Restores database
       ├──► Restores metadata
       └──► Starts services
       │
       ▼ 30 minutes later...
┌──────────────┐
│   WSL2       │
│  (Restored)  │ ◄── Everything works!
└──────────────┘

Scenario B: New PC
┌──────────────┐     New PC       ┌──────────────┐
│   Old PC     │  ─────────────►  │   New PC     │
│  (Working)   │   Hardware       │  (Fresh)     │
└──────┬───────┘   upgrade        └──────────────┘
       │
       │ Plug in old drive with:
       │ - Media files (E: drive) ✓
       │ - Backups folder ✓
       │
       ▼ Same Recovery Process
┌─────────────────────────┐
│ fresh-install-restore.sh│
└─────────────────────────┘
       │
       ▼ Done!
┌──────────────┐
│   New PC     │
│ Plex Ready   │ ◄── Exact same setup!
└──────────────┘
```

#### Recovery Process

```bash
# One-command recovery from backup
./fresh-install-restore.sh /mnt/e/Plex/Backups/full_20260217_023537
```

**What happens automatically:**

```
Minute 0-5: Prerequisites Check
├── Check WSL2 installed ✓
├── Install Docker if missing
└── Install required packages

Minute 5-10: Setup Infrastructure
├── Clone GitHub template
├── Create directory structure
└── Setup config paths

Minute 10-25: Restore Data
├── Extract Plex database
├── Extract Plex metadata
├── Restore Sonarr config
├── Restore Radarr config
├── Restore all *arr configs
└── Set correct permissions

Minute 25-30: Network & Start
├── Show Windows setup instructions
├── Start all containers
├── Verify services responding
└── Display access URLs
```

**Recovery time: ~30 minutes** (vs hours manually)

---

## The Complete Workflow

### Visual Workflow Overview

```
YOUR JOURNEY WITH THIS PROJECT:

┌─────────────────────────────────────────────────────────────────┐
│ 1. INITIAL MIGRATION (One-time setup)                           │
└─────────────────────────────────────────────────────────────────┘

    Windows Plex                   WSL2 Setup                    Result
         │                              │                            │
         │  Stop Service                │                            │
         ▼                              ▼                            ▼
    ┌─────────┐                  ┌──────────┐               ┌─────────────┐
    │ Backup  │ ───────────────► │ Install  │ ────────────► │ WSL2 Plex   │
    │ Data    │   Copy DB &      │ WSL2 +   │   Restore     │ Better      │
    └─────────┘   Metadata       │ Docker   │   Data        │ Performance │
                                  └──────────┘               └─────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ 2. DAILY OPERATION (Ongoing use)                                │
└─────────────────────────────────────────────────────────────────┘

    Request                        Download                      Watch
      │                              │                            │
      ▼                              ▼                            ▼
┌──────────┐                 ┌──────────┐               ┌──────────┐
│ Overseerr│ ──► Sonarr ────►│ Radarr   │ ──► qBit ────►│ Plex     │
│ "Add     │    Search       │ Download │     Save      │ Stream   │
│  Movie"  │    Indexers     │ Torrent  │     to E:     │ 4K/HDR   │
└──────────┘                 └──────────┘               └──────────┘

┌─────────────────────────────────────────────────────────────────┐
│ 3. REGULAR BACKUPS (Protection)                                 │
└─────────────────────────────────────────────────────────────────┘

Every Day @ 3 AM                    Every Week @ 2 AM
        │                                  │
        ▼                                  ▼
┌──────────────┐                  ┌──────────────┐
│ Config Backup│                  │ Full Backup  │
│ (1MB)        │                  │ (3-10GB)     │
│ Takes 10 sec │                  │ Takes 10 min │
└──────┬───────┘                  └──────┬───────┘
       │                                 │
       └──────────────┬──────────────────┘
                      ▼
            ┌──────────────────┐
            │ /mnt/e/Plex/     │
            │ Backups/         │
            │ (DrivePool)      │
            └──────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ 4. DISASTER RECOVERY (When things go wrong)                     │
└─────────────────────────────────────────────────────────────────┘

Disaster                          Recovery                      Result
   │                                  │                            │
   ▼                                  ▼                            ▼
┌──────────┐  Run restore script  ┌──────────┐            ┌─────────────┐
│ WSL2     │ ───────────────────► │ Auto     │ ─────────► │ Everything  │
│ Crashed  │  fresh-install-      │ Install  │   30 min   │ Works!      │
│          │  restore.sh          │ & Restore│            │ Same setup  │
└──────────┘                      └──────────┘            └─────────────┘

Time Comparison:
┌────────────────┬──────────────────┐
│ Without Backup │ Days of work     │
│ With Backup    │ 30 minutes       │
└────────────────┴──────────────────┘
```

---

## Why This Setup?

### Your Media is Always Safe
- Media files stay on Windows drive (accessible even if WSL fails)
- Backups are stored separately (external drive, cloud, NAS)
- One command restores everything

### Easy to Maintain
- Docker containers auto-restart if they crash
- Single command updates all services
- Backup before any changes

### Production Ready
- Used daily for months without issues
- Handles VPN connections seamlessly
- GPU transcoding for 4K content
- Complete *arr automation

---

## Quick Reference

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f plex

# Backup now
./backup-config.sh full /mnt/e/Plex/Backups

# Update containers
docker-compose pull && docker-compose up -d

# Check status
docker ps
```

---

## Support

- **Migration Issues**: See `docs/migration/MIGRATION_GUIDE.md`
- **Quick Commands**: See `docs/QUICK_REFERENCE.md`
- **Workflow Guide**: See `docs/WORKFLOW.md`

**GitHub**: https://github.com/manishgant/plex-wsl-setup
