<#
.SYNOPSIS
    DRY RUN / TEST HARNESS for Install-Office-Snapdragon.ps1.
    Exercises the same logic and progress bars WITHOUT downloading the real
    Office Deployment Tool, downloading Office, or installing anything.

.DESCRIPTION
    This mirrors the real script step-for-step but fakes the two slow parts:
      - "Download" is simulated by writing small dummy files into a test
        folder that grow over time, so you can watch the real progress-bar
        math (folder size vs target) actually work.
      - "Configure/install" is simulated with a timed sleep loop instead of
        launching setup.exe, so you can watch the time-estimated progress bar.

    Nothing is downloaded from Microsoft, no setup.exe is run, and no Office
    files are installed. Everything happens under a throwaway test folder
    (default: C:\ODT_Test) which you can safely delete afterwards.

.PARAMETER TestFolder
    Folder to use for the dry run. Defaults to C:\ODT_Test so it never
    collides with a real C:\ODT.

.PARAMETER SimulatedDownloadSeconds
    How long the fake "download" phase should take. Default 20.

.PARAMETER SimulatedInstallSeconds
    How long the fake "configure/install" phase should take. Default 20.

.PARAMETER SkipOdtLinkCheck
    If set, skips even the harmless step of checking that Microsoft's ODT
    download page is reachable and a link can be parsed out of it (no file
    is downloaded either way - this just tests the link-detection regex).

.EXAMPLE
    .\Test-Install-Office-Snapdragon.ps1

.EXAMPLE
    .\Test-Install-Office-Snapdragon.ps1 -SimulatedDownloadSeconds 5 -SimulatedInstallSeconds 5
#>

[CmdletBinding()]
param(
    [string]$TestFolder = "C:\ODT_Test",
    [int]$SimulatedDownloadSeconds = 20,
    [int]$SimulatedInstallSeconds = 20,
    [switch]$SkipOdtLinkCheck
)

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Test-Install-Office-Snapdragon_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

# Same embedded XML as the real script, just to prove the write-to-disk step works.
$OfficeConfigXml = @'
<Configuration>
  <Add OfficeClientEdition="64" Channel="Current">
    <Product ID="O365BusinessRetail">
      <Language ID="en-us" />
    </Product>
  </Add>
  <Display Level="None" AcceptEULA="TRUE" />
</Configuration>
'@

$ErrorActionPreference = "Stop"
$results = [ordered]@{}

function Write-TestResult($name, $pass, $detail = "") {
    $results[$name] = $pass
    $color = if ($pass) { "Green" } else { "Red" }
    $mark  = if ($pass) { "PASS" } else { "FAIL" }
    Write-Host "[$mark] $name" -ForegroundColor $color
    if ($detail) { Write-Host "       $detail" -ForegroundColor Gray }
}

Write-Host "=== DRY RUN: Install-Office-Snapdragon.ps1 test harness ===" -ForegroundColor Cyan
Write-Host "No real download, no real install. Test folder: $TestFolder`n" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# 0. Admin check (report only - do not require it for the test itself)
# ---------------------------------------------------------------------------
function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
$isAdmin = Test-IsAdmin
Write-TestResult "Running as Administrator" $isAdmin `
    "(Not required for this dry run, but the real script will refuse to start without it.)"

# ---------------------------------------------------------------------------
# 1. Write the embedded XML to the test folder
# ---------------------------------------------------------------------------
try {
    if (-not (Test-Path $TestFolder)) {
        New-Item -Path $TestFolder -ItemType Directory | Out-Null
    }
    $xmlDest = Join-Path $TestFolder "installOfficeBusRet64.xml"
    Set-Content -Path $xmlDest -Value $OfficeConfigXml -Encoding UTF8

    $writtenOk = (Test-Path $xmlDest) -and ((Get-Content $xmlDest -Raw).Contains("O365BusinessRetail"))
    Write-TestResult "Embedded XML writes to disk correctly" $writtenOk "Written to: $xmlDest"
} catch {
    Write-TestResult "Embedded XML writes to disk correctly" $false $_.Exception.Message
}

# ---------------------------------------------------------------------------
# 2. "Office Click to Run" process detection (just reports current state)
# ---------------------------------------------------------------------------
$c2r = Get-Process -Name "OfficeClickToRun" -ErrorAction SilentlyContinue
Write-TestResult "Office Click to Run detection logic runs" $true `
    $(if ($c2r) { "Currently running - real script would close it." } else { "Not currently running." })

