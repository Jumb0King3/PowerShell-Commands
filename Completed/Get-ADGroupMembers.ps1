# Get-ADGroupMembers.ps1
# Prompts for an AD group name and lists its members, with a choice of
# output: names only, full details (GivenName/Surname/DisplayName), or
# full details exported to CSV.
# Pressing Enter with no input at the group prompt cancels.

$groupName = Read-Host "Enter the AD group name (press Enter with no input to cancel)"
if ([string]::IsNullOrWhiteSpace($groupName)) {
    Write-Host "No group name entered. Cancelling." -ForegroundColor Yellow
    return
}

try {
    $members = Get-ADGroupMember -Identity $groupName -ErrorAction Stop
}
catch {
    Write-Host "Error: Could not retrieve members for '$groupName'. $($_.Exception.Message)" -ForegroundColor Red
    return
}

if (-not $members) {
    Write-Host "No members found in '$groupName'." -ForegroundColor Yellow
    return
}

Write-Host "`nHow do you want to view the members of '$groupName' ($($members.Count) found)?" -ForegroundColor Cyan
Write-Host "  1. Names only"
Write-Host "  2. Full details (Name, GivenName, Surname, DisplayName)"
Write-Host "  3. Full details, exported to CSV"
$choice = Read-Host "Enter 1, 2, or 3 (press Enter with no input to cancel)"

switch ($choice) {

    "1" {
        $members | Select-Object Name | Format-Table -AutoSize
    }

    "2" {
        try {
            $members | Get-ADUser -Properties GivenName, Surname, DisplayName -ErrorAction Stop |
                Select-Object Name, GivenName, Surname, DisplayName | Format-Table -AutoSize
        }
        catch {
            Write-Host "Error: Could not retrieve user details. $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    "3" {
        $defaultPath = "C:\Temp\$groupName.csv"
        $csvPath = Read-Host "Enter the CSV output path (press Enter with no input to use $defaultPath)"
        if ([string]::IsNullOrWhiteSpace($csvPath)) { $csvPath = $defaultPath }

        $csvFolder = Split-Path $csvPath -Parent
        if ($csvFolder -and -not (Test-Path $csvFolder)) {
            New-Item -Path $csvFolder -ItemType Directory -Force | Out-Null
        }

        try {
            $members | Get-ADUser -Properties GivenName, Surname, DisplayName -ErrorAction Stop |
                Select-Object Name, GivenName, Surname, DisplayName |
                Export-Csv -Path $csvPath -NoTypeInformation -ErrorAction Stop
            Write-Host "Exported to $csvPath" -ForegroundColor Green
        }
        catch {
            Write-Host "Error: Could not export CSV. $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    default {
        Write-Host "No valid option entered. Cancelling." -ForegroundColor Yellow
    }
}
