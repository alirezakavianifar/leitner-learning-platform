# ==============================================================================
# Leitner Platform - Server Deployment Script
# ==============================================================================
# This script archives local source files (excluding build files, node_modules,
# and binaries), uploads them via passwordless SCP to the server 45.94.215.188,
# and triggers Docker Compose rebuild and boot.
# ==============================================================================

$ServerIP = "45.94.215.188"
$ServerUser = "root"
$KeyPath = "C:\Users\Administrator\.ssh\id_rsa_deploy"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$ZipPath = "E:\temp\leitner_platform_$Timestamp.zip"
$StagingFolder = "E:\temp\leitner_deploy_staging_$Timestamp"

# Excluded Directories and Files
$ExcludeDirs = @('.git', 'node_modules', 'bin', 'obj', '.vs', 'dist', 'TestResults', 'temp', 'mobile-app', 'docs', 'scripts')
$ExcludeFiles = @('app-premium-release.apk', 'app-premium-release.rar', 'document.PDF', 'screen.png', 'ngrok_test.log')

# Root Project Directory (where this script is launched or where it is located)
$ProjectRoot = (Get-Item $PSScriptRoot).Parent.FullName

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "Preparing Leitner Platform Deployment to $ServerIP" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

# 1. Clean Staging Environment & Old Archives
Get-ChildItem -Path "E:\temp" -Filter "leitner_platform_*.zip" -ErrorAction SilentlyContinue | ForEach-Object { Try { Remove-Item $_.FullName -Force } Catch {} }
If (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
If (Test-Path $StagingFolder) { Remove-Item $StagingFolder -Recurse -Force }
New-Item -ItemType Directory -Force -Path $StagingFolder | Out-Null

# 2. Selectively Copy Source Files (Recursive Exclusions)
Write-Host "Packaging source files (excluding node_modules, build folders, and binaries)..." -ForegroundColor Yellow

Function Copy-Source([string]$Src, [string]$Dest) {
    Get-ChildItem -Path $Src -File | ForEach-Object {
        If ($ExcludeFiles -notcontains $_.Name) {
            $TargetFile = Join-Path $Dest $_.Name
            $Dir = Split-Path $TargetFile
            If (-not (Test-Path $Dir)) { New-Item -ItemType Directory -Force -Path $Dir | Out-Null }
            Try {
                Copy-Item -Path $_.FullName -Destination $TargetFile -Force -ErrorAction Stop
            } Catch {
                Write-Warning "Skipped locked file: $_.FullName"
            }
        }
    }
    Get-ChildItem -Path $Src -Directory | ForEach-Object {
        If ($ExcludeDirs -notcontains $_.Name) {
            $SubDest = Join-Path $Dest $_.Name
            Copy-Source $_.FullName $SubDest
        }
    }
}

Copy-Source $ProjectRoot $StagingFolder

# 3. Create Zip Archive
Write-Host "Compressing deployment archive..." -ForegroundColor Yellow
Compress-Archive -Path "$StagingFolder\*" -DestinationPath $ZipPath -Force
Remove-Item $StagingFolder -Recurse -Force

$ArchiveSize = [math]::Round((Get-Item $ZipPath).Length / 1MB, 2)
Write-Host "Archive created at $ZipPath ($ArchiveSize MB)" -ForegroundColor Green

# 4. Upload Zip to Remote Server via SCP
Write-Host "Uploading archive to the server ($ServerIP)..." -ForegroundColor Yellow
$ScpArgs = @(
    "-i", $KeyPath,
    "-o", "StrictHostKeyChecking=no",
    $ZipPath,
    "${ServerUser}@${ServerIP}:/tmp/leitner_platform.zip"
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
             "unzip -o /tmp/leitner_platform.zip -d /opt/leitner-platform; " +
             "rm -f /tmp/leitner_platform.zip; " +
             "cd /opt/leitner-platform && " +
             "docker compose -f deployment/docker-compose.yml --env-file .env up -d --build"

$SshArgs = @(
    "-i", $KeyPath,
    "-o", "StrictHostKeyChecking=no",
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
if (Test-Path $ZipPath) {
    Remove-Item $ZipPath -Force
    Write-Host "  [OK] Local temporary archive deleted." -ForegroundColor Green
}

Write-Host "`nAll operations completed successfully! Enjoy your deployed app at http://$ServerIP" -ForegroundColor Cyan
