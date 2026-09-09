# Get-BitLockerStatus.ps1
# Reports BitLocker status for all volumes on this device.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Get-BitLockerStatus_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

Write-Host "Collecting BitLocker status for $env:COMPUTERNAME ..." -ForegroundColor Cyan

try {
    Get-BitLockerVolume -ErrorAction Stop |
        Select-Object MountPoint, VolumeStatus, ProtectionStatus, EncryptionPercentage, LockStatus, AutoUnlockEnabled, KeyProtector |
        Format-List
}
catch {
    Write-Host "Error: Could not retrieve BitLocker status. $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
Stop-Transcript | Out-Null
Read-Host "`nPress Enter to close this window"
