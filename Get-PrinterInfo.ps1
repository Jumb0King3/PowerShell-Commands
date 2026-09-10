# Get-PrinterInfo.ps1
# Lists all printers configured on this device.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Get-PrinterInfo_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

Write-Host "Collecting printer information for $env:COMPUTERNAME ..." -ForegroundColor Cyan

try {
    Get-Printer | Select-Object Name, Type, DriverName, PortName, Shared, Published, PrinterStatus |
        Format-Table -AutoSize
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
Stop-Transcript | Out-Null
Read-Host "`nPress Enter to close this window"
