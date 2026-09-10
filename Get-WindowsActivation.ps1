# Get-WindowsActivation.ps1
# Reports Windows activation/license status and activation expiry.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Get-WindowsActivation_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

Write-Host "Collecting Windows activation information for $env:COMPUTERNAME ..." -ForegroundColor Cyan

try {
    Write-Host "`n===== WINDOWS ACTIVATION =====" -ForegroundColor Cyan
    Get-CimInstance SoftwareLicensingProduct | Where-Object { $_.PartialProductKey -and $_.Name -like "*Windows*" } |
        Select-Object Name, Description, LicenseStatus, PartialProductKey |
        Format-List

    Write-Host "`n===== ACTIVATION EXPIRY =====" -ForegroundColor Cyan
    cscript.exe "$env:SystemRoot\System32\slmgr.vbs" /xpr
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
Stop-Transcript | Out-Null
Read-Host "`nPress Enter to close this window"
