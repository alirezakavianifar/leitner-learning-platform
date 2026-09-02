# =============================================================================
#  Leitner Learning Platform - Admin & App Lifecycle Manager
#  Usage:
#    .\scripts\manage-admin.ps1                                # Interactive menu
#    .\scripts\manage-admin.ps1 -Action down                   # Admin only down
#    .\scripts\manage-admin.ps1 -Action down -Scope Global     # Admin + Mobile App down
#    .\scripts\manage-admin.ps1 -Action mobile-on              # Mobile App maintenance ON
#    .\scripts\manage-admin.ps1 -Action mobile-off             # Mobile App maintenance OFF
#    .\scripts\manage-admin.ps1 -Action up                     # Bring all services UP
#    .\scripts\manage-admin.ps1 -Action restart                # Restart admin panel
#    .\scripts\manage-admin.ps1 -Action status                 # Check admin & mobile status
# =============================================================================

param (
    [ValidateSet("down", "stop", "up", "start", "restart", "status", "logs", "deploy-maintenance", "mobile-on", "mobile-off", "interactive")]
    [string]$Action = "interactive",

    [ValidateSet("AdminOnly", "Global", "MobileOnly")]
    [string]$Scope = "AdminOnly",

    [ValidateSet("Remote", "Local")]
    [string]$Target = "Remote",

    [string]$ServerIP = "45.94.215.188",
    [string]$ServerUser = "root",
    [string]$KeyPath = "C:\Users\Administrator\.ssh\id_rsa_deploy",
    [int]$Tail = 60
)

$ErrorActionPreference = "Continue"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

$ProjectRoot = (Get-Item $PSScriptRoot).Parent.FullName

# -- UI Formatting Helpers ----------------------------------------------------
function Write-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  +====================================================================+" -ForegroundColor Cyan
    Write-Host "  |       Leitner Learning Platform - System Lifecycle Manager         |" -ForegroundColor Cyan
    Write-Host "  +====================================================================+" -ForegroundColor Cyan
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

function Write-Warn([string]$msg) {
    Write-Host "  [WARN] $msg" -ForegroundColor DarkYellow
}

# -- SSH & Remote Helpers -----------------------------------------------------
function Invoke-SshCmd {
    param (
        [string]$Command,
        [int]$TimeoutSec = 20
    )
    if (-not (Test-Path $KeyPath)) {
        throw "SSH private key not found at: $KeyPath"
    }
    $sshArgs = @(
        "-n",
        "-T",
        "-i", $KeyPath,
        "-o", "StrictHostKeyChecking=no",
        "-o", "ConnectTimeout=$TimeoutSec",
        "-o", "ServerAliveInterval=5",
        "-o", "ServerAliveCountMax=3",
        "${ServerUser}@${ServerIP}",
        $Command
    )
    $output = & ssh $sshArgs 2>&1
    return @{
        ExitCode = $LASTEXITCODE
        Output   = $output
    }
}

function Test-RemoteHost {
    try {
        $res = Invoke-SshCmd -Command "echo 'pong'" -TimeoutSec 8
        return ($res.ExitCode -eq 0 -and ($res.Output -join "") -match "pong")
    } catch {
        return $false
    }
}

# -- Database & Mobile App Maintenance Helpers --------------------------------
function Get-RemoteMobileMaintenanceStatus {
    $cmd = "echo 'SELECT value FROM system_configs WHERE key = '\''maintenance_mode'\'';' | docker exec -i leitner-postgres-db psql -U leitner_admin -d leitner_db -t"
    $res = Invoke-SshCmd -Command $cmd
    $val = ($res.Output -join "").Trim().ToLower()
    return ($val -eq "true")
}

