# Add-CalendarPermissionsByGroup.ps1
# Connects to Exchange Online if not already connected, then grants (or
# updates) calendar permissions on a target calendar for every member of
# a Microsoft 365 Group.
# Disconnects from Exchange Online when you exit.
# Logs all output to a transcript file for ticket documentation.
# Pressing Enter with no input at any prompt cancels.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Add-CalendarPermissionsByGroup_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
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

# --- Prompts ---
$groupSearch = Read-Host "`nEnter the group's display name or part of it to search for (press Enter with no input to cancel)"
if ([string]::IsNullOrWhiteSpace($groupSearch)) {
    Write-Host "No group search text entered. Cancelling." -ForegroundColor Yellow
    Stop-ScriptHere
    return
}

$owner = Read-Host "Enter the calendar owner's mailbox email (press Enter with no input to cancel)"
if ([string]::IsNullOrWhiteSpace($owner)) {
    Write-Host "No calendar owner entered. Cancelling." -ForegroundColor Yellow
    Stop-ScriptHere
    return
}

Write-Host "`nAccess level options: Owner, PublishingEditor, Editor, PublishingAuthor, Author, NonEditingAuthor, Reviewer, Contributor, AvailabilityOnly, LimitedDetails, None" -ForegroundColor Cyan
$accessRight = Read-Host "Enter the access level to grant (press Enter with no input to cancel)"
if ([string]::IsNullOrWhiteSpace($accessRight)) {
    Write-Host "No access level entered. Cancelling." -ForegroundColor Yellow
    Stop-ScriptHere
    return
}

$updateAnswer = Read-Host "If a member already has a permission on this calendar, update it to this level? Type Y or N (press Enter with no input to default to Y)"
$updateExisting = -not ($updateAnswer -eq "N" -or $updateAnswer -eq "n")

# --- Resolve the group unambiguously ---
try {
    $groups = @(Get-UnifiedGroup -ResultSize Unlimited -ErrorAction Stop | Where-Object { $_.DisplayName -like "*$groupSearch*" })
}
catch {
    Write-Host "Error: Could not search Microsoft 365 Groups. $($_.Exception.Message)" -ForegroundColor Red
    Stop-ScriptHere
    return
}

if ($groups.Count -eq 0) {
    Write-Host "No Microsoft 365 Group matched '$groupSearch'." -ForegroundColor Yellow
    Stop-ScriptHere
    return
}
if ($groups.Count -gt 1) {
    Write-Host "`nMultiple groups matched '$groupSearch' :" -ForegroundColor Cyan
    $gi = 1
    $groupIndex = @{}
    foreach ($g in $groups) { Write-Host "  $gi. $($g.DisplayName)"; $groupIndex[$gi] = $g; $gi++ }
    $sel = Read-Host "`nEnter the number of the group to use (press Enter with no input to cancel)"
    if ([string]::IsNullOrWhiteSpace($sel) -or -not $groupIndex.ContainsKey([int]$sel)) {
        Write-Host "No valid selection made. Cancelling." -ForegroundColor Yellow
        Stop-ScriptHere
        return
    }
    $group = $groupIndex[[int]$sel]
}
else {
    $group = $groups[0]
}

# --- Resolve the target calendar folder ---
try {
    $calendarFolder = Get-MailboxFolder -Identity "$($owner):\" -Recurse -ErrorAction Stop |
        Where-Object { $_.FolderClass -eq "IPF.Appointment" -or $_.FolderType -eq "Calendar" } |
        Select-Object -First 1
}
catch {
    Write-Host "Error: Could not find calendar folder for $owner. $($_.Exception.Message)" -ForegroundColor Red
    Stop-ScriptHere
    return
}

if (-not $calendarFolder) {
    Write-Host "No calendar folder found for $owner." -ForegroundColor Yellow
    Stop-ScriptHere
    return
}

$calendarIdentity = $calendarFolder.Identity.ToString()

# --- Get group members ---
try {
    $members = @(Get-UnifiedGroupLinks -Identity $group.Identity -LinkType Members -ResultSize Unlimited -ErrorAction Stop)
}
catch {
    Write-Host "Error: Could not retrieve members of '$($group.DisplayName)'. $($_.Exception.Message)" -ForegroundColor Red
    Stop-ScriptHere
    return
}

if ($members.Count -eq 0) {
    Write-Host "`n'$($group.DisplayName)' has no members. Nothing to do." -ForegroundColor Yellow
    Stop-ScriptHere
    return
}

Write-Host "`nThis will grant/update '$accessRight' access to $($calendarFolder.FolderPath -replace '/','\') for all $($members.Count) member(s) of '$($group.DisplayName)'." -ForegroundColor Yellow
$confirm = Read-Host "Type YES to continue (anything else cancels)"
if ($confirm -ne "YES") {
    Write-Host "Not confirmed. Cancelling." -ForegroundColor Yellow
    Stop-ScriptHere
    return
}

# --- Apply permissions ---
$results = @()

foreach ($member in $members) {
    if (-not $member.PrimarySmtpAddress) { continue }

    try {
        $existing = Get-MailboxFolderPermission -Identity $calendarIdentity -User $member.PrimarySmtpAddress -ErrorAction SilentlyContinue

        if ($existing) {
            if ($updateExisting) {
                Set-MailboxFolderPermission -Identity $calendarIdentity -User $member.PrimarySmtpAddress -AccessRights $accessRight -ErrorAction Stop
                $action = "Updated"
            }
            else {
                $action = "Skipped (already has access)"
            }
        }
        else {
            Add-MailboxFolderPermission -Identity $calendarIdentity -User $member.PrimarySmtpAddress -AccessRights $accessRight -ErrorAction Stop
            $action = "Added"
        }

        Write-Host "$($member.PrimarySmtpAddress) : $action" -ForegroundColor Green
        $results += [PSCustomObject]@{ Member = $member.PrimarySmtpAddress; Action = $action; Error = "" }
    }
    catch {
        Write-Host "$($member.PrimarySmtpAddress) : FAILED - $($_.Exception.Message)" -ForegroundColor Red
        $results += [PSCustomObject]@{ Member = $member.PrimarySmtpAddress; Action = "Failed"; Error = $_.Exception.Message }
    }
}

Write-Host "`nSummary :" -ForegroundColor Cyan
$results | Format-Table -AutoSize

Stop-ScriptHere
