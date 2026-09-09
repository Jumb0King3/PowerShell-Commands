# Copy-M365GroupMemberships.ps1
# Connects to Microsoft Graph and Exchange Online (if not already connected),
# then copies all group memberships from one user to another - covering
# Microsoft 365 Groups, Distribution Lists, Mail-Enabled Security Groups,
# and plain Entra ID Security Groups (non-mail-enabled).
# Prompts for the source user (copy from) and target user (copy to).
# Disconnects from both services when you exit.
# Logs all output to a transcript file for ticket documentation.
# Pressing Enter with no input at either user prompt cancels.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Copy-M365GroupMemberships_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

function Stop-ScriptHere {
    try {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        Write-Host "`nDisconnected from Exchange Online." -ForegroundColor Cyan
    }
    catch { }
    try {
        Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
        Write-Host "Disconnected from Microsoft Graph." -ForegroundColor Cyan
    }
    catch { }
    Write-Host "Log saved to: $logFile" -ForegroundColor Cyan
    Stop-Transcript | Out-Null
    Read-Host "`nPress Enter to close this window"
}

# --- Ensure connected to Microsoft Graph FIRST (loading it after EXO can cause an assembly conflict) ---
$graphConnected = $false
try {
    $ctx = Get-MgContext -ErrorAction Stop
    if ($ctx) { $graphConnected = $true }
}
catch { $graphConnected = $false }

if (-not $graphConnected) {
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Groups)) {
        Write-Host "Microsoft Graph module not found. Installing (this can take a few minutes the first time)..." -ForegroundColor Cyan
        try {
            Install-Module -Name Microsoft.Graph -Scope CurrentUser -Force -ErrorAction Stop
        }
        catch {
            Write-Host "Error installing Microsoft Graph module: $($_.Exception.Message)" -ForegroundColor Red
            Stop-Transcript | Out-Null
            Read-Host "`nPress Enter to close this window"
            return
        }
    }

    try {
        Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
        Import-Module Microsoft.Graph.Users -ErrorAction Stop
        Import-Module Microsoft.Graph.Groups -ErrorAction Stop
        Connect-MgGraph -Scopes "Group.ReadWrite.All", "User.Read.All" -NoWelcome -ErrorAction Stop
        Write-Host "Connected to Microsoft Graph." -ForegroundColor Green
    }
    catch {
        Write-Host "Error connecting to Microsoft Graph: $($_.Exception.Message)" -ForegroundColor Red
        Stop-Transcript | Out-Null
        Read-Host "`nPress Enter to close this window"
        return
    }
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
            Stop-ScriptHere
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
            Stop-ScriptHere
            return
        }
    }
    Write-Host "Connected to Exchange Online." -ForegroundColor Green
}

# --- Get source and target users ---
$SourceUser = Read-Host "`nEnter the source user's email - the user to copy group memberships FROM (press Enter with no input to cancel)"
if ([string]::IsNullOrWhiteSpace($SourceUser)) {
    Write-Host "No source user entered. Cancelling." -ForegroundColor Yellow
    Stop-ScriptHere
    return
}

$TargetUser = Read-Host "Enter the target user's email - the user to copy group memberships TO (press Enter with no input to cancel)"
if ([string]::IsNullOrWhiteSpace($TargetUser)) {
    Write-Host "No target user entered. Cancelling." -ForegroundColor Yellow
    Stop-ScriptHere
    return
}

$matchingGroups = @()   # each entry: Name, Type, Identity, IsDirSynced, Source ("EXO" or "Graph")

# --- Check Microsoft 365 Groups (Unified Groups) via Exchange Online ---
Write-Host "`nSearching Microsoft 365 Groups for memberships held by $SourceUser ..." -ForegroundColor Cyan
try {
    $unifiedGroups = Get-UnifiedGroup -ResultSize Unlimited -ErrorAction Stop
    $total = $unifiedGroups.Count
    $count = 0
    foreach ($grp in $unifiedGroups) {
        $count++
        Write-Progress -Activity "Checking Microsoft 365 Groups" -Status "$count of $total : $($grp.DisplayName)" -PercentComplete (($count / $total) * 100)
        try {
            $members = Get-UnifiedGroupLinks -Identity $grp.Identity -LinkType Members -ResultSize Unlimited -ErrorAction Stop
            if ($members | Where-Object { $_.PrimarySmtpAddress -eq $SourceUser -or $_.Name -eq $SourceUser }) {
                $matchingGroups += [PSCustomObject]@{ Name = $grp.DisplayName; Type = "M365 Group"; Identity = $grp.Identity; IsDirSynced = $false; Source = "EXO" }
            }
        }
        catch { }
    }
    Write-Progress -Activity "Checking Microsoft 365 Groups" -Completed
}
catch {
    Write-Host "Error: Could not retrieve Microsoft 365 Groups. $($_.Exception.Message)" -ForegroundColor Red
}

