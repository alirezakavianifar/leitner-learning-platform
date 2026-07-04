# =============================================================================
#  Leitner Learning Platform - Dev Launcher
#  Usage: .\scripts\start-dev.ps1
#  Starts the .NET backend and the Flutter frontend on your chosen target.
# =============================================================================

$ErrorActionPreference = "Stop"

# -- Paths --------------------------------------------------------------------
$ROOT         = Split-Path $PSScriptRoot -Parent
$BACKEND_PROJ = "$ROOT\backend\LeitnerPlatform.API\LeitnerPlatform.API.csproj"
$MOBILE_DIR   = "$ROOT\mobile-app"
$BACKEND_URL  = "http://localhost:5217"

# -- Helpers ------------------------------------------------------------------
function Write-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  +======================================================+" -ForegroundColor Cyan
    Write-Host "  |      Leitner Learning Platform  -  Dev Launcher      |" -ForegroundColor Cyan
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

function Wait-ForBackend {
    param([int]$TimeoutSec = 60)
    Write-Step "Waiting for backend to be ready on $BACKEND_URL ..."
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        try {
            $r = Invoke-WebRequest -Uri "$BACKEND_URL/api/v1/config/features" `
                                   -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
            if ($r.StatusCode -lt 500) { return $true }
        } catch { }
        Start-Sleep -Milliseconds 800
    }
    return $false
}

# -- 1. Kill any stale backend on port 5217 -----------------------------------
Write-Header
Write-Step "Checking for existing process on port 5217 ..."
$stale = netstat -ano |
         Select-String ":5217\s.*LISTENING" |
         ForEach-Object { ($_ -split "\s+")[-1] } |
         Select-Object -First 1

if ($stale) {
    Write-Info "Killing stale process PID $stale on port 5217 ..."
    Stop-Process -Id ([int]$stale) -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}
Write-Ok "Port 5217 is free."

# -- 2. Start the .NET backend in a new terminal window -----------------------
Write-Step "Starting .NET backend ..."
$backendArgs = "dotnet run --project `"$BACKEND_PROJ`" --urls `"$BACKEND_URL`""
Start-Process powershell -ArgumentList "-NoExit", "-Command", $backendArgs `
              -WindowStyle Normal

# Wait until the backend is actually responding
$ready = Wait-ForBackend -TimeoutSec 60
if ($ready) {
    Write-Ok "Backend is up and responding at $BACKEND_URL"
} else {
    Write-Err "Backend did not become ready within 60s. Check the backend window for errors."
    Write-Host ""
    $cont = Read-Host "  Continue anyway and launch the frontend? [y/N]"
    if ($cont -ne 'y' -and $cont -ne 'Y') { exit 1 }
}

Write-Host ""

# -- 3. Detect available Flutter devices --------------------------------------
Write-Step "Detecting Flutter devices ..."
$deviceOutput = & flutter devices 2>&1 | Out-String

$hasWindows = $deviceOutput -match "windows"
$hasChrome  = $deviceOutput -match "chrome"
$hasAndroid = $deviceOutput -match "emulator|android"
$hasIOS     = $deviceOutput -match "iPhone|iPad|iOS"

# -- 4. Show menu -------------------------------------------------------------
Write-Host ""
Write-Host "  +---------------------------------------------+" -ForegroundColor Magenta
Write-Host "  |        Choose a Flutter target               |" -ForegroundColor Magenta
Write-Host "  +---------------------------------------------+" -ForegroundColor Magenta
Write-Host ""

$menuItems = @(
    @{ Key="W"; Label="Windows desktop app";       Check=$hasWindows },
    @{ Key="C"; Label="Chrome (web)";              Check=$hasChrome  },
    @{ Key="A"; Label="Android device/emulator";   Check=$hasAndroid },
    @{ Key="I"; Label="iOS device/simulator";      Check=$hasIOS     }
)

foreach ($item in $menuItems) {
    if ($item.Check) {
        Write-Host "    [$($item.Key)]  $($item.Label)" -ForegroundColor White
    } else {
        Write-Host "    [$($item.Key)]  $($item.Label)  (not detected)" -ForegroundColor DarkGray
    }
}

Write-Host "    [Q]  Quit (backend stays running)" -ForegroundColor DarkGray
Write-Host ""

# -- 5. Read user choice ------------------------------------------------------
$deviceFlag = $null
while ($null -eq $deviceFlag) {
    $raw = (Read-Host "  Your choice").Trim().ToUpper()

    switch ($raw) {

        "Q" {
            Write-Info "Exiting launcher. Backend is still running in its window."
            exit 0
        }

        "W" {
            if (-not $hasWindows) {
                Write-Err "Windows device not detected."
                Write-Info "Enable with:  flutter config --enable-windows-desktop"
            } else {
                $deviceFlag = "-d windows"
            }
        }

        "C" {
            if (-not $hasChrome) {
                Write-Err "Chrome not detected. Make sure Google Chrome is installed."
            } else {
                $deviceFlag = "-d chrome"
            }
        }

        "A" {
            if (-not $hasAndroid) {
                Write-Err "No Android device/emulator connected."
                Write-Info "Start an Android emulator via Android Studio, then re-run this script."
            } else {
                $androidLine = & flutter devices 2>&1 |
                               Select-String "android|emulator" |
                               Select-Object -First 1
                if ($androidLine) {
                    $parts = $androidLine -split "$([char]0x2022)"
                    if ($parts.Count -gt 1) {
                        $deviceFlag = "-d $($parts[1].Trim())"
                    } else {
                        $deviceFlag = ""
                    }
                } else {
                    $deviceFlag = ""
                }
            }
        }

        "I" {
            if (-not $hasIOS) {
                Write-Err "No iOS device/simulator connected."
            } else {
                $iosLine = & flutter devices 2>&1 |
                           Select-String "iPhone|iPad|iOS" |
                           Select-Object -First 1
                if ($iosLine) {
                    $parts = $iosLine -split "$([char]0x2022)"
                    if ($parts.Count -gt 1) {
                        $deviceFlag = "-d $($parts[1].Trim())"
                    } else {
                        $deviceFlag = ""
                    }
                } else {
                    $deviceFlag = ""
                }
            }
        }

        default {
            Write-Err "Invalid choice. Type W, C, A, I, or Q."
        }
    }
}

# -- 6. Launch Flutter in a new terminal window -------------------------------
Write-Host ""
Write-Step "Launching Flutter ($deviceFlag) ..."

$flutterCmd = "Set-Location '$MOBILE_DIR'; flutter run $deviceFlag"
Start-Process powershell -ArgumentList "-NoExit", "-Command", $flutterCmd `
              -WindowStyle Normal

Write-Host ""
Write-Ok "Flutter is starting in a new window."
Write-Ok "Backend : $BACKEND_URL"
Write-Host ""
Write-Host "  +---------------------------------------------------+" -ForegroundColor DarkGreen
Write-Host "  |   Both services are running. Happy coding!        |" -ForegroundColor DarkGreen
Write-Host "  +---------------------------------------------------+" -ForegroundColor DarkGreen
Write-Host ""
