#!/bin/bash
# Plex WSL Startup Script
# Run this script every time WSL starts to ensure network is configured
# Add to .bashrc or .zshrc: source /opt/plex-service/scripts/plex-wsl-startup.sh

# Get current WSL IP
WSL_IP=$(ip addr show eth0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)
WINDOWS_IP="YOUR_WINDOWS_IP"
WIN_USER="${WINDOWS_USER:-$(whoami)}"

if [ -z "$WSL_IP" ]; then
    echo "[Plex-WSL] Error: Could not detect WSL IP address"
    return 1
fi

echo "[Plex-WSL] Current WSL IP: $WSL_IP"
echo "[Plex-WSL] Windows IP: $WINDOWS_IP"

# Create PowerShell script with current IP
PS_SCRIPT_PATH="/mnt/c/Users/${WIN_USER}/Documents/setup-plex-wsl.ps1"

cat > "$PS_SCRIPT_PATH" << EOF
# Plex WSL Network Bridge - Auto Setup
# Generated on $(date)
# WSL IP: $WSL_IP
# Windows IP: $WINDOWS_IP

param(
    [string]\$WslIp = "$WSL_IP",
    [string]\$WindowsIp = "$WINDOWS_IP"
)

Write-Host "Setting up Plex WSL Network Bridge..." -ForegroundColor Cyan
Write-Host "WSL IP: \$WslIp" -ForegroundColor Yellow
Write-Host "Windows IP: \$WindowsIp" -ForegroundColor Yellow

# Function to test if running as admin
function Test-Admin {
    \$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return \$currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Error "Please run this script as Administrator!"
    exit 1
}

# Reset port proxy
Write-Host "Resetting port proxy rules..." -ForegroundColor Yellow
netsh interface portproxy reset

# Add port forwarding rules
Write-Host "Adding port forwarding rules..." -ForegroundColor Yellow
netsh interface portproxy add v4tov4 listenport=32400 listenaddress=\$WindowsIp connectport=32400 connectaddress=\$WslIp
netsh interface portproxy add v4tov4 listenport=32469 listenaddress=\$WindowsIp connectport=32469 connectaddress=\$WslIp
netsh interface portproxy add v4tov4 listenport=32400 listenaddress=0.0.0.0 connectport=32400 connectaddress=\$WslIp
netsh interface portproxy add v4tov4 listenport=32469 listenaddress=0.0.0.0 connectport=32469 connectaddress=\$WslIp

Write-Host "\`nCurrent port forwarding rules:" -ForegroundColor Green
netsh interface portproxy show all

# Configure Windows Firewall
Write-Host "\`nConfiguring Windows Firewall..." -ForegroundColor Yellow
Remove-NetFirewallRule -DisplayName "Plex WSL*" -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "Plex WSL TCP" -Direction Inbound -Protocol TCP -LocalPort 32400,32469 -Action Allow -Profile Any | Out-Null
New-NetFirewallRule -DisplayName "Plex WSL UDP" -Direction Inbound -Protocol UDP -LocalPort 32400,32469,1900,5353,32410,32412,32413,32414 -Action Allow -Profile Any | Out-Null

Write-Host "\`nFirewall rules configured!" -ForegroundColor Green

# Test connection
Write-Host "\`nTesting connection to Plex..." -ForegroundColor Cyan
try {
    \$response = Invoke-WebRequest -Uri "http://localhost:32400/identity" -TimeoutSec 5 -ErrorAction Stop
    Write-Host "SUCCESS! Plex is accessible on localhost:32400" -ForegroundColor Green
} catch {
    Write-Warning "Could not connect to Plex on localhost. Make sure Plex container is running."
}

try {
    \$response = Invoke-WebRequest -Uri "http://\${WindowsIp}:32400/identity" -TimeoutSec 5 -ErrorAction Stop
    Write-Host "SUCCESS! Plex is accessible on \${WindowsIp}:32400" -ForegroundColor Green
} catch {
    Write-Warning "Could not connect to Plex on \${WindowsIp}. Check if the IP is correct."
}

Write-Host "\`n========================================" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "Plex URL: http://\${WindowsIp}:32400/web" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
EOF

echo "[Plex-WSL] PowerShell script updated at: C:\Users\${WIN_USER}\Documents\setup-plex-wsl.ps1"
echo "[Plex-WSL] To complete setup, run in PowerShell (Admin):"
echo "[Plex-WSL]   powershell -ExecutionPolicy Bypass -File \"C:\Users\${WIN_USER}\Documents\setup-plex-wsl.ps1\""
