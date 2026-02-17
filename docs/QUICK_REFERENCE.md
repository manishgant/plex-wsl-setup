# Quick Reference: Plex Docker WSL Commands

## Fedora 43 Specific Commands

### Starting Services (Fedora)
```bash
# Start with Fedora docker-compose
docker-compose -f docker-compose-fedora43.yml up -d

# Stop services
docker-compose -f docker-compose-fedora43.yml down

# View logs
docker-compose -f docker-compose-fedora43.yml logs -f
```

### SELinux Commands (Fedora)
```bash
# Check SELinux status
getenforce

# Set permissive (less secure)
sudo setenforce 0

# Set enforcing (recommended)
sudo setenforce 1

# Fix SELinux contexts
sudo semanage fcontext -a -t container_file_t "$(pwd)/config(/.*)?"
sudo semanage fcontext -a -t container_file_t "$(pwd)/data(/.*)?"
sudo restorecon -Rv config/ data/ downloads/

# View SELinux logs for denials
sudo ausearch -m avc -ts recent
```

### Systemd Commands (Fedora)
```bash
# Check Docker status
sudo systemctl status docker

# Restart Docker
sudo systemctl restart docker

# Enable Docker on boot
sudo systemctl enable docker
```

## Daily Operations

```bash
# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# View all container logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f plex
docker-compose logs -f sonarr
docker-compose logs -f radarr

# Restart a service
docker-compose restart plex

# Update all containers
docker-compose pull
docker-compose up -d
```

## GPU Verification

```bash
# Check NVIDIA in WSL
nvidia-smi

# Check NVIDIA in container
docker exec plex nvidia-smi

# Check transcoding capability
docker exec plex ls -la /dev/nvidia*

# View Plex hardware transcoding settings
cat config/plex/Library/Application\ Support/Plex\ Media\ Server/Preferences.xml | grep -i "Hardware"
```

## Migration Commands

```bash
# Backup Windows Plex data
# Run in PowerShell as Admin
Stop-Service "PlexService"
Copy-Item "$env:LOCALAPPDATA\Plex Media Server" "C:\PlexBackup" -Recurse

# Copy to WSL
cp -r /mnt/c/PlexBackup ~/plex-backup

# Copy database to Docker
docker-compose stop plex
cp -r ~/plex-backup/Plug-in\ Support/Databases/* ~/docker/config/plex/Library/Application\ Support/Plex\ Media\ Server/Plug-in\ Support/Databases/
docker-compose start plex
```

## Troubleshooting

```bash
# Reset container
# WARNING: This deletes all container data!
docker-compose down -v
docker-compose up -d

# Shell into container
docker exec -it plex /bin/bash
docker exec -it sonarr /bin/bash

# Check container stats
docker stats

# Clean up Docker
docker system prune -a
docker volume prune
```

## File Locations

### Windows (Original)
```
%LOCALAPPDATA%\Plex Media Server\
```

### WSL Docker
```
./config/plex/                    # Plex config
./config/sonarr/                  # Sonarr config
./config/radarr/                  # Radarr config
./config/prowlarr/                # Prowlarr config
./config/overseerr/               # Overseerr config
./config/tautulli/                # Tautulli config
./data/                           # Media files
./downloads/                      # Download location
./transcode/                      # Transcode temp directory
```

## URLs

| Service | URL | Default Port |
|---------|-----|--------------|
| Plex | http://localhost:32400/web | 32400 |
| Sonarr | http://localhost:8989 | 8989 |
| Radarr | http://localhost:7878 | 7878 |
| Prowlarr | http://localhost:9696 | 9696 |
| Overseerr | http://localhost:5055 | 5055 |
| Tautulli | http://localhost:8181 | 8181 |

## Environment Variables

Edit `.env` file:
```bash
PLEX_CLAIM_TOKEN=claim-xxxxxxxxxxxxxxxx
PUID=1000
PGID=1000
TZ=America/New_York
```

## Health Check Endpoints

```bash
curl http://localhost:32400/identity
curl http://localhost:8989/sonarr/api/v3/health
curl http://localhost:7878/radarr/api/v3/health
curl http://localhost:9696/prowlarr/api/v1/health
curl http://localhost:5055/api/v1/status
curl http://localhost:8181/status
```

## Performance Tuning

### WSL Config (.wslconfig)
```ini
[wsl2]
memory=16GB
processors=8
swap=8GB
cuda=true
```

### Docker Resources
Monitor with: `docker system df`

### Plex Transcode Settings
- Transcoder quality: Automatic
- Transcoder temporary directory: /transcode
- Use hardware acceleration: ✓
- Generate video preview thumbnails: Disable initially
