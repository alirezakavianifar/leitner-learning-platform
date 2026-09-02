# =============================================================================
#  Leitner Learning Platform - Admin & Platform Down Shortcut
#  Usage:
#    .\scripts\admin-down.ps1                                # Interactive menu
#    .\scripts\admin-down.ps1 down                           # Admin only down
#    .\scripts\admin-down.ps1 down -Scope Global             # Admin + Mobile App down
#    .\scripts\admin-down.ps1 mobile-on                      # Mobile App maintenance ON
#    .\scripts\admin-down.ps1 mobile-off                     # Mobile App maintenance OFF
#    .\scripts\admin-down.ps1 up                             # Bring all services UP
#    .\scripts\admin-down.ps1 status                         # Check system status
#    .\scripts\admin-down.ps1 restart                        # Restart admin panel
# =============================================================================

[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [ValidateSet("down", "stop", "up", "start", "restart", "status", "logs", "deploy-maintenance", "mobile-on", "mobile-off", "interactive")]
    [string]$Action = "interactive",

    [Parameter(Position = 1)]
    [ValidateSet("AdminOnly", "Global", "MobileOnly")]
    [string]$Scope = "AdminOnly",

    [Parameter(Position = 2)]
    [ValidateSet("Remote", "Local")]
    [string]$Target = "Remote",

    [string]$ServerIP = "45.94.215.188",
    [string]$ServerUser = "root",
    [string]$KeyPath = "C:\Users\Administrator\.ssh\id_rsa_deploy",
    [int]$Tail = 60
)

$scriptPath = Join-Path $PSScriptRoot "manage-admin.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Error "Underlying management script not found at: $scriptPath"
    exit 1
}

& $scriptPath -Action $Action -Scope $Scope -Target $Target -ServerIP $ServerIP -ServerUser $ServerUser -KeyPath $KeyPath -Tail $Tail
