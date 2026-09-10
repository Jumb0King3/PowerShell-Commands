# Restore-FromRestorePoint.ps1
# Lists available System Restore points and rolls Windows back to whichever
# one you choose. Requires Administrator and typed confirmation.
#
# WARNING: Performing the restore will AUTOMATICALLY REBOOT this computer
# to complete the rollback - there is no way to do this without a restart,
# it is a Windows limitation. Save/close anything important before
# confirming.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Restore-FromRestorePoint_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
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

$restorePoints = @(Get-ComputerRestorePoint | Sort-Object SequenceNumber -Descending)

if ($restorePoints.Count -eq 0) {
    Write-Host "No restore points were found on this computer." -ForegroundColor Yellow
    Stop-ScriptHere
    return
}

Write-Host "Available restore points:" -ForegroundColor Cyan
$restorePoints | Select-Object SequenceNumber, Description, CreationTime | Format-Table -AutoSize

$selection = Read-Host "`nEnter the Sequence Number of the restore point to use (press Enter with no input to cancel)"
if ([string]::IsNullOrWhiteSpace($selection)) {
    Write-Host "No selection made. Cancelling." -ForegroundColor Yellow
    Stop-ScriptHere
    return
}

$chosen = $restorePoints | Where-Object { $_.SequenceNumber -eq [int]$selection }
if (-not $chosen) {
    Write-Host "No restore point found with Sequence Number $selection." -ForegroundColor Red
    Stop-ScriptHere
    return
}

Write-Host "`nYou selected:" -ForegroundColor Cyan
Write-Host "  Sequence Number: $($chosen.SequenceNumber)"
Write-Host "  Description:     $($chosen.Description)"
Write-Host "  Created:         $($chosen.CreationTime)"

Write-Host "`nWARNING: This will roll Windows back to this restore point and AUTOMATICALLY REBOOT the computer to complete the process." -ForegroundColor Red
Write-Host "Save and close anything important before continuing." -ForegroundColor Red
$confirm = Read-Host "Type YES to continue (anything else cancels)"
if ($confirm -ne "YES") {
    Write-Host "Not confirmed. Cancelling." -ForegroundColor Yellow
    Stop-ScriptHere
    return
}

try {
    $restorePointObject = Get-CimInstance -Namespace root\default -ClassName SystemRestore |
        Where-Object { $_.SequenceNumber -eq $chosen.SequenceNumber }

    if (-not $restorePointObject) {
        throw "Could not locate the restore point via CIM (SequenceNumber $($chosen.SequenceNumber))."
    }

    Write-Host "`nStarting restore. The computer will reboot shortly to complete this..." -ForegroundColor Cyan
    Stop-Transcript | Out-Null
    Invoke-CimMethod -InputObject $restorePointObject -MethodName Restore
}
catch {
    Start-Transcript -Path $logFile -Append | Out-Null
    Write-Host "Error: Could not start the restore. $($_.Exception.Message)" -ForegroundColor Red
    Stop-ScriptHere
}
