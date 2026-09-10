# Get-DiskHealth.ps1
# Reports physical disk health status and logical disk space usage.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Get-DiskHealth_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

function Format-ReadableSize {
    param([AllowNull()][double]$Bytes)
    if ($null -eq $Bytes -or $Bytes -lt 0) { return 'Unknown' }
    if ($Bytes -lt 1KB) { return "{0:N0} B" -f $Bytes }
    if ($Bytes -lt 1MB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    if ($Bytes -lt 1GB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -lt 1TB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    return "{0:N2} TB" -f ($Bytes / 1TB)
}

Write-Host "Collecting disk health for $env:COMPUTERNAME ..." -ForegroundColor Cyan

Write-Host "`n===== Physical Disks =====" -ForegroundColor Cyan
try {
    Get-PhysicalDisk |
        Select-Object FriendlyName, SerialNumber, MediaType, HealthStatus, OperationalStatus, @{Name = "Size"; Expression = { Format-ReadableSize $_.Size }} |
        Format-Table -AutoSize
}
catch { Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red }

Write-Host "`n===== Logical Disks =====" -ForegroundColor Cyan
try {
    Get-CimInstance Win32_LogicalDisk |
        Select-Object DeviceID, VolumeName, FileSystem, @{Name = "Size"; Expression = { Format-ReadableSize $_.Size }}, @{Name = "FreeSpace"; Expression = { Format-ReadableSize $_.FreeSpace }} |
        Format-Table -AutoSize
}
catch { Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red }

Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
Stop-Transcript | Out-Null
Read-Host "`nPress Enter to close this window"
