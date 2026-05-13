# Auto-detects the current LAN IP, updates assets/config.json, then starts the backend.
$ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "*Wi-Fi*", "*Ethernet*", "*LAN*" `
    | Where-Object { $_.IPAddress -notlike "169.*" -and $_.IPAddress -ne "127.0.0.1" } `
    | Select-Object -First 1).IPAddress

if (-not $ip) {
    Write-Error "Could not detect LAN IP. Connect to Wi-Fi or Ethernet first."
    exit 1
}

$configPath = "$PSScriptRoot\assets\config.json"
$config = @{ API_BASE_URL = "http://${ip}:3000/api" } | ConvertTo-Json
Set-Content -Path $configPath -Value $config -Encoding utf8

Write-Host "IP detected: $ip"
Write-Host "Updated assets/config.json -> http://${ip}:3000/api"
Write-Host ""
Write-Host "Rebuild the app for the new URL to take effect (flutter build / flutter run)."
Write-Host "Starting backend on port 3000..."

Set-Location "$PSScriptRoot\backend"
node server.js
