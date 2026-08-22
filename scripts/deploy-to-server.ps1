# ==============================================================================
# Leitner Platform - Server Deployment Script
# ==============================================================================
# Archives local source files, uploads via SCP, extracts on the remote server,
# syncs course packages incrementally, and executes Docker Compose build & boot.
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

function Invoke-ScpWithRetry {
    param (
        [string[]]$Arguments,
        [int]$MaxRetries = 4,
        [int]$DelaySeconds = 2
    )
    for ($i = 1; $i -le $MaxRetries; $i++) {
        & scp $Arguments
        if ($LASTEXITCODE -eq 0) {
            return $true
        }
        if ($i -lt $MaxRetries) {
            Write-Host "    [SCP retry $i/$MaxRetries in ${DelaySeconds}s...]" -ForegroundColor DarkYellow
            Start-Sleep -Seconds $DelaySeconds
        }
    }
    return $false
}

function Invoke-SshWithRetry {
    param (
        [string[]]$Arguments,
        [int]$MaxRetries = 4,
        [int]$DelaySeconds = 2
    )
    for ($i = 1; $i -le $MaxRetries; $i++) {
        & ssh $Arguments
        if ($LASTEXITCODE -eq 0) {
            return $true
        }
        if ($i -lt $MaxRetries) {
            Write-Host "    [SSH retry $i/$MaxRetries in ${DelaySeconds}s...]" -ForegroundColor DarkYellow
            Start-Sleep -Seconds $DelaySeconds
        }
    }
    return $false
}

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

Set-Location $ProjectRoot

# 2. Create Source Archive (Excluding heavy binaries, node_modules, and course zip assets)
Write-Host "Creating lightweight source archive..." -ForegroundColor Yellow
$TempArchiveName = "leitner_deploy_$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()).tar.gz"
$TempArchivePath = Join-Path $ProjectRoot $TempArchiveName

$ExcludeArgs = @(
    "--exclude=*.dll", "--exclude=*.pdb", "--exclude=*.exe", "--exclude=*.apk", "--exclude=*.rar", "--exclude=*.cobertura.xml",
    "--exclude=*/bin", "--exclude=*/obj", "--exclude=*/dist", "--exclude=*/node_modules", "--exclude=*/TestResults",
    "--exclude=*/.git", "--exclude=bin", "--exclude=obj", "--exclude=dist", "--exclude=node_modules", "--exclude=TestResults", "--exclude=.git",
    "--exclude=data", "--exclude=mobile-app", "--exclude=docs", "--exclude=scripts", "--exclude=temp",
    "--exclude=backend/LeitnerPlatform.API/wwwroot/courses/*.zip"
)

try {
    & tar -czf $TempArchiveName @ExcludeArgs backend admin-panel deployment .env
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $TempArchivePath)) {
        throw "Failed to create source archive (tar exited with code $LASTEXITCODE)."
    }
    $ArchiveSizeKB = [math]::Round((Get-Item $TempArchivePath).Length / 1KB, 2)
    Write-Host "  [OK] Source archive created ($ArchiveSizeKB KB)." -ForegroundColor Green

    # 3. Upload & Extract Archive on Remote Server
    Write-Host "Uploading source archive to server ($ServerIP)..." -ForegroundColor Yellow
    $ScpArgs = @(
        "-O",
        "-i", $KeyPath,
        "-o", "StrictHostKeyChecking=no",
        "-o", "ConnectTimeout=15",
        $TempArchiveName,
        "${ServerUser}@${ServerIP}:/tmp/$TempArchiveName"
    )
    $uploadOk = Invoke-ScpWithRetry -Arguments $ScpArgs
    if (-not $uploadOk) {
        throw "SCP transfer of source archive failed after retries."
    }

    Write-Host "Extracting source archive on remote server..." -ForegroundColor Yellow
    $ExtractCmd = "mkdir -p /opt/leitner-platform && tar -xzf /tmp/$TempArchiveName -C /opt/leitner-platform && rm -f /tmp/$TempArchiveName"
    $SshArgs = @(
        "-n",
        "-T",
        "-i", $KeyPath,
        "-o", "StrictHostKeyChecking=no",
        "-o", "ConnectTimeout=15",
        "${ServerUser}@${ServerIP}",
        $ExtractCmd
    )
    $extractOk = Invoke-SshWithRetry -Arguments $SshArgs
    if (-not $extractOk) {
        throw "Remote archive extraction failed after retries."
    }
    Write-Host "  [OK] Source code deployed successfully!" -ForegroundColor Green

} finally {
    # Clean up local temporary archive
    if (Test-Path $TempArchivePath) {
        Remove-Item $TempArchivePath -Force -ErrorAction SilentlyContinue
    }
}

