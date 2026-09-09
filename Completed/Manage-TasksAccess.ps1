# Manage-TasksAccess.ps1
# Connects to Exchange Online if not already connected, then lets you
# Grant, View (all or one user), Edit, or Remove Tasks folder permissions -
# including any sub-folders under Tasks, not just the main Tasks folder -
# looping back to the menu after each action so you can perform multiple
# actions on the same connection.
# Disconnects from Exchange Online when you exit.
# Logs all output to a transcript file for ticket documentation.
# Pressing Enter with no input at any prompt cancels.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Manage-TasksAccess_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
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

# --- Function: list Tasks folders (main + sub-folders) and let the user pick one ---
function Select-TasksFolder {
    param($owner)

    try {
        $tasksFolders = Get-MailboxFolder -Identity "$($owner):\" -Recurse -ErrorAction Stop |
            Where-Object { $_.FolderClass -eq "IPF.Task" -or $_.FolderType -eq "Tasks" }
    }
    catch {
        Write-Host "Error: Could not list Tasks folders for $owner. $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }

    if (-not $tasksFolders) {
        Write-Host "No Tasks folders found for $owner." -ForegroundColor Yellow
        return $null
    }

    Write-Host "`nTasks folders found for $owner :" -ForegroundColor Cyan
    $i = 1
    $indexed = @{}
    foreach ($folder in $tasksFolders) {
        $displayName = ($folder.FolderPath -replace '/', '\').TrimStart('\')
        Write-Host "  $i. $displayName"
        $indexed[$i] = $folder
        $i++
    }

    if ($tasksFolders.Count -eq 1) {
        Write-Host "(Only one Tasks folder found - selecting it automatically.)" -ForegroundColor DarkGray
        $chosen = $indexed[1]
    }
    else {
        $selection = Read-Host "`nEnter the number of the Tasks folder to use (press Enter with no input to skip)"
        if ([string]::IsNullOrWhiteSpace($selection) -or -not $indexed.ContainsKey([int]$selection)) {
            Write-Host "No valid selection made. Skipping." -ForegroundColor Yellow
            return $null
        }
        $chosen = $indexed[[int]$selection]
    }

    return $chosen.Identity.ToString()
}

# --- Main menu loop ---
$keepGoing = $true

while ($keepGoing) {

    Write-Host "`nWhat do you want to do?" -ForegroundColor Cyan
    Write-Host "  1. Grant access (new permission)"
    Write-Host "  2. View access - all users"
    Write-Host "  3. View access - a specific user"
    Write-Host "  4. Edit existing permission (change access level)"
    Write-Host "  5. Remove permission"
    $action = Read-Host "`nEnter 1, 2, 3, 4, or 5 (press Enter with no input to exit)"
    if ([string]::IsNullOrWhiteSpace($action)) {
        Write-Host "No option entered. Exiting." -ForegroundColor Yellow
        break
    }

    $owner = Read-Host "Enter the mailbox owner's email (whose Tasks folders you want to check) (press Enter with no input to exit)"
    if ([string]::IsNullOrWhiteSpace($owner)) {
        Write-Host "No mailbox owner entered. Exiting." -ForegroundColor Yellow
        break
    }

    $tasksIdentity = Select-TasksFolder -owner $owner
    if (-not $tasksIdentity) {
        Write-Host ""
        $again = Read-Host "Press Enter to return to the menu, or type X to exit"
        if ($again -eq "X" -or $again -eq "x") { $keepGoing = $false }
        continue
    }

    switch ($action) {

        "1" {
            $grantee = Read-Host "Enter the email of the user being granted access (press Enter with no input to skip)"
            if (-not [string]::IsNullOrWhiteSpace($grantee)) {
                Write-Host "`nAccess level options: Owner, PublishingEditor, Editor, PublishingAuthor, Author, NonEditingAuthor, Reviewer, Contributor, None" -ForegroundColor Cyan
                $accessRight = Read-Host "Enter the access level to grant (press Enter with no input to skip)"
                if (-not [string]::IsNullOrWhiteSpace($accessRight)) {
                    try {
                        Add-MailboxFolderPermission -Identity $tasksIdentity -User $grantee -AccessRights $accessRight -ErrorAction Stop
                        Write-Host "$grantee granted '$accessRight' access to $tasksIdentity." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "Error: Could not grant access. $($_.Exception.Message)" -ForegroundColor Red
                        Write-Host "(If this user already has a permission on this folder, use option 4 - Edit - instead.)" -ForegroundColor Yellow
                    }
                } else { Write-Host "No access level entered. Skipping." -ForegroundColor Yellow }
            } else { Write-Host "No user entered. Skipping." -ForegroundColor Yellow }
        }

        "2" {
            try {
                Write-Host "`nAll permissions on $tasksIdentity :" -ForegroundColor Cyan
                Get-MailboxFolderPermission -Identity $tasksIdentity -ErrorAction Stop | Select-Object User, AccessRights | Format-Table -AutoSize
            }
            catch {
                Write-Host "Error: Could not retrieve permissions. $($_.Exception.Message)" -ForegroundColor Red
            }
        }

        "3" {
            $grantee = Read-Host "Enter the email of the user whose access you want to view (press Enter with no input to skip)"
            if (-not [string]::IsNullOrWhiteSpace($grantee)) {
                try {
                    Write-Host "`nAccess for $grantee on $tasksIdentity :" -ForegroundColor Cyan
                    Get-MailboxFolderPermission -Identity $tasksIdentity -User $grantee -ErrorAction Stop | Select-Object User, AccessRights | Format-Table -AutoSize
                }
                catch {
                    Write-Host "Error: Could not retrieve permissions for $grantee. $($_.Exception.Message)" -ForegroundColor Red
                }
            } else { Write-Host "No user entered. Skipping." -ForegroundColor Yellow }
        }

        "4" {
            $grantee = Read-Host "Enter the email of the user whose access you want to change (press Enter with no input to skip)"
            if (-not [string]::IsNullOrWhiteSpace($grantee)) {
                Write-Host "`nAccess level options: Owner, PublishingEditor, Editor, PublishingAuthor, Author, NonEditingAuthor, Reviewer, Contributor, None" -ForegroundColor Cyan
                $accessRight = Read-Host "Enter the new access level (press Enter with no input to skip)"
                if (-not [string]::IsNullOrWhiteSpace($accessRight)) {
                    try {
                        Set-MailboxFolderPermission -Identity $tasksIdentity -User $grantee -AccessRights $accessRight -ErrorAction Stop
                        Write-Host "$grantee's access to $tasksIdentity updated to '$accessRight'." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "Error: Could not update access. $($_.Exception.Message)" -ForegroundColor Red
                        Write-Host "(If this user doesn't have a permission on this folder yet, use option 1 - Grant - instead.)" -ForegroundColor Yellow
                    }
                } else { Write-Host "No access level entered. Skipping." -ForegroundColor Yellow }
            } else { Write-Host "No user entered. Skipping." -ForegroundColor Yellow }
        }

        "5" {
            $grantee = Read-Host "Enter the email of the user whose access you want to remove (press Enter with no input to skip)"
            if (-not [string]::IsNullOrWhiteSpace($grantee)) {
                Write-Host "`nThis will remove $grantee's access to $tasksIdentity." -ForegroundColor Red
                $confirm = Read-Host "Type YES to confirm (anything else skips)"
                if ($confirm -eq "YES") {
                    try {
                        Remove-MailboxFolderPermission -Identity $tasksIdentity -User $grantee -Confirm:$false -ErrorAction Stop
                        Write-Host "$grantee's access to $tasksIdentity has been removed." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "Error: Could not remove access. $($_.Exception.Message)" -ForegroundColor Red
                    }
                } else { Write-Host "Not confirmed. Skipping." -ForegroundColor Yellow }
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