function Set-RemoteMobileMaintenance {
    param([bool]$Enable)
    $val = if ($Enable) { "true" } else { "false" }
    $cmd = "echo 'UPDATE system_configs SET value = '\''$val'\'' WHERE key = '\''maintenance_mode'\'';' | docker exec -i leitner-postgres-db psql -U leitner_admin -d leitner_db"
    $res = Invoke-SshCmd -Command $cmd
    if ($res.ExitCode -eq 0) {
        if ($Enable) {
            Write-Ok "Mobile App Maintenance Mode is now ACTIVE (ON)."
            Write-Info "Mobile app users will see the MaintenanceScreen upon launching or checking."
        } else {
            Write-Ok "Mobile App Maintenance Mode is now DEACTIVATED (OFF)."
            Write-Info "Mobile app users can use the app normally."
        }
    } else {
        Write-Err "Failed to update database maintenance_mode: $($res.Output -join ' ')"
    }
}

# -- Remote Actions -----------------------------------------------------------
function Get-RemoteStatus {
    Write-Step "Querying Remote Server ($ServerIP) for system status..."
    $cmd = "docker inspect -f '{{.State.Status}}|{{.State.StartedAt}}|{{.State.FinishedAt}}' leitner-admin-panel 2>/dev/null || echo 'NOT_FOUND'"
    $res = Invoke-SshCmd -Command $cmd
    
    $raw = ($res.Output -join "").Trim()
    $parts = $raw -split "\|"
    $adminState = if ($parts.Length -gt 0 -and $raw -ne "NOT_FOUND") { $parts[0].Trim() } else { "exited" }

    # Query mobile maintenance mode in DB
    $isMobileMaintenance = Get-RemoteMobileMaintenanceStatus

    # Get container ports & resource metrics
    $psCmd = "docker ps -a --filter name=leitner-admin-panel --format '{{.Names}} - Status: {{.Status}} - Ports: {{.Ports}}'"
    $psRes = Invoke-SshCmd -Command $psCmd
    $details = ($psRes.Output -join "`n").Trim()

    Write-Host ""
    Write-Host "  --- [ System Status Overview ] ---" -ForegroundColor DarkCyan
    if ($adminState -eq "running") {
        Write-Host "  [ADMIN PANEL]  : " -NoNewline
        Write-Host "UP and RUNNING" -ForegroundColor Green
        Write-Host "                   $details" -ForegroundColor DarkGray
        Write-Host "                   Public URL: http://$ServerIP (Port 80 / 8081)" -ForegroundColor DarkGreen
    } else {
        Write-Host "  [ADMIN PANEL]  : " -NoNewline
        Write-Host "DOWN / STOPPED" -ForegroundColor Yellow
        Write-Host "                   $details" -ForegroundColor DarkGray
        Write-Host "                   Visitors will see the maintenance fallback page." -ForegroundColor DarkYellow
    }

    Write-Host "  [MOBILE APPS]  : " -NoNewline
    if ($isMobileMaintenance) {
        Write-Host "IN MAINTENANCE MODE (Users blocked with MaintenanceScreen)" -ForegroundColor Yellow
    } else {
        Write-Host "NORMAL / ACTIVE (Users studying uninterrupted)" -ForegroundColor Green
    }
    Write-Host "                   API Endpoint: https://api.rightlearn.ir/api/v1" -ForegroundColor DarkGray
    Write-Host ""

    return @{ AdminState = $adminState; MobileMaintenance = $isMobileMaintenance }
}

function Stop-RemoteAdmin {
    param([string]$ChosenScope = "AdminOnly")

    if ($ChosenScope -eq "MobileOnly") {
        Write-Step "Enabling Maintenance Mode for Mobile Apps (Admin Panel remains up)..."
        Set-RemoteMobileMaintenance -Enable $true
        return
    }

    Write-Step "Taking DOWN the Admin Panel on production server ($ServerIP)..."
    $stopCmd = "docker stop leitner-admin-panel"
    $res = Invoke-SshCmd -Command $stopCmd

    if ($res.ExitCode -eq 0) {
        Write-Ok "Admin Panel container 'leitner-admin-panel' has been stopped successfully."
        Write-Info "Administrative web interface is now DOWN."
    } else {
        Write-Err "Failed to stop container: $($res.Output -join ' ')"
    }

    if ($ChosenScope -eq "Global") {
        Write-Step "Setting Mobile App Maintenance Mode to ACTIVE (Full Platform Down)..."
        Set-RemoteMobileMaintenance -Enable $true
        Write-Ok "Full Platform is now in MAINTENANCE / DOWN mode."
    } else {
        Write-Info "Mobile apps and background workers remain active and running."
    }
}

