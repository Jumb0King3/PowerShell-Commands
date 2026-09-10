# Get-PendingRebootStatus.ps1
# Checks whether this device has a pending restart, based on Component
# Based Servicing, Windows Update, pending file rename operations, and
# computer rename status.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Get-PendingRebootStatus_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

Write-Host "Checking pending reboot status for $env:COMPUTERNAME ..." -ForegroundColor Cyan

try {
    $cbsRebootPending = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
    $windowsUpdateRebootPending = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"

    $pendingFileRenameOperations = $null
    $sessionManagerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
    if (Test-Path $sessionManagerPath) {
        $pendingFileRenameOperations = (Get-ItemProperty -Path $sessionManagerPath -Name PendingFileRenameOperations -ErrorAction SilentlyContinue).PendingFileRenameOperations
    }

    $computerNameMismatch = $false
    $activeComputerName = $null
    $pendingComputerName = $null
    $activeNamePath = "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName"
    $pendingNamePath = "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName"

    if (Test-Path $activeNamePath) { $activeComputerName = (Get-ItemProperty $activeNamePath).ComputerName }
    if (Test-Path $pendingNamePath) { $pendingComputerName = (Get-ItemProperty $pendingNamePath).ComputerName }
    if ($activeComputerName -and $pendingComputerName) { $computerNameMismatch = ($activeComputerName -ne $pendingComputerName) }

    $pendingFileRename = [bool]$pendingFileRenameOperations
    $rebootPending = ($cbsRebootPending -or $windowsUpdateRebootPending -or $pendingFileRename -or $computerNameMismatch)

    [PSCustomObject]@{
        ComputerName                   = $env:COMPUTERNAME
        RebootPending                  = $rebootPending
        ComponentBasedServicingPending = $cbsRebootPending
        WindowsUpdatePending           = $windowsUpdateRebootPending
        FileRenameOperationsPending    = $pendingFileRename
        ComputerRenamePending          = $computerNameMismatch
        ActiveComputerName             = $activeComputerName
        PendingComputerName            = $pendingComputerName
        Checked                        = Get-Date
    } | Format-List

    if ($rebootPending) { Write-Host "A restart is pending." -ForegroundColor Yellow } else { Write-Host "No pending restart was detected." -ForegroundColor Green }
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
Stop-Transcript | Out-Null
Read-Host "`nPress Enter to close this window"
