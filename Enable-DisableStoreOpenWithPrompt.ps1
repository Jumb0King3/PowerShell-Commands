# Enable-DisableStoreOpenWithPrompt.ps1
# Applies the "Disable Store Open With Prompt" tweak.
# Backs up the target registry key to a Ventoy USB (or nearest removable
# drive) at <Drive>:\Recovery\Backups before making any change. If no such
# drive can be detected, prompts for a manual backup location instead.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Enable-DisableStoreOpenWithPrompt_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
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

$regPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'
$regExePath = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer'
$regName = 'NoUseStoreOpenWith'
$newValue = 1
$propertyType = 'DWord'

Write-Host "Applying tweak: Disable Store Open With Prompt" -ForegroundColor Cyan

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

$backupFile = Join-Path $backupRoot "Enable-DisableStoreOpenWithPrompt_Backup_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').reg"
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

if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }

try {
    $before = (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue).$regName
    New-ItemProperty -Path $regPath -Name $regName -Value $newValue -PropertyType $propertyType -Force -ErrorAction Stop | Out-Null
    Write-Host "Set '$regName' at $regPath from '$before' to '$newValue'." -ForegroundColor Green
}
catch {
    Write-Host "Error: Could not apply tweak. $($_.Exception.Message)" -ForegroundColor Red
}

Stop-ScriptHere
