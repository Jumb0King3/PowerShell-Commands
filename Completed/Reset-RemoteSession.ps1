# Reset-RemoteSession.ps1
# Prompts for a remote computer name, shows logged-on sessions (quser),
# then prompts for the session ID to forcibly reset (rwinsta).
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

$sessionId = Read-Host "`nEnter the session ID to reset/kill (press Enter with no input to cancel)"
if ([string]::IsNullOrWhiteSpace($sessionId)) {
    Write-Host "No session ID entered. Cancelling." -ForegroundColor Yellow
    return
}

Write-Host "`nWARNING: This will forcibly terminate session $sessionId on $computerName without a graceful logoff. Any unsaved work in that session will be lost." -ForegroundColor Red
$confirm = Read-Host "Type YES to confirm (anything else cancels)"
if ($confirm -ne "YES") {
    Write-Host "Not confirmed. Cancelling." -ForegroundColor Yellow
    return
}

try {
    Invoke-Command -ComputerName $computerName -ScriptBlock { param($id) rwinsta $id } -ArgumentList $sessionId -ErrorAction Stop
    Write-Host "Session $sessionId reset on $computerName." -ForegroundColor Green
}
catch {
    Write-Host "Error: Could not reset session '$sessionId' on '$computerName'. $($_.Exception.Message)" -ForegroundColor Red
}
