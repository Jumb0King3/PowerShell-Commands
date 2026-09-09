# Get-EntraJoinStatus.ps1
# Reports this device's Entra ID join / registration status (dsregcmd /status).

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Get-EntraJoinStatus_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

Write-Host "Gathering Entra join status for $env:COMPUTERNAME ..." -ForegroundColor Cyan
Write-Host ""

dsregcmd /status

Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
Stop-Transcript | Out-Null
Read-Host "`nPress Enter to close this window"
