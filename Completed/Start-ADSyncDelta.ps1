# Start-ADSyncDelta.ps1
# Triggers a Delta sync cycle for Entra Connect (Azure AD Connect).
# Must be run on the client's HostedApp server (where the sync engine is installed) - not on a session host (SH).
# Confirms before running since this kicks off a sync.

Import-Module ADSync -ErrorAction SilentlyContinue

if (-not (Get-Module ADSync)) {
    Write-Host "Error: The ADSync module is not available on this machine. Run this on the client's HostedApp server." -ForegroundColor Red
    return
}

$confirm = Read-Host "This will trigger a Delta sync cycle. Type YES to continue (anything else cancels)"
if ($confirm -ne "YES") {
    Write-Host "Not confirmed. Cancelling." -ForegroundColor Yellow
    return
}

try {
    Start-ADSyncSyncCycle -PolicyType Delta -ErrorAction Stop
    Write-Host "Delta sync cycle started." -ForegroundColor Green
}
catch {
    Write-Host "Error starting sync cycle: $($_.Exception.Message)" -ForegroundColor Red
}
