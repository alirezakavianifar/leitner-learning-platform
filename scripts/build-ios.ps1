# =============================================================================
#  Leitner Learning Platform - iOS IPA & Simulator Builder (Fully Automated)
#  Usage: .\scripts\build-ios.ps1 -Flavor "premium" -BuildType "both"
# =============================================================================

param (
    [string]$Flavor = "premium",
    [string]$TargetUrl = "https://api.rightlearn.ir",
    [ValidateSet("ipa", "simulator", "both")]
    [string]$BuildType = "both",
    [switch]$SkipRubika,
    [switch]$SkipAppetize,
    [switch]$ForceLocal
)

$ErrorActionPreference = "Stop"

# -- Paths --------------------------------------------------------------------
$ROOT         = Split-Path $PSScriptRoot -Parent
$MOBILE_DIR   = "$ROOT\mobile-app"
$OUTPUT_DIR   = "$ROOT"
$BACKEND_URL  = "http://localhost:5217"
$ENV_PATH     = "$ROOT\.env"

# -- Helpers ------------------------------------------------------------------
function Write-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  +======================================================+" -ForegroundColor Cyan
    Write-Host "  |      Leitner Learning Platform  -  iOS Builder       |" -ForegroundColor Cyan
    Write-Host "  +======================================================+" -ForegroundColor Cyan
    Write-Host ""
}

