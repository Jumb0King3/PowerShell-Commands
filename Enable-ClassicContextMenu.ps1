# Enable-ClassicContextMenu.ps1
# Restores the classic (Windows 10-style) full right-click context menu on
# Windows 11, by setting an empty default value under a specific CLSID key.
# Backs up the FULL original state (including whether the parent CLSID key
# itself existed) via Export-Clixml to a Ventoy USB (or nearest removable
# drive) at <Drive>:\Recovery\Backups\ClassicContextMenu\OriginalState.clixml
# before making any change. Skips re-backing-up if a backup already exists
# there. If no such drive can be detected, prompts for a manual backup
# location. Requires Administrator. Restarts Explorer when done.

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
$logFile = Join-Path $logFolder "Enable-ClassicContextMenu_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

function Stop-ScriptHere {
    Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
    Stop-Transcript | Out-Null
    Read-Host "`nPress Enter to close this window"
}

$SettingName = 'ClassicContextMenu'
$DisplayName = 'Classic Context Menu'
$ParentPath = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}'
$Path = Join-Path $ParentPath 'InprocServer32'
$Name = ''
$UserSid = ([Security.Principal.WindowsIdentity]::GetCurrent()).User.Value

Write-Host "Applying tweak: $DisplayName" -ForegroundColor Cyan

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
        $ParentKeyExisted = Test-Path $ParentPath
        $KeyExisted = Test-Path $Path
        $ValueExisted = $false
        $ValueKind = $null
        $Value = $null
        if ($KeyExisted) {
            $Key = Get-Item -LiteralPath $Path
            try {
                if (@($Key.GetValueNames()) -contains '') {
                    $ValueExisted = $true
                    $ValueKind = $Key.GetValueKind('').ToString()
                    $Value = $Key.GetValue('')
                }
            } finally { $Key.Close() }
        }
        [pscustomobject]@{
            FormatVersion = 1; ComputerName = $env:COMPUTERNAME; UserSid = $UserSid
            ParentPath = $ParentPath; ParentKeyExisted = $ParentKeyExisted
            Path = $Path; Name = ''; KeyExisted = $KeyExisted
            ValueExisted = $ValueExisted; ValueKind = $ValueKind; Value = $Value
        } | Export-Clixml -LiteralPath $stateFile -Depth 5
        Write-Host "Original state backed up to: $stateFile" -ForegroundColor Green
    }
    else {
        Write-Host "An original-state backup already exists at $stateFile and was not overwritten." -ForegroundColor Yellow
    }

    New-Item -Path $Path -Force | Out-Null
    $Key = Get-Item -LiteralPath $Path
    try { $Key.SetValue('', '', [Microsoft.Win32.RegistryValueKind]::String) }
    finally { $Key.Close() }

    Write-Host "'$DisplayName' was applied successfully." -ForegroundColor Green
    Write-Host "Restarting Windows Explorer..." -ForegroundColor Yellow
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Start-Process explorer.exe
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Stop-ScriptHere
