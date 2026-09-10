# Get-WarrantyInfo.ps1
# Collects hardware identification info (manufacturer, model, serial
# number, BIOS version) needed to look up warranty status on the
# manufacturer's site.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Get-WarrantyInfo_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

Write-Host "Collecting hardware information for $env:COMPUTERNAME ..." -ForegroundColor Cyan

try {
    $computerSystem = Get-CimInstance Win32_ComputerSystem
    $bios = Get-CimInstance Win32_BIOS
    $baseBoard = Get-CimInstance Win32_BaseBoard

    [PSCustomObject]@{
        ComputerName = $env:COMPUTERNAME
        Manufacturer = $computerSystem.Manufacturer
        Model        = $computerSystem.Model
        SerialNumber = $bios.SerialNumber
        BIOSVersion  = ($bios.SMBIOSBIOSVersion -join ", ")
        Mainboard    = $baseBoard.Product
    } | Format-List
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "Look up the serial number above on the manufacturer's warranty site for coverage details." -ForegroundColor Cyan
Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
Stop-Transcript | Out-Null
Read-Host "`nPress Enter to close this window"
