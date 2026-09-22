#Requires -Modules ExchangeOnlineManagement

<#
    Import-InboxRules.ps1

    Creates Exchange Online inbox rules for a single mailbox from a CSV file
    (InboxRules-Import.csv), which was converted from an EXO Get-InboxRule
    export (InboxRules-Before.json).

    The CSV schema supports more than just "move to folder" rules: each row
    can carry any combination of the conditions/actions below, so it holds
    up for future exports too, not just the current ruleset.

    CSV columns:
        Name                        - Rule name (required, used for duplicate detection)
        Enabled                     - True/False. If False, the rule is created then disabled.
        Priority                    - Informational only (kept from the source export so the
                                       CSV can be sorted / reviewed in original rule order).
                                       Not passed to New-InboxRule - rules are created in the
                                       order they appear in the CSV, which sets their priority.
        From                        - Semicolon-separated sender email addresses
        FromAddressContainsWords    - Semicolon-separated words/phrases
        SentTo                      - Semicolon-separated recipient identities (email address,
                                       or display name for internal/on-prem recipients that had
                                       no SMTP address in the source export - see WARNING below)
        SubjectContainsWords        - Semicolon-separated words/phrases
        SentOnlyToMe                - True/False
        StopProcessingRules         - True/False
        DeleteMessage               - True/False
        MoveToFolder                - Folder name/path (e.g. "4. Invoices"); the mailbox prefix
                                       is added automatically at import time
        CopyToFolder                - Folder name/path, same handling as MoveToFolder
        ForwardTo                   - Semicolon-separated recipient identities
        MarkAsRead                  - True/False

    WARNING - SentTo for internal recipients:
        Where the source export only had an internal/EX-resolved recipient
        (no SMTP address), the CSV falls back to that recipient's display
        name (e.g. "Rosalie Byrne"). Exchange Online can usually resolve a
        -SentTo value by display name, but if a rule below fails because a
        SentTo recipient can't be resolved, replace that name in the CSV
        with the recipient's email address and re-run.

    Usage:
        Connect-ExchangeOnline
        .\Import-InboxRules.ps1
        .\Import-InboxRules.ps1 -Mailbox "someoneelse@willistemby.com.au" -CsvPath ".\InboxRules-Import.csv"

        # Dry run - shows what would be created/disabled without changing anything:
        .\Import-InboxRules.ps1 -WhatIf
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [string]$Mailbox = "lorettap@willistemby.com.au",
    [string]$CsvPath = (Join-Path $PSScriptRoot "InboxRules-Import.csv")
)

$SEP = ';'

function ConvertTo-Bool($value) {
    return ($value -and $value.Trim().ToLower() -eq 'true')
}

function ConvertTo-List($value) {
    if ([string]::IsNullOrWhiteSpace($value)) { return $null }
    return $value -split [regex]::Escape($SEP) | Where-Object { $_ -ne '' } | ForEach-Object { $_.Trim() }
}

if (-not (Test-Path $CsvPath)) {
    throw "CSV file not found: $CsvPath"
}

$Rules = Import-Csv -Path $CsvPath

foreach ($Rule in $Rules) {

    try {

        $ExistingRule = Get-InboxRule -Mailbox $Mailbox -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq $Rule.Name }

        if ($ExistingRule) {
            Write-Warning "Rule already exists: $($Rule.Name)"
            continue
        }

        $params = @{
            Mailbox = $Mailbox
            Name    = $Rule.Name
        }

        $from = ConvertTo-List $Rule.From
        if ($from) { $params['From'] = $from }

        $fromAddrWords = ConvertTo-List $Rule.FromAddressContainsWords
        if ($fromAddrWords) { $params['FromAddressContainsWords'] = $fromAddrWords }

        $sentTo = ConvertTo-List $Rule.SentTo
        if ($sentTo) { $params['SentTo'] = $sentTo }

        $subjectWords = ConvertTo-List $Rule.SubjectContainsWords
        if ($subjectWords) { $params['SubjectContainsWords'] = $subjectWords }

        if (ConvertTo-Bool $Rule.SentOnlyToMe) { $params['SentOnlyToMe'] = $true }
        if (ConvertTo-Bool $Rule.StopProcessingRules) { $params['StopProcessingRules'] = $true }
        if (ConvertTo-Bool $Rule.DeleteMessage) { $params['DeleteMessage'] = $true }
        if (ConvertTo-Bool $Rule.MarkAsRead) { $params['MarkAsRead'] = $true }

        if (-not [string]::IsNullOrWhiteSpace($Rule.MoveToFolder)) {
            $params['MoveToFolder'] = "$Mailbox`:\$($Rule.MoveToFolder)"
        }

        if (-not [string]::IsNullOrWhiteSpace($Rule.CopyToFolder)) {
            $params['CopyToFolder'] = "$Mailbox`:\$($Rule.CopyToFolder)"
        }

        $forwardTo = ConvertTo-List $Rule.ForwardTo
        if ($forwardTo) { $params['ForwardTo'] = $forwardTo }

        if ($PSCmdlet.ShouldProcess($Rule.Name, "Create inbox rule in mailbox $Mailbox")) {
            New-InboxRule @params

            if (-not (ConvertTo-Bool $Rule.Enabled)) {
                Disable-InboxRule -Mailbox $Mailbox -Identity $Rule.Name -Confirm:$false
            }

            Write-Host "Created: $($Rule.Name)" -ForegroundColor Green
        }
    }
    catch {
        Write-Warning "Failed: $($Rule.Name)"
        Write-Warning $_.Exception.Message
    }
}
