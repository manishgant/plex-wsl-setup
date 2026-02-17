#!/bin/bash

# Plex Docker Setup Script for Fedora 43 on WSL2
# Run this from /opt/plex-service/

echo "=== Plex Docker Setup for Fedora 43 ==="
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Update system
echo "[1/7] Updating system packages..."
sudo dnf update -y

# 2. Install prerequisites
echo "[2/7] Installing prerequisites..."
sudo dnf install -y curl wget jq git ca-certificates gnupg

# 3. Check SELinux status
echo "[3/7] Checking SELinux status..."
SELINUX_STATUS=$(getenforce)
echo "SELinux is currently: $SELINUX_STATUS"
if [ "$SELINUX_STATUS" == "Enforcing" ]; then
    echo -e "${YELLOW}WARNING: SELinux is enforcing.${NC}"
    echo "The docker-compose.yml uses :Z flags for proper labeling."
    echo "If you experience permission issues, run: sudo setenforce 0"
fi

# 4. Install Docker
echo "[4/7] Checking Docker installation..."
if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing Docker CE..."
    
    sudo dnf -y install dnf-plugins-core
    sudo dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    sudo systemctl enable --now docker
    sudo usermod -aG docker $USER
    
    echo -e "${YELLOW}Docker installed. Please log out and back in, then re-run this script.${NC}"
    exit 0
else
    echo -e "${GREEN}Docker already installed${NC}"
    sudo systemctl start docker 2>/dev/null || true
fi

# 5. Install Docker Compose
echo "[5/7] Checking Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    echo "Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# 6. Setup NVIDIA Container Toolkit
echo "[6/7] Setting up NVIDIA Container Toolkit..."
if command -v nvidia-smi &> /dev/null; then
    echo "NVIDIA GPU detected"
    
    if ! rpm -qa | grep -q nvidia-docker2; then
        echo "Installing NVIDIA Container Toolkit..."
        
        distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
        curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | \
            sudo gpg --dearmor -o /usr/share/keyrings/nvidia-docker-archive-keyring.gpg
        curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.repo | \
            sudo tee /etc/yum.repos.d/nvidia-docker.repo > /dev/null
        
        sudo dnf clean all
        sudo dnf install -y nvidia-docker2
        
        sudo mkdir -p /etc/docker
        sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
    "runtimes": {
        "nvidia": {
            "path": "nvidia-container-runtime",
            "runtimeArgs": []
        }
    },
    "default-runtime": "nvidia"
}
EOF
        
        sudo systemctl restart docker
    fi
    
    echo "Testing GPU access..."
    if docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi > /dev/null 2>&1; then
        echo -e "${GREEN}✓ GPU accessible in Docker${NC}"
    else
        echo -e "${YELLOW}! GPU not accessible. Check Windows NVIDIA drivers.${NC}"
    fi
else
    echo -e "${YELLOW}No NVIDIA GPU detected. Skipping GPU setup.${NC}"
fi

# 7. Create directory structure
echo "[7/7] Creating directory structure..."

# Create config directories in /opt/plex-service
sudo mkdir -p /opt/plex-service/config/{plex,sonarr,radarr,prowlarr,overseerr,tautulli}
sudo mkdir -p /mnt/wsl/transcode

# Check if Windows media directory exists
if [ ! -d "/mnt/e/Plex" ]; then
    echo -e "${YELLOW}WARNING: /mnt/e/Plex not found${NC}"
    echo "Please ensure your E: drive is mounted and has a Plex folder"
    echo "Expected structure:"
    echo "  /mnt/e/Plex/"
    echo "    ├── TV/"
    echo "    ├── Movies/"
    echo "    ├── Music/"
    echo "    ├── Photos/"
    echo "    └── Downloads/"
fi

# Set permissions
sudo chown -R 1000:1000 /opt/plex-service/config
sudo chmod -R 755 /opt/plex-service/config

# Handle SELinux if enforcing
if [ "$SELINUX_STATUS" == "Enforcing" ]; then
    echo "Applying SELinux contexts..."
    sudo semanage fcontext -a -t container_file_t "/opt/plex-service/config(/.*)?" 2>/dev/null || true
    sudo restorecon -Rv /opt/plex-service/config/ 2>/dev/null || true
fi

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "Next steps:"
echo "1. Get your Plex claim token: https://www.plex.tv/claim/"
echo "2. Create .env file:"
echo "   echo 'PLEX_CLAIM_TOKEN=claim-your_token_here' > /opt/plex-service/.env"
echo "3. Start services:"
echo "   cd /opt/plex-service && docker-compose up -d"
echo "4. Verify: ./verify.sh"
echo ""
echo "Services will be available at:"
echo "  - Plex:       http://localhost:32400/web"
echo "  - Sonarr:     http://localhost:8989"
echo "  - Radarr:     http://localhost:7878"
echo "  - Prowlarr:   http://localhost:9696"
echo "  - Overseerr:  http://localhost:5055"
echo "  - Tautulli:   http://localhost:8181"
