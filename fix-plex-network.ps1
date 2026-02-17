# Plex WSL2 Network Fix Script
# Run this in Windows PowerShell as Administrator

Write-Host "=== Plex WSL2 Network Fix ===" -ForegroundColor Green

# 1. Check Windows Firewall for Plex port
Write-Host "`nChecking Windows Firewall..." -ForegroundColor Yellow
$plexRule = Get-NetFirewallRule -DisplayName "Plex Media Server" -ErrorAction SilentlyContinue
if (-not $plexRule) {
    Write-Host "Creating Plex firewall rule..." -ForegroundColor Cyan
    New-NetFirewallRule -DisplayName "Plex Media Server" -Direction Inbound -Protocol TCP -LocalPort 32400 -Action Allow -Profile Any
    New-NetFirewallRule -DisplayName "Plex Media Server UDP" -Direction Inbound -Protocol UDP -LocalPort 32400,32469,5353 -Action Allow -Profile Any
    Write-Host "Firewall rules created!" -ForegroundColor Green
} else {
    Write-Host "Plex firewall rule already exists" -ForegroundColor Green
}

# 2. Get WSL2 IP
Write-Host "`nChecking WSL2 IP configuration..." -ForegroundColor Yellow
$wslIp = (wsl hostname -I).Trim().Split()[0]
Write-Host "WSL2 IP: $wslIp" -ForegroundColor Cyan

# 3. Configure port proxy from Windows to WSL2 (0.0.0.0 catch-all for VPN compatibility)
Write-Host "`nConfiguring port proxy..." -ForegroundColor Yellow
$existingProxy = netsh interface portproxy show v4tov4 | Select-String "32400"
if (-not $existingProxy) {
    netsh interface portproxy add v4tov4 listenport=32400 listenaddress=0.0.0.0 connectport=32400 connectaddress=$wslIp
    Write-Host "Port proxy added: Windows 0.0.0.0:32400 -> WSL2 $wslIp`:32400" -ForegroundColor Green
} else {
    Write-Host "Port proxy already exists, updating..." -ForegroundColor Yellow
    netsh interface portproxy delete v4tov4 listenport=32400 listenaddress=0.0.0.0
    netsh interface portproxy add v4tov4 listenport=32400 listenaddress=0.0.0.0 connectport=32400 connectaddress=$wslIp
    Write-Host "Port proxy updated!" -ForegroundColor Green
}

# 4. Verify configuration
Write-Host "`n=== Verification ===" -ForegroundColor Green
Write-Host "Firewall rules:"
Get-NetFirewallRule -DisplayName "Plex*" | Select-Object DisplayName, Enabled, Direction | Format-Table

Write-Host "`nPort proxies:"
netsh interface portproxy show v4tov4 | Select-String "32400"

Write-Host "`n=== Done! ===" -ForegroundColor Green
Write-Host "Plex should now be accessible at:"
Write-Host "  - Local: http://localhost:32400" -ForegroundColor Cyan
Write-Host "  - Local Network: http://<YOUR_WINDOWS_IP>:32400" -ForegroundColor Cyan
Write-Host "  - With VPN: Works with any VPN IP (0.0.0.0 catch-all)" -ForegroundColor Yellow
Write-Host "`nRestart Plex if it's still showing indirect connections." -ForegroundColor Yellow
