# Get-StartupApps.ps1
# Collects startup applications from WMI and the standard Run registry
# keys (current user, local machine, and 32-bit local machine).

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Get-StartupApps_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

Write-Host "Collecting startup application information for $env:COMPUTERNAME ..." -ForegroundColor Cyan

try {
    Write-Host "`n===== WMI STARTUP COMMANDS =====" -ForegroundColor Cyan
    Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, Location, User | Sort-Object Name | Format-Table -AutoSize

    $runKeys = @(
        @{ Label = "CURRENT USER RUN KEY"; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" }
        @{ Label = "LOCAL MACHINE RUN KEY"; Path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" }
        @{ Label = "32-BIT LOCAL MACHINE RUN KEY"; Path = "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run" }
    )

    foreach ($runKey in $runKeys) {
        Write-Host "`n===== $($runKey.Label) =====" -ForegroundColor Cyan
        if (Test-Path $runKey.Path) {
            Get-ItemProperty $runKey.Path | Format-List
        }
        else {
            Write-Host "Key was not found." -ForegroundColor Yellow
        }
    }
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
Stop-Transcript | Out-Null
Read-Host "`nPress Enter to close this window"