function Start-RemoteAdmin {
    param([bool]$RestoreMobile = $true)
    Write-Step "Bringing UP the Admin Panel on production server ($ServerIP)..."
    $startCmd = "docker start leitner-admin-panel"
    $res = Invoke-SshCmd -Command $startCmd

    if ($res.ExitCode -eq 0) {
        Write-Ok "Admin Panel container 'leitner-admin-panel' has been started successfully."
        Write-Info "Administrative interface is now UP and accessible at: http://$ServerIP"
    } else {
        Write-Err "Failed to start container: $($res.Output -join ' ')"
    }

    if ($RestoreMobile) {
        $isMaint = Get-RemoteMobileMaintenanceStatus
        if ($isMaint) {
            Write-Step "Deactivating Mobile App Maintenance Mode..."
            Set-RemoteMobileMaintenance -Enable $false
        }
    }
}

function Restart-RemoteAdmin {
    Write-Step "Restarting the Admin Panel on production server ($ServerIP)..."
    $restartCmd = "docker restart leitner-admin-panel"
    $res = Invoke-SshCmd -Command $restartCmd

    if ($res.ExitCode -eq 0) {
        Write-Ok "Admin Panel container 'leitner-admin-panel' restarted successfully."
    } else {
        Write-Err "Failed to restart container: $($res.Output -join ' ')"
    }
}

function Get-RemoteLogs {
    param([int]$Lines = 60)
    Write-Step "Fetching recent $Lines log lines from 'leitner-admin-panel'..."
    $logCmd = "docker logs --tail $Lines leitner-admin-panel"
    $res = Invoke-SshCmd -Command $logCmd
    Write-Host ""
    Write-Host "----------------- [ REMOTE LOGS START ] -----------------" -ForegroundColor DarkGray
    $res.Output | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
    Write-Host "------------------ [ REMOTE LOGS END ] ------------------" -ForegroundColor DarkGray
    Write-Host ""
}

function Deploy-MaintenanceFallback {
    Write-Step "Configuring server maintenance fallback for Admin Panel on $ServerIP..."
    $localHtml = Join-Path $ProjectRoot "deployment\maintenance.html"
    $localNginx = Join-Path $ProjectRoot "deployment\nginx.default.conf"

    if (-not (Test-Path $localHtml)) {
        Write-Err "maintenance.html not found at $localHtml"
        return
    }

    # Upload maintenance.html to /var/www/html/
    Write-Step "Uploading maintenance.html to /var/www/html/maintenance.html..."
    $scpArgs = @(
        "-i", $KeyPath,
        "-o", "StrictHostKeyChecking=no",
        $localHtml,
        "${ServerUser}@${ServerIP}:/var/www/html/maintenance.html"
    )
    & scp $scpArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Failed to upload maintenance.html via scp."
        return
    }

    # Upload & configure Nginx default site
    Write-Step "Updating remote Nginx default configuration..."
    $scpNginxArgs = @(
        "-i", $KeyPath,
        "-o", "StrictHostKeyChecking=no",
        $localNginx,
        "${ServerUser}@${ServerIP}:/etc/nginx/sites-available/default"
    )
    & scp $scpNginxArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Failed to upload nginx.default.conf via scp."
        return
    }

    # Test Nginx and reload
    Write-Step "Testing and reloading remote Nginx service..."
    $reloadCmd = "nginx -t && systemctl reload nginx"
    $res = Invoke-SshCmd -Command $reloadCmd
    if ($res.ExitCode -eq 0) {
        Write-Ok "Remote Nginx reloaded successfully. When Admin Panel is down, a branded maintenance page will display!"
    } else {
        Write-Err "Nginx reload failed: $($res.Output -join ' ')"
    }
}

