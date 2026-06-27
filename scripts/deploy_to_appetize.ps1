# Deploy to Appetize.io with automatic Ngrok tunneling and backend routing
# Usage: .\deploy_to_appetize.ps1 [-TargetPlatform <platform>] [-Flavor <flavor>]
# Examples: 
#   .\deploy_to_appetize.ps1
#   .\deploy_to_appetize.ps1 -TargetPlatform android-x64 -Flavor premium

Param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("android-x64", "android-arm", "android-arm64", "universal")]
    [string]$TargetPlatform = "android-x64",

    [Parameter(Mandatory=$false)]
    [ValidateSet("premium", "store")]
    [string]$Flavor = "premium"
)

$ErrorActionPreference = "Stop"

# Clear host for nice display
Clear-Host
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "             LEITNER LEARNING PLATFORM - APPETIZE.IO DEPLOYER        " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

# 1. Resolve Paths
$RepoRoot = Resolve-Path "$PSScriptRoot\.."
$EnvPath = "$RepoRoot\.env"
$BackendDir = "$RepoRoot\backend\LeitnerPlatform.API"
$MobileDir = "$RepoRoot\mobile-app"

Write-Host "[*] Repository root: $RepoRoot" -ForegroundColor Gray

# 2. Load Credentials from .env
$APPETIZE_API_TOKEN = $null
$APPETIZE_PUBLIC_KEY = $null

if (Test-Path $EnvPath) {
    Write-Host "[*] Loading environment variables from $EnvPath..." -ForegroundColor Gray
    Get-Content $EnvPath | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
            $key, $value = $line.Split("=", 2)
            $key = $key.Trim()
            $value = $value.Trim()
            if ($key -eq "APPETIZE_API_TOKEN") { $APPETIZE_API_TOKEN = $value }
            if ($key -eq "APPETIZE_PUBLIC_KEY") { $APPETIZE_PUBLIC_KEY = $value }
        }
    }
} else {
    Write-Host "[!] No .env file found at $EnvPath. Proceeding with manual input..." -ForegroundColor Yellow
}

# 3. Check Backend
Write-Host "[*] Checking if local backend is running on port 5217..." -ForegroundColor Cyan
$backendRunning = $false
$socket = New-Object System.Net.Sockets.TcpClient
try {
    $connect = $socket.BeginConnect("localhost", 5217, $null, $null)
    $success = $connect.AsyncWaitHandle.WaitOne(800, $false)
    if ($success) {
        $socket.EndConnect($connect)
        $backendRunning = $true
    }
} catch {
    # Ignore and proceed to start
} finally {
    $socket.Close()
}

