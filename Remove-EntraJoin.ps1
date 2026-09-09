# Remove-EntraJoin.ps1
# Removes the Entra ID join from this device (dsregcmd /leave).
# Shows before/after status. This is destructive to this device's Entra
# join - requires typed confirmation.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Remove-EntraJoin_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

Write-Host "WARNING" -ForegroundColor Red
Write-Host "This will remove the Entra ID join from $env:COMPUTERNAME."
Write-Host ""

$Confirm = Read-Host "Type LEAVE to continue (anything else cancels)"
if ($Confirm -ne "LEAVE") {
    Write-Host "Not confirmed. Cancelling." -ForegroundColor Yellow
    Stop-Transcript | Out-Null
    Read-Host "`nPress Enter to close this window"
    return
}

Write-Host "`n===== BEFORE =====" -ForegroundColor Cyan
dsregcmd /status

Write-Host "`n===== LEAVE COMMAND =====" -ForegroundColor Cyan
dsregcmd /leave

Write-Host "`n===== AFTER =====" -ForegroundColor Cyan
dsregcmd /status

Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
Stop-Transcript | Out-Null
Read-Host "`nPress Enter to close this window"
