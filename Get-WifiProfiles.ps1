# Get-WifiProfiles.ps1
# Lists saved Wi-Fi profiles and current wireless interface status on this
# device.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Get-WifiProfiles_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

Write-Host "Collecting Wi-Fi profiles for $env:COMPUTERNAME ..." -ForegroundColor Cyan

try {
    Write-Host "`n===== WIFI PROFILES =====" -ForegroundColor Cyan
    netsh wlan show profiles

    Write-Host "`n===== WIFI INTERFACES =====" -ForegroundColor Cyan
    netsh wlan show interfaces
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
Stop-Transcript | Out-Null
Read-Host "`nPress Enter to close this window"
