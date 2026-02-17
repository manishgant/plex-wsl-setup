#!/bin/bash
# WSL Plex Network Setup Script
# This script configures network settings for Plex on WSL
# It should be run from WSL

# Get current WSL IP
WSL_IP=$(ip addr show eth0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
WINDOWS_IP="YOUR_WINDOWS_IP"

echo "WSL IP: $WSL_IP"
echo "Windows IP: $WINDOWS_IP"

# Export for docker-compose
export ADVERTISE_IP="http://${WINDOWS_IP}:32400/"

# Output PowerShell commands for Windows setup
cat << EOF > /tmp/setup-plex-network.ps1
# Run this in PowerShell as Administrator
# Plex Port Forwarding Setup

# Remove existing rules (including 0.0.0.0 catch-all)
netsh interface portproxy delete v4tov4 listenport=32400 listenaddress=0.0.0.0 2>\$null
netsh interface portproxy delete v4tov4 listenport=32469 listenaddress=0.0.0.0 2>\$null
netsh interface portproxy delete v4tov4 listenport=32400 listenaddress=$WINDOWS_IP 2>\$null
netsh interface portproxy delete v4tov4 listenport=32469 listenaddress=$WINDOWS_IP 2>\$null

# Add 0.0.0.0 catch-all port forwarding (works with VPN and dynamic IPs)
netsh interface portproxy add v4tov4 listenport=32400 listenaddress=0.0.0.0 connectport=32400 connectaddress=$WSL_IP
netsh interface portproxy add v4tov4 listenport=32469 listenaddress=0.0.0.0 connectport=32469 connectaddress=$WSL_IP

# Also add specific IP if provided (for backward compatibility)
if ("$WINDOWS_IP" -ne "YOUR_WINDOWS_IP") {
    netsh interface portproxy add v4tov4 listenport=32400 listenaddress=$WINDOWS_IP connectport=32400 connectaddress=$WSL_IP
    netsh interface portproxy add v4tov4 listenport=32469 listenaddress=$WINDOWS_IP connectport=32469 connectaddress=$WSL_IP
}

# Show current rules
Write-Host "Current port forwarding rules:" -ForegroundColor Green
netsh interface portproxy show all

# Ensure Windows Firewall allows Plex
New-NetFirewallRule -DisplayName "Plex Media Server" -Direction Inbound -Protocol TCP -LocalPort 32400,32469 -Action Allow -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "Plex Media Server UDP" -Direction Inbound -Protocol UDP -LocalPort 32400,32469,1900,5353 -Action Allow -ErrorAction SilentlyContinue

Write-Host "Port forwarding configured successfully!" -ForegroundColor Green
Write-Host "Plex should be accessible at: http://$WINDOWS_IP:32400" -ForegroundColor Cyan
EOF

echo ""
echo "PowerShell script created at: /tmp/setup-plex-network.ps1"
echo "Copy this to Windows and run as Administrator:"
echo "  cp /tmp/setup-plex-network.ps1 /mnt/c/temp/"
echo "  # Then in Windows PowerShell (Admin):"
echo "  C:\temp\setup-plex-network.ps1"
