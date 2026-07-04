# =============================================================================
#  Leitner Learning Platform - Admin Panel Launcher
#  Usage: .\scripts\start-admin.ps1
#  Starts the React admin panel and automatically connects to the backend API.
# =============================================================================

$ErrorActionPreference = "Stop"

# -- Paths & Ports -----------------------------------------------------------
$ROOT         = Split-Path $PSScriptRoot -Parent
$ADMIN_DIR    = "$ROOT\admin-panel"
$BACKEND_URL  = "http://localhost:5217/api/v1"

# -- Helper Functions ---------------------------------------------------------
function Write-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  +======================================================+" -ForegroundColor Cyan
    Write-Host "  |      Leitner Learning Platform - Admin Launcher      |" -ForegroundColor Cyan
    Write-Host "  +======================================================+" -ForegroundColor Cyan
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

# -- 1. Environment Verification ----------------------------------------------
Write-Header

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Err "Node.js (node) is not installed or not available in the system PATH."
    Write-Info "Please install Node.js v22 LTS from https://nodejs.org/ and restart your terminal."
    exit 1
}

# -- 2. Dependency Setup ------------------------------------------------------
if (-not (Test-Path "$ADMIN_DIR\node_modules")) {
    Write-Step "node_modules not found. Installing admin-panel dependencies..."
    Push-Location $ADMIN_DIR
    try {
        npm install
        Write-Ok "Dependencies installed successfully."
    } catch {
        Write-Err "npm install failed. Please navigate to the admin-panel directory and run 'npm install' manually."
        Pop-Location
        exit 1
    }
    Pop-Location
}

# -- 3. Start the Admin Panel Dev Server --------------------------------------
Write-Step "Launching Admin Panel dev server..."
Write-Info "API URL: $BACKEND_URL"

# Command sets the API base URL environment variable, navigates to directory, and starts Vite with the --open flag
$adminCmd = "Set-Location '$ADMIN_DIR'; `$env:VITE_API_BASE_URL='$BACKEND_URL'; npm run dev -- --open"

Start-Process powershell -ArgumentList "-NoExit", "-Command", $adminCmd `
              -WindowStyle Normal

Write-Ok "Admin Panel is starting in a new window and will open your default browser."
Write-Host ""
