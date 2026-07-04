# =============================================================================
#  Leitner Learning Platform - Ngrok Tunnel Launcher
#  Usage: .\scripts\start-tunnel.ps1
#  Starts a persistent Ngrok tunnel forwarding port 5217 to the public internet.
# =============================================================================

$ErrorActionPreference = "Stop"

# -- Helpers ------------------------------------------------------------------
function Write-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  +======================================================+" -ForegroundColor Cyan
    Write-Host "  |      Leitner Learning Platform  -  Tunnel Launcher  |`n  +======================================================+" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step([string]$msg) {
    Write-Host "  >> $msg" -ForegroundColor Yellow
}

function Write-Ok([string]$msg) {
    Write-Host "  [OK] $msg" -ForegroundColor Green
}

function Write-Err([string]$msg) {
    Write-Host "  [ERROR] $msg" -ForegroundColor Red
}

function Write-Info([string]$msg) {
    Write-Host "  [INFO] $msg" -ForegroundColor DarkCyan
}

# -- Logic --------------------------------------------------------------------
Write-Header

# 1. Verify ngrok command exists
if (-not (Get-Command ngrok -ErrorAction SilentlyContinue)) {
    Write-Err "'ngrok' command was not found in your system PATH."
    Write-Host "  Please download it from https://ngrok.com and add it to your PATH." -ForegroundColor Yellow
    exit 1
}

# 1.5. Ensure backend is running on port 5217
$ROOT         = Split-Path $PSScriptRoot -Parent
$BACKEND_PROJ = "$ROOT\backend\LeitnerPlatform.API\LeitnerPlatform.API.csproj"
$BACKEND_URL  = "http://localhost:5217"

$backendRunning = netstat -ano | Select-String ":5217\s.*LISTENING"
if (-not $backendRunning) {
    Write-Step "Starting .NET backend in a new window..."
    $backendArgs = "dotnet run --project `"$BACKEND_PROJ`" --urls `"$BACKEND_URL`""
    Start-Process powershell -ArgumentList "-NoExit", "-Command", $backendArgs -WindowStyle Normal
} else {
    Write-Info "Backend is already running on port 5217."
}

# 2. Check if ngrok is already running
$ngrokUrl = $null
try {
    $tunnels = Invoke-RestMethod -Uri "http://127.0.0.1:4040/api/tunnels" -TimeoutSec 2 -ErrorAction SilentlyContinue
    if ($tunnels.tunnels) {
        $ngrokUrl = $tunnels.tunnels[0].public_url
        Write-Info "Ngrok is already running."
    }
} catch {}

if ($null -eq $ngrokUrl) {
    Write-Step "Launching Ngrok tunnel on port 5217 in a new window..."
    
    # Launch in a new command window so user can monitor logs/close it manually
    Start-Process cmd -ArgumentList '/k "title Ngrok Tunnel - Leitner & ngrok http 5217"'
    
    Write-Step "Waiting for tunnel to establish..."
    $attempts = 0
    $maxAttempts = 6
    while ($attempts -lt $maxAttempts) {
        Start-Sleep -Seconds 2
        try {
            $tunnels = Invoke-RestMethod -Uri "http://127.0.0.1:4040/api/tunnels" -TimeoutSec 2
            if ($tunnels.tunnels) {
                $ngrokUrl = $tunnels.tunnels[0].public_url
                break
            }
        } catch {}
        $attempts++
    }
}

if ($ngrokUrl) {
    Write-Ok "Tunnel active!"
    Write-Host ""
    Write-Host "  Forwarding URL: $ngrokUrl" -ForegroundColor Green
    Write-Host "  Use this URL when compiling your APK using the build-apk script." -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Err "Could not establish the tunnel. Make sure your ngrok configuration is valid."
}
