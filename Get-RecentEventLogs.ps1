# Get-RecentEventLogs.ps1
# Collects recent Windows Application/System errors and warnings from the
# last 7 days (up to 250 events).

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Get-RecentEventLogs_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

Write-Host "Collecting recent Windows errors/warnings (last 7 days) for $env:COMPUTERNAME ..." -ForegroundColor Cyan

try {
    Get-WinEvent -FilterHashtable @{ LogName = @("Application", "System"); Level = 1,2,3; StartTime = (Get-Date).AddDays(-7) } -ErrorAction Stop |
        Select-Object -First 250 TimeCreated, LogName, Id, LevelDisplayName, ProviderName, Message |
        Format-List
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
Stop-Transcript | Out-Null
Read-Host "`nPress Enter to close this window"
