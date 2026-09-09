# Backup-BitLockerKey.ps1
# Backs up BitLocker recovery keys for all encrypted volumes on this device
# to Entra ID (Azure AD), and saves a local report of what was backed up.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Backup-BitLockerKey_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

function Stop-ScriptHere {
    Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
    Stop-Transcript | Out-Null
    Read-Host "`nPress Enter to close this window"
}

Write-Host "Backing up BitLocker recovery keys to Entra ID for $env:COMPUTERNAME ..." -ForegroundColor Cyan

try {
    $volumes = Get-BitLockerVolume -ErrorAction Stop
}
catch {
    Write-Host "Error: Could not retrieve BitLocker volumes. $($_.Exception.Message)" -ForegroundColor Red
    Stop-ScriptHere
    return
}

$foundAny = $false

foreach ($volume in $volumes) {
    foreach ($protector in $volume.KeyProtector) {
        if ($protector.KeyProtectorType -eq "RecoveryPassword") {
            $foundAny = $true
            Write-Host "`nMount Point: $($volume.MountPoint)" -ForegroundColor Cyan
            Write-Host "Recovery Key ID: $($protector.KeyProtectorId)"

            try {
                BackupToAAD-BitLockerKeyProtector -MountPoint $volume.MountPoint -KeyProtectorId $protector.KeyProtectorId -ErrorAction Stop
                Write-Host "SUCCESS: Recovery key backed up to Entra ID." -ForegroundColor Green
            }
            catch {
                Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}

if (-not $foundAny) {
    Write-Host "`nNo recovery password protectors found on this device." -ForegroundColor Yellow
}

Stop-ScriptHere
