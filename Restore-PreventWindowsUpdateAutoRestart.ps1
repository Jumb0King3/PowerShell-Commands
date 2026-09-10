# Restore-PreventWindowsUpdateAutoRestart.ps1
# Restores "Prevent Windows Update Auto Restart" to its state before
# Enable-PreventWindowsUpdateAutoRestart.ps1 was run, using the
# OriginalState.clixml backup that script created.
# Looks for the backup in <Drive>:\Recovery\Backups\PreventWindowsUpdateAutoRestart
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
$logFile = Join-Path $logFolder "Restore-PreventWindowsUpdateAutoRestart_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

function Stop-ScriptHere {
    Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
    Stop-Transcript | Out-Null
    Read-Host "`nPress Enter to close this window"
}

$SettingName = 'PreventWindowsUpdateAutoRestart'
$DisplayName = 'Prevent Windows Update Auto Restart'
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

$stateFile = Join-Path (Join-Path $backupRoot $SettingName) "OriginalState.clixml"
if (-not (Test-Path -LiteralPath $stateFile)) {
    Write-Host "No backup found for '$DisplayName' at $stateFile." -ForegroundColor Red
    Write-Host "Run Enable-PreventWindowsUpdateAutoRestart.ps1 first to create one." -ForegroundColor Yellow
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
    if (-not $state.ValueExisted) {
        if (Test-Path -LiteralPath $state.Path) {
            Remove-ItemProperty -LiteralPath $state.Path -Name $state.Name -ErrorAction SilentlyContinue
        }
        if (-not $state.KeyExisted -and (Test-Path -LiteralPath $state.Path)) {
            $KeyToCheck = Get-Item -LiteralPath $state.Path
            try { $IsEmpty = ($KeyToCheck.SubKeyCount -eq 0 -and $KeyToCheck.ValueCount -eq 0) }
            finally { $KeyToCheck.Close() }
            if ($IsEmpty) {
                Remove-Item -LiteralPath $state.Path -Force -ErrorAction SilentlyContinue
            }
            else {
                Write-Host "Note: $($state.Path) was not removed because it now contains other values/subkeys not related to this tweak." -ForegroundColor Yellow
            }
        }
    }
    else {
        if (-not (Test-Path -LiteralPath $state.Path)) { New-Item -Path $state.Path -Force | Out-Null }
        New-ItemProperty -Path $state.Path -Name $state.Name -Value $state.Value -PropertyType $state.ValueKind -Force | Out-Null
    }
    Write-Host "'$DisplayName' restored successfully." -ForegroundColor Green
    Write-Host "Sign out or restart Windows for the change to take full effect." -ForegroundColor Yellow
}
catch {
    Write-Host "Error: Could not restore the backup. $($_.Exception.Message)" -ForegroundColor Red
}

Stop-ScriptHere
