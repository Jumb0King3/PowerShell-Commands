# Start-IntuneSync.ps1
# Triggers an Intune policy sync on this device by starting the
# EnterpriseMgmt scheduled tasks.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Start-IntuneSync_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

Write-Host "Attempting Intune sync on $env:COMPUTERNAME ..." -ForegroundColor Cyan
Write-Host ""

$tasks = Get-ScheduledTask | Where-Object { $_.TaskPath -like "*EnterpriseMgmt*" }

if (-not $tasks) {
    Write-Host "No EnterpriseMgmt scheduled tasks found. This device may not be Intune-enrolled." -ForegroundColor Yellow
}
else {
    foreach ($task in $tasks) {
        try {
            Start-ScheduledTask -InputObject $task -ErrorAction Stop
            Write-Host "STARTED: $($task.TaskName)" -ForegroundColor Green
        }
        catch {
            Write-Host "SKIPPED: $($task.TaskName) - $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    Write-Host "`nIntune sync tasks processed." -ForegroundColor Green
}

Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
Stop-Transcript | Out-Null
Read-Host "`nPress Enter to close this window"
