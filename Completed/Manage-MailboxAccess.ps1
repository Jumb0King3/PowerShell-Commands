# Manage-MailboxAccess.ps1
# Connects to Exchange Online if not already connected, then lets you View,
# Add, Remove, or Change Full Access, Send As, and Send on Behalf permissions
# on a mailbox - looping back to the menu so you can work through multiple
# mailboxes/actions in the same session.
# Disconnects from Exchange Online when you exit.
# Logs all output to a transcript file for ticket documentation.
# Pressing Enter with no input at any prompt cancels/skips.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Manage-MailboxAccess_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
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

# --- Helper functions for each permission type ---

function Show-AllAccess($mailbox) {
    try {
        Write-Host "`nAll Full Access permissions on $mailbox :" -ForegroundColor Cyan
        Get-MailboxPermission -Identity $mailbox -ErrorAction Stop |
            Where-Object { $_.User -notlike "NT AUTHORITY\SELF" } |
            Select-Object User, AccessRights, IsInherited | Format-Table -AutoSize

        Write-Host "Send As permissions on $mailbox :" -ForegroundColor Cyan
        Get-RecipientPermission -Identity $mailbox -ErrorAction Stop |
            Where-Object { $_.AccessRights -contains "SendAs" } |
            Select-Object Trustee, AccessRights | Format-Table -AutoSize

        Write-Host "Send on Behalf permissions on $mailbox :" -ForegroundColor Cyan
        $sob = (Get-Mailbox -Identity $mailbox -ErrorAction Stop).GrantSendOnBehalfTo
        if ($sob) { $sob | ForEach-Object { Write-Host "  $_" } } else { Write-Host "  (None)" -ForegroundColor Yellow }
    }
    catch {
        Write-Host "Error: Could not retrieve access for $mailbox. $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Show-FullAccessOnly($mailbox) {
    try {
        Write-Host "`nFull Access (non-inherited) on $mailbox :" -ForegroundColor Cyan
        Get-MailboxPermission -Identity $mailbox -ErrorAction Stop |
            Where-Object { $_.AccessRights -eq "FullAccess" -and $_.IsInherited -eq $false } |
            Select-Object User, AccessRights | Format-Table -AutoSize
    }
    catch {
        Write-Host "Error: Could not retrieve Full Access permissions. $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Show-SendAsOnly($mailbox) {
    try {
        Write-Host "`nSend As access on $mailbox :" -ForegroundColor Cyan
        Get-RecipientPermission -Identity $mailbox -ErrorAction Stop |
            Where-Object { $_.AccessRights -eq "SendAs" } |
            Select-Object Trustee, AccessRights | Format-Table -AutoSize
    }
    catch {
        Write-Host "Error: Could not retrieve Send As permissions. $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Show-SendOnBehalfOnly($mailbox) {
    try {
        Write-Host "`nSend on Behalf access on $mailbox :" -ForegroundColor Cyan
        $sob = (Get-Mailbox -Identity $mailbox -ErrorAction Stop).GrantSendOnBehalfTo
        if ($sob) { $sob | ForEach-Object { Write-Host "  $_" } } else { Write-Host "  (None)" -ForegroundColor Yellow }
    }
    catch {
        Write-Host "Error: Could not retrieve Send on Behalf permissions. $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Add-FullAccessPerm($mailbox, $user) {
    Write-Host "`nShould this mailbox automatically appear in $user's Outlook (AutoMapping)?" -ForegroundColor Cyan
    Write-Host "  Y = Yes, auto-appear in Outlook (default for a personal delegate)"
    Write-Host "  N = No, they'll add it manually via 'Open shared mailbox' (common for shared/service mailboxes)"
    $autoMapAnswer = Read-Host "Enter Y or N (press Enter with no input to default to Y)"
    $autoMap = -not ($autoMapAnswer -eq "N" -or $autoMapAnswer -eq "n")

    try {
        Add-MailboxPermission -Identity $mailbox -User $user -AccessRights FullAccess -AutoMapping:$autoMap -ErrorAction Stop | Out-Null
        Write-Host "Full Access granted to $user on $mailbox (AutoMapping: $autoMap)." -ForegroundColor Green
    }
    catch {
        Write-Host "Error: Could not grant Full Access. $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Add-SendAsPerm($mailbox, $user) {
    try {
        Add-RecipientPermission -Identity $mailbox -Trustee $user -AccessRights SendAs -Confirm:$false -ErrorAction Stop | Out-Null
        Write-Host "Send As granted to $user on $mailbox." -ForegroundColor Green
    }
    catch {
        Write-Host "Error: Could not grant Send As. $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Add-SendOnBehalfPerm($mailbox, $user) {
    try {
        Set-Mailbox -Identity $mailbox -GrantSendOnBehalfTo @{Add = $user} -ErrorAction Stop
        Write-Host "Send on Behalf granted to $user on $mailbox." -ForegroundColor Green
    }
    catch {
        Write-Host "Error: Could not grant Send on Behalf. $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Remove-FullAccessPerm($mailbox, $user) {
    try {
        Remove-MailboxPermission -Identity $mailbox -User $user -AccessRights FullAccess -Confirm:$false -ErrorAction Stop
        Write-Host "Full Access removed from $user on $mailbox." -ForegroundColor Green
    }
    catch {
        Write-Host "Error: Could not remove Full Access. $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Remove-SendAsPerm($mailbox, $user) {
    try {
        Remove-RecipientPermission -Identity $mailbox -Trustee $user -AccessRights SendAs -Confirm:$false -ErrorAction Stop
        Write-Host "Send As removed from $user on $mailbox." -ForegroundColor Green
    }
    catch {
        Write-Host "Error: Could not remove Send As. $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Remove-SendOnBehalfPerm($mailbox, $user) {
    try {
        Set-Mailbox -Identity $mailbox -GrantSendOnBehalfTo @{Remove = $user} -ErrorAction Stop
        Write-Host "Send on Behalf removed from $user on $mailbox." -ForegroundColor Green
    }
    catch {
        Write-Host "Error: Could not remove Send on Behalf. $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Select-PermissionType {
    Write-Host "  1. Full Access"
    Write-Host "  2. Send As"
    Write-Host "  3. Send on Behalf"
    return Read-Host "Enter 1, 2, or 3 (press Enter with no input to skip)"
}

# --- Main menu loop ---
$keepGoing = $true

while ($keepGoing) {

    Write-Host "`nWhat do you want to do?" -ForegroundColor Cyan
    Write-Host "  1. View mailbox access"
    Write-Host "  2. Add mailbox access"
    Write-Host "  3. Remove mailbox access"
    Write-Host "  4. Change mailbox access (remove one type, add another)"
    $action = Read-Host "`nEnter 1, 2, 3, or 4 (press Enter with no input to exit)"
    if ([string]::IsNullOrWhiteSpace($action)) {
        Write-Host "No option entered. Exiting." -ForegroundColor Yellow
        break
    }

    $mailbox = Read-Host "Enter the mailbox email address (press Enter with no input to exit)"
    if ([string]::IsNullOrWhiteSpace($mailbox)) {
        Write-Host "No mailbox entered. Exiting." -ForegroundColor Yellow
        break
    }

    switch ($action) {

        "1" {
            Write-Host "`nView which?" -ForegroundColor Cyan
            Write-Host "  1. All access (Full Access, Send As, Send on Behalf)"
            Write-Host "  2. Full Access only"
            Write-Host "  3. Send As only"
            Write-Host "  4. Send on Behalf only"
            $viewChoice = Read-Host "Enter 1, 2, 3, or 4 (press Enter with no input to skip)"
            switch ($viewChoice) {
                "1" { Show-AllAccess $mailbox }
                "2" { Show-FullAccessOnly $mailbox }
                "3" { Show-SendAsOnly $mailbox }
                "4" { Show-SendOnBehalfOnly $mailbox }
                default { Write-Host "No valid option entered. Skipping." -ForegroundColor Yellow }
            }
        }

        "2" {
            $user = Read-Host "Enter the email of the user to grant access to (press Enter with no input to skip)"
            if (-not [string]::IsNullOrWhiteSpace($user)) {
                Write-Host "`nGrant which type of access?" -ForegroundColor Cyan
                $typeChoice = Select-PermissionType
                switch ($typeChoice) {
                    "1" { Add-FullAccessPerm $mailbox $user }
                    "2" { Add-SendAsPerm $mailbox $user }
                    "3" { Add-SendOnBehalfPerm $mailbox $user }
                    default { Write-Host "No valid option entered. Skipping." -ForegroundColor Yellow }
                }
            } else { Write-Host "No user entered. Skipping." -ForegroundColor Yellow }
        }

        "3" {
            $user = Read-Host "Enter the email of the user to remove access from (press Enter with no input to skip)"
            if (-not [string]::IsNullOrWhiteSpace($user)) {
                Write-Host "`nRemove which type of access?" -ForegroundColor Cyan
                $typeChoice = Select-PermissionType
                if ($typeChoice -eq "1" -or $typeChoice -eq "2" -or $typeChoice -eq "3") {
                    $typeLabel = @{ "1" = "Full Access"; "2" = "Send As"; "3" = "Send on Behalf" }[$typeChoice]
                    Write-Host "`nThis will remove $typeLabel access for $user on $mailbox." -ForegroundColor Red
                    $confirm = Read-Host "Type YES to confirm (anything else skips)"
                    if ($confirm -eq "YES") {
                        switch ($typeChoice) {
                            "1" { Remove-FullAccessPerm $mailbox $user }
                            "2" { Remove-SendAsPerm $mailbox $user }
                            "3" { Remove-SendOnBehalfPerm $mailbox $user }
                        }
                    } else { Write-Host "Not confirmed. Skipping." -ForegroundColor Yellow }
                } else { Write-Host "No valid option entered. Skipping." -ForegroundColor Yellow }
            } else { Write-Host "No user entered. Skipping." -ForegroundColor Yellow }
        }

        "4" {
            $user = Read-Host "Enter the email of the user whose access you want to change (press Enter with no input to skip)"
            if (-not [string]::IsNullOrWhiteSpace($user)) {
                Write-Host "`nChange FROM which type?" -ForegroundColor Cyan
                $fromChoice = Select-PermissionType
                Write-Host "`nChange TO which type?" -ForegroundColor Cyan
                $toChoice = Select-PermissionType

                if (($fromChoice -eq "1" -or $fromChoice -eq "2" -or $fromChoice -eq "3") -and
                    ($toChoice -eq "1" -or $toChoice -eq "2" -or $toChoice -eq "3") -and
                    ($fromChoice -ne $toChoice)) {

                    $typeLabels = @{ "1" = "Full Access"; "2" = "Send As"; "3" = "Send on Behalf" }
                    Write-Host "`nThis will remove $($typeLabels[$fromChoice]) and grant $($typeLabels[$toChoice]) for $user on $mailbox." -ForegroundColor Red
                    $confirm = Read-Host "Type YES to confirm (anything else skips)"
                    if ($confirm -eq "YES") {
                        switch ($fromChoice) {
                            "1" { Remove-FullAccessPerm $mailbox $user }
                            "2" { Remove-SendAsPerm $mailbox $user }
                            "3" { Remove-SendOnBehalfPerm $mailbox $user }
                        }
                        switch ($toChoice) {
                            "1" { Add-FullAccessPerm $mailbox $user }
                            "2" { Add-SendAsPerm $mailbox $user }
                            "3" { Add-SendOnBehalfPerm $mailbox $user }
                        }
                    } else { Write-Host "Not confirmed. Skipping." -ForegroundColor Yellow }
                }
                else {
                    Write-Host "Invalid selection - 'From' and 'To' must both be valid and different. Skipping." -ForegroundColor Yellow
                }
            } else { Write-Host "No user entered. Skipping." -ForegroundColor Yellow }
        }

        default {
            Write-Host "Invalid option entered." -ForegroundColor Yellow
        }
    }

    Write-Host ""
    $again = Read-Host "Press Enter to return to the menu, or type X to exit"
    if ($again -eq "X" -or $again -eq "x") {
        $keepGoing = $false
    }
}

Stop-ScriptHere
