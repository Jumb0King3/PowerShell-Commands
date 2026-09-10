# Get-RunningServices.ps1
# Collects all Windows services and their state, exporting to CSV, with a
# summary of running vs. stopped-automatic services.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$reportFile = Join-Path $logFolder "$env:COMPUTERNAME-RunningServices_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').csv"

Write-Host "Collecting service information for $env:COMPUTERNAME ..." -ForegroundColor Cyan

try {
    $services = Get-CimInstance Win32_Service |
        Select-Object Name, DisplayName, State, StartMode, StartName, ProcessId, PathName |
        Sort-Object State, DisplayName

    $services | Export-Csv -Path $reportFile -NoTypeInformation -Encoding UTF8

    $runningCount = @($services | Where-Object { $_.State -eq "Running" }).Count
    $stoppedAutoCount = @($services | Where-Object { $_.State -eq "Stopped" -and $_.StartMode -eq "Auto" }).Count

    Write-Host "Running services: $runningCount" -ForegroundColor Green
    Write-Host "Stopped automatic services: $stoppedAutoCount" -ForegroundColor Yellow
    Write-Host "`nReport saved to: $reportFile" -ForegroundColor Green
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Read-Host "`nPress Enter to close this window"
