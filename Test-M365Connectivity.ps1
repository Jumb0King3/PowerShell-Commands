# Test-M365Connectivity.ps1
# Tests TCP port 443 connectivity to a standard set of Microsoft 365
# endpoints, to help diagnose whether a device/network can reach M365
# services.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Test-M365Connectivity_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

$targets = @(
    "login.microsoftonline.com", "outlook.office365.com", "teams.microsoft.com",
    "office.com", "graph.microsoft.com", "endpoint.microsoft.com",
    "manage.microsoft.com", "windowsupdate.microsoft.com"
)

Write-Host "Testing Microsoft 365 endpoint connectivity from $env:COMPUTERNAME ..." -ForegroundColor Cyan

foreach ($target in $targets) {
    Write-Host "`nTesting $target ..." -ForegroundColor Cyan
    try {
        $result = Test-NetConnection -ComputerName $target -Port 443 -WarningAction SilentlyContinue
        $result | Format-List
        $color = if ($result.TcpTestSucceeded) { "Green" } else { "Red" }
        Write-Host "$target : $(if ($result.TcpTestSucceeded) { 'REACHABLE' } else { 'NOT REACHABLE' })" -ForegroundColor $color
    }
    catch {
        Write-Host "Error testing $target : $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
Stop-Transcript | Out-Null
Read-Host "`nPress Enter to close this window"
