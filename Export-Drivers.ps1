# Export-Drivers.ps1
# Exports all currently installed device drivers on this device to a
# Ventoy USB (or the nearest removable drive) at <Drive>:\Recovery\Drivers,
# matching the same backup-drive convention used by the registry tweak
# scripts. If no such drive can be detected, prompts for a manual location.

function Get-RecoveryRoot {
    try {
        $ventoy = Get-Volume -ErrorAction Stop | Where-Object { $_.FileSystemLabel -eq 'Ventoy' -and $_.DriveLetter }
        if ($ventoy) { return "$($ventoy[0].DriveLetter):\Recovery" }
    }
    catch { }
    try {
        $removable = Get-Volume -ErrorAction Stop | Where-Object { $_.DriveType -eq 'Removable' -and $_.DriveLetter }
        if ($removable) { return "$($removable[0].DriveLetter):\Recovery" }
    }
    catch { }
    return $null
}

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Export-Drivers_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

function Stop-ScriptHere {
    Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
    Stop-Transcript | Out-Null
    Read-Host "`nPress Enter to close this window"
}

$recoveryRoot = Get-RecoveryRoot
if (-not $recoveryRoot) {
    Write-Host "Could not automatically detect the Ventoy USB (or any removable drive)." -ForegroundColor Yellow
    $recoveryRoot = Read-Host "Enter a folder path to save exported drivers to (press Enter with no input to cancel)"
    if ([string]::IsNullOrWhiteSpace($recoveryRoot)) {
        Write-Host "No location provided. Cancelling." -ForegroundColor Red
        Stop-ScriptHere
        return
    }
}

$driverFolderRoot = Join-Path $recoveryRoot "Drivers"
if (-not (Test-Path $driverFolderRoot)) {
    try { New-Item -Path $driverFolderRoot -ItemType Directory -Force -ErrorAction Stop | Out-Null }
    catch {
        Write-Host "Error: Could not create folder '$driverFolderRoot'. $($_.Exception.Message)" -ForegroundColor Red
        Stop-ScriptHere
        return
    }
}

$driverFolder = Join-Path $driverFolderRoot ("$env:COMPUTERNAME-{0:yyyyMMdd_HHmmss}" -f (Get-Date))
New-Item -Path $driverFolder -ItemType Directory -Force | Out-Null

Write-Host "Exporting drivers from $env:COMPUTERNAME to $driverFolder ..." -ForegroundColor Cyan

try {
    Export-WindowsDriver -Online -Destination $driverFolder
    Write-Host "`nDrivers exported to: $driverFolder" -ForegroundColor Green
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Stop-ScriptHere
