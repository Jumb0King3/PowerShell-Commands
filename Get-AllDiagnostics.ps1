# Get-AllDiagnostics.ps1
# Collects a broad diagnostic snapshot in one pass: system info, BitLocker
# status, Entra join status, network config, adapters, printers, recent
# Windows updates, and Intune Management Extension logs (if present) - all
# saved into one timestamped folder instead of running several separate
# scripts.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }

$outputFolder = Join-Path $logFolder "AllDiagnostics_$env:COMPUTERNAME`_$(Get-Date -Format 'yyyy-MM-dd_HHmmss')"
New-Item -Path $outputFolder -ItemType Directory -Force | Out-Null

Write-Host "Collecting diagnostics for $env:COMPUTERNAME ..." -ForegroundColor Cyan
Write-Host "This may take a moment.`n"

Write-Host "Gathering system info..." -ForegroundColor Cyan
Get-ComputerInfo | Out-File (Join-Path $outputFolder "SystemInfo.txt")

Write-Host "Gathering BitLocker status..." -ForegroundColor Cyan
try { Get-BitLockerVolume | Format-List | Out-File (Join-Path $outputFolder "BitLocker.txt") }
catch { "FAILED: $($_.Exception.Message)" | Out-File (Join-Path $outputFolder "BitLocker.txt") }

Write-Host "Gathering Entra join status..." -ForegroundColor Cyan
dsregcmd /status | Out-File (Join-Path $outputFolder "EntraStatus.txt")

Write-Host "Gathering network configuration..." -ForegroundColor Cyan
ipconfig /all | Out-File (Join-Path $outputFolder "IPConfig.txt")
try { Get-NetAdapter | Format-Table -AutoSize | Out-String | Out-File (Join-Path $outputFolder "Adapters.txt") }
catch { "FAILED: $($_.Exception.Message)" | Out-File (Join-Path $outputFolder "Adapters.txt") }

Write-Host "Gathering printer info..." -ForegroundColor Cyan
try { Get-Printer | Format-Table -AutoSize | Out-String | Out-File (Join-Path $outputFolder "Printers.txt") }
catch { "FAILED: $($_.Exception.Message)" | Out-File (Join-Path $outputFolder "Printers.txt") }

Write-Host "Gathering recent updates..." -ForegroundColor Cyan
try {
    Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 50 |
        Format-Table -AutoSize | Out-String | Out-File (Join-Path $outputFolder "RecentUpdates.txt")
}
catch { "FAILED: $($_.Exception.Message)" | Out-File (Join-Path $outputFolder "RecentUpdates.txt") }

$imeLogPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"
if (Test-Path $imeLogPath) {
    Write-Host "Copying Intune Management Extension logs..." -ForegroundColor Cyan
    $intuneFolder = Join-Path $outputFolder "IntuneLogs"
    New-Item -Path $intuneFolder -ItemType Directory -Force | Out-Null
    Copy-Item -Path "$imeLogPath\*" -Destination $intuneFolder -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "`nDiagnostics saved to:" -ForegroundColor Green
Write-Host $outputFolder -ForegroundColor Yellow
Read-Host "`nPress Enter to close this window"
