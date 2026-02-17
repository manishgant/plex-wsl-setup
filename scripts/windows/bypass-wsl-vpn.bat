@echo off
REM Run as Administrator after Mullvad connects
REM Update WSL2_IP with your current WSL2 IP from: ip addr show eth0

for /f "tokens=2 delims= " %%a in ('wsl -e sh -c "hostname -I | awk '{print \$1}'"') do set WSL2_IP=%%a
echo WSL2 IP: %WSL2_IP%

if "%WSL2_IP%"=="" (
    echo Failed to get WSL2 IP
    exit /b 1
)

for /f "tokens=1 delims=." %%a in ("%WSL2_IP%") do set SUBNET=%%a
for /f "tokens=2 delims=." %%a in ("%WSL2_IP%") do set SUBNET=%SUBNET%.%%a

REM Get default gateway from active route
for /f "tokens=2" %%a in ('route print 0.0.0.0 ^| findstr "0.0.0.0" ^| findstr /v "127" ^| findstr /v "224"') do set GW=%%a
echo Gateway: %GW%

if "%GW%"=="" (
    echo Could not find gateway
    exit /b 1
)

echo Adding route for WSL2 subnet...
route add %SUBNET%.0 mask 255.255.240.0 %GW% metric 1 -p
echo Done!