# -- Local Actions ------------------------------------------------------------
function Get-LocalPortPid {
    param([int]$Port = 5173)
    $line = netstat -ano | Select-String ":$Port\s.*LISTENING" | Select-Object -First 1
    if ($line) {
        $pidStr = ($line.ToString().Trim() -split "\s+")[-1]
        return [int]$pidStr
    }
    return $null
}

function Get-LocalStatus {
    Write-Step "Checking Local Admin Panel status (port 5173)..."
    $pidNum = Get-LocalPortPid -Port 5173
    if ($pidNum) {
        Write-Ok "Local Admin Panel is RUNNING on PID $pidNum (http://localhost:5173)."
        return @{ State = "running"; Pid = $pidNum }
    } else {
        Write-Warn "Local Admin Panel is STOPPED / NOT LISTENING on port 5173."
        return @{ State = "exited"; Pid = $null }
    }
}

function Stop-LocalAdmin {
    Write-Step "Stopping Local Admin Panel..."
    $pidNum = Get-LocalPortPid -Port 5173
    if ($pidNum) {
        Stop-Process -Id $pidNum -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        Write-Ok "Killed local process PID $pidNum. Local Admin Panel is now DOWN."
    } else {
        Write-Info "No active process found listening on port 5173."
    }
}

function Start-LocalAdmin {
    Write-Step "Launching Local Admin Panel..."
    $launcher = Join-Path $ProjectRoot "scripts\start-admin.ps1"
    if (Test-Path $launcher) {
        & $launcher
    } else {
        Write-Err "start-admin.ps1 launcher not found at $launcher"
    }
}

function Restart-LocalAdmin {
    Stop-LocalAdmin
    Start-Sleep -Seconds 1
    Start-LocalAdmin
}

# -- Execution Dispatcher -----------------------------------------------------
function Execute-Action {
    param (
        [string]$Act,
        [string]$Tgt,
        [string]$Scp = "AdminOnly"
    )

    if ($Tgt -eq "Remote") {
        if (-not (Test-RemoteHost)) {
            Write-Err "Unable to reach remote server at $ServerIP via SSH."
            Write-Info "Please verify network connection and SSH key: $KeyPath"
            return
        }

        switch ($Act.ToLower()) {
            { $_ -in @("down", "stop") }               { Stop-RemoteAdmin -ChosenScope $Scp }
            { $_ -in @("up", "start") }                { Start-RemoteAdmin -RestoreMobile $true }
            "restart"                                  { Restart-RemoteAdmin }
            "status"                                   { [void](Get-RemoteStatus) }
            "logs"                                     { Get-RemoteLogs -Lines $Tail }
            "mobile-on"                                { Set-RemoteMobileMaintenance -Enable $true }
            "mobile-off"                               { Set-RemoteMobileMaintenance -Enable $false }
            "deploy-maintenance"                       { Deploy-MaintenanceFallback }
            default { Write-Err "Unrecognized action: $Act" }
        }
    } else {
        # Local target
        switch ($Act.ToLower()) {
            { $_ -in @("down", "stop") }               { Stop-LocalAdmin }
            { $_ -in @("up", "start") }                { Start-LocalAdmin }
            "restart"                                  { Restart-LocalAdmin }
            "status"                                   { [void](Get-LocalStatus) }
            default { Write-Err "Unrecognized action for local target: $Act" }
        }
    }
}