if ($backendRunning) {
    Write-Host "[+] Local backend is already running on port 5217." -ForegroundColor Green
} else {
    Write-Host "[!] Local backend not detected. Starting backend project in a new window..." -ForegroundColor Yellow
    $csprojPath = "$BackendDir\LeitnerPlatform.API.csproj"
    if (Test-Path $csprojPath) {
        Start-Process dotnet -ArgumentList "run --project `"$csprojPath`" --launch-profile http" -WorkingDirectory $RepoRoot
        Write-Host "[*] Waiting 5 seconds for backend to initialize..." -ForegroundColor Gray
        Start-Sleep -Seconds 5
    } else {
        Write-Error "Could not find backend project at $csprojPath!"
    }
}

# 4. Check & Start Ngrok
Write-Host "[*] Checking if Ngrok is running..." -ForegroundColor Cyan
$ngrokTunnelsUrl = "http://127.0.0.1:4040/api/tunnels"
$ngrokRunning = $false

try {
    $ngrokApi = Invoke-RestMethod -Uri $ngrokTunnelsUrl -ErrorAction SilentlyContinue
    if ($ngrokApi) { $ngrokRunning = $true }
} catch {
    # Ngrok API offline
}

if ($ngrokRunning) {
    Write-Host "[+] Ngrok is already running." -ForegroundColor Green
} else {
    Write-Host "[!] Ngrok is not running. Starting Ngrok tunnel for port 5217 in a new window..." -ForegroundColor Yellow
    Start-Process ngrok -ArgumentList "http 5217" -WorkingDirectory $RepoRoot
    Write-Host "[*] Waiting 4 seconds for Ngrok to establish tunnel..." -ForegroundColor Gray
    Start-Sleep -Seconds 4
}

# 5. Extract Ngrok Public URL
Write-Host "[*] Fetching Ngrok public tunnel URL..." -ForegroundColor Cyan
$publicUrl = $null
for ($i = 1; $i -le 10; $i++) {
    try {
        $ngrokApi = Invoke-RestMethod -Uri $ngrokTunnelsUrl -ErrorAction SilentlyContinue
        if ($ngrokApi -and $ngrokApi.tunnels -and $ngrokApi.tunnels.Count -gt 0) {
            $publicUrl = $ngrokApi.tunnels[0].public_url
            break
        }
    } catch {
        # Retry
    }
    Write-Host "    Retrying tunnel detection ($i/10)..." -ForegroundColor Gray
    Start-Sleep -Seconds 1
}

if (-not $publicUrl) {
    Write-Error "Failed to retrieve Ngrok public tunnel URL! Ensure ngrok is authenticated and running."
}

# Format API Base URL
$apiUrl = "$publicUrl/api/v1"
Write-Host "[+] Tunnel established successfully!" -ForegroundColor Green
Write-Host "    Ngrok URL:     $publicUrl" -ForegroundColor Green
Write-Host "    API Base URL:  $apiUrl" -ForegroundColor Green

# 6. Compile Flutter Application
Write-Host "[*] Compiling Flutter application ($Flavor flavor)..." -ForegroundColor Cyan
if (-not (Test-Path $MobileDir)) {
    Write-Error "Flutter project not found at $MobileDir!"
}

Push-Location $MobileDir
try {
    Write-Host "[*] Synchronizing dependencies (flutter pub get)..." -ForegroundColor Gray
    flutter pub get

    $buildArgs = @("build", "apk", "--flavor", $Flavor, "--release")
    
    # Customize entrypoint based on flavor
    if ($Flavor -eq "premium") {
        $buildArgs += @("-t", "lib/main_premium.dart")
    } elseif ($Flavor -eq "store") {
        $buildArgs += @("-t", "lib/main_store.dart")
    }

    # Add targeted architectures
    if ($TargetPlatform -ne "universal") {
        $buildArgs += @("--target-platform", $TargetPlatform)
    }

    # Inject Ngrok API Base URL
    $buildArgs += @("--dart-define=API_BASE_URL=$apiUrl")

    Write-Host "[*] Running: flutter $($buildArgs -join ' ')" -ForegroundColor Gray
    & flutter $buildArgs
} catch {
    Pop-Location
    Write-Error "Flutter compilation failed!"
}
Pop-Location

# 7. Locate built APK
Write-Host "[*] Locating built APK..." -ForegroundColor Cyan
$apkFile = Get-ChildItem -Path "$MobileDir\build" -Filter "*$Flavor*release.apk" -Recurse | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-not $apkFile -or -not (Test-Path $apkFile.FullName)) {
    Write-Error "Could not locate compiled APK in build outputs!"
}

$apkRelativePath = Resolve-Path -Relative -LiteralPath $apkFile.FullName
Write-Host "[+] Found compiled APK at: $apkRelativePath" -ForegroundColor Green
Write-Host "    Size: $([Math]::Round($apkFile.Length / 1MB, 2)) MB" -ForegroundColor Green

# 8. Upload to Appetize.io
if ($APPETIZE_API_TOKEN) {
    # Automatically discover Public Key for com.leitnerplatform.mobile_app.premium if not set
    if (-not $APPETIZE_PUBLIC_KEY) {
        Write-Host "[*] API Token found. Searching Appetize.io for existing app matching flavor..." -ForegroundColor Cyan
        try {
            $headers = @{ "X-API-KEY" = $APPETIZE_API_TOKEN }
            $appsResponse = Invoke-RestMethod -Uri "https://api.appetize.io/v1/apps" -Headers $headers -ErrorAction SilentlyContinue
            if ($appsResponse -and $appsResponse.data) {
                # Determine bundle ID expected
                $expectedBundle = "com.leitnerplatform.mobile_app.$Flavor"
                $matchedApp = $appsResponse.data | Where-Object { $_.bundle -eq $expectedBundle } | Sort-Object -Property updated -Descending | Select-Object -First 1
                if ($matchedApp) {
                    $APPETIZE_PUBLIC_KEY = $matchedApp.publicKey
                    Write-Host "[+] Discovered existing Appetize app: $APPETIZE_PUBLIC_KEY" -ForegroundColor Green
                }
            }
        } catch {
            Write-Host "[!] Could not fetch apps list for auto-discovery: $_" -ForegroundColor Yellow
        }
    }

    if ($APPETIZE_PUBLIC_KEY) {
        Write-Host "[*] Updating existing Appetize.io application (Public Key: $APPETIZE_PUBLIC_KEY)..." -ForegroundColor Cyan
        $uploadUrl = "https://api.appetize.io/v1/apps/$APPETIZE_PUBLIC_KEY"
    } else {
        Write-Host "[*] Creating a new application on Appetize.io..." -ForegroundColor Cyan
        $uploadUrl = "https://api.appetize.io/v1/apps"
    }

    Write-Host "[*] Uploading APK. Please wait..." -ForegroundColor Gray
    
    # We use curl.exe because Windows PowerShell 5.1 Invoke-RestMethod lacks -Form multipart upload support
    $curlCmd = "curl.exe"
    $curlArgs = @(
        "-s",
        "-X", "POST",
        $uploadUrl,
        "-H", "X-API-KEY: $APPETIZE_API_TOKEN",
        "-F", "file=@$($apkFile.FullName)",
        "-F", "platform=android"
    )

    try {
        $responseJson = & $curlCmd $curlArgs
        $response = $responseJson | ConvertFrom-Json

        if ($response -and $response.publicKey) {
            Write-Host "======================================================================" -ForegroundColor Green
            Write-Host "🎉 SUCCESS! Appetize.io build uploaded successfully." -ForegroundColor Green
            Write-Host "   Public Key:  $($response.publicKey)" -ForegroundColor Green
            Write-Host "   Preview URL: https://appetize.io/app/$($response.publicKey)" -ForegroundColor Green
            Write-Host "======================================================================" -ForegroundColor Green
            
            # Auto-launch preview link
            Write-Host "[*] Launching Appetize.io preview in your browser..." -ForegroundColor Gray
            Start-Process "https://appetize.io/app/$($response.publicKey)"
        } else {
            Write-Host "[!] Upload failed. Raw response: $responseJson" -ForegroundColor Red
        }
    } catch {
        Write-Host "[!] Error uploading to Appetize: $_" -ForegroundColor Red
    }
} else {
    Write-Host "======================================================================" -ForegroundColor Yellow
    Write-Host "⚠️ APPETIZE API CREDENTIALS NOT CONFIGURED" -ForegroundColor Yellow
    Write-Host "   To automate uploads, add APPETIZE_API_TOKEN to your .env file." -ForegroundColor Yellow
    Write-Host "   " -ForegroundColor Yellow
    Write-Host "   Manual steps to run:" -ForegroundColor Yellow
    Write-Host "   1. Open: https://appetize.io/upload" -ForegroundColor Yellow
    Write-Host "   2. Drag & drop the APK: $apkRelativePath" -ForegroundColor Yellow
    Write-Host "======================================================================" -ForegroundColor Yellow
}
