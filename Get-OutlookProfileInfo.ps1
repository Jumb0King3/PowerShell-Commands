# Get-OutlookProfileInfo.ps1
# Lists all files directly in the local Outlook data folder (not just
# OST/PST/NST - see Get-OutlookDataFiles.ps1 for that narrower search).

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Get-OutlookProfileInfo_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

function Format-ReadableSize {
    param([AllowNull()][double]$Bytes)
    if ($null -eq $Bytes -or $Bytes -lt 0) { return 'Unknown' }
    if ($Bytes -lt 1KB) { return "{0:N0} B" -f $Bytes }
    if ($Bytes -lt 1MB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    if ($Bytes -lt 1GB) { return "{0:N2} MB" -f ($Bytes / 1GB) }
    if ($Bytes -lt 1TB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    return "{0:N2} TB" -f ($Bytes / 1TB)
}

Write-Host "===== Outlook Data Files =====" -ForegroundColor Cyan

$outlookPath = "$env:LOCALAPPDATA\Microsoft\Outlook"

if (Test-Path $outlookPath) {
    Get-ChildItem $outlookPath -File |
        Select-Object Name, @{Name = "Size"; Expression = { Format-ReadableSize $_.Length }}, LastWriteTime, FullName |
        Format-Table -AutoSize
}
else {
    Write-Host "Outlook folder not found." -ForegroundColor Yellow
}

Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
Stop-Transcript | Out-Null
Read-Host "`nPress Enter to close this window"
