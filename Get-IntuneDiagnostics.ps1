# Get-IntuneDiagnostics.ps1
# Collects local Intune/Entra diagnostics for this device: computer info,
# Entra join status, Intune Management Extension logs, and an MDM
# diagnostics CAB file - all saved into one timestamped folder.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }

$outputFolder = Join-Path $logFolder "IntuneDiagnostics_$env:COMPUTERNAME`_$(Get-Date -Format 'yyyy-MM-dd_HHmmss')"
New-Item -Path $outputFolder -ItemType Directory -Force | Out-Null

Write-Host "Collecting Intune diagnostics for $env:COMPUTERNAME ..." -ForegroundColor Cyan
Write-Host "This may take a moment.`n"

Write-Host "Gathering computer info..." -ForegroundColor Cyan
Get-ComputerInfo | Out-File (Join-Path $outputFolder "DeviceInfo.txt")

Write-Host "Gathering Entra join status..." -ForegroundColor Cyan
dsregcmd /status | Out-File (Join-Path $outputFolder "EntraStatus.txt")

$imeLogPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"
if (Test-Path $imeLogPath) {
    Write-Host "Copying Intune Management Extension logs..." -ForegroundColor Cyan
    Copy-Item -Path "$imeLogPath\*" -Destination $outputFolder -Recurse -Force -ErrorAction SilentlyContinue
}
else {
    Write-Host "Intune Management Extension log folder not found - skipping." -ForegroundColor Yellow
}

Write-Host "Running mdmdiagnosticstool.exe (this can take a minute)..." -ForegroundColor Cyan
try {
    mdmdiagnosticstool.exe -area DeviceEnrollment,DeviceProvisioning,Autopilot -cab (Join-Path $outputFolder "MDMDiagnostics.cab")
}
catch {
    $_.Exception.Message | Out-File (Join-Path $outputFolder "MDMDiagnostics-Error.txt")
    Write-Host "mdmdiagnosticstool.exe failed - see MDMDiagnostics-Error.txt for details." -ForegroundColor Red
}

Write-Host "`nDiagnostics saved to:" -ForegroundColor Green
Write-Host $outputFolder -ForegroundColor Yellow
Read-Host "`nPress Enter to close this window"
