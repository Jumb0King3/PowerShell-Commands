# Get-LocalAdmins.ps1
# Lists members of the local Administrators group on this device.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Get-LocalAdmins_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

Write-Host "Collecting local administrators for $env:COMPUTERNAME ..." -ForegroundColor Cyan

try {
    $admins = Get-LocalGroupMember -Group "Administrators" -ErrorAction Stop

    if ($admins) {
        $admins | Select-Object Name, ObjectClass, PrincipalSource | Sort-Object Name | Format-Table -AutoSize
    }
    else {
        Write-Host "No local administrators found." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
Stop-Transcript | Out-Null
Read-Host "`nPress Enter to close this window"
