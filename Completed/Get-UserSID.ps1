# Get-UserSID.ps1
# Prompts for a username and returns their AD SID.

$username = Read-Host "Enter the username (press Enter with no input to cancel)"
if ([string]::IsNullOrWhiteSpace($username)) {
    Write-Host "No username entered. Cancelling." -ForegroundColor Yellow
    return
}

try {
    Get-ADUser -Identity $username -ErrorAction Stop | Select-Object SID
}
catch {
    Write-Host "Error: Could not retrieve SID for '$username'. $($_.Exception.Message)" -ForegroundColor Red
}
