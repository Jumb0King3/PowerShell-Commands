# Clear-ScriptsLogs.ps1
# Deletes all .txt transcript logs in Documents\Scripts Logs. Requires
# typed confirmation before running.
#
# NOTE: Adapted from an original that cleared a shared toolkit "Reports"
# folder - that folder doesn't exist in this setup, so this clears the
# actual log location these scripts use: Documents\Scripts Logs.
# For safety, this only removes .txt log files - it does NOT touch the
# RegistryBackups or IntuneDiagnostics subfolders, since those hold
# actual backup/diagnostic data rather than disposable run logs.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"

if (-not (Test-Path $logFolder)) {
    Write-Host "Log folder not found - nothing to clear." -ForegroundColor Yellow
    Read-Host "`nPress Enter to close this window"
    return
}

$logFiles = @(Get-ChildItem -Path $logFolder -Filter "*.txt" -File -ErrorAction SilentlyContinue)

if ($logFiles.Count -eq 0) {
    Write-Host "No .txt log files found - nothing to clear." -ForegroundColor Yellow
    Read-Host "`nPress Enter to close this window"
    return
}

Write-Host "This will permanently delete $($logFiles.Count) log file(s) from:" -ForegroundColor Yellow
Write-Host $logFolder
Write-Host "(RegistryBackups and IntuneDiagnostics subfolders will NOT be touched.)" -ForegroundColor Yellow

$confirm = Read-Host "Type YES to continue (anything else cancels)"
if ($confirm -ne "YES") {
    Write-Host "Not confirmed. Cancelling." -ForegroundColor Yellow
    Read-Host "`nPress Enter to close this window"
    return
}

$deleted = 0
foreach ($file in $logFiles) {
    try {
        Remove-Item -Path $file.FullName -Force -ErrorAction Stop
        $deleted++
    }
    catch {
        Write-Host "Failed to delete $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nLogs cleared successfully." -ForegroundColor Green
Write-Host "Files deleted: $deleted" -ForegroundColor Green
Read-Host "`nPress Enter to close this window"
