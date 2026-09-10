# Enable-RemoveShareContextMenu.ps1
# Removes the "Share" entry from the right-click context menu.
# Backs up the target registry key to a Ventoy USB (or nearest removable
# drive) at <Drive>:\Recovery\Backups before making any change. If no such
# drive can be detected, prompts for a manual backup location instead.
#
# NOTE: The original script called a custom helper (Apply-RemoveShareContextMenu)
# whose internal logic wasn't available to reconstruct from, so this
# implements the standard, widely documented registry method for this tweak
# (overriding the Share verb's CLSID with an empty handler).
# Verify behavior on a test machine before wider rollout.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Enable-RemoveShareContextMenu_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

function Stop-ScriptHere {
    Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
    Stop-Transcript | Out-Null
    Read-Host "`nPress Enter to close this window"
}

function Get-BackupRoot {
    try {
        $ventoy = Get-Volume -ErrorAction Stop | Where-Object { $_.FileSystemLabel -eq 'Ventoy' -and $_.DriveLetter }
        if ($ventoy) { return "$($ventoy[0].DriveLetter):\Recovery\Backups" }
    }
    catch { }
    try {
        $removable = Get-Volume -ErrorAction Stop | Where-Object { $_.DriveType -eq 'Removable' -and $_.DriveLetter }
        if ($removable) { return "$($removable[0].DriveLetter):\Recovery\Backups" }
    }
    catch { }
    return $null
}

$regPath = 'HKCU:\Software\Classes\CLSID\{e2bf9676-5f8f-435c-97eb-11607a5bedf7}'
$regExePath = 'HKCU\Software\Classes\CLSID\{e2bf9676-5f8f-435c-97eb-11607a5bedf7}'

Write-Host "Applying tweak: Remove Share Context Menu Entry" -ForegroundColor Cyan

$backupRoot = Get-BackupRoot
if (-not $backupRoot) {
    Write-Host "Could not automatically detect the Ventoy USB (or any removable drive)." -ForegroundColor Yellow
    $backupRoot = Read-Host "Enter a folder path to save the backup to (press Enter with no input to cancel)"
    if ([string]::IsNullOrWhiteSpace($backupRoot)) {
        Write-Host "No backup location provided. Aborting without making any changes." -ForegroundColor Red
        Stop-ScriptHere
        return
    }
}
if (-not (Test-Path $backupRoot)) {
    try { New-Item -Path $backupRoot -ItemType Directory -Force -ErrorAction Stop | Out-Null }
    catch {
        Write-Host "Error: Could not create backup folder '$backupRoot'. $($_.Exception.Message)" -ForegroundColor Red
        Stop-ScriptHere
        return
    }
}

$backupFile = Join-Path $backupRoot "Enable-RemoveShareContextMenu_Backup_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').reg"
if (Test-Path $regPath) {
    try {
        $exportResult = reg.exe export $regExePath $backupFile /y 2>&1
        if ($LASTEXITCODE -eq 0) { Write-Host "Backed up existing key to: $backupFile" -ForegroundColor Green }
        else { Write-Host "Error: Backup failed ($exportResult). Aborting without making any changes." -ForegroundColor Red; Stop-ScriptHere; return }
    }
    catch { Write-Host "Error: Could not back up the registry key. $($_.Exception.Message)" -ForegroundColor Red; Stop-ScriptHere; return }
}
else {
    Write-Host "Key does not currently exist - nothing to back up yet. It will be created." -ForegroundColor Yellow
}

try {
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }
    Write-Host "Share context menu override key created." -ForegroundColor Green

    Write-Host "Restarting Explorer for the change to take effect..." -ForegroundColor Cyan
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Start-Process explorer.exe
    Write-Host "Explorer restarted." -ForegroundColor Green
}
catch {
    Write-Host "Error: Could not apply tweak. $($_.Exception.Message)" -ForegroundColor Red
}

Stop-ScriptHere
