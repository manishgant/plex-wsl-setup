#!/bin/bash

# Verification script for Plex Docker setup on Fedora 43 on WSL2
# Run this after starting containers to verify everything works

echo "=== Plex Docker Verification Script ==="
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0

# Function to check if a command succeeded
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $1"
        return 0
    else
        echo -e "${RED}✗${NC} $1"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

echo "[1/11] Checking Docker daemon..."
docker ps > /dev/null 2>&1
check_status "Docker daemon running"

echo ""
echo "[2/11] Checking SELinux status..."
SELINUX_STATUS=$(getenforce)
echo " SELinux status: $SELINUX_STATUS"
if [ "$SELINUX_STATUS" != "Enforcing" ]; then
    echo -e "${GREEN}✓${NC} SELinux not blocking (status: $SELINUX_STATUS)"
else
    echo -e "${YELLOW}!${NC} SELinux is Enforcing - containers use :Z flag on volumes"
fi

echo ""
echo "[3/11] Checking container status..."
CONTAINERS=("plex" "sonarr" "radarr" "prowlarr" "overseerr" "tautulli")
for container in "${CONTAINERS[@]}"; do
    STATUS=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
    if [ "$STATUS" = "running" ]; then
        echo -e "${GREEN}✓${NC} $container: $STATUS"
    else
        echo -e "${RED}✗${NC} $container: ${STATUS:-not found}"
        ERRORS=$((ERRORS + 1))
    fi
done

echo ""
echo "[4/11] Checking Plex endpoint..."
curl -s http://localhost:32400/identity > /dev/null 2>&1
check_status "Plex responding on port 32400"

echo ""
echo "[5/11] Checking *arr stack endpoints..."
curl -s http://localhost:8989/sonarr/api/v3/health > /dev/null 2>&1
check_status "Sonarr responding on port 8989"

curl -s http://localhost:7878/radarr/api/v3/health > /dev/null 2>&1
check_status "Radarr responding on port 7878"

curl -s http://localhost:9696/prowlarr/api/v1/health > /dev/null 2>&1
check_status "Prowlarr responding on port 9696"

echo ""
echo "[6/11] Checking additional tools..."
curl -s http://localhost:5055/api/v1/status > /dev/null 2>&1
check_status "Overseerr responding on port 5055"

curl -s http://localhost:8181/status > /dev/null 2>&1
check_status "Tautulli responding on port 8181"

echo ""
echo "[7/11] Checking GPU support..."
if docker exec plex nvidia-smi > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} NVIDIA GPU accessible in Plex container"
    echo " GPU Info:"
    docker exec plex nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader | sed 's/^/ /'
    
    echo ""
    echo " Checking transcoding support..."
    if docker exec plex ls -la /dev/nvidia* 2>/dev/null | grep -q nvidia; then
        echo -e "${GREEN}✓${NC} NVIDIA devices accessible"
    else
        echo -e "${YELLOW}!${NC} NVIDIA devices not found in /dev/ (may still work via runtime)"
    fi
else
    echo -e "${YELLOW}!${NC} NVIDIA GPU not detected in Plex container"
    echo " This is normal if:"
    echo " - You don't have an NVIDIA GPU"
    echo " - Windows NVIDIA drivers need updating"
    echo " - Run 'wsl --update' in Windows PowerShell"
fi

echo ""
echo "[8/11] Checking volume mappings..."
for dir in /opt/plex-service/config/plex /opt/plex-service/config/sonarr /opt/plex-service/config/radarr /opt/plex-service/config/prowlarr /opt/plex-service/config/overseerr /opt/plex-service/config/tautulli; do
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓${NC} Directory exists: $dir"
    else
        echo -e "${RED}✗${NC} Directory missing: $dir"
        ERRORS=$((ERRORS + 1))
    fi
done

echo ""
echo "[9/11] Checking permissions..."
if [ "$(stat -c %u /opt/plex-service/config/plex)" = "1000" ]; then
    echo -e "${GREEN}✓${NC} Config directories owned by UID 1000"
else
    echo -e "${YELLOW}!${NC} Config directories not owned by UID 1000"
    echo " Fix with: sudo chown -R 1000:1000 /opt/plex-service/config/"
fi

# Check SELinux contexts if SELinux is enforcing
if [ "$SELINUX_STATUS" = "Enforcing" ]; then
    echo ""
    echo "[10/11] Checking SELinux contexts..."
    SELINUX_TYPE=$(ls -Zd /opt/plex-service/config/plex 2>/dev/null | awk '{print $1}')
    if echo "$SELINUX_TYPE" | grep -q "container_file_t"; then
        echo -e "${GREEN}✓${NC} SELinux contexts properly set for containers"
    else
        echo -e "${YELLOW}!${NC} SELinux contexts not set"
        echo " Current context: $SELINUX_TYPE"
    fi
else
    echo ""
    echo "[10/11] Skipping SELinux context check"
fi

echo ""
echo "[11/11] Checking disk space..."
DF_OUTPUT=$(df -h /opt/plex-service | awk 'NR==2 {print $4}')
echo " Available disk space: $DF_OUTPUT"

# Check for errors in logs
echo ""
echo "Checking logs for critical errors..."
ERROR_COUNT=$(docker-compose logs --no-color 2>&1 | grep -i "error\|fatal" | wc -l)
if [ "$ERROR_COUNT" -eq 0 ]; then
    echo -e "${GREEN}✓${NC} No critical errors found in recent logs"
else
    echo -e "${YELLOW}!${NC} Found $ERROR_COUNT error(s) in logs"
fi

echo ""
echo "=== Verification Complete ==="
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}All critical checks passed!${NC}"
    echo ""
    echo "Your services are available at:"
    echo "  - Plex:       http://localhost:32400/web"
    echo "  - Sonarr:     http://localhost:8989"
    echo "  - Radarr:     http://localhost:7878"
    echo "  - Prowlarr:   http://localhost:9696"
    echo "  - Overseerr:  http://localhost:5055"
    echo "  - Tautulli:   http://localhost:8181"
    exit 0
else
    echo -e "${RED}$ERRORS check(s) failed.${NC} Please review the output above."
    exit 1
fi
