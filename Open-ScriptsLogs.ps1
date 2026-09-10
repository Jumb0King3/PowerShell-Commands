# Open-ScriptsLogs.ps1
# Opens the Documents\Scripts Logs folder in File Explorer.
#
# NOTE: Adapted from an original that opened a shared toolkit "Reports"
# folder ($global:AppRoot\Reports) - that folder doesn't exist in this
# setup, so this opens the actual log location these scripts use instead:
# Documents\Scripts Logs.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }

try {
    Start-Process -FilePath "explorer.exe" -ArgumentList "`"$logFolder`"" -ErrorAction Stop
    Write-Host "Opened: $logFolder" -ForegroundColor Green
}
catch {
    Write-Host "Error: Could not open the folder. $($_.Exception.Message)" -ForegroundColor Red
}
