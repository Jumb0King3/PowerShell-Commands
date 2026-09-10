# Get-BatteryReport.ps1
# Generates a Windows battery report (HTML) for this device.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$reportFile = Join-Path $logFolder "$env:COMPUTERNAME-BatteryReport_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').html"

Write-Host "Generating battery report for $env:COMPUTERNAME ..." -ForegroundColor Cyan

try {
    powercfg /batteryreport /output $reportFile
    Write-Host "`nBattery report saved to: $reportFile" -ForegroundColor Green
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Read-Host "`nPress Enter to close this window"
