# Get-UserGroupMembership.ps1
# Prompts for a username and lists the AD groups that user is a member of.
# Pressing Enter with no input cancels the script.

$username = Read-Host "Enter the username (press Enter with no input to cancel)"

if ([string]::IsNullOrWhiteSpace($username)) {
    Write-Host "No username entered. Cancelling." -ForegroundColor Yellow
    return
}

try {
    Get-ADPrincipalGroupMembership -Identity $username -ErrorAction Stop | Select-Object Name
}
catch {
    Write-Host "Error: Could not retrieve group membership for '$username'. $($_.Exception.Message)" -ForegroundColor Red
}