# 4. Incremental Course Assets Sync
$LocalCoursesDir = Join-Path $ProjectRoot "backend\LeitnerPlatform.API\wwwroot\courses"
if (Test-Path $LocalCoursesDir) {
    $LocalZipFiles = Get-ChildItem -Path $LocalCoursesDir -Filter "*.zip" -ErrorAction SilentlyContinue
    if ($LocalZipFiles -and $LocalZipFiles.Count -gt 0) {
        Write-Host "Checking course packages synchronization..." -ForegroundColor Yellow
        $RemoteLsOutput = & ssh -n -T -i $KeyPath -o StrictHostKeyChecking=no -o ConnectTimeout=15 "${ServerUser}@${ServerIP}" "mkdir -p /opt/leitner-platform/backend/LeitnerPlatform.API/wwwroot/courses && ls -l /opt/leitner-platform/backend/LeitnerPlatform.API/wwwroot/courses"
        
        foreach ($zipFile in $LocalZipFiles) {
            $fileName = $zipFile.Name
            $fileLength = $zipFile.Length
            
            # Check if remote file exists with exact size
            $matched = $false
            if ($RemoteLsOutput) {
                foreach ($line in $RemoteLsOutput) {
                    if ($line -match [regex]::Escape($fileName) -and $line -match "\b$fileLength\b") {
                        $matched = $true
                        break
                    }
                }
            }
            
            if (-not $matched) {
                Write-Host "  Syncing course package: $fileName ($([math]::Round($fileLength / 1MB, 2)) MB)..." -ForegroundColor DarkYellow
                $CourseScpArgs = @(
                    "-O",
                    "-i", $KeyPath,
                    "-o", "StrictHostKeyChecking=no",
                    "-o", "ConnectTimeout=15",
                    $zipFile.FullName,
                    "${ServerUser}@${ServerIP}:/opt/leitner-platform/backend/LeitnerPlatform.API/wwwroot/courses/$fileName"
                )
                $syncOk = Invoke-ScpWithRetry -Arguments $CourseScpArgs
                if ($syncOk) {
                    Write-Host "  [OK] $fileName synced." -ForegroundColor Green
                } else {
                    Write-Warning "  Failed to sync $fileName after retries."
                }
            } else {
                Write-Host "  [OK] Course package up to date: $fileName" -ForegroundColor DarkGray
            }
        }
    }
}

# 5. Build & Run Containers on Remote Server
Write-Host "`nBuilding and launching Docker containers on the remote server..." -ForegroundColor Yellow
$DeployCmd = "cd /opt/leitner-platform && docker compose -f deployment/docker-compose.yml --env-file .env up -d --build"

$SshDeployArgs = @(
    "-n",
    "-T",
    "-i", $KeyPath,
    "-o", "StrictHostKeyChecking=no",
    "-o", "ServerAliveInterval=15",
    "-o", "ServerAliveCountMax=10",
    "-o", "TCPKeepAlive=yes",
    "-o", "ConnectTimeout=30",
    "${ServerUser}@${ServerIP}",
    $DeployCmd
)
$deployOk = Invoke-SshWithRetry -Arguments $SshDeployArgs

if (-not $deployOk) {
    Write-Error "Deployment execution failed on the remote server!"
    Exit 1
}

# 6. Verify Running State
Write-Host "`nDeployment finished. Verifying container status..." -ForegroundColor Green
$VerifyCmd = "cd /opt/leitner-platform && docker compose -f deployment/docker-compose.yml ps"
$VerifyArgs = @(
    "-n",
    "-T",
    "-i", $KeyPath,
    "-o", "StrictHostKeyChecking=no",
    "-o", "ConnectTimeout=15",
    "${ServerUser}@${ServerIP}",
    $VerifyCmd
)
& ssh $VerifyArgs

Write-Host "`nAll operations completed successfully! Enjoy your deployed app at http://$ServerIP" -ForegroundColor Cyan
