# Clear-PrintQueue.ps1
# Stops the Print Spooler, clears all pending/stuck print jobs, and
# restarts the spooler. Requires typed confirmation before running.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Clear-PrintQueue_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

Write-Host "WARNING" -ForegroundColor Red
Write-Host "This will stop the Print Spooler, clear ALL pending print jobs on $env:COMPUTERNAME, then restart it."
Write-Host ""

$confirm = Read-Host "Type YES to continue (anything else cancels)"
if ($confirm -ne "YES") {
    Write-Host "Not confirmed. Cancelling." -ForegroundColor Yellow
    Stop-Transcript | Out-Null
    Read-Host "`nPress Enter to close this window"
    return
}

try {
    Write-Host "`nStopping Print Spooler..." -ForegroundColor Cyan
    Stop-Service Spooler -Force -ErrorAction Stop

    $spoolFolder = "$env:SystemRoot\System32\spool\PRINTERS"
    if (Test-Path $spoolFolder) {
        Remove-Item -Path "$spoolFolder\*" -Force -Recurse -ErrorAction SilentlyContinue
        Write-Host "Print queue cleared." -ForegroundColor Green
    }

    Write-Host "Starting Print Spooler..." -ForegroundColor Cyan
    Start-Service Spooler -ErrorAction Stop

    Write-Host "`nSUCCESS: Print queue cleared successfully." -ForegroundColor Green
}
catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
Stop-Transcript | Out-Null
Read-Host "`nPress Enter to close this window"
