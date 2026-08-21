# ==============================================================================
# Leitner Platform - Server Deployment Script
# ==============================================================================
# This script archives local source files and directly streams them via SSH
# to the server 45.94.215.188, extracting in /opt/leitner-platform and
# triggering Docker Compose rebuild and boot.
# ==============================================================================

param (
    [ValidateSet("ON", "OFF")]
    [string]$Sms = "ON"
)

$ServerIP = "45.94.215.188"
$ServerUser = "root"
$KeyPath = "C:\Users\Administrator\.ssh\id_rsa_deploy"

# Root Project Directory
$ProjectRoot = (Get-Item $PSScriptRoot).Parent.FullName

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "Preparing Leitner Platform Deployment to $ServerIP" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

# 1. Configure SMS State in .env
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

# 2. Stream Source Archive to Remote Server via SSH Pipe
Write-Host "Streaming and extracting source files directly to server ($ServerIP)..." -ForegroundColor Yellow

$ExcludeArgs = "--exclude=*.dll --exclude=*.pdb --exclude=*.exe --exclude=*.apk --exclude=*.rar --exclude=*.cobertura.xml " +
               "--exclude=*/bin --exclude=*/obj --exclude=*/dist --exclude=*/node_modules --exclude=*/TestResults " +
               "--exclude=*/.git --exclude=bin --exclude=obj --exclude=dist --exclude=node_modules --exclude=TestResults --exclude=.git " +
               "--exclude=data --exclude=mobile-app --exclude=docs --exclude=scripts --exclude=temp"

$StreamCmd = "tar -czf - $ExcludeArgs backend admin-panel deployment .env | " +
             "ssh -i `"$KeyPath`" -C -o StrictHostKeyChecking=no -o ServerAliveInterval=10 -o ServerAliveCountMax=10 -o TCPKeepAlive=yes -o ConnectTimeout=15 ${ServerUser}@${ServerIP} " +
             "`"mkdir -p /opt/leitner-platform && tar -xzf - -C /opt/leitner-platform`""

Set-Location $ProjectRoot

$MaxAttempts = 5
$StreamSuccess = $false
$BackoffSeconds = @(3, 5, 8, 10, 15)

for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    Write-Host "Transfer attempt $attempt of $MaxAttempts..." -ForegroundColor Yellow
    cmd.exe /c $StreamCmd
    if ($LASTEXITCODE -eq 0) {
        $StreamSuccess = $true
        break
    }
    $WaitTime = $BackoffSeconds[[math]::Min($attempt - 1, $BackoffSeconds.Length - 1)]
    Write-Host "Transfer attempt $attempt failed (Exit code: $LASTEXITCODE). Retrying in $WaitTime seconds..." -ForegroundColor DarkYellow
    Start-Sleep -Seconds $WaitTime
}

if (-not $StreamSuccess) {
    Write-Error "Transfer failed after $MaxAttempts attempts! Verify network connectivity, server status, and SSH key configuration."
    Exit 1
}
Write-Host "Source transfer & extraction completed successfully!" -ForegroundColor Green

# 3. Build & Run Containers on Remote Server
Write-Host "Building and launching Docker containers on the remote server..." -ForegroundColor Yellow
$DeployCmd = "cd /opt/leitner-platform && docker compose -f deployment/docker-compose.yml --env-file .env up -d --build"

$SshArgs = @(
    "-i", $KeyPath,
    "-C",
    "-o", "StrictHostKeyChecking=no",
    "-o", "ServerAliveInterval=10",
    "-o", "ServerAliveCountMax=10",
    "-o", "TCPKeepAlive=yes",
    "-o", "ConnectTimeout=30",
    "${ServerUser}@${ServerIP}",
    $DeployCmd
)
& ssh $SshArgs

If ($LASTEXITCODE -ne 0) {
    Write-Error "Deployment execution failed on the remote server!"
    Exit $LASTEXITCODE
}

# 4. Verify Running State
Write-Host "`nDeployment finished. Verifying container status..." -ForegroundColor Green
$VerifyCmd = "cd /opt/leitner-platform && docker compose -f deployment/docker-compose.yml ps"
$VerifyArgs = @(
    "-i", $KeyPath,
    "-o", "StrictHostKeyChecking=no",
    "-o", "ServerAliveInterval=10",
    "-o", "ServerAliveCountMax=10",
    "-o", "TCPKeepAlive=yes",
    "-o", "ConnectTimeout=15",
    "${ServerUser}@${ServerIP}",
    $VerifyCmd
)
& ssh $VerifyArgs

Write-Host "`nAll operations completed successfully! Enjoy your deployed app at http://$ServerIP" -ForegroundColor Cyan
