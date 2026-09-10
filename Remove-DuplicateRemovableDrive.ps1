<#
.SYNOPSIS
    Removes the duplicate removable-drive entry from File Explorer's navigation
    pane by setting System.IsPinnedToNameSpaceTree = 0 under the "Removable
    Drives" delegate folder CLSID.

.DESCRIPTION
    Target key:   HKEY_CURRENT_USER\Software\Classes\CLSID\{F5FB2C77-0E2F-4A16-A381-3E560C68BC83}
    Target value: System.IsPinnedToNameSpaceTree (DWORD) = 0

    This is a per-user (HKCU) change, so no administrator elevation is required.
    It does not disable or remove the drive itself - it remains accessible
    normally under This PC.

    Safe to run repeatedly (idempotent) - if the value is already 0, it will
    report that and skip re-writing it, then still restart Explorer if needed.

    Before making any change, the existing key (if present) is exported to a
    timestamped .reg backup file on a Ventoy USB (or the nearest removable
    drive, detected regardless of drive letter) at <Drive>:\Recovery\Backups.
    If no such drive can be found, you will be prompted for a manual backup
    location instead.

.NOTES
    Verification note: the CLSID {F5FB2C77-0E2F-4A16-A381-3E560C68BC83} is
    confirmed as the "Removable Drives" delegate folder, and
    System.IsPinnedToNameSpaceTree is a genuine, Microsoft-documented shell
    property used for pinning/unpinning namespace folders. The most widely
    tested community fixes for this specific duplicate-drive symptom instead
    remove the HKLM DelegateFolders registration or modify a ShellFolder
    "Attributes" value - not this exact value. This script implements what
    was requested; if it does not resolve the duplicate on your system, that
    alternative approach may be needed instead.
#>

$ErrorActionPreference = 'Stop'

$RegPath      = 'HKCU:\Software\Classes\CLSID\{F5FB2C77-0E2F-4A16-A381-3E560C68BC83}'
$RegExePath   = 'HKCU\Software\Classes\CLSID\{F5FB2C77-0E2F-4A16-A381-3E560C68BC83}'
$ValueName    = 'System.IsPinnedToNameSpaceTree'
$DesiredValue = 0

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }

$timestamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$logFile = Join-Path $logFolder "Remove-DuplicateRemovableDrive_$timestamp.txt"
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

Write-Host "Remove Duplicate Removable Drive Entry" -ForegroundColor Cyan
Write-Host "Target key:   $RegPath"
Write-Host "Target value: $ValueName`n"

# --- Permission check ---
# This key lives under HKEY_CURRENT_USER, so administrator elevation is NOT
# required - it only affects the currently signed-in user's own profile.
try {
    if (-not (Test-Path "HKCU:\Software\Classes")) { throw "Cannot access HKCU:\Software\Classes" }
    Write-Host "Running as: $env:USERDOMAIN\$env:USERNAME (elevation not required for this change)." -ForegroundColor Green
}
catch {
    Write-Host "Error: Could not access the current user's registry hive. $($_.Exception.Message)" -ForegroundColor Red
    Stop-ScriptHere
    return
}

# --- Locate the Ventoy/removable USB (or ask) and back up the key before changing anything ---
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

$backupFile = Join-Path $backupRoot "RemovableDrivesCLSID_Backup_$timestamp.reg"
try {
    if (Test-Path $RegPath) {
        $exportResult = reg.exe export $RegExePath $backupFile /y 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Backed up existing key to: $backupFile" -ForegroundColor Green
        }
        else {
            Write-Host "Error: Backup failed ($exportResult). Aborting without making any changes." -ForegroundColor Red
            Stop-ScriptHere
            return
        }
    }
    else {
        Write-Host "Key does not currently exist - nothing to back up yet. It will be created." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "Error: Could not back up the registry key. $($_.Exception.Message)" -ForegroundColor Red
    Stop-ScriptHere
    return
}

# --- Check current value (idempotency) ---
$currentValue = $null
if (Test-Path $RegPath) {
    $currentValue = (Get-ItemProperty -Path $RegPath -Name $ValueName -ErrorAction SilentlyContinue).$ValueName
}

$displayCurrent = if ($null -eq $currentValue) { '(not set)' } else { $currentValue }

if ($null -ne $currentValue -and $currentValue -eq $DesiredValue) {
    Write-Host "`n'$ValueName' is already set to $DesiredValue. No change needed." -ForegroundColor Green
}
else {
    Write-Host "`nCurrent value: $displayCurrent" -ForegroundColor Cyan
    Write-Host "Setting '$ValueName' to $DesiredValue ..." -ForegroundColor Cyan

    try {
        if (-not (Test-Path $RegPath)) {
            New-Item -Path $RegPath -Force | Out-Null
        }
        New-ItemProperty -Path $RegPath -Name $ValueName -Value $DesiredValue -PropertyType DWord -Force -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Host "Error: Could not set the registry value. $($_.Exception.Message)" -ForegroundColor Red
        Stop-ScriptHere
        return
    }
}

# --- Verify ---
$verifyValue = (Get-ItemProperty -Path $RegPath -Name $ValueName -ErrorAction SilentlyContinue).$ValueName
if ($verifyValue -eq $DesiredValue) {
    Write-Host "Verified: '$ValueName' is now $verifyValue." -ForegroundColor Green
}
else {
    Write-Host "Warning: Verification failed - value reads as '$verifyValue', expected $DesiredValue." -ForegroundColor Red
    Stop-ScriptHere
    return
}

# --- Restart Explorer ---
Write-Host "`nRestarting Explorer for the change to take effect..." -ForegroundColor Cyan
try {
    Stop-Process -Name explorer -Force -ErrorAction Stop
    Start-Sleep -Seconds 2
    Start-Process explorer.exe
    Write-Host "Explorer restarted successfully." -ForegroundColor Green
    Write-Host "`nSUCCESS: The duplicate removable-drive entry should no longer appear in the navigation pane." -ForegroundColor Green
    Write-Host "Your SD card / removable drive will still be accessible normally under This PC." -ForegroundColor Green
}
catch {
    Write-Host "Warning: Could not automatically restart Explorer. $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "The registry change was still applied successfully - please sign out and back in, or restart Explorer manually via Task Manager." -ForegroundColor Yellow
}

Stop-ScriptHere
