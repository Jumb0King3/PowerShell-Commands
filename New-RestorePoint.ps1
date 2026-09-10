# New-RestorePoint.ps1
# Creates a Windows System Restore point. Requires Administrator.
#
# NOTE: Windows normally limits Checkpoint-Computer to creating one restore
# point per 24 hours (to stop restore points from constantly overwriting
# each other). If you need to create more than one in a day for testing,
# you may need to temporarily adjust
# HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore\SystemRestorePointCreationFrequency
# (in minutes) - this script does not change that setting for you.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "New-RestorePoint_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

function Stop-ScriptHere {
    Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
    Stop-Transcript | Out-Null
    Read-Host "`nPress Enter to close this window"
}

# --- Elevation check ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Error: This script must be run as Administrator." -ForegroundColor Red
    Stop-ScriptHere
    return
}

$description = Read-Host "Enter a description for this restore point (press Enter with no input to use a default timestamp name)"
if ([string]::IsNullOrWhiteSpace($description)) {
    $description = "Manual restore point $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
}

Write-Host "`nCreating restore point: $description" -ForegroundColor Cyan

try {
    Checkpoint-Computer -Description $description -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
    Write-Host "Restore point created successfully." -ForegroundColor Green

    Write-Host "`nCurrent restore points:" -ForegroundColor Cyan
    Get-ComputerRestorePoint | Select-Object SequenceNumber, Description, CreationTime | Format-Table -AutoSize
}
catch {
    Write-Host "Error: Could not create restore point. $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "If this is because a restore point was already created in the last 24 hours, that is a normal Windows limit - see the note at the top of this script." -ForegroundColor Yellow
}

Stop-ScriptHere
