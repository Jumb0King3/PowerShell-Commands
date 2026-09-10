# Get-UserProfiles.ps1
# Lists user profiles on this device with size, last-use time, and health
# status. This can take a while on large profiles since it walks each
# profile folder to calculate size.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Get-UserProfiles_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

function Format-ReadableSize {
    param([AllowNull()][double]$Bytes)
    if ($null -eq $Bytes -or $Bytes -lt 0) { return 'Unknown' }
    if ($Bytes -lt 1KB) { return "{0:N0} B" -f $Bytes }
    if ($Bytes -lt 1MB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    if ($Bytes -lt 1GB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -lt 1TB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    return "{0:N2} TB" -f ($Bytes / 1TB)
}

Write-Host "Collecting user profile information for $env:COMPUTERNAME (this can take a while on large profiles)..." -ForegroundColor Cyan

try {
    $profiles = Get-CimInstance Win32_UserProfile | Where-Object { $_.LocalPath -like "C:\Users\*" }

    $report = foreach ($profile in $profiles) {
        $size = $null
        $folderSize = $null
        try {
            $size = (Get-ChildItem $profile.LocalPath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
            $folderSize = Format-ReadableSize $size
        }
        catch {
            $folderSize = "Unknown"
        }

        [PSCustomObject]@{
            UserProfile  = $profile.LocalPath
            LastUseTime  = $profile.LastUseTime
            Loaded       = $profile.Loaded
            Special      = $profile.Special
            HealthStatus = $profile.HealthStatus
            Size         = $folderSize
            SizeBytes    = $size
        }
    }

    $report | Sort-Object SizeBytes -Descending | Format-Table -AutoSize
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
Stop-Transcript | Out-Null
Read-Host "`nPress Enter to close this window"
