# =============================================================================
#  Leitner Learning Platform - Android APK Builder (Fully Automated)
#  Usage: .\scripts\build-apk.ps1 -Flavor "premium"
# =============================================================================

param (
    [string]$Flavor = "premium",
    [string]$TargetUrl = "https://api.rightlearn.ir"
)

$ErrorActionPreference = "Stop"

# -- Paths --------------------------------------------------------------------
$ROOT         = Split-Path $PSScriptRoot -Parent
$MOBILE_DIR   = "$ROOT\mobile-app"
$OUTPUT_DIR   = "$ROOT"
$BACKEND_URL  = "http://localhost:5217"

# -- Helpers ------------------------------------------------------------------
function Write-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  +======================================================+" -ForegroundColor Cyan
    Write-Host "  |      Leitner Learning Platform  -  APK Builder       |" -ForegroundColor Cyan
    Write-Host "  +======================================================+" -ForegroundColor Cyan
    Write-Host ""
}

function Show-BuildProgress([string]$activity, [string]$status, [int]$percent) {
    Write-Progress -Activity "APK Build & Distribution Pipeline" -Status "[$percent%] ${activity}: $status" -PercentComplete $percent
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

function Send-RubikaFile {
    param (
        [string]$FilePath,
        [string]$BotToken = "CBGADB0AFGZDLMGWVNLANQKRQDWYEONKZZUGWWHCFZVZDUUFQYKAVHKZMABOOHXL"
    )

    if (-not (Test-Path $FilePath)) {
        Write-Err "File not found for Rubika upload: $FilePath"
        return
    }

    $fileName = Split-Path $FilePath -Leaf
    $fileLength = (Get-Item $FilePath).Length
    $mbSize = [math]::Round($fileLength / 1MB, 2)
    Write-Step "Uploading '$fileName' ($mbSize MB) to Rubika Bot (@AliDeveloperBot)..."
    Show-BuildProgress "Rubika Cloud Upload" "Transferring $fileName to bot..." 85

    $pythonScript = "$ROOT\scripts\upload-to-rubika.py"
    if (Test-Path $pythonScript) {
        $env:RUBIKA_BOT_TOKEN = $BotToken
        $env:UPLOAD_FILE_PATH = (Resolve-Path $FilePath).Path
        & python -u $pythonScript
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "Rubika delivery completed successfully!"
            return
        } else {
            Write-Err "Python upload script encountered an error (exit code $LASTEXITCODE)."
        }
    }
}

# -- Logic --------------------------------------------------------------------
Write-Header
Show-BuildProgress "Initializing" "Validating build parameters..." 5

# Validate flavor
if ($Flavor -ne "premium" -and $Flavor -ne "store") {
    Write-Err "Invalid flavor: '$Flavor'. Supported values are: 'premium', 'store'."
    exit 1
}

$apiBaseUrl = ""

