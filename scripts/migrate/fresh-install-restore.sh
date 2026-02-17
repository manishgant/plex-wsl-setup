#!/bin/bash
# Plex WSL2 Fresh Install & Restore Script
# Automates complete setup from backup after catastrophic failure
#
# Usage: ./fresh-install-restore.sh /path/to/backup
#
# Example:
#   ./fresh-install-restore.sh /mnt/e/Plex/Backups/full_20260217_023537

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="${INSTALL_DIR:-/opt/plex-service}"
GITHUB_REPO="${GITHUB_REPO:-https://github.com/manishgant/plex-wsl-setup.git}"

# Parse arguments
BACKUP_PATH="${1:-}"

if [ -z "$BACKUP_PATH" ]; then
    echo -e "${RED}Error: Backup path required${NC}"
    echo ""
    echo "Usage: $0 /path/to/backup"
    echo ""
    echo "Examples:"
    echo "  $0 /mnt/e/Plex/Backups/full_20260217_023537"
    echo "  $0 /media/external/plex-backup-20260217"
    echo "  BACKUP_PATH=/mnt/backup $0"
    exit 1
fi

if [ ! -d "$BACKUP_PATH" ]; then
    echo -e "${RED}Error: Backup directory not found: $BACKUP_PATH${NC}"
    exit 1
fi

if [ ! -f "$BACKUP_PATH/restore.sh" ]; then
    echo -e "${RED}Error: No restore.sh found in backup directory${NC}"
    echo "This doesn't appear to be a valid Plex backup"
    exit 1
fi

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}Plex WSL2 Fresh Install & Restore${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""
echo -e "Install Directory: ${GREEN}$INSTALL_DIR${NC}"
echo -e "Backup Location: ${GREEN}$BACKUP_PATH${NC}"
echo ""

read -p "Continue with fresh install? This will setup everything automatically! (yes/no): " confirm
if [[ $confirm != "yes" ]]; then
    echo "Installation cancelled."
    exit 0
fi

echo ""

# ============================================================================
# STEP 1: Check Prerequisites
# ============================================================================

echo -e "${YELLOW}[Step 1/8] Checking Prerequisites...${NC}"

# Check if running as root (shouldn't be)
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Error: Do not run as root. Run as regular user with sudo access.${NC}"
    exit 1
fi

# Check if sudo is available
if ! command -v sudo &> /dev/null; then
    echo -e "${RED}Error: sudo is required but not installed${NC}"
    exit 1
fi

# Check WSL
if [ ! -f /proc/sys/fs/binfmt_misc/WSLInterop ]; then
    echo -e "${YELLOW}Warning: This doesn't appear to be WSL2. Some features may not work.${NC}"
fi

# Check if install directory already exists
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}Warning: $INSTALL_DIR already exists${NC}"
    read -p "Remove existing directory and continue? (yes/no): " remove_confirm
    if [[ $remove_confirm == "yes" ]]; then
        sudo rm -rf "$INSTALL_DIR"
    else
        echo "Installation cancelled."
        exit 0
    fi
fi

echo -e "${GREEN}✓ Prerequisites check complete${NC}"
echo ""

# ============================================================================
# STEP 2: Install Dependencies
# ============================================================================

echo -e "${YELLOW}[Step 2/8] Installing Dependencies...${NC}"

# Update system
sudo dnf update -y

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    sudo dnf install -y docker docker-compose
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker $USER
    echo -e "${GREEN}✓ Docker installed${NC}"
else
    echo -e "${GREEN}✓ Docker already installed${NC}"
fi

# Install other useful tools
sudo dnf install -y curl wget htop nano vim git

echo -e "${GREEN}✓ Dependencies installed${NC}"
echo ""

# ============================================================================
# STEP 3: Create Directory Structure
# ============================================================================

echo -e "${YELLOW}[Step 3/8] Creating Directory Structure...${NC}"

sudo mkdir -p "$INSTALL_DIR"
sudo chown $USER:$USER "$INSTALL_DIR"

cd "$INSTALL_DIR"

# Create config directories
mkdir -p config/{plex,sonarr,radarr,prowlarr,overseerr,tautulli,flaresolverr}

echo -e "${GREEN}✓ Directory structure created${NC}"
echo ""

# ============================================================================
# STEP 4: Clone GitHub Template
# ============================================================================

echo -e "${YELLOW}[Step 4/8] Cloning GitHub Template...${NC}"

