# ==============================================================================
# Leitner Platform - Server Deployment Script
# ==============================================================================
# This script archives local source files (excluding build files, node_modules,
# and binaries), uploads them via passwordless SCP to the server 45.94.215.188,
# and triggers Docker Compose rebuild and boot.
# ==============================================================================

param (
    [ValidateSet("ON", "OFF")]
    [string]$Sms = "ON"
)

$ServerIP = "45.94.215.188"
$ServerUser = "root"
$KeyPath = "C:\Users\Administrator\.ssh\id_rsa_deploy"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$TarPath = "E:\temp\leitner_platform_$Timestamp.tar.gz"

# Root Project Directory
$ProjectRoot = (Get-Item $PSScriptRoot).Parent.FullName

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "Preparing Leitner Platform Deployment to $ServerIP" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

# 1. Clean Old Archives
Get-ChildItem -Path "E:\temp" -Filter "leitner_platform_*" -ErrorAction SilentlyContinue | ForEach-Object { Try { Remove-Item $_.FullName -Recurse -Force } Catch {} }

# 2. Configure SMS State in .env
$EnvFile = Join-Path $ProjectRoot ".env"
if (Test-Path $EnvFile) {
    Write-Host "Configuring SMS state to: $Sms" -ForegroundColor Yellow
    $Content = Get-Content $EnvFile
    $NewContent = $Content | ForEach-Object {
        if ($Sms -eq "OFF") {
            if ($_ -match "^\s*SMS_GATEWAY_API_KEY\s*=") {
                "# " + $_.TrimStart()
            } else {
                $_
            }
        } else { # ON
            if ($_ -match "^\s*#\s*SMS_GATEWAY_API_KEY\s*=") {
                $_.Replace("#", "").TrimStart()
            } else {
                $_
            }
        }
    }
    $NewContent | Set-Content $EnvFile -Force
    Write-Host "  [OK] SMS configuration updated." -ForegroundColor Green
}

# 3. Create Ultra-Compact Tar Archive (<300 KB)
Write-Host "Compressing minimal source archive..." -ForegroundColor Yellow
Set-Location $ProjectRoot
tar -czf $TarPath `
    --exclude="*.dll" `
    --exclude="*.pdb" `
    --exclude="*.exe" `
    --exclude="*.apk" `
    --exclude="*.rar" `
    --exclude="bin" `
    --exclude="obj" `
    --exclude="node_modules" `
    --exclude=".git" `
    --exclude="data" `
    --exclude="mobile-app" `
    --exclude="docs" `
    --exclude="scripts" `
    --exclude="temp" `
    backend admin-panel deployment .env

$ArchiveSize = [math]::Round((Get-Item $TarPath).Length / 1KB, 2)
Write-Host "Archive created at $TarPath ($ArchiveSize KB)" -ForegroundColor Green

# 4. Upload Tar Archive to Remote Server via SCP
Write-Host "Uploading archive to the server ($ServerIP)..." -ForegroundColor Yellow
$ScpArgs = @(
    "-i", $KeyPath,
    "-o", "StrictHostKeyChecking=no",
    "-o", "ConnectTimeout=15",
    $TarPath,
    "${ServerUser}@${ServerIP}:/tmp/leitner_platform.tar.gz"
)

& scp $ScpArgs

If ($LASTEXITCODE -ne 0) {
    Write-Error "Upload failed! Check SSH key configuration."
    Exit $LASTEXITCODE
}
Write-Host "Upload completed successfully!" -ForegroundColor Green

# 5. Extract and Deploy on the Server
Write-Host "Extracting and building containers on the remote server..." -ForegroundColor Yellow
$RemoteCmd = "mkdir -p /opt/leitner-platform; " +
             "tar -xzf /tmp/leitner_platform.tar.gz -C /opt/leitner-platform; " +
             "rm -f /tmp/leitner_platform.tar.gz; " +
             "cd /opt/leitner-platform && " +
             "docker compose -f deployment/docker-compose.yml --env-file .env up -d --build"

$SshArgs = @(
    "-i", $KeyPath,
    "-o", "StrictHostKeyChecking=no",
    "-o", "ConnectTimeout=15",
    "${ServerUser}@${ServerIP}",
    $RemoteCmd
)
& ssh $SshArgs

If ($LASTEXITCODE -ne 0) {
    Write-Error "Deployment execution failed on the remote server!"
    Exit $LASTEXITCODE
}

# 6. Verify Running State
Write-Host "`nDeployment finished. Verifying container status..." -ForegroundColor Green
$VerifyCmd = "cd /opt/leitner-platform && docker compose -f deployment/docker-compose.yml ps"
& ssh -i $KeyPath -o StrictHostKeyChecking=no "${ServerUser}@${ServerIP}" $VerifyCmd

# 7. Local Clean-Up
Write-Host "`nCleaning up local temporary archive..." -ForegroundColor Yellow
if (Test-Path $TarPath) {
    Remove-Item $TarPath -Force
    Write-Host "  [OK] Local temporary archive deleted." -ForegroundColor Green
}

Write-Host "`nAll operations completed successfully! Enjoy your deployed app at http://$ServerIP" -ForegroundColor Cyan
