# Get-OfficeVersion.ps1
# Reports the installed Microsoft 365 / Office Click-to-Run version and
# update channel on this device.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Get-OfficeVersion_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

$officeConfigPath = "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration"

Write-Host "Checking Office version on $env:COMPUTERNAME ..." -ForegroundColor Cyan

if (Test-Path $officeConfigPath) {
    Get-ItemProperty $officeConfigPath |
        Select-Object ProductReleaseIds, ClientVersionToReport, VersionToReport, CDNBaseUrl, UpdateChannel, Platform, InstallationPath |
        Format-List
}
else {
    Write-Host "Office Click-to-Run configuration was not found." -ForegroundColor Yellow
}

Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
Stop-Transcript | Out-Null
Read-Host "`nPress Enter to close this window"
