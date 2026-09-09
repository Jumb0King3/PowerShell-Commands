# Update-PRT.ps1
# Refreshes this device's Primary Refresh Token (dsregcmd /refreshprt).

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Update-PRT_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

Write-Host "Refreshing PRT on $env:COMPUTERNAME ..." -ForegroundColor Cyan
Write-Host ""

dsregcmd /refreshprt

Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
Stop-Transcript | Out-Null
Read-Host "`nPress Enter to close this window"