if (-not [string]::IsNullOrWhiteSpace($TargetUrl)) {
    $apiBaseUrl = $TargetUrl.Trim()
    if (-not ($apiBaseUrl.StartsWith("http://") -or $apiBaseUrl.StartsWith("https://"))) {
        $apiBaseUrl = "http://$apiBaseUrl"
    }
    if ($apiBaseUrl.EndsWith("/")) {
        $apiBaseUrl = $apiBaseUrl.Substring(0, $apiBaseUrl.Length - 1)
    }
    if (-not $apiBaseUrl.EndsWith("/api/v1")) {
        $apiBaseUrl = "$apiBaseUrl/api/v1"
    }
    Write-Info "Targeting custom specified backend endpoint: $apiBaseUrl"
} else {
    Show-BuildProgress "Backend Verification" "Checking local server status on port 5217..." 10
    Write-Step "Checking if backend is running on port 5217..."
    $backendRunning = $false
    try {
        $r = Invoke-WebRequest -Uri "$BACKEND_URL/api/v1/config/features" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
        if ($r.StatusCode -lt 500) {
            $backendRunning = $true
            Write-Ok "Backend is online and responding at $BACKEND_URL"
        }
    } catch {
        Write-Host "  [WARNING] Backend was not detected on port 5217." -ForegroundColor Yellow
    }

    if (-not $backendRunning) {
        Write-Host "  Please ensure your backend is running before proceeding." -ForegroundColor Yellow
        $ans = Read-Host "  Do you want to continue anyway? (y/n)"
        if ($ans.Trim().ToLower() -ne "y") {
            Write-Host "  Build cancelled." -ForegroundColor Red
            exit 0
        }
    }

    Show-BuildProgress "Tunnel Resolution" "Checking Ngrok tunnel..." 15
    Write-Step "Checking if Ngrok is running..."
    $ngrokUrl = $null

    try {
        $tunnels = Invoke-RestMethod -Uri "http://127.0.0.1:4040/api/tunnels" -TimeoutSec 2 -ErrorAction SilentlyContinue
        if ($tunnels.tunnels) {
            $ngrokUrl = $tunnels.tunnels[0].public_url
            Write-Ok "Detected active Ngrok tunnel: $ngrokUrl"
        }
    } catch {}

    if ($null -eq $ngrokUrl) {
        if (-not (Get-Command ngrok -ErrorAction SilentlyContinue)) {
            Write-Err "'ngrok' was not found in your system PATH."
            Write-Host "  Please install ngrok or run it manually and pass the URL." -ForegroundColor Yellow
            $ngrokUrl = Read-Host "  Or manually enter your active Ngrok/dev URL (or press Enter for default dev local loopback)"
        } else {
            Write-Step "Starting Ngrok tunnel in background for port 5217..."
            Start-Process ngrok -ArgumentList "http 5217" -WindowStyle Hidden
            
            Write-Step "Waiting for Ngrok tunnel to establish..."
            $attempts = 0
            $maxAttempts = 6
            while ($attempts -lt $maxAttempts) {
                Start-Sleep -Seconds 2
                try {
                    $tunnels = Invoke-RestMethod -Uri "http://127.0.0.1:4040/api/tunnels" -TimeoutSec 2
                    if ($tunnels.tunnels) {
                        $ngrokUrl = $tunnels.tunnels[0].public_url
                        Write-Ok "Ngrok tunnel established successfully!"
                        break
                    }
                } catch {}
                $attempts++
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($ngrokUrl)) {
        $apiBaseUrl = "http://10.0.2.2:5217/api/v1"
        Write-Info "Using default Android emulator loopback: $apiBaseUrl"
    } else {
        $ngrokUrl = $ngrokUrl.Trim()
        if (-not ($ngrokUrl.StartsWith("http://") -or $ngrokUrl.StartsWith("https://"))) {
            $ngrokUrl = "https://$ngrokUrl"
        }
        if ($ngrokUrl.EndsWith("/")) {
            $ngrokUrl = $ngrokUrl.Substring(0, $ngrokUrl.Length - 1)
        }
        if (-not $ngrokUrl.EndsWith("/api/v1")) {
            $apiBaseUrl = "$ngrokUrl/api/v1"
        } else {
            $apiBaseUrl = $ngrokUrl
        }
        Write-Info "Targeting backend endpoint: $apiBaseUrl"
    }
}

Show-BuildProgress "Workspace Preparation" "Entering mobile app directory..." 20
Write-Step "Navigating to mobile application directory..."
Push-Location $MOBILE_DIR

try {
    Show-BuildProgress "Flutter Clean" "Cleaning temporary build files..." 25
    Write-Step "Running flutter clean..."
    flutter clean

    Show-BuildProgress "Flutter Dependencies" "Fetching packages (pub get)..." 35
    Write-Step "Fetching flutter packages..."
    flutter pub get
    if ($LASTEXITCODE -ne 0) {
        throw "flutter pub get failed with exit code $LASTEXITCODE"
    }

    Show-BuildProgress "Flutter Compilation" "Compiling release APK for flavor '$Flavor'..." 45
    Write-Step "Building release APK for flavor '$Flavor' with API_BASE_URL=$apiBaseUrl ..."
    flutter build apk --release --flavor $Flavor -t "lib/main_$Flavor.dart" --dart-define=API_BASE_URL=$apiBaseUrl
    if ($LASTEXITCODE -ne 0) {
        throw "flutter build apk failed with exit code $LASTEXITCODE"
    }

    $apkPath = "$MOBILE_DIR\build\app\outputs\flutter-apk\app-$Flavor-release.apk"
    $destPath = "$OUTPUT_DIR\app-$Flavor-release.apk"

    if (Test-Path $apkPath) {
        Show-BuildProgress "Packaging" "Copying APK to workspace root..." 70
        Write-Step "Copying generated APK to workspace root..."
        Copy-Item -Path $apkPath -Destination $destPath -Force

        $zipPath = "$OUTPUT_DIR\app-$Flavor-release.zip"
        Show-BuildProgress "Packaging" "Compressing $destPath into ZIP archive..." 75
        Write-Step "Compressing $destPath into $zipPath archive..."
        tar.exe -a -cf $zipPath -C $OUTPUT_DIR "app-$Flavor-release.apk"

        # Also maintain .rar copy for compatibility
        $rarPath = "$OUTPUT_DIR\app-$Flavor-release.rar"
        Copy-Item -Path $zipPath -Destination $rarPath -Force

        # Send to Rubika Bot
        Send-RubikaFile -FilePath $zipPath
        
        Show-BuildProgress "Reclaiming Space" "Cleaning up intermediate build cache..." 95
        Write-Step "Cleaning up intermediate build files to reclaim disk space..."
        Start-Sleep -Seconds 2
        try { flutter clean 2>$null } catch {}
        
        Show-BuildProgress "Complete" "All operations finished successfully!" 100
        Write-Ok "APK built and compressed successfully!"
        Write-Host ""
        Write-Host "  Output Locations:" -ForegroundColor Green
        Write-Host "    - Raw APK : $destPath" -ForegroundColor DarkCyan
        Write-Host "    - ZIP File: $zipPath" -ForegroundColor DarkCyan
        Write-Host ""
        Write-Host "  How to install on Android:" -ForegroundColor Cyan
        Write-Host "    1. Download '$([System.IO.Path]::GetFileName($zipPath))' from Rubika to your phone." -ForegroundColor Gray
        Write-Host "    2. Use your phone's File Manager to EXTRACT / UNZIP the file." -ForegroundColor Gray
        Write-Host "    3. Tap on the extracted '$([System.IO.Path]::GetFileName($destPath))' to install." -ForegroundColor Gray
        Write-Host ""
    } else {
        Write-Err "Could not locate the compiled APK at $apkPath."
    }
}
catch {
    Write-Err "Build failed: $_"
}
finally {
    Write-Progress -Activity "APK Build & Distribution Pipeline" -Completed
    Pop-Location
}
