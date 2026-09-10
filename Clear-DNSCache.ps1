# Clear-DNSCache.ps1
# Flushes the local DNS resolver cache on this device.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Clear-DNSCache_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

Write-Host "Flushing local DNS cache on $env:COMPUTERNAME ..." -ForegroundColor Cyan
Write-Host ""

ipconfig /flushdns

Write-Host "`nDone." -ForegroundColor Green
Write-Host "Log saved to: $logFile" -ForegroundColor Cyan
Stop-Transcript | Out-Null
Read-Host "`nPress Enter to close this window"