# --- Check Distribution Lists and Mail-Enabled Security Groups via Exchange Online ---
Write-Host "Searching Distribution Lists and Mail-Enabled Security Groups for memberships held by $SourceUser ..." -ForegroundColor Cyan
try {
    $distGroups = Get-DistributionGroup -ResultSize Unlimited -ErrorAction Stop
    $total = $distGroups.Count
    $count = 0
    foreach ($grp in $distGroups) {
        $count++
        Write-Progress -Activity "Checking Distribution Lists / Mail-Enabled Security Groups" -Status "$count of $total : $($grp.Name)" -PercentComplete (($count / $total) * 100)
        try {
            $members = Get-DistributionGroupMember -Identity $grp.Identity -ResultSize Unlimited -ErrorAction Stop
            if ($members | Where-Object { $_.PrimarySmtpAddress -eq $SourceUser -or $_.Name -eq $SourceUser }) {
                $typeLabel = if ($grp.RecipientTypeDetails -eq "MailUniversalSecurityGroup") { "Mail-Enabled Security Group" } else { "Distribution List" }
                $matchingGroups += [PSCustomObject]@{ Name = $grp.Name; Type = $typeLabel; Identity = $grp.Identity; IsDirSynced = $grp.IsDirSynced; Source = "EXO" }
            }
        }
        catch { }
    }
    Write-Progress -Activity "Checking Distribution Lists / Mail-Enabled Security Groups" -Completed
}
catch {
    Write-Host "Error: Could not retrieve Distribution Lists / Mail-Enabled Security Groups. $($_.Exception.Message)" -ForegroundColor Red
}

# --- Check plain Entra ID Security Groups (non-mail-enabled) via Microsoft Graph ---
Write-Host "Searching Entra ID Security Groups (non-mail-enabled) for memberships held by $SourceUser ..." -ForegroundColor Cyan
try {
    $sourceUserObj = Get-MgUser -UserId $SourceUser -ErrorAction Stop
    $memberOfGroups = Get-MgUserMemberOf -UserId $sourceUserObj.Id -All -ErrorAction Stop

    foreach ($g in $memberOfGroups) {
        try {
            $groupDetail = Get-MgGroup -GroupId $g.Id -ErrorAction Stop
            if (-not $groupDetail.MailEnabled -and -not $groupDetail.GroupTypes.Contains("DynamicMembership")) {
                $matchingGroups += [PSCustomObject]@{ Name = $groupDetail.DisplayName; Type = "Security Group (Entra ID)"; Identity = $groupDetail.Id; IsDirSynced = $groupDetail.OnPremisesSyncEnabled; Source = "Graph" }
            }
            elseif ($groupDetail.GroupTypes.Contains("DynamicMembership")) {
                Write-Host "  Skipping '$($groupDetail.DisplayName)' - dynamic membership group, members can't be added manually." -ForegroundColor DarkGray
            }
        }
        catch { }
    }
}
catch {
    Write-Host "Error: Could not retrieve Entra ID group memberships. $($_.Exception.Message)" -ForegroundColor Red
}

if (-not $matchingGroups) {
    Write-Host "`n$SourceUser is not a member of any Microsoft 365 Groups, Distribution Lists, Mail-Enabled Security Groups, or Entra ID Security Groups. Nothing to copy." -ForegroundColor Yellow
    Stop-ScriptHere
    return
}

Write-Host "`n$SourceUser is a member of $($matchingGroups.Count) group(s):" -ForegroundColor Cyan
$matchingGroups | ForEach-Object {
    $syncNote = if ($_.IsDirSynced) { " [AD Synced]" } else { "" }
    Write-Host "  $($_.Name)  [$($_.Type)]$syncNote"
}

if ($matchingGroups | Where-Object { $_.IsDirSynced }) {
    Write-Host "`nNote: one or more groups above are AD Synced. Changes to these should normally be made in on-prem AD - adding the member here may fail or be reverted on the next sync." -ForegroundColor Yellow
}

Write-Host "`nThis will add $TargetUser to all $($matchingGroups.Count) group(s) listed above." -ForegroundColor Yellow
$confirm = Read-Host "Type YES to continue (anything else cancels)"
if ($confirm -ne "YES") {
    Write-Host "Not confirmed. Cancelling." -ForegroundColor Yellow
    Stop-ScriptHere
    return
}

$targetUserObj = $null
if ($matchingGroups | Where-Object { $_.Source -eq "Graph" }) {
    try {
        $targetUserObj = Get-MgUser -UserId $TargetUser -ErrorAction Stop
    }
    catch {
        Write-Host "Error: Could not resolve target user '$TargetUser' in Microsoft Graph. $($_.Exception.Message)" -ForegroundColor Red
    }
}

foreach ($grp in $matchingGroups) {
    try {
        if ($grp.Type -eq "M365 Group") {
            Add-UnifiedGroupLinks -Identity $grp.Identity -LinkType Members -Links $TargetUser -ErrorAction Stop
        }
        elseif ($grp.Source -eq "EXO") {
            Add-DistributionGroupMember -Identity $grp.Identity -Member $TargetUser -ErrorAction Stop
        }
        else {
            if (-not $targetUserObj) { throw "Target user could not be resolved in Microsoft Graph." }
            New-MgGroupMember -GroupId $grp.Identity -DirectoryObjectId $targetUserObj.Id -ErrorAction Stop
        }
        Write-Host "Added $TargetUser to $($grp.Name) [$($grp.Type)]" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to add $TargetUser to $($grp.Name) [$($grp.Type)] - $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nDone." -ForegroundColor Cyan
Stop-ScriptHere
