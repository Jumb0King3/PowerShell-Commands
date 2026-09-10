# Remove-NetworkPrinters.ps1
# Removes all network (connection-type) printers from this device. Does
# not touch locally attached or directly-IP printers. Requires typed
# confirmation before running.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Remove-NetworkPrinters_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

$printers = Get-Printer | Where-Object { $_.Type -eq "Connection" }

if (-not $printers) {
    Write-Host "No network printers found." -ForegroundColor Yellow
    Stop-Transcript | Out-Null
    Read-Host "`nPress Enter to close this window"
    return
}

Write-Host "The following network printers will be removed from $env:COMPUTERNAME :" -ForegroundColor Yellow
$printers | Format-Table Name, DriverName, PortName -AutoSize

$confirm = Read-Host "Type YES to continue (anything else cancels)"
if ($confirm -ne "YES") {
    Write-Host "Not confirmed. Cancelling." -ForegroundColor Yellow
    Stop-Transcript | Out-Null
    Read-Host "`nPress Enter to close this window"
    return
}

foreach ($printer in $printers) {
    try {
        Remove-Printer -Name $printer.Name -ErrorAction Stop
        Write-Host "Removed: $($printer.Name)" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed: $($printer.Name) - $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
Stop-Transcript | Out-Null
Read-Host "`nPress Enter to close this window"
