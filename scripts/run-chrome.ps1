# =============================================================================
#  Leitner Learning Platform - Run Mobile App in Chrome (Flutter Web)
#  Usage: .\scripts\run-chrome.ps1 [-TargetUrl "http://45.94.215.188"] [-Flavor "premium"]
# =============================================================================

param (
    [string]$Flavor = "premium",
    [string]$TargetUrl = "http://45.94.215.188",
    [string]$Device = "chrome"
)

$ErrorActionPreference = "Stop"

$ROOT       = Split-Path $PSScriptRoot -Parent
$MOBILE_DIR = "$ROOT\mobile-app"

Write-Host ""
Write-Host "  +======================================================+" -ForegroundColor Cyan
Write-Host "  |    Leitner Learning Platform - Run Web App ($Device)  |" -ForegroundColor Cyan
Write-Host "  +======================================================+" -ForegroundColor Cyan
Write-Host ""

$apiBaseUrl = $TargetUrl.Trim()
if (-not ($apiBaseUrl.StartsWith("http://") -or $apiBaseUrl.StartsWith("https://"))) {
    $apiBaseUrl = "http://$apiBaseUrl"
}
if (-not $apiBaseUrl.EndsWith("/api/v1")) {
    $apiBaseUrl = "$apiBaseUrl/api/v1"
}

Write-Host "  [INFO] Target API Base URL: $apiBaseUrl" -ForegroundColor DarkCyan
Write-Host "  >> Navigating to mobile-app directory..." -ForegroundColor Yellow

Push-Location $MOBILE_DIR

try {
    Write-Host "  >> Fetching Flutter dependencies..." -ForegroundColor Yellow
    flutter pub get

    Write-Host "  >> Launching Flutter Web on '$Device' (Flavor: $Flavor)..." -ForegroundColor Green
    Write-Host ""
    if ($Device -eq "web-server") {
        Start-Process "http://localhost:8080"
        flutter run -d web-server --web-port 8080 --flavor $Flavor -t "lib/main_$Flavor.dart" --dart-define=API_BASE_URL=$apiBaseUrl
    } else {
        flutter run -d $Device --flavor $Flavor -t "lib/main_$Flavor.dart" --dart-define=API_BASE_URL=$apiBaseUrl
    }
}
catch {
    Write-Host "  [ERROR] Failed to run web app on ${Device}: $_" -ForegroundColor Red
    Write-Host "  [TIP] If Chrome crashes with out-of-memory error, try running with web-server:" -ForegroundColor Yellow
    Write-Host "        .\scripts\run-chrome.ps1 -Device web-server" -ForegroundColor Yellow
}
finally {
    Pop-Location
}
