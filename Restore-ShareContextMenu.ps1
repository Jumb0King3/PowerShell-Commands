# Restore-ShareContextMenu.ps1
# Restores the "Share" context menu entry removed by
# Enable-RemoveShareContextMenu.ps1, using the backup that script created
# (a clixml recording whether the key existed, plus a .reg export of the
# HKEY_CLASSES_ROOT\*\shellex\ContextMenuHandlers\Sharing key if it did).
# Looks for the backup in <Drive>:\Recovery\Backups\RemoveShareContextMenu
# on a Ventoy USB (or the nearest removable drive). If none is found,
# prompts for the folder where the backup was saved. Requires typed
# confirmation and Administrator.

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
$logFile = Join-Path $logFolder "Restore-ShareContextMenu_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

function Stop-ScriptHere {
    Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
    Stop-Transcript | Out-Null
    Read-Host "`nPress Enter to close this window"
}

$SettingName = 'RemoveShareContextMenu'
$DisplayName = 'Share Context Menu'
$UserSid = ([Security.Principal.WindowsIdentity]::GetCurrent()).User.Value

$backupRoot = Get-BackupRoot
if (-not $backupRoot) {
    Write-Host "Could not automatically detect the Ventoy USB (or any removable drive)." -ForegroundColor Yellow
    $backupRoot = Read-Host "Enter the folder path where the backup is saved (press Enter with no input to cancel)"
    if ([string]::IsNullOrWhiteSpace($backupRoot)) {
        Write-Host "No backup location provided. Cancelling." -ForegroundColor Red
        Stop-ScriptHere
        return
    }
}

$backupFolder = Join-Path $backupRoot $SettingName
$stateFile = Join-Path $backupFolder "OriginalState.clixml"
$regFile = Join-Path $backupFolder "SharingKey.reg"

if (-not (Test-Path -LiteralPath $stateFile)) {
    Write-Host "No backup found for '$DisplayName' at $stateFile." -ForegroundColor Red
    Write-Host "Run Enable-RemoveShareContextMenu.ps1 first to create one." -ForegroundColor Yellow
    Stop-ScriptHere
    return
}

$state = Import-Clixml -LiteralPath $stateFile

if ($state.ComputerName -ne $env:COMPUTERNAME -or $state.UserSid -ne $UserSid) {
    Write-Host "Error: This backup belongs to a different computer or Windows user ($($state.ComputerName)) and will not be applied here." -ForegroundColor Red
    Stop-ScriptHere
    return
}

Write-Host "Found backup: $stateFile" -ForegroundColor Cyan
Write-Host "This will restore '$DisplayName' to its previous state." -ForegroundColor Yellow
$confirm = Read-Host "Type YES to continue (anything else cancels)"
if ($confirm -ne "YES") {
    Write-Host "Not confirmed. Cancelling." -ForegroundColor Yellow
    Stop-ScriptHere
    return
}

try {
    if ($state.KeyExisted) {
        if (-not (Test-Path -LiteralPath $regFile)) {
            throw "Backup record says the key existed, but the expected .reg file was not found at $regFile."
        }
        $importResult = reg.exe import $regFile 2>&1
        if ($LASTEXITCODE -ne 0) { throw "reg.exe import failed: $importResult" }
        Write-Host "'$DisplayName' restored successfully from $regFile." -ForegroundColor Green
    }
    else {
        Write-Host "The Share context menu key did not exist before the tweak was applied - nothing to restore." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "Error: Could not restore the backup. $($_.Exception.Message)" -ForegroundColor Red
}

Stop-ScriptHere
