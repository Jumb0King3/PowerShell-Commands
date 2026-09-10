# Update-AllApplications.ps1
# Upgrades all winget-managed applications on this device. Installs winget
# (App Installer) automatically if it isn't already present. This can
# trigger UAC prompts per application and take a while - requires typed
# confirmation before running.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Update-AllApplications_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

Write-Host "WARNING" -ForegroundColor Red
Write-Host "This will upgrade ALL winget-managed applications on $env:COMPUTERNAME."
Write-Host "This may take a while and can trigger UAC prompts per application."
Write-Host ""

$confirm = Read-Host "Type YES to continue (anything else cancels)"
if ($confirm -ne "YES") {
    Write-Host "Not confirmed. Cancelling." -ForegroundColor Yellow
    Stop-Transcript | Out-Null
    Read-Host "`nPress Enter to close this window"
    return
}

$winget = Get-Command winget.exe -ErrorAction SilentlyContinue

if (-not $winget) {
    Write-Host "`nWinget not detected. Attempting installation..." -ForegroundColor Cyan
    try {
        Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction Stop
        Write-Host "Winget installation completed." -ForegroundColor Green
        $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    }
    catch {
        Write-Host "FAILED TO INSTALL WINGET: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Install App Installer from the Microsoft Store manually, then re-run this script." -ForegroundColor Yellow
        Stop-Transcript | Out-Null
        Read-Host "`nPress Enter to close this window"
        return
    }
    if (-not $winget) {
        Write-Host "Winget still unavailable after installation attempt." -ForegroundColor Red
        Stop-Transcript | Out-Null
        Read-Host "`nPress Enter to close this window"
        return
    }
}

Write-Host "`nChecking for updates..." -ForegroundColor Cyan
Write-Host "`n===== AVAILABLE UPDATES BEFORE =====" -ForegroundColor Cyan
winget upgrade --include-unknown --accept-source-agreements

Write-Host "`n===== STARTING WINGET UPGRADE =====" -ForegroundColor Cyan
Write-Host "Updating applications (this may take a while, UAC prompts may appear)..." -ForegroundColor Cyan
winget upgrade --all --include-unknown --accept-package-agreements --accept-source-agreements

Write-Host "`n===== AVAILABLE UPDATES AFTER =====" -ForegroundColor Cyan
winget upgrade --include-unknown --accept-source-agreements

Write-Host "`nUpgrade completed." -ForegroundColor Green
Write-Host "Log saved to: $logFile" -ForegroundColor Cyan
Stop-Transcript | Out-Null
Read-Host "`nPress Enter to close this window"
