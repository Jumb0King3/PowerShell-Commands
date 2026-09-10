# Compress-ScriptsLogs.ps1
# Compresses the contents of Documents\Scripts Logs into a timestamped ZIP
# archive under Documents\Scripts Logs Archives.
#
# NOTE: Adapted from an original that zipped a shared toolkit "Reports"
# folder - that folder doesn't exist in this setup, so this zips the
# actual log location these scripts use: Documents\Scripts Logs.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
$archiveFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs Archives"

if (-not (Test-Path $logFolder)) {
    Write-Host "Log folder not found - nothing to compress." -ForegroundColor Yellow
    Read-Host "`nPress Enter to close this window"
    return
}
if (-not (Test-Path $archiveFolder)) { New-Item -Path $archiveFolder -ItemType Directory -Force | Out-Null }

$archiveFile = Join-Path $archiveFolder ("$env:COMPUTERNAME-ScriptsLogs-{0:yyyyMMdd_HHmmss}.zip" -f (Get-Date))
$logItems = @(Get-ChildItem -Path $logFolder -Force -ErrorAction SilentlyContinue)

if ($logItems.Count -eq 0) {
    Write-Host "There is nothing to compress." -ForegroundColor Yellow
    Read-Host "`nPress Enter to close this window"
    return
}

Write-Host "Compressing logs..." -ForegroundColor Cyan

try {
    Compress-Archive -Path (Join-Path $logFolder "*") -DestinationPath $archiveFile -CompressionLevel Optimal -Force -ErrorAction Stop
    Write-Host "Archive created successfully." -ForegroundColor Green
    Write-Host "Archive saved to: $archiveFile" -ForegroundColor Green
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Read-Host "`nPress Enter to close this window"