# ---------------------------------------------------------------------------
# 3. ODT download link detection (network read-only, no file downloaded)
# ---------------------------------------------------------------------------
if (-not $SkipOdtLinkCheck) {
    try {
        $detailsPage = "https://www.microsoft.com/en-us/download/details.aspx?id=49117"
        $html = Invoke-WebRequest -Uri $detailsPage -UseBasicParsing
        $downloadUrl = ($html.Links | Where-Object { $_.href -match "officedeploymenttool.*\.exe$" } | Select-Object -First 1 -ExpandProperty href)
        Write-TestResult "Can reach Microsoft page and parse ODT link" ([bool]$downloadUrl) `
            $(if ($downloadUrl) { $downloadUrl } else { "No matching link found in page." })
    } catch {
        Write-TestResult "Can reach Microsoft page and parse ODT link" $false $_.Exception.Message
    }
} else {
    Write-Host "[SKIP] ODT link check skipped by -SkipOdtLinkCheck" -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# 4. Sophos detection (report only)
# ---------------------------------------------------------------------------
$sophos = Get-Service -Name "Sophos*" -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Running" }
Write-TestResult "Sophos detection logic runs" $true `
    $(if ($sophos) { "Sophos is running - real script would prompt to pause it." } else { "Sophos not detected as running." })

# ---------------------------------------------------------------------------
# 5. FAKE download - proves the folder-size progress bar math works
# ---------------------------------------------------------------------------
function Get-FolderSizeGB($path) {
    if (-not (Test-Path $path)) { return 0 }
    $bytes = (Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    if (-not $bytes) { return 0 }
    return [math]::Round($bytes / 1GB, 4)
}

Write-Host "`nSimulating Office download (writing dummy files, no network transfer)..." -ForegroundColor Cyan

$fakeOfficeFolder = Join-Path $TestFolder "Office"
if (-not (Test-Path $fakeOfficeFolder)) { New-Item -Path $fakeOfficeFolder -ItemType Directory | Out-Null }

# Small fake target so the bar reaches 100% quickly but still exercises real math.
$fakeTargetGB = 0.01  # 10 MB stand-in for the real ~3GB
$chunks = 10
$bytesPerChunk = [int](($fakeTargetGB * 1GB) / $chunks)
$sleepPerChunk = [math]::Max(1, [int]($SimulatedDownloadSeconds / $chunks))

$dummyBytes = New-Object byte[] $bytesPerChunk
$downloadOk = $true
try {
    for ($i = 1; $i -le $chunks; $i++) {
        $chunkFile = Join-Path $fakeOfficeFolder "chunk_$i.bin"
        [System.IO.File]::WriteAllBytes($chunkFile, $dummyBytes)

        $currentGB = Get-FolderSizeGB $fakeOfficeFolder
        $percent = [math]::Min(99, [math]::Round(($currentGB / $fakeTargetGB) * 100))
        Write-Progress -Activity "Downloading Office (SIMULATED)" -Status "$currentGB GB of ~$fakeTargetGB GB (fake)" -PercentComplete $percent
        Start-Sleep -Seconds $sleepPerChunk
    }
    Write-Progress -Activity "Downloading Office (SIMULATED)" -Status "Download complete" -PercentComplete 100
    Start-Sleep -Seconds 1
    Write-Progress -Activity "Downloading Office (SIMULATED)" -Completed
} catch {
    $downloadOk = $false
}
Write-TestResult "Simulated download progress bar completes" $downloadOk

# ---------------------------------------------------------------------------
# 6. FAKE configure/install - proves the time-estimated progress bar works
# ---------------------------------------------------------------------------
Write-Host "`nSimulating Office configure/install step (no setup.exe launched)..." -ForegroundColor Cyan

$installOk = $true
try {
    $startTime = Get-Date
    $estimatedSeconds = $SimulatedInstallSeconds
    do {
        $elapsed = (Get-Date) - $startTime
        $percent = [math]::Min(95, [math]::Round(($elapsed.TotalSeconds / $estimatedSeconds) * 100))
        Write-Progress -Activity "Installing Office (SIMULATED)" -Status "Elapsed $($elapsed.ToString('hh\:mm\:ss'))" -PercentComplete $percent
        Start-Sleep -Seconds 2
    } while ($elapsed.TotalSeconds -lt $estimatedSeconds)

    Write-Progress -Activity "Installing Office (SIMULATED)" -Status "Complete" -PercentComplete 100
    Start-Sleep -Seconds 1
    Write-Progress -Activity "Installing Office (SIMULATED)" -Completed
} catch {
    $installOk = $false
}
Write-TestResult "Simulated install progress bar completes" $installOk

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
Write-Host "`nCleaning up test folder ($TestFolder)..." -ForegroundColor Cyan
try {
    Remove-Item -Path $TestFolder -Recurse -Force -ErrorAction SilentlyContinue
    Write-TestResult "Test folder cleaned up" (-not (Test-Path $TestFolder))
} catch {
    Write-TestResult "Test folder cleaned up" $false $_.Exception.Message
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
$failed = $results.GetEnumerator() | Where-Object { -not $_.Value }
foreach ($r in $results.GetEnumerator()) {
    $color = if ($r.Value) { "Green" } else { "Red" }
    Write-Host " - $($r.Key): $(if ($r.Value) {'PASS'} else {'FAIL'})" -ForegroundColor $color
}

if ($failed) {
    Write-Host "`n$($failed.Count) check(s) failed. Review above before trusting the real script's logic." -ForegroundColor Red
} else {
    Write-Host "`nAll checks passed. Script logic and progress bars behave as expected." -ForegroundColor Green
}

Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
Stop-Transcript | Out-Null
Read-Host "`nPress Enter to close this window"