# Clone the repo
if git clone "$GITHUB_REPO" temp-clone; then
    # Move files from temp-clone to current directory
    cp -r temp-clone/* .
    cp -r temp-clone/.env.example .
    rm -rf temp-clone
    echo -e "${GREEN}✓ Template cloned from GitHub${NC}"
else
    echo -e "${YELLOW}⚠ Could not clone from GitHub, using local files...${NC}"
    echo "Please ensure docker-compose.yml and scripts are present"
fi

echo ""

# ============================================================================
# STEP 5: Restore from Backup
# ============================================================================

echo -e "${YELLOW}[Step 5/8] Restoring from Backup...${NC}"
echo -e "${BLUE}This may take a while for full backups...${NC}"
echo ""

# Run the restore script from the backup
cd "$INSTALL_DIR"
bash "$BACKUP_PATH/restore.sh"

echo -e "${GREEN}✓ Backup restored${NC}"
echo ""

# ============================================================================
# STEP 6: Setup Environment
# ============================================================================

echo -e "${YELLOW}[Step 6/8] Setting up Environment...${NC}"

# Copy .env.example to .env if not exists
if [ ! -f .env ] && [ -f .env.example ]; then
    cp .env.example .env
    echo -e "${YELLOW}⚠ Created .env from template. Please edit it to add your PLEX_CLAIM_TOKEN${NC}"
fi

# Check if .env has PLEX_CLAIM_TOKEN
if [ -f .env ]; then
    if ! grep -q "PLEX_CLAIM_TOKEN=" .env || grep -q "PLEX_CLAIM_TOKEN=claim-" .env; then
        echo ""
        echo -e "${YELLOW}⚠ No valid PLEX_CLAIM_TOKEN found in .env${NC}"
        echo "You'll need to:"
        echo "1. Get a claim token from https://www.plex.tv/claim/"
        echo "2. Edit $INSTALL_DIR/.env and set PLEX_CLAIM_TOKEN"
        echo ""
    fi
fi

echo -e "${GREEN}✓ Environment setup complete${NC}"
echo ""

# ============================================================================
# STEP 7: Windows Network Setup Instructions
# ============================================================================

echo -e "${YELLOW}[Step 7/8] Windows Network Setup Instructions${NC}"
echo ""

cat << 'INSTRUCTIONS'
============================================================================
IMPORTANT: Windows Setup Required
============================================================================

Please run these commands in Windows PowerShell as Administrator:

1. Get WSL IP and setup port proxy:
   $wslIp = (wsl hostname -I).Trim().Split()[0]
   netsh interface portproxy add v4tov4 listenport=32400 listenaddress=0.0.0.0 connectport=32400 connectaddress=$wslIp
   netsh interface portproxy add v4tov4 listenport=32469 listenaddress=0.0.0.0 connectport=32469 connectaddress=$wslIp

OR use the provided script:
   cd C:\path\to\plex-wsl-setup
   .\fix-plex-network.ps1

2. Configure Windows Firewall:
   New-NetFirewallRule -DisplayName "Plex Media Server" -Direction Inbound -Protocol TCP -LocalPort 32400,32469 -Action Allow -Profile Any
   New-NetFirewallRule -DisplayName "Plex Media Server UDP" -Direction Inbound -Protocol UDP -LocalPort 32400,32469,1900,5353 -Action Allow -Profile Any

3. Copy .wslconfig to your Windows user profile:
   From WSL: cp /opt/plex-service/.wslconfig /mnt/c/Users/YOUR_USERNAME/

============================================================================
INSTRUCTIONS

echo ""
read -p "Press Enter when you've completed Windows setup..."
echo ""

# ============================================================================
# STEP 8: Start Services
# ============================================================================

echo -e "${YELLOW}[Step 8/8] Starting Services...${NC}"
echo ""

# Start containers
docker compose up -d

echo ""
echo -e "${GREEN}✓ Containers started${NC}"
echo ""

# Wait for Plex to be ready
echo -e "${BLUE}Waiting for Plex to be ready...${NC}"
sleep 10

# Check if Plex is responding
for i in {1..30}; do
    if curl -s http://localhost:32400/identity > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Plex is responding!${NC}"
        break
    fi
    echo -n "."
    sleep 2
done

echo ""

# ============================================================================
# SUMMARY
# ============================================================================

echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}✓ FRESH INSTALL & RESTORE COMPLETE!${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""
echo "Your Plex server has been restored with all data and settings!"
echo ""
echo -e "${BLUE}Access your services:${NC}"
echo "  Plex:       http://localhost:32400/web"
echo "  Sonarr:     http://localhost:8989"
echo "  Radarr:     http://localhost:7878"
echo "  Prowlarr:   http://localhost:9696"
echo "  Overseerr:  http://localhost:5055"
echo "  Tautulli:   http://localhost:8181"
echo ""
echo -e "${BLUE}From Windows:${NC}"
echo "  Plex:       http://YOUR_WINDOWS_IP:32400/web"
echo ""
echo -e "${YELLOW}Important:${NC}"
if [ -f .env ] && grep -q "PLEX_CLAIM_TOKEN=" .env && ! grep -q "PLEX_CLAIM_TOKEN=claim-" .env; then
    echo "  ✓ Plex claim token is configured"
else
    echo "  ⚠ Don't forget to set your PLEX_CLAIM_TOKEN in $INSTALL_DIR/.env"
    echo "    Get one at: https://www.plex.tv/claim/"
fi
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Verify all services are running: docker compose ps"
echo "  2. Check Plex remote access in Settings → Remote Access"
echo "  3. Verify *arr apps can connect to Plex"
echo "  4. Set up automated backups: ./backup-config.sh full /mnt/e/Plex/Backups"
echo ""
echo -e "${GREEN}Your Plex server is ready to use!${NC}"
echo ""
