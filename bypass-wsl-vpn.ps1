# Run as Administrator after Mullvad VPN connects
# Requires running as Admin

param(
    [switch]$Remove
)

$ErrorActionPreference = "Stop"

# Get WSL2 IP using Windows network adapter
$wslAdapter = Get-NetAdapter | Where-Object { $_.InterfaceDescription -match "WSL" -or $_.Name -match "WSL" }
if (-not $wslAdapter) {
    Write-Error "WSL2 network adapter not found"
    exit 1
}
$wslIP = (Get-NetIPAddress -InterfaceIndex $wslAdapter.ifIndex -AddressFamily IPv4).IPAddress
$cidr = (Get-NetIPAddress -InterfaceIndex $wslAdapter.ifIndex -AddressFamily IPv4).PrefixLength
Write-Host "WSL2 IP: $wslIP/$cidr"

# Extract subnet
$ipParts = $wslIP -split '\.'
$subnet = "$($ipParts[0]).$($ipParts[1]).$($ipParts[2]).0"

# Get default gateway from ACTUAL physical adapter (not VPN)
$physicalAdapter = Get-NetAdapter | Where-Object { 
    $_.Status -eq "Up" -and 
    $_.InterfaceDescription -notmatch "VPN|Mullvad|TAP|TUN|Virtual" -and
    $_.Name -notmatch "VPN|Mullvad|vEthernet|WSL"
} | Select-Object -First 1

if (-not $physicalAdapter) {
    Write-Error "Could not find physical network adapter"
    exit 1
}

$gateway = (Get-NetRoute -InterfaceIndex $physicalAdapter.ifIndex -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | 
    Select-Object -First 1).NextHop

if (-not $gateway) {
    Write-Error "Could not determine gateway from physical adapter"
    exit 1
}
Write-Host "Physical adapter: $($physicalAdapter.Name) (IF index: $($physicalAdapter.ifIndex))"
Write-Host "Gateway: $gateway"

# Calculate subnet mask from CIDR
$prefix = $cidr
$binaryString = ("1" * $prefix).PadRight(32, "0")
$maskBytes = [System.Collections.Generic.List[byte]]::new()
for ($i = 0; $i -lt 32; $i += 8) {
    $byteStr = $binaryString.Substring($i, 8)
    [void]$maskBytes.Add([Convert]::ToByte($byteStr, 2))
}
$maskStr = ($maskBytes | ForEach-Object { $_ }) -join "."
Write-Host "Subnet mask: $maskStr"

if ($Remove) {
    Write-Host "Removing route..."
    route delete $subnet mask $maskStr 2>$null
    Write-Host "Route removed."
} else {
    # Remove existing route first
    route delete $subnet mask $maskStr 2>$null | Out-Null
    
    # Add route with interface specified
    Write-Host "Adding route: $subnet mask $maskStr via $gateway interface $($physicalAdapter.ifIndex)"
    route add $subnet mask $maskStr $gateway if $physicalAdapter.ifIndex -p
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Route added successfully!" -ForegroundColor Green
    } else {
        Write-Error "Failed to add route"
        exit 1
    }
}
