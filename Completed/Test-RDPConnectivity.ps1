# Test-RDPConnectivity.ps1
# Prompts for a target public IP or hostname, detects the local RDP port
# from the registry (defaults to 3389 if not found), then tests TCP
# connectivity to that target on that port and saves a report.
# Pressing Enter with no input cancels.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs\RDP Connectivity Tests"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }

$TargetHost = Read-Host "Enter the target public IP address or hostname (press Enter with no input to cancel)"
if ([string]::IsNullOrWhiteSpace($TargetHost)) {
    Write-Host "No target entered. Cancelling." -ForegroundColor Yellow
    return
}

if (-not (Get-Command Test-NetConnection -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Test-NetConnection is not available in this PowerShell session." -ForegroundColor Red
    return
}

$regPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp'
$port = 3389
$portMessage = 'Defaulting to port 3389.'
try {
    $value = Get-ItemPropertyValue -LiteralPath $regPath -Name PortNumber -ErrorAction Stop
    if ([int]$value -ge 1 -and [int]$value -le 65535) {
        $port = [int]$value
        $portMessage = 'Port detected from the local RDP-Tcp registry configuration.'
    }
}
catch {
    $portMessage = "Unable to read the local RDP port. Defaulting to 3389. $($_.Exception.Message)"
}

Write-Host "Detected local RDP port: $port" -ForegroundColor Cyan
Write-Host $portMessage -ForegroundColor Cyan
Write-Host "Testing $TargetHost on TCP port $port..." -ForegroundColor Cyan

$result = Test-NetConnection -ComputerName $TargetHost -Port $port -InformationLevel Detailed -WarningAction SilentlyContinue
$outcome = if ($result.TcpTestSucceeded) { 'PASS - The TCP port is reachable.' } else { 'FAIL - The TCP port was not reachable.' }

$safeTarget = $TargetHost -replace '[^a-zA-Z0-9._-]', '_'
$report = Join-Path $logFolder ("RDP-Test_{0}_{1:yyyyMMdd_HHmmss}.txt" -f $safeTarget, (Get-Date))
$text = @(
    'Remote Desktop Connectivity Test', '================================',
    "Date: $(Get-Date)", "Target: $TargetHost", "Detected RDP Port: $port", "Tested Port: $port",
    "Remote Address: $($result.RemoteAddress)", "Remote Port: $($result.RemotePort)",
    "Ping Succeeded: $($result.PingSucceeded)", "TCP Test Succeeded: $($result.TcpTestSucceeded)",
    '', $outcome
) | Out-String

$outcomeColor = if ($result.TcpTestSucceeded) { "Green" } else { "Red" }
Write-Host "`n$text" -ForegroundColor $outcomeColor
Set-Content -LiteralPath $report -Value $text -Encoding UTF8
Write-Host "Report saved to: $report" -ForegroundColor Cyan

Read-Host "`nPress Enter to close this window"
