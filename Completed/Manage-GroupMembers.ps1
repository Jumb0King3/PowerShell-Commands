# Manage-GroupMembers.ps1
# Connects to Exchange Online if not already connected, then lets you browse
# Distribution Lists and Mail-Enabled Security Groups, view their members
# (labeled as User, Contact, or External User), and remove a member -
# looping back so you can work through multiple groups in the same session.
# Disconnects from Exchange Online when you exit.
# Logs all output to a transcript file for ticket documentation.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Manage-GroupMembers_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

function Stop-ScriptHere {
    try {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        Write-Host "`nDisconnected from Exchange Online." -ForegroundColor Cyan
    }
    catch { }
    Write-Host "Log saved to: $logFile" -ForegroundColor Cyan
    Stop-Transcript | Out-Null
    Read-Host "`nPress Enter to close this window"
}

function Get-GroupTypeLabel($group) {
    switch ($group.RecipientTypeDetails) {
        "MailUniversalDistributionGroup" { "Distribution List" }
        "MailUniversalSecurityGroup"     { "Mail-Enabled Security Group" }
        "MailNonUniversalGroup"          { "Mail-Enabled Group (Legacy)" }
        default                          { $group.RecipientTypeDetails }
    }
}

function Get-GroupSyncLabel($group) {
    if ($group.IsDirSynced) { "AD Synced" } else { "Cloud Only" }
}

function Get-GroupDisplayName($group) {
    # Strip a trailing timestamp (e.g. "Forwarding Group20251006063813" -> "Forwarding Group")
    return ($group.Name -replace '\d{10,}$', '').TrimEnd()
}

function Get-MemberTypeLabel($member) {
    switch ($member.RecipientType) {
        "UserMailbox"    { "User" }
        "MailContact"    { "Contact" }
        "MailUser"       { "External User" }
        "GuestMailUser"  { "External User (Guest)" }
        default          { $member.RecipientType }
    }
}

function Get-MemberDisplayName($member) {
    # Name is sometimes a GUID (e.g. for system-generated forwarding groups) -
    # fall back to DisplayName or PrimarySmtpAddress when that happens.
    $isGuid = $member.Name -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    if (-not $isGuid -and -not [string]::IsNullOrWhiteSpace($member.Name)) {
        return $member.Name
    }
    if (-not [string]::IsNullOrWhiteSpace($member.DisplayName)) {
        return $member.DisplayName
    }
    if (-not [string]::IsNullOrWhiteSpace($member.PrimarySmtpAddress)) {
        return $member.PrimarySmtpAddress
    }
    return $member.Name
}

# --- Ensure connected to Exchange Online ---
$connected = $false
try {
    Get-ConnectionInformation -ErrorAction Stop | Where-Object { $_.State -eq "Connected" } | ForEach-Object { $connected = $true }
}
catch { $connected = $false }

if (-not $connected) {
    if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
        Write-Host "ExchangeOnlineManagement module not found. Installing..." -ForegroundColor Cyan
        try {
            Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force -ErrorAction Stop
        }
        catch {
            Write-Host "Error installing module: $($_.Exception.Message)" -ForegroundColor Red
            Stop-Transcript | Out-Null
            Read-Host "`nPress Enter to close this window"
            return
        }
    }

    try {
        Connect-ExchangeOnline -ErrorAction Stop
    }
    catch {
        try {
            Connect-ExchangeOnline -DisableWAM -ErrorAction Stop
        }
        catch {
            Write-Host "Error connecting to Exchange Online: $($_.Exception.Message)" -ForegroundColor Red
            Stop-Transcript | Out-Null
            Read-Host "`nPress Enter to close this window"
            return
        }
    }
    Write-Host "Connected to Exchange Online." -ForegroundColor Green
}

