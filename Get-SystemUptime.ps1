# Get-SystemUptime.ps1
# Reports how long this device has been running since its last boot.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Get-SystemUptime_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

try {
    $lastBoot = (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).LastBootUpTime
    $uptime = (Get-Date) - $lastBoot

    Write-Host "Computer: $env:COMPUTERNAME" -ForegroundColor Cyan
    Write-Host "Last boot: $lastBoot"
    Write-Host "System has been up for: $($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m" -ForegroundColor Green
}
catch {
    Write-Host "Error: Could not retrieve system uptime. $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
Stop-Transcript | Out-Null
Read-Host "`nPress Enter to close this window"