function Show-BuildProgress([string]$activity, [string]$status, [int]$percent) {
    Write-Progress -Activity "iOS Build & Distribution Pipeline" -Status "[$percent%] ${activity}: $status" -PercentComplete $percent
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
    Write-Step "Uploading iOS package '$fileName' ($mbSize MB) to Rubika Bot (@AliDeveloperBot)..."
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

function Deploy-AppetizeSimulator {
    param (
        [string]$SimulatorZipPath
    )

    if (-not (Test-Path $SimulatorZipPath)) {
        return
    }

    $appetizeToken = $null
    if (Test-Path $ENV_PATH) {
        Get-Content $ENV_PATH | ForEach-Object {
            $line = $_.Trim()
            if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
                $k, $v = $line.Split("=", 2)
                if ($k.Trim() -eq "APPETIZE_API_TOKEN") { $appetizeToken = $v.Trim() }
            }
        }
    }

    if (-not $appetizeToken) {
        Write-Info "Appetize API token not configured in .env (skipping direct API upload)."
        return
    }

    Write-Step "Uploading iOS Simulator package to Appetize.io for browser streaming..."
    Show-BuildProgress "Appetize Cloud Upload" "Uploading iOS simulator build to Appetize.io..." 90

    $curlCmd = "curl.exe"
    $curlArgs = @(
        "-s",
        "-X", "POST",
        "https://api.appetize.io/v1/apps",
        "-H", "X-API-KEY: $appetizeToken",
        "-F", "file=@$SimulatorZipPath",
        "-F", "platform=ios"
    )

    try {
        $resJson = & $curlCmd $curlArgs
        $res = $resJson | ConvertFrom-Json
        if ($res -and $res.publicKey) {
            Write-Ok "Appetize.io iOS build live: https://appetize.io/app/$($res.publicKey)"
        }
    } catch {
        Write-Err "Failed to deploy to Appetize: $_"
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

# Normalize and validate backend target URL
$apiBaseUrl = ""
if (-not [string]::IsNullOrWhiteSpace($TargetUrl)) {
    $apiBaseUrl = $TargetUrl.Trim()
    if (-not ($apiBaseUrl.StartsWith("http://") -or $apiBaseUrl.StartsWith("https://"))) {
        $apiBaseUrl = "https://$apiBaseUrl"
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
        $apiBaseUrl = "https://api.rightlearn.ir/api/v1"
        Write-Info "Using standard production API endpoint: $apiBaseUrl"
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

# Determine OS environment
$isMacOS = $false
if ($PSVersionTable.PSVersion.Major -ge 6) {
    $isMacOS = $IsMacOS
} else {
    $isMacOS = [System.Environment]::OSVersion.Platform -eq 'Unix'
}

# File outputs
$ipaOut         = "$OUTPUT_DIR\app-$Flavor-release.ipa"
$ipaZip         = "$OUTPUT_DIR\app-$Flavor-ios-release.zip"
$ipaRar         = "$OUTPUT_DIR\app-$Flavor-ios-release.rar"
$simulatorZip   = "$OUTPUT_DIR\app-$Flavor-ios-simulator.zip"

if ($isMacOS -or $ForceLocal) {
    # -------------------------------------------------------------------------
    # Native macOS Execution Flow
    # -------------------------------------------------------------------------
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

        # Check CocoaPods
        if (Test-Path "$MOBILE_DIR\ios") {
            Show-BuildProgress "CocoaPods" "Installing iOS pods..." 40
            Write-Step "Installing CocoaPods dependencies..."
            Push-Location "$MOBILE_DIR\ios"
            try {
                if (Get-Command pod -ErrorAction SilentlyContinue) {
                    pod install --repo-update
                }
            } catch {
                Write-Host "  [WARNING] pod install had warnings/errors, continuing build..." -ForegroundColor Yellow
            } finally {
                Pop-Location
            }
        }

        # 1. Build Simulator (if requested)
        if ($BuildType -eq "simulator" -or $BuildType -eq "both") {
            Show-BuildProgress "iOS Compilation" "Compiling iOS Simulator bundle for flavor '$Flavor'..." 50
            Write-Step "Building iOS Simulator release with API_BASE_URL=$apiBaseUrl ..."
            flutter build ios --simulator --release -t "lib/main_$Flavor.dart" --dart-define=API_BASE_URL=$apiBaseUrl
            
            $simAppPath = "$MOBILE_DIR\build\ios\iphonesimulator\Runner.app"
            if (Test-Path $simAppPath) {
                Show-BuildProgress "Packaging" "Compressing Simulator bundle to $simulatorZip..." 65
                Write-Step "Archiving iOS Simulator bundle for Appetize / Simulators..."
                tar.exe -a -cf $simulatorZip -C "$MOBILE_DIR\build\ios\iphonesimulator" "Runner.app"
                Write-Ok "iOS Simulator package ready: $simulatorZip"
            }
        }

        # 2. Build Physical IPA (if requested)
        if ($BuildType -eq "ipa" -or $BuildType -eq "both") {
            Show-BuildProgress "iOS Compilation" "Compiling iOS Release bundle for flavor '$Flavor'..." 70
            Write-Step "Building iOS release bundle with API_BASE_URL=$apiBaseUrl ..."
            flutter build ios --release --no-codesign -t "lib/main_$Flavor.dart" --dart-define=API_BASE_URL=$apiBaseUrl
            
            $runnerAppPath = "$MOBILE_DIR\build\ios\iphoneos\Runner.app"
            if (Test-Path $runnerAppPath) {
                Show-BuildProgress "Packaging" "Creating IPA Payload structure..." 80
                Write-Step "Assembling unsigned IPA package..."
                $payloadDir = "$MOBILE_DIR\build\ios\iphoneos\Payload"
                if (Test-Path $payloadDir) { Remove-Item $payloadDir -Recurse -Force }
                New-Item -ItemType Directory -Path $payloadDir | Out-Null
                Copy-Item -Path $runnerAppPath -Destination "$payloadDir\Runner.app" -Recurse -Force

                # Zip Payload into .ipa
                tar.exe -a -cf $ipaOut -C "$MOBILE_DIR\build\ios\iphoneos" "Payload"
                tar.exe -a -cf $ipaZip -C $OUTPUT_DIR "app-$Flavor-release.ipa"
                Copy-Item -Path $ipaZip -Destination $ipaRar -Force
                Write-Ok "iOS IPA package ready: $ipaOut"
            }
        }

        # Distribution steps
        if (-not $SkipRubika) {
            if (Test-Path $ipaZip) {
                Send-RubikaFile -FilePath $ipaZip
            } elseif (Test-Path $simulatorZip) {
                Send-RubikaFile -FilePath $simulatorZip
            }
        }

        if (-not $SkipAppetize -and (Test-Path $simulatorZip)) {
            Deploy-AppetizeSimulator -SimulatorZipPath $simulatorZip
        }

        Show-BuildProgress "Reclaiming Space" "Cleaning up intermediate build cache..." 95
        Write-Step "Cleaning up intermediate build files to reclaim disk space..."
        Start-Sleep -Seconds 2
        try { flutter clean 2>$null } catch {}

        Show-BuildProgress "Complete" "All operations finished successfully!" 100
        Write-Ok "iOS build completed successfully!"
    }
    catch {
        Write-Err "Build failed: $_"
    }
    finally {
        Show-BuildProgress "Done" "Finished pipeline" 100
        Write-Progress -Activity "iOS Build & Distribution Pipeline" -Completed
        Pop-Location
    }
} else {
    # -------------------------------------------------------------------------
    # Windows Host Execution Flow
    # -------------------------------------------------------------------------
    Show-BuildProgress "Environment Check" "Analyzing build host capabilities..." 30
    Write-Host ""
    Write-Host "  [NOTICE] You are running on Windows." -ForegroundColor Cyan
    Write-Host "           Apple Xcode toolchains require macOS to compile iOS native binaries." -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Available Automation Solutions for Windows Developers:" -ForegroundColor Yellow
    Write-Host "  =======================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  1. Automated Cloud Build (GitHub Actions macOS Runner) [RECOMMENDED]" -ForegroundColor Green
    Write-Host "     - A dedicated GitHub Actions workflow is pre-configured at:" -ForegroundColor Gray
    Write-Host "       .github/workflows/build-ios.yml" -ForegroundColor DarkCyan
    Write-Host "     - Runs on Apple Silicon (macos-14) cloud runners." -ForegroundColor Gray
    Write-Host "     - Automatically compiles the IPA and Simulator bundles and uploads to Rubika!" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2. In-Browser Live Interactive iOS Streaming (Appetize.io)" -ForegroundColor Green
    Write-Host "     - Test the app in an iOS device frame directly in Google Chrome / Edge." -ForegroundColor Gray
    Write-Host "     - Execute: .\scripts\deploy_to_appetize.ps1" -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "  3. Local macOS Machine or CI Server" -ForegroundColor Green
    Write-Host "     - On any Mac, simply run: ./scripts/build-ios.sh --flavor $Flavor" -ForegroundColor DarkCyan
    Write-Host "     - Or with PowerShell Core: pwsh ./scripts/build-ios.ps1 -Flavor $Flavor" -ForegroundColor DarkCyan
    Write-Host ""

    # Offer to open GitHub Actions directly in browser
    $ghWorkflowUrl = "https://github.com/alirezakavianifar/leitner-learning-platform/actions/workflows/build-ios.yml"
    Write-Host "  Would you like to open the GitHub Actions iOS Builder now?" -ForegroundColor Cyan
    $answer = Read-Host "  Open GitHub Actions iOS workflow in browser? (y/n)"
    if ($answer.Trim().ToLower() -eq "y") {
        Write-Step "Opening GitHub Actions in your web browser..."
        Start-Process $ghWorkflowUrl
    }
}

Write-Host ""
Write-Host "  Output Reference & Installation Guide for iOS:" -ForegroundColor Cyan
Write-Host "  =============================================" -ForegroundColor Cyan
Write-Host "  1. Sideloading onto Physical iPhone / iPad:" -ForegroundColor Yellow
Write-Host "     - Tool: Sideloadly (https://sideloadly.io) or AltStore (https://altstore.io)" -ForegroundColor Gray
Write-Host "     - Connect device via USB, drag 'app-$Flavor-release.ipa', enter Apple ID." -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Appetize.io Cloud Preview (No Mac or iPhone required):" -ForegroundColor Yellow
Write-Host "     - Drag 'app-$Flavor-ios-simulator.zip' to https://appetize.io/upload" -ForegroundColor Gray
Write-Host "     - Stream live on browser with full touch and network connectivity." -ForegroundColor Gray
Write-Host ""
