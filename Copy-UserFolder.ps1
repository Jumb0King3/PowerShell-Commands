# Copy-UserFolder.ps1
# Prompts for source folder, destination folder, username, and ticket number,
# then runs the robocopy command with a live progress bar showing percent
# complete, transfer speed, estimated time remaining, and the current file
# being copied. Full robocopy detail still goes to the log file.
# Pressing Enter with no input at any prompt cancels.

$sourcePath = Read-Host "Enter the source folder path (this is the location to copy FROM) (press Enter with no input to cancel)"
if ([string]::IsNullOrWhiteSpace($sourcePath)) {
    Write-Host "No source path entered. Cancelling." -ForegroundColor Yellow
    return
}

$destPath = Read-Host "Enter the destination folder path (this is the location to copy TO) (press Enter with no input to cancel)"
if ([string]::IsNullOrWhiteSpace($destPath)) {
    Write-Host "No destination path entered. Cancelling." -ForegroundColor Yellow
    return
}

$username = Read-Host "Enter the username (press Enter with no input to cancel)"
if ([string]::IsNullOrWhiteSpace($username)) {
    Write-Host "No username entered. Cancelling." -ForegroundColor Yellow
    return
}

$ticketNumber = Read-Host "Enter the ticket number (press Enter with no input to cancel)"
if ([string]::IsNullOrWhiteSpace($ticketNumber)) {
    Write-Host "No ticket number entered. Cancelling." -ForegroundColor Yellow
    return
}

$logPath = "C:\Robocopy Logs\$username-ID$ticketNumber.txt"
$logFolder = Split-Path $logPath -Parent
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }

function Get-FolderSize {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return 0 }
    $bytes = (Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    if (-not $bytes) { return 0 }
    return $bytes
}

function Format-ReadableSize {
    param([double]$Bytes)
    if ($Bytes -lt 1MB) { return "{0:N1} KB" -f ($Bytes / 1KB) }
    if ($Bytes -lt 1GB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    return "{0:N2} GB" -f ($Bytes / 1GB)
}

function Format-TimeSpan {
    param([TimeSpan]$Span)
    if ($Span.TotalHours -ge 1) { return "{0:h\h\ mm\m}" -f $Span }
    if ($Span.TotalMinutes -ge 1) { return "{0:m\m\ ss\s}" -f $Span }
    return "{0:ss}s" -f $Span
}

Write-Host "Calculating source folder size..." -ForegroundColor Cyan
$totalSourceBytes = Get-FolderSize -Path $sourcePath
$initialDestBytes = Get-FolderSize -Path $destPath

if ($totalSourceBytes -eq 0) {
    Write-Host "Warning: Source folder appears empty or inaccessible - progress percentage may not be meaningful." -ForegroundColor Yellow
}
else {
    Write-Host "Total to copy: $(Format-ReadableSize $totalSourceBytes)" -ForegroundColor Cyan
}

# Start robocopy as a background process - full detail goes to the log file only.
$argList = @(
    "`"$sourcePath`"", "`"$destPath`"", "*.*",
    "/COPY:DAT", "/DCOPY:DAT", "/E", "/W:1", "/R:10", "/MT:25",
    "/log:`"$logPath`""
)
$process = Start-Process -FilePath "robocopy.exe" -ArgumentList $argList -PassThru -WindowStyle Hidden

$startTime = Get-Date
$lastBytes = 0
$lastCheckTime = $startTime

while (-not $process.HasExited) {
    $now = Get-Date
    $elapsed = $now - $startTime

    if ($totalSourceBytes -gt 0) {
        $currentDestBytes = Get-FolderSize -Path $destPath
        $copiedBytes = [math]::Max(0, $currentDestBytes - $initialDestBytes)
        $percent = [math]::Min(99, [math]::Round(($copiedBytes / $totalSourceBytes) * 100))

        # Speed based on progress since the last check, not the whole run,
        # so it reflects current pace rather than a diluted all-time average.
        $intervalSeconds = ($now - $lastCheckTime).TotalSeconds
        $bytesSinceLast = $copiedBytes - $lastBytes
        $bytesPerSecond = if ($intervalSeconds -gt 0) { $bytesSinceLast / $intervalSeconds } else { 0 }

        $etaText = "calculating..."
        if ($bytesPerSecond -gt 0) {
            $remainingBytes = $totalSourceBytes - $copiedBytes
            $etaSeconds = $remainingBytes / $bytesPerSecond
            $etaText = Format-TimeSpan ([TimeSpan]::FromSeconds($etaSeconds))
        }

        $speedText = if ($bytesPerSecond -gt 0) { "$(Format-ReadableSize $bytesPerSecond)/s" } else { "..." }

        # Show the most recently logged file name for extra context, if available.
        $currentFile = $null
        try {
            $lastLine = Get-Content -Path $logPath -Tail 5 -ErrorAction SilentlyContinue |
                Where-Object { $_ -match '\S' } | Select-Object -Last 1
            if ($lastLine) { $currentFile = ($lastLine -replace '^\s*\d+%?\s*', '').Trim() }
        }
        catch { }

        $status = "$(Format-ReadableSize $copiedBytes) of $(Format-ReadableSize $totalSourceBytes) ($percent%) - $speedText - ETA $etaText - Elapsed $(Format-TimeSpan $elapsed)"
        Write-Progress -Activity "Copying $username's folder" -Status $status -PercentComplete $percent -CurrentOperation $currentFile

        $lastBytes = $copiedBytes
        $lastCheckTime = $now
    }
    else {
        Write-Progress -Activity "Copying $username's folder" -Status "Copying... Elapsed $(Format-TimeSpan $elapsed)" -PercentComplete 0
    }

    Start-Sleep -Seconds 1
}

Write-Progress -Activity "Copying $username's folder" -Status "Complete" -PercentComplete 100
Start-Sleep -Milliseconds 500
Write-Progress -Activity "Copying $username's folder" -Completed

$exitCode = $process.ExitCode
$totalElapsed = (Get-Date) - $startTime
# Robocopy exit codes 0-7 are all forms of success (0 = nothing copied/no changes, 1-7 = files copied/mismatched/etc.)
if ($exitCode -le 7) {
    Write-Host "`nCopy completed successfully in $(Format-TimeSpan $totalElapsed)." -ForegroundColor Green
}
else {
    Write-Host "`nCopy finished with errors (exit code $exitCode) after $(Format-TimeSpan $totalElapsed). Check the log for details." -ForegroundColor Red
}

Write-Host "Log File: $logPath" -ForegroundColor Cyan
