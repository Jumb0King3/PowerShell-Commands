# View-AppliedTweaks.ps1
# Checks the LIVE registry state of all 19 Enable-* tweaks and reports
# whether each is currently Applied or Not Applied on this device.
#
# NOTE: Redesigned from the original, which determined "Applied" status by
# checking whether a backup file still existed (since its Restore tools
# deleted the backup once a tweak was reverted). This version's
# Restore-*.ps1 scripts deliberately do NOT delete backups after
# restoring (so a history is kept), which would make a backup-presence
# check unreliable here - it would keep reporting "Applied" even after a
# tweak had been restored. Instead, this checks each tweak's actual
# current registry value directly against its known "applied" value, which
# is always accurate regardless of backup file history.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "View-AppliedTweaks_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

$tweaks = @(
    @{ DisplayName = 'Auto Close Unresponsive Programs';    Path = 'HKCU:\Control Panel\Desktop'; Name = 'AutoEndTasks'; Expected = '1' }
    @{ DisplayName = 'Disable Advertising ID Tracking';     Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'; Name = 'Enabled'; Expected = 0 }
    @{ DisplayName = 'Disable Cortana';                     Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name = 'AllowCortana'; Expected = 0 }
    @{ DisplayName = 'Disable Fast Startup';                Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'; Name = 'HiberbootEnabled'; Expected = 0 }
    @{ DisplayName = 'Disable Lock Screen';                 Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization'; Name = 'NoLockScreen'; Expected = 1 }
    @{ DisplayName = 'Disable Notification Center';         Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'; Name = 'DisableNotificationCenter'; Expected = 1 }
    @{ DisplayName = 'Disable Store Open With Prompt';      Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'; Name = 'NoUseStoreOpenWith'; Expected = 1 }
    @{ DisplayName = 'Force Faster Shutdown of Frozen Apps'; Path = 'HKCU:\Control Panel\Desktop'; Name = 'WaitToKillAppTimeout'; Expected = '2000' }
    @{ DisplayName = 'Hide Start Menu Power Button';        Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name = 'NoClose'; Expected = 1 }
    @{ DisplayName = 'Long File Paths';                     Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'; Name = 'LongPathsEnabled'; Expected = 1 }
    @{ DisplayName = 'Low Disk Space Warnings';              Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name = 'NoLowDiskSpaceChecks'; Expected = 1 }
    @{ DisplayName = 'Menu Opening Delay';                  Path = 'HKCU:\Control Panel\Desktop'; Name = 'MenuShowDelay'; Expected = '200' }
    @{ DisplayName = 'Prevent Windows Update Auto Restart';  Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'; Name = 'NoAutoRebootWithLoggedOnUsers'; Expected = 1 }
    @{ DisplayName = 'Search Suggestions';                  Path = 'HKCU:\Software\Policies\Microsoft\Windows\Explorer'; Name = 'DisableSearchBoxSuggestions'; Expected = 1 }
    @{ DisplayName = 'Separate File Explorer Processes';    Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'SeparateProcess'; Expected = 1 }
    @{ DisplayName = 'Shortcut Arrows';                     Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Icons'; Name = '29'; Expected = '%windir%\System32\shell32.dll,-50' }
    @{ DisplayName = 'Verbose Startup Messages';            Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'; Name = 'VerboseStatus'; Expected = 1 }
)

$contextMenuTweaks = @(
    @{ DisplayName = 'Classic Context Menu'; Path = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32' }
    @{ DisplayName = 'Share Context Menu';   Path = 'HKCU:\Software\Classes\CLSID\{e2bf9676-5f8f-435c-97eb-11607a5bedf7}' }
)

Write-Host "Checking applied tweak status for $env:COMPUTERNAME ..." -ForegroundColor Cyan

$results = [System.Collections.Generic.List[object]]::new()

foreach ($tweak in $tweaks) {
    $currentValue = (Get-ItemProperty -Path $tweak.Path -Name $tweak.Name -ErrorAction SilentlyContinue).($tweak.Name)
    $applied = ($null -ne $currentValue -and "$currentValue" -eq "$($tweak.Expected)")
    $results.Add([PSCustomObject]@{
        Tweak         = $tweak.DisplayName
        Status        = if ($applied) { "Applied" } else { "Not Applied" }
        CurrentValue  = if ($null -eq $currentValue) { "(not set)" } else { $currentValue }
    })
}

foreach ($tweak in $contextMenuTweaks) {
    $applied = Test-Path $tweak.Path
    $results.Add([PSCustomObject]@{
        Tweak         = $tweak.DisplayName
        Status        = if ($applied) { "Applied" } else { "Not Applied" }
        CurrentValue  = if ($applied) { "(key exists)" } else { "(key not present)" }
    })
}

$sorted = @($results | Sort-Object @{Expression = {$_.Status -eq "Applied"}; Descending = $true}, Tweak)
$sorted | Format-Table -AutoSize

$appliedCount = @($sorted | Where-Object Status -eq "Applied").Count
Write-Host "`n$appliedCount of $($results.Count) tweaks currently applied on this computer." -ForegroundColor Cyan

Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
Stop-Transcript | Out-Null
Read-Host "`nPress Enter to close this window"
