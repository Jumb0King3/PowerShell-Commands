# Get-UsersInOU.ps1
# Prompts for an OU distinguished name and lists all users in that OU
# (Name and SamAccountName).
# Pressing Enter with no input cancels.

$ouPath = Read-Host "Enter the OU distinguished name (e.g. OU=Disabled Users,OU=PhoenixIB,OU=FocusNet - Hosting,DC=focusnet,DC=net,DC=au) (press Enter with no input to cancel)"
if ([string]::IsNullOrWhiteSpace($ouPath)) {
    Write-Host "No OU entered. Cancelling." -ForegroundColor Yellow
    return
}

try {
    $users = Get-ADUser -SearchBase $ouPath -Filter * -ErrorAction Stop | Select-Object Name, SamAccountName
    if (-not $users) {
        Write-Host "No users found in that OU." -ForegroundColor Yellow
    }
    else {
        Write-Host "`nUsers in $ouPath :" -ForegroundColor Cyan
        $users | Format-Table -AutoSize
    }
}
catch {
    Write-Host "Error: Could not retrieve users from that OU. $($_.Exception.Message)" -ForegroundColor Red
}
