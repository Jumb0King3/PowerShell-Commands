# Remove-DuplicateRemovableDrive.ps1
# Removes the duplicate removable-drive entry from File Explorer's navigation
# pane by setting System.IsPinnedToNameSpaceTree = 0 under the "Removable
# Drives" delegate folder CLSID.
# Backs up the FULL original state (whether the key/value existed, its
# type, and its value) via Export-Clixml to a Ventoy USB (or nearest
# removable drive) at <Drive>:\Recovery\Backups\<SettingName>\OriginalState.clixml
# before making any change. Skips re-backing-up if a backup already
# exists there, so re-running this script won't overwrite your true
# original state with an already-tweaked one. If no such drive can be
# detected, prompts for a manual backup location.
#
# NOTE: This is a per-user (HKCU) change, so unlike the other tweak
# scripts in this set, administrator elevation is NOT required here - it
# only affects the currently signed-in user's own profile. It does not
# disable or remove the drive itself - it remains accessible normally
# under This PC.
#
# Verification note: the CLSID {F5FB2C77-0E2F-4A16-A381-3E560C68BC83} is
# confirmed as the "Removable Drives" delegate folder, and
# System.IsPinnedToNameSpaceTree is a genuine, Microsoft-documented shell
# property used for pinning/unpinning namespace folders. The most widely
# tested community fixes for this specific duplicate-drive symptom instead
# remove the HKLM DelegateFolders registration or modify a ShellFolder
# "Attributes" value - not this exact value. This script implements what
# was requested; if it does not resolve the duplicate on your system, that
# alternative approach may be needed instead.

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
$logFile = Join-Path $logFolder "Remove-DuplicateRemovableDrive_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

function Stop-ScriptHere {
    Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
    Stop-Transcript | Out-Null
    Read-Host "`nPress Enter to close this window"
}

$SettingName = 'RemovableDrivesCLSID'
$DisplayName = 'Removable Drives (duplicate entry fix)'
$Path = 'HKCU:\Software\Classes\CLSID\{F5FB2C77-0E2F-4A16-A381-3E560C68BC83}'
$Name = 'System.IsPinnedToNameSpaceTree'
$NewValue = 0
$PropertyType = 'DWord'
$UserSid = ([Security.Principal.WindowsIdentity]::GetCurrent()).User.Value

Write-Host "Applying tweak: $DisplayName" -ForegroundColor Cyan

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

try {
    if (-not (Test-Path -LiteralPath $stateFile)) {
        $KeyExisted = Test-Path -LiteralPath $Path
        $ValueExisted = $false
        $ValueKind = $null
        $Value = $null
        if ($KeyExisted) {
            $Key = Get-Item -LiteralPath $Path
            try {
                if (@($Key.GetValueNames()) -contains $Name) {
                    $ValueExisted = $true
                    $ValueKind = $Key.GetValueKind($Name).ToString()
                    $Value = $Key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                }
            } finally { $Key.Close() }
        }
        [pscustomobject]@{
            FormatVersion = 1; ComputerName = $env:COMPUTERNAME; UserSid = $UserSid
            Path = $Path; Name = $Name; KeyExisted = $KeyExisted
            ValueExisted = $ValueExisted; ValueKind = $ValueKind; Value = $Value
        } | Export-Clixml -LiteralPath $stateFile -Depth 5
        Write-Host "Original state backed up to: $stateFile" -ForegroundColor Green
    }
    else {
        Write-Host "An original-state backup already exists at $stateFile and was not overwritten." -ForegroundColor Yellow
    }

    New-Item -Path $Path -Force | Out-Null
    New-ItemProperty -Path $Path -Name $Name -Value $NewValue -PropertyType $PropertyType -Force | Out-Null
    $Actual = Get-ItemPropertyValue -LiteralPath $Path -Name $Name
    if ([string]$Actual -ne [string]$NewValue) { throw "Registry verification failed for $Name." }

    Write-Host "'$DisplayName' was applied successfully." -ForegroundColor Green
    Write-Host "Your SD card / removable drive will still be accessible normally under This PC." -ForegroundColor Green

    Write-Host "Restarting Windows Explorer..." -ForegroundColor Yellow
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Start-Process explorer.exe
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Stop-ScriptHere
