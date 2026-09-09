# Logoff-RemoteSession.ps1
# Prompts for a remote computer name, shows logged-on sessions (quser),
# then prompts for the session ID to log off.
# Pressing Enter with no input at any prompt cancels.

$computerName = Read-Host "Enter the remote computer name (press Enter with no input to cancel)"
if ([string]::IsNullOrWhiteSpace($computerName)) {
    Write-Host "No computer name entered. Cancelling." -ForegroundColor Yellow
    return
}

Write-Host "`nCurrent sessions on $computerName :" -ForegroundColor Cyan
try {
    Invoke-Command -ComputerName $computerName -ScriptBlock { quser } -ErrorAction Stop
}
catch {
    Write-Host "Error: Could not connect to '$computerName'. $($_.Exception.Message)" -ForegroundColor Red
    return
}

$sessionId = Read-Host "`nEnter the session ID to log off (press Enter with no input to cancel)"
if ([string]::IsNullOrWhiteSpace($sessionId)) {
    Write-Host "No session ID entered. Cancelling." -ForegroundColor Yellow
    return
}

try {
    Invoke-Command -ComputerName $computerName -ScriptBlock { param($id) logoff $id } -ArgumentList $sessionId -ErrorAction Stop
    Write-Host "Session $sessionId logged off on $computerName." -ForegroundColor Green
}
catch {
    Write-Host "Error: Could not log off session '$sessionId' on '$computerName'. $($_.Exception.Message)" -ForegroundColor Red
}
