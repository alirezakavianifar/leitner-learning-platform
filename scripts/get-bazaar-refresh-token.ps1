# ==============================================================================
# Leitner Platform - Cafe Bazaar Refresh Token Generator
# ==============================================================================
# Usage:
#   .\scripts\get-bazaar-refresh-token.ps1
#   .\scripts\get-bazaar-refresh-token.ps1 -RedirectUri "https://api.rightlearn.ir/bazaar/callback"
#   .\scripts\get-bazaar-refresh-token.ps1 -Code "AUTH_CODE_HERE" -RedirectUri "https://..."
# ==============================================================================

param (
    [string]$RedirectUri = "",
    [string]$Code = ""
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Get-Item $PSScriptRoot).Parent.FullName
$EnvFile = Join-Path $ProjectRoot ".env"
$AppSettingsFile = Join-Path $ProjectRoot "backend\LeitnerPlatform.API\appsettings.json"

Write-Host ""
Write-Host "  +======================================================+" -ForegroundColor Cyan
Write-Host "  |    Cafe Bazaar Developer API Token Setup Tool        |" -ForegroundColor Cyan
Write-Host "  +======================================================+" -ForegroundColor Cyan
Write-Host ""

# 1. Load credentials from .env
$clientId = ""
$clientSecret = ""

if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match "^\s*CAFEBAZAAR_CLIENT_ID\s*=\s*(.+)$") {
            $clientId = $matches[1].Trim()
        }
        if ($_ -match "^\s*CAFEBAZAAR_CLIENT_SECRET\s*=\s*(.+)$") {
            $clientSecret = $matches[1].Trim()
        }
    }
}

if ([string]::IsNullOrWhiteSpace($clientId)) {
    $clientId = Read-Host "  Enter Cafe Bazaar Client ID"
}
if ([string]::IsNullOrWhiteSpace($clientSecret)) {
    $clientSecret = Read-Host "  Enter Cafe Bazaar Client Secret"
}

Write-Host "  Client ID     : " -NoNewline; Write-Host $clientId -ForegroundColor Yellow
Write-Host "  Client Secret : " -NoNewline; Write-Host ($clientSecret.Substring(0, [math]::Min(8, $clientSecret.Length)) + "...") -ForegroundColor DarkGray
Write-Host ""

# 2. Redirect URI
if ([string]::IsNullOrWhiteSpace($RedirectUri)) {
    Write-Host "  Please enter the EXACT Redirect URI (آدرس بازگشت) configured" -ForegroundColor Cyan
    Write-Host "  in your Cafe Bazaar Developer Console (Pishkhan -> Web Services):" -ForegroundColor Cyan
    Write-Host "  (e.g., https://api.rightlearn.ir/bazaar/callback or http://localhost)" -ForegroundColor DarkGray
    $enteredUri = Read-Host "  Redirect URI"
    if ([string]::IsNullOrWhiteSpace($enteredUri)) {
        $RedirectUri = "https://api.rightlearn.ir/bazaar/callback"
        Write-Host "  Using default: $RedirectUri" -ForegroundColor Yellow
    } else {
        $RedirectUri = $enteredUri.Trim()
    }
}

# 3. Prompt user to open browser if no code is provided
if ([string]::IsNullOrWhiteSpace($Code)) {
    $encodedRedirect = [System.Uri]::EscapeDataString($RedirectUri)
    $authUrl = "https://cafebazaar.ir/auth/authorize/?response_type=code&access_type=offline&redirect_uri=$encodedRedirect&client_id=$clientId"

    Write-Host ""
    Write-Host "  -------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "  STEP 1: Open the following URL in your browser:" -ForegroundColor Cyan
    Write-Host "  -------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "  $authUrl" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Log in to your Bazaar developer account and click 'Allow / تأیید'." -ForegroundColor Gray
    Write-Host "  You will be redirected to: $RedirectUri?code=XXXXX" -ForegroundColor Gray
    Write-Host "  Copy the 'code' parameter value from the browser URL bar." -ForegroundColor Gray
    Write-Host ""

    $enteredCode = Read-Host "  STEP 2: Paste the authorization code here"
    if ([string]::IsNullOrWhiteSpace($enteredCode)) {
        Write-Host "  [ERROR] Code cannot be empty. Aborted." -ForegroundColor Red
        exit 1
    }
    $Code = $enteredCode.Trim()
}

# Clean code in case full URL was pasted
if ($Code.Contains("code=")) {
    $Code = $Code.Substring($Code.IndexOf("code=") + 5).Split("&")[0]
}

Write-Host ""
Write-Host "  Exchanging authorization code for permanent refresh token..." -ForegroundColor Yellow

# 4. Exchange code for tokens
$tokenEndpoint = "https://pardakht.cafebazaar.ir/devapi/v2/auth/token/"
$body = @{
    grant_type    = "authorization_code"
    client_id     = $clientId
    client_secret = $clientSecret
    code          = $Code
    redirect_uri  = $RedirectUri
}

try {
    $response = Invoke-RestMethod -Method Post -Uri $tokenEndpoint -Body $body -ContentType "application/x-www-form-urlencoded"
    
    if ($null -eq $response -or [string]::IsNullOrWhiteSpace($response.refresh_token)) {
        Write-Host "  [ERROR] Response did not contain a refresh_token:" -ForegroundColor Red
        Write-Host ($response | ConvertTo-Json -Depth 3) -ForegroundColor DarkRed
        exit 1
    }

    $refreshToken = $response.refresh_token
    Write-Host "  [SUCCESS] Refresh token obtained successfully!" -ForegroundColor Green
    Write-Host "  Refresh Token : " -NoNewline; Write-Host $refreshToken -ForegroundColor Cyan

    # 5. Automatically update .env
    if (Test-Path $EnvFile) {
        $envLines = Get-Content $EnvFile
        $hasKey = $false
        $newEnvLines = $envLines | ForEach-Object {
            if ($_ -match "^\s*CAFEBAZAAR_REFRESH_TOKEN\s*=") {
                $hasKey = $true
                "CAFEBAZAAR_REFRESH_TOKEN=$refreshToken"
            } else {
                $_
            }
        }
        if (-not $hasKey) {
            $newEnvLines += "CAFEBAZAAR_REFRESH_TOKEN=$refreshToken"
        }
        $newEnvLines | Set-Content $EnvFile -Force
        Write-Host "  [OK] Saved CAFEBAZAAR_REFRESH_TOKEN to $EnvFile" -ForegroundColor Green
    }

    # 6. Automatically update appsettings.json if present
    if (Test-Path $AppSettingsFile) {
        try {
            $jsonContent = Get-Content $AppSettingsFile -Raw
            $appSettings = $jsonContent | ConvertFrom-Json
            if ($null -ne $appSettings.CafeBazaar) {
                $appSettings.CafeBazaar.RefreshToken = $refreshToken
                $newJson = $appSettings | ConvertTo-Json -Depth 10
                $newJson | Set-Content $AppSettingsFile -Force
                Write-Host "  [OK] Updated CafeBazaar.RefreshToken in appsettings.json" -ForegroundColor Green
            }
        } catch {
            Write-Host "  [INFO] Could not automatically update appsettings.json (formatting preserved)." -ForegroundColor DarkGray
        }
    }

    Write-Host ""
    Write-Host "  Done! Your Cafe Bazaar Developer API is now fully configured." -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "  [ERROR] Token exchange failed:" -ForegroundColor Red
    if ($_.Exception.Response) {
        $stream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        Write-Host $reader.ReadToEnd() -ForegroundColor Red
    } else {
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
    exit 1
}
