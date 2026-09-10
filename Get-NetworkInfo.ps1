# Get-NetworkInfo.ps1
# Collects a full network diagnostic snapshot: ipconfig /all, adapters,
# IP addresses, DNS servers, and routing table.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Get-NetworkInfo_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

Write-Host "Collecting network information for $env:COMPUTERNAME ..." -ForegroundColor Cyan

Write-Host "`n===== IPCONFIG =====" -ForegroundColor Cyan
ipconfig /all

Write-Host "`n===== ADAPTERS =====" -ForegroundColor Cyan
try { Get-NetAdapter | Format-Table -AutoSize } catch { Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red }

Write-Host "`n===== IP ADDRESSES =====" -ForegroundColor Cyan
try { Get-NetIPAddress | Format-Table -AutoSize } catch { Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red }

Write-Host "`n===== DNS SERVERS =====" -ForegroundColor Cyan
try { Get-DnsClientServerAddress | Format-Table -AutoSize } catch { Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red }

Write-Host "`n===== ROUTES =====" -ForegroundColor Cyan
try { Get-NetRoute | Format-Table -AutoSize } catch { Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red }

Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
Stop-Transcript | Out-Null
Read-Host "`nPress Enter to close this window"
