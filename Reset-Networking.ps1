# Reset-Networking.ps1
# Flushes DNS, resets Winsock, and resets TCP/IP on this device.
# This is a disruptive network reset - it will interrupt active network
# connections and a restart is recommended afterward. Requires typed
# confirmation before running.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Reset-Networking_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

Write-Host "WARNING" -ForegroundColor Red
Write-Host "This will flush DNS, reset Winsock, and reset TCP/IP on $env:COMPUTERNAME."
Write-Host "Active network connections will be interrupted, and a restart is recommended afterward."
Write-Host ""

$confirm = Read-Host "Type YES to continue (anything else cancels)"
if ($confirm -ne "YES") {
    Write-Host "Not confirmed. Cancelling." -ForegroundColor Yellow
    Stop-Transcript | Out-Null
    Read-Host "`nPress Enter to close this window"
    return
}

Write-Host "`n===== FLUSH DNS =====" -ForegroundColor Cyan
ipconfig /flushdns

Write-Host "`n===== WINSOCK RESET =====" -ForegroundColor Cyan
netsh winsock reset

Write-Host "`n===== TCP/IP RESET =====" -ForegroundColor Cyan
netsh int ip reset

Write-Host "`nNetworking reset complete. Restart recommended." -ForegroundColor Green
Write-Host "Log saved to: $logFile" -ForegroundColor Cyan
Stop-Transcript | Out-Null
Read-Host "`nPress Enter to close this window"