# -- Interactive Menu Loop ----------------------------------------------------
function Show-InteractiveMenu {
    $currentTgt = $Target

    while ($true) {
        Write-Header
        Write-Host "  Target Environment: " -NoNewline
        if ($currentTgt -eq "Remote") {
            Write-Host "REMOTE PRODUCTION ($ServerIP)" -ForegroundColor Cyan
        } else {
            Write-Host "LOCAL DEVELOPMENT (localhost:5173)" -ForegroundColor Yellow
        }
        Write-Host ""

        # Show brief status banner
        if ($currentTgt -eq "Remote") {
            $statusObj = Get-RemoteStatus
            $isMobileMaint = $statusObj.MobileMaintenance
        } else {
            [void](Get-LocalStatus)
            $isMobileMaint = $false
        }

        Write-Host "  Available Actions:" -ForegroundColor Magenta
        Write-Host "    [1] Take Admin Panel DOWN (Admin Only - Mobile Apps stay active)" -ForegroundColor Red
        Write-Host "    [2] FULL PLATFORM DOWN (Take Down Admin + Put Mobile Apps in Maintenance)" -ForegroundColor DarkRed
        if ($currentTgt -eq "Remote") {
            $toggleLabel = if ($isMobileMaint) { "Turn OFF Mobile App Maintenance (Bring Apps Back)" } else { "Turn ON Mobile App Maintenance (Show MaintenanceScreen)" }
            Write-Host "    [3] $toggleLabel" -ForegroundColor Yellow
        }
        Write-Host "    [4] Bring All Services UP (Start Admin + Restore Mobile App)" -ForegroundColor Green
        Write-Host "    [5] Restart Admin Panel" -ForegroundColor Cyan
        Write-Host "    [6] Check Full Status & Health" -ForegroundColor White
        if ($currentTgt -eq "Remote") {
            Write-Host "    [7] View Admin Panel Logs" -ForegroundColor Gray
            Write-Host "    [8] Deploy / Update Nginx Maintenance Fallback Page" -ForegroundColor DarkCyan
        }
        Write-Host "    [T] Switch Target (Remote <-> Local)" -ForegroundColor White
        Write-Host "    [Q] Quit" -ForegroundColor DarkGray
        Write-Host ""

        $choice = (Read-Host "  Enter choice").Trim().ToUpper()

        switch ($choice) {
            "1" { Execute-Action -Act "down" -Tgt $currentTgt -Scp "AdminOnly" }
            "2" { Execute-Action -Act "down" -Tgt $currentTgt -Scp "Global" }
            "3" {
                if ($currentTgt -eq "Remote") {
                    if ($isMobileMaint) {
                        Execute-Action -Act "mobile-off" -Tgt $currentTgt
                    } else {
                        Execute-Action -Act "mobile-on" -Tgt $currentTgt
                    }
                } else {
                    Write-Warn "Mobile maintenance toggle is only applicable to Remote target."
                }
            }
            "4" { Execute-Action -Act "up" -Tgt $currentTgt }
            "5" { Execute-Action -Act "restart" -Tgt $currentTgt }
            "6" { Execute-Action -Act "status" -Tgt $currentTgt }
            "7" { 
                if ($currentTgt -eq "Remote") {
                    Execute-Action -Act "logs" -Tgt $currentTgt
                } else {
                    Write-Warn "Logs option is only applicable to Remote Docker target."
                }
            }
            "8" {
                if ($currentTgt -eq "Remote") {
                    Execute-Action -Act "deploy-maintenance" -Tgt $currentTgt
                }
            }
            "T" {
                if ($currentTgt -eq "Remote") { $currentTgt = "Local" }
                else { $currentTgt = "Remote" }
                Write-Info "Switched target to: $currentTgt"
                Start-Sleep -Milliseconds 600
                continue
            }
            "Q" {
                Write-Info "Exiting Lifecycle Manager. Have a great day!"
                Write-Host ""
                exit 0
            }
            default {
                Write-Err "Invalid choice. Please select from the menu above."
            }
        }

        Write-Host ""
        Write-Host "  Press Enter to continue..." -ForegroundColor DarkGray
        [void][System.Console]::ReadLine()
    }
}

# -- Entry Point --------------------------------------------------------------
if ($Action -eq "interactive") {
    Show-InteractiveMenu
} else {
    Write-Header
    Execute-Action -Act $Action -Tgt $Target -Scp $Scope
    Write-Host ""
}
