# Find-MailboxAccessForUser.ps1
# Connects to Exchange Online if not already connected, then prompts for a
# user and searches every mailbox in the tenant for Full Access permissions
# held by that user - showing which mailbox and what access level.
# Disconnects from Exchange Online when you exit.
# Logs all output to a transcript file for ticket documentation.
# Pressing Enter with no input at the user prompt cancels.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Find-MailboxAccessForUser_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
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

# --- Search all mailboxes for access held by this user ---
$user = Read-Host "`nEnter the user's email to search for (press Enter with no input to cancel)"
if ([string]::IsNullOrWhiteSpace($user)) {
    Write-Host "No user entered. Cancelling." -ForegroundColor Yellow
    Stop-ScriptHere
    return
}

Write-Host "`nSearching all mailboxes for access held by $user - this can take a while on larger tenants..." -ForegroundColor Cyan

try {
    $allMailboxes = Get-Mailbox -ResultSize Unlimited -ErrorAction Stop
}
catch {
    Write-Host "Error: Could not retrieve mailbox list. $($_.Exception.Message)" -ForegroundColor Red
    Stop-ScriptHere
    return
}

$results = @()
$total = $allMailboxes.Count
$count = 0

foreach ($mbx in $allMailboxes) {
    $count++
    Write-Progress -Activity "Checking mailbox permissions" -Status "$count of $total : $($mbx.DisplayName)" -PercentComplete (($count / $total) * 100)

    try {
        $perms = Get-MailboxPermission -Identity $mbx.Identity -ErrorAction SilentlyContinue |
            Where-Object { $_.User -like $user -and $_.AccessRights -ne "None" }

        foreach ($p in $perms) {
            $results += [PSCustomObject]@{
                Mailbox      = $mbx.DisplayName
                User         = $p.User
                AccessRights = ($p.AccessRights -join ', ')
            }
        }
    }
    catch { }
}

Write-Progress -Activity "Checking mailbox permissions" -Completed

if (-not $results) {
    Write-Host "`n$user has no mailbox access found on any mailbox." -ForegroundColor Yellow
}
else {
    Write-Host "`nMailboxes $user has access to :" -ForegroundColor Cyan
    $results | Format-Table -AutoSize
}

Stop-ScriptHere
