# Get-InstalledApps.ps1
# Lists installed applications (from the standard uninstall registry keys)
# and exports them to a CSV in Documents\Scripts Logs.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$reportFile = Join-Path $logFolder "$env:COMPUTERNAME-InstalledApps_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').csv"

Write-Host "Collecting installed applications for $env:COMPUTERNAME ..." -ForegroundColor Cyan

$registryPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

try {
    $apps = Get-ItemProperty $registryPaths -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName } |
        Select-Object DisplayName, DisplayVersion, Publisher, InstallDate |
        Sort-Object DisplayName

    $apps | Export-Csv -Path $reportFile -NoTypeInformation
    $apps | Format-Table -AutoSize

    Write-Host "`nInstalled applications report saved to: $reportFile" -ForegroundColor Green
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Read-Host "`nPress Enter to close this window"
