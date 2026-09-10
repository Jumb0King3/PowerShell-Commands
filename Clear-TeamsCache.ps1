# Clear-TeamsCache.ps1
# Closes Microsoft Teams and deletes its cache folders. This is destructive
# to locally cached Teams data (not your messages/files, which live in the
# cloud) - requires typed confirmation before running.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Clear-TeamsCache_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

Write-Host "WARNING" -ForegroundColor Red
Write-Host "This will close Teams and delete its local cache folders on $env:COMPUTERNAME."
Write-Host "Teams will need to re-sync data on next launch (may take longer to load once)."
Write-Host ""

$confirm = Read-Host "Type YES to continue (anything else cancels)"
if ($confirm -ne "YES") {
    Write-Host "Not confirmed. Cancelling." -ForegroundColor Yellow
    Stop-Transcript | Out-Null
    Read-Host "`nPress Enter to close this window"
    return
}

Write-Host "`nClearing Teams cache on $env:COMPUTERNAME at $(Get-Date)" -ForegroundColor Cyan

Stop-Process -Name Teams -Force -ErrorAction SilentlyContinue
Stop-Process -Name ms-teams -Force -ErrorAction SilentlyContinue

$cachePaths = @("$env:APPDATA\Microsoft\Teams", "$env:LOCALAPPDATA\Microsoft\Teams")

foreach ($path in $cachePaths) {
    if (Test-Path $path) {
        try {
            Write-Host "Removing $path" -ForegroundColor Cyan
            Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
            Write-Host "Removed $path" -ForegroundColor Green
        }
        catch {
            Write-Host "Error removing $path : $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    else {
        Write-Host "$path not found - skipping." -ForegroundColor Yellow
    }
}

Write-Host "`nDone." -ForegroundColor Green
Write-Host "Log saved to: $logFile" -ForegroundColor Cyan
Stop-Transcript | Out-Null
Read-Host "`nPress Enter to close this window"
