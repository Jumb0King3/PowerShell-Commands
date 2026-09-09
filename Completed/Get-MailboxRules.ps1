# Get-MailboxRules.ps1
# Connects to Exchange Online if not already connected, then prompts for a
# mailbox and lists inbox rules in a summary table (including hidden rules).
# You can then choose a rule by number to view its full property details.
# Disconnects from Exchange Online when you exit.
# Logs all output to a transcript file for ticket documentation.
# Pressing Enter with no input at any prompt cancels/exits.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Get-MailboxRules_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
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

# --- Get inbox rules ---
$mailbox = Read-Host "`nEnter the mailbox email address (press Enter with no input to cancel)"
if ([string]::IsNullOrWhiteSpace($mailbox)) {
    Write-Host "No mailbox entered. Cancelling." -ForegroundColor Yellow
    Stop-ScriptHere
    return
}

try {
    $rules = Get-InboxRule -Mailbox $mailbox -IncludeHidden -ErrorAction Stop
}
catch {
    Write-Host "Error: Could not retrieve inbox rules for '$mailbox'. $($_.Exception.Message)" -ForegroundColor Red
    Stop-ScriptHere
    return
}

if (-not $rules) {
    Write-Host "No inbox rules found for $mailbox." -ForegroundColor Yellow
    Stop-ScriptHere
    return
}

# --- Summary table with index numbers ---
Write-Host "`nInbox rules for $mailbox :" -ForegroundColor Cyan
$i = 1
$indexed = @{}
$summary = foreach ($rule in $rules) {
    $indexed[$i] = $rule
    [PSCustomObject]@{
        "#"                   = $i
        Name                  = $rule.Name
        Enabled               = $rule.Enabled
        Priority              = $rule.Priority
        ForwardTo             = ($rule.ForwardTo -join ', ')
        RedirectTo            = ($rule.RedirectTo -join ', ')
        DeleteMessage         = $rule.DeleteMessage
        StopProcessingRules   = $rule.StopProcessingRules
    }
    $i++
}
$summary | Format-Table -AutoSize | Out-Host

# --- Loop: let the user drill into a specific rule, or exit ---
$reviewing = $true
while ($reviewing) {
    $selection = Read-Host "`nEnter a rule number to view full details, or press Enter with no input to finish"
    if ([string]::IsNullOrWhiteSpace($selection)) {
        $reviewing = $false
    }
    elseif ($indexed.ContainsKey([int]$selection)) {
        $ruleDetail = $indexed[[int]$selection]
        Write-Host "`nFull details for rule '$($ruleDetail.Name)' :" -ForegroundColor Cyan
        $ruleDetail | Format-List * | Out-Host
    }
    else {
        Write-Host "Invalid rule number entered." -ForegroundColor Yellow
    }
}

Stop-ScriptHere
