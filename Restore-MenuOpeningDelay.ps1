# Restore-MenuOpeningDelay.ps1
# Restores the "Menu Opening Delay" registry value to its state before
# Enable-FasterMenuOpening.ps1 was run, using the .reg backup that script
# created.
# Looks for the backup in <Drive>:\Recovery\Backups on a Ventoy USB (or the
# nearest removable drive). If none is found, prompts for the folder where
# the backup was saved. Requires typed confirmation before restoring.

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

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Restore-MenuOpeningDelay_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

function Stop-ScriptHere {
    Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
    Stop-Transcript | Out-Null
    Read-Host "`nPress Enter to close this window"
}

$displayName = "Menu Opening Delay"
$backupPrefix = "Enable-FasterMenuOpening_Backup_"

$backupRoot = Get-BackupRoot
if (-not $backupRoot) {
    Write-Host "Could not automatically detect the Ventoy USB (or any removable drive)." -ForegroundColor Yellow
    $backupRoot = Read-Host "Enter the folder path where the backup .reg file is saved (press Enter with no input to cancel)"
    if ([string]::IsNullOrWhiteSpace($backupRoot)) {
        Write-Host "No backup location provided. Cancelling." -ForegroundColor Red
        Stop-ScriptHere
        return
    }
}
if (-not (Test-Path $backupRoot)) {
    Write-Host "Error: Backup folder '$backupRoot' does not exist." -ForegroundColor Red
    Stop-ScriptHere
    return
}

$backupFile = Get-ChildItem -Path $backupRoot -Filter "$backupPrefix*.reg" -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-not $backupFile) {
    Write-Host "No backup found for '$displayName' in $backupRoot." -ForegroundColor Red
    Write-Host "Run Enable-FasterMenuOpening.ps1 first to create one." -ForegroundColor Yellow
    Stop-ScriptHere
    return
}

Write-Host "Found backup: $($backupFile.FullName)" -ForegroundColor Cyan
Write-Host "This will restore '$displayName' to its previous state." -ForegroundColor Yellow
$confirm = Read-Host "Type YES to continue (anything else cancels)"
if ($confirm -ne "YES") {
    Write-Host "Not confirmed. Cancelling." -ForegroundColor Yellow
    Stop-ScriptHere
    return
}

try {
    $importResult = reg.exe import $backupFile.FullName 2>&1
    if ($LASTEXITCODE -ne 0) { throw "reg.exe import failed: $importResult" }
    Write-Host "'$displayName' restored successfully." -ForegroundColor Green
    Write-Host "Sign out and back in for the change to take effect." -ForegroundColor Yellow
}
catch {
    Write-Host "Error: Could not restore the backup. $($_.Exception.Message)" -ForegroundColor Red
}

Stop-ScriptHere