# --- Get all Distribution Lists and Mail-Enabled Security Groups ---
try {
    $allGroups = Get-DistributionGroup -ResultSize Unlimited -ErrorAction Stop | Sort-Object Name
}
catch {
    Write-Host "Error: Could not retrieve groups. $($_.Exception.Message)" -ForegroundColor Red
    Stop-ScriptHere
    return
}

if (-not $allGroups) {
    Write-Host "No groups found." -ForegroundColor Yellow
    Stop-ScriptHere
    return
}

$browsingGroups = $true

while ($browsingGroups) {

    # --- List groups ---
    Write-Host "`nGroups:" -ForegroundColor Cyan
    $gi = 1
    $groupIndex = @{}
    foreach ($grp in $allGroups) {
        $typeLabel = Get-GroupTypeLabel $grp
        $syncLabel = Get-GroupSyncLabel $grp
        $groupDisplayName = Get-GroupDisplayName $grp
        Write-Host ("  {0}. {1}  [{2}] [{3}]" -f $gi, $groupDisplayName, $typeLabel, $syncLabel)
        $groupIndex[$gi] = $grp
        $gi++
    }

    $groupSelection = Read-Host "`nEnter a group number to view members (press Enter with no input to exit)"
    if ([string]::IsNullOrWhiteSpace($groupSelection)) {
        $browsingGroups = $false
        break
    }
    if (-not $groupIndex.ContainsKey([int]$groupSelection)) {
        Write-Host "Invalid group number entered." -ForegroundColor Yellow
        continue
    }

    $selectedGroup = $groupIndex[[int]$groupSelection]
    $selectedGroupDisplayName = Get-GroupDisplayName $selectedGroup

    # --- Browse members of the selected group ---
    $browsingMembers = $true

    while ($browsingMembers) {

        try {
            $members = Get-DistributionGroupMember -Identity $selectedGroup.Identity -ResultSize Unlimited -ErrorAction Stop | Sort-Object Name
        }
        catch {
            Write-Host "Error: Could not retrieve members. $($_.Exception.Message)" -ForegroundColor Red
            $browsingMembers = $false
            continue
        }

        Write-Host "`nMembers of '$selectedGroupDisplayName' :" -ForegroundColor Cyan
        if (-not $members) {
            Write-Host "  (No members)" -ForegroundColor Yellow
        }
        else {
            $mi = 1
            $memberIndex = @{}
            foreach ($m in $members) {
                $memberTypeLabel = Get-MemberTypeLabel $m
                $memberDisplayName = Get-MemberDisplayName $m
                Write-Host ("  {0}. {1}  [{2}]" -f $mi, $memberDisplayName, $memberTypeLabel)
                $memberIndex[$mi] = $m
                $mi++
            }
        }

        $memberSelection = Read-Host "`nEnter a member number to remove, or press Enter to go back to the group list"
        if ([string]::IsNullOrWhiteSpace($memberSelection) -or $memberSelection -eq "B" -or $memberSelection -eq "b") {
            $browsingMembers = $false
        }
        elseif ($members -and $memberIndex.ContainsKey([int]$memberSelection)) {
            $toRemove = $memberIndex[[int]$memberSelection]
            $toRemoveDisplayName = Get-MemberDisplayName $toRemove
            Write-Host "`nThis will remove '$toRemoveDisplayName' from '$selectedGroupDisplayName'." -ForegroundColor Red
            $confirm = Read-Host "Type YES to confirm (anything else cancels)"
            if ($confirm -eq "YES") {
                try {
                    Remove-DistributionGroupMember -Identity $selectedGroup.Identity -Member $toRemove.Identity -Confirm:$false -ErrorAction Stop
                    Write-Host "'$toRemoveDisplayName' removed from '$selectedGroupDisplayName'." -ForegroundColor Green
                }
                catch {
                    Write-Host "Error: Could not remove member. $($_.Exception.Message)" -ForegroundColor Red
                }
            }
            else {
                Write-Host "Not confirmed. Skipping." -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "Invalid selection entered." -ForegroundColor Yellow
        }
    }
}

Stop-ScriptHere
