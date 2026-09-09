# Copy-ADGroupMemberships.ps1
# Copies all AD group memberships from one user to another.
# Prompts for the source user (copy from) and target user (copy to).
# Pressing Enter with no input at either prompt cancels.

$SourceUser = Read-Host "Enter the source username - the user to copy group memberships FROM (press Enter with no input to cancel)"
if ([string]::IsNullOrWhiteSpace($SourceUser)) {
    Write-Host "No source user entered. Cancelling." -ForegroundColor Yellow
    return
}

$TargetUser = Read-Host "Enter the target username - the user to copy group memberships TO (press Enter with no input to cancel)"
if ([string]::IsNullOrWhiteSpace($TargetUser)) {
    Write-Host "No target user entered. Cancelling." -ForegroundColor Yellow
    return
}

# Get all groups the source user is a member of
try {
    $Groups = Get-ADUser $SourceUser -Properties MemberOf -ErrorAction Stop | Select-Object -ExpandProperty MemberOf
}
catch {
    Write-Host "Error: Could not retrieve group memberships for '$SourceUser'. $($_.Exception.Message)" -ForegroundColor Red
    return
}

if (-not $Groups) {
    Write-Host "$SourceUser is not a member of any groups. Nothing to copy." -ForegroundColor Yellow
    return
}

Write-Host "`n$SourceUser is a member of $($Groups.Count) group(s):" -ForegroundColor Cyan
$Groups | ForEach-Object { Write-Host "  $_" }

Write-Host "`nThis will add $TargetUser to all $($Groups.Count) group(s) listed above." -ForegroundColor Yellow
$confirm = Read-Host "Type YES to continue (anything else cancels)"
if ($confirm -ne "YES") {
    Write-Host "Not confirmed. Cancelling." -ForegroundColor Yellow
    return
}

foreach ($GroupDN in $Groups) {
    try {
        Add-ADGroupMember -Identity $GroupDN -Members $TargetUser -ErrorAction Stop
        Write-Host "Added $TargetUser to $GroupDN" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to add $TargetUser to $GroupDN - $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nDone." -ForegroundColor Cyan
