# Enable-RemoveShareContextMenu.ps1
# Removes the "Share" entry from the right-click context menu by deleting
# the HKEY_CLASSES_ROOT\*\shellex\ContextMenuHandlers\Sharing key entirely.
# Backs up whether the key existed via Export-Clixml, and if it did, also
# exports the key itself to a .reg file for a full restore - both saved to
# a Ventoy USB (or nearest removable drive) at
# <Drive>:\Recovery\Backups\RemoveShareContextMenu\ before making any
# change. Skips re-backing-up if a backup already exists there. If no such
# drive can be detected, prompts for a manual backup location. Requires
# Administrator.

#Requires -RunAsAdministrator

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
$logFile = Join-Path $logFolder "Enable-RemoveShareContextMenu_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

function Stop-ScriptHere {
    Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
    Stop-Transcript | Out-Null
    Read-Host "`nPress Enter to close this window"
}

$SettingName = 'RemoveShareContextMenu'
$DisplayName = 'Share Context Menu'
$RegistryPath = 'Registry::HKEY_CLASSES_ROOT\*\shellex\ContextMenuHandlers\Sharing'
$RegExePath = 'HKEY_CLASSES_ROOT\*\shellex\ContextMenuHandlers\Sharing'
$UserSid = ([Security.Principal.WindowsIdentity]::GetCurrent()).User.Value

Write-Host "Applying tweak: Remove $DisplayName" -ForegroundColor Cyan

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

$backupFolder = Join-Path $backupRoot $SettingName
if (-not (Test-Path $backupFolder)) {
    try { New-Item -Path $backupFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null }
    catch {
        Write-Host "Error: Could not create backup folder '$backupFolder'. $($_.Exception.Message)" -ForegroundColor Red
        Stop-ScriptHere
        return
    }
}
$stateFile = Join-Path $backupFolder "OriginalState.clixml"
$regFile = Join-Path $backupFolder "SharingKey.reg"

try {
    if (-not (Test-Path -LiteralPath $stateFile)) {
        $KeyExisted = Test-Path $RegistryPath
        [pscustomobject]@{
            FormatVersion = 1; ComputerName = $env:COMPUTERNAME; UserSid = $UserSid; KeyExisted = $KeyExisted
        } | Export-Clixml -LiteralPath $stateFile

        if ($KeyExisted) {
            $exportResult = reg.exe export $RegExePath $regFile /y 2>&1
            if ($LASTEXITCODE -ne 0) { throw "Registry export failed: $exportResult" }
        }
        Write-Host "Original state backed up to: $stateFile" -ForegroundColor Green
    }
    else {
        Write-Host "An original-state backup already exists at $stateFile and was not overwritten." -ForegroundColor Yellow
    }

    if (Test-Path $RegistryPath) {
        Remove-Item $RegistryPath -Recurse -Force
    }

    Write-Host "'$DisplayName' was removed successfully." -ForegroundColor Green
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Stop-ScriptHere
