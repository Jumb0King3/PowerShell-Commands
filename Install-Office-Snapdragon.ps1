# Install-Office-Snapdragon.ps1
# Installs Microsoft 365 Business Retail (64-bit, Current Channel) using
# the Office Deployment Tool (ODT): writes the config XML, closes Office
# Click-to-Run if running, downloads/extracts the ODT if needed, then runs
# setup.exe /download followed by setup.exe /configure.
#
# NOTE: This script was reconstructed using Microsoft's standard, publicly
# documented ODT procedure - no original script was provided to port from,
# only a description of its intended behavior. Verify on one test machine
# before relying on it broadly. This performs a real install and downloads
# several GB - requires typed confirmation before running.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Install-Office-Snapdragon_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

function Stop-ScriptHere {
    Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
    Stop-Transcript | Out-Null
    Read-Host "`nPress Enter to close this window"
}

# --- Elevation check ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Error: This script must be run as Administrator to install Office." -ForegroundColor Red
    Stop-ScriptHere
    return
}

Write-Host "WARNING" -ForegroundColor Red
Write-Host "This will download and install Microsoft 365 Business Retail on $env:COMPUTERNAME."
Write-Host "This downloads several GB and can take a while."
Write-Host ""

$confirm = Read-Host "Type YES to continue (anything else cancels)"
if ($confirm -ne "YES") {
    Write-Host "Not confirmed. Cancelling." -ForegroundColor Yellow
    Stop-ScriptHere
    return
}

try {
    $odtFolder = "C:\ODT"
    if (-not (Test-Path $odtFolder)) { New-Item -Path $odtFolder -ItemType Directory -Force | Out-Null }

    $officeConfigXml = @'
<Configuration>
  <Add OfficeClientEdition="64" Channel="Current">
<Product ID="O365BusinessRetail">
  <Language ID="en-us" />
</Product>
  </Add>
  <Display Level="None" AcceptEULA="TRUE" />
</Configuration>
'@

    $xmlPath = Join-Path $odtFolder "installOfficeBusRet64.xml"
    Set-Content -Path $xmlPath -Value $officeConfigXml -Encoding UTF8
    Write-Host "Office configuration written to: $xmlPath" -ForegroundColor Green

    # Close Office Click-to-Run if it's currently running, so the
    # install/config step isn't blocked by files in use.
    $c2r = Get-Process -Name "OfficeClickToRun" -ErrorAction SilentlyContinue
    if ($c2r) {
        Write-Host "Closing Office Click-to-Run before installing..." -ForegroundColor Cyan
        Stop-Process -Name "OfficeClickToRun" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }

    # Only warn about Sophos rather than force-stopping it - forcibly
    # killing enterprise AV can trigger tamper-protection alerts, so this
    # is left for the tech to handle manually if it blocks setup.
    $sophos = Get-Service -Name "Sophos*" -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Running" }
    if ($sophos) {
        Write-Host "WARNING: Sophos is currently running. It may need to be paused manually if the install is blocked." -ForegroundColor Yellow
    }

    # Download and extract the Office Deployment Tool if not already present
    $setupExe = Join-Path $odtFolder "setup.exe"
    if (-not (Test-Path $setupExe)) {
        Write-Host "Locating the Office Deployment Tool download link..." -ForegroundColor Cyan
        $detailsPage = "https://www.microsoft.com/en-us/download/details.aspx?id=49117"
        $html = Invoke-WebRequest -Uri $detailsPage -UseBasicParsing
        $downloadUrl = ($html.Links | Where-Object { $_.href -match "officedeploymenttool.*\.exe$" } | Select-Object -First 1 -ExpandProperty href)

        if (-not $downloadUrl) { throw "Could not find the Office Deployment Tool download link on Microsoft's page." }

        $odtInstaller = Join-Path $odtFolder "odtsetup.exe"
        Write-Host "Downloading Office Deployment Tool..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $downloadUrl -OutFile $odtInstaller -UseBasicParsing

        Write-Host "Extracting Office Deployment Tool..." -ForegroundColor Cyan
        Start-Process -FilePath $odtInstaller -ArgumentList "/extract:`"$odtFolder`" /quiet" -Wait

        if (-not (Test-Path $setupExe)) { throw "Office Deployment Tool extraction did not produce setup.exe as expected." }
    }

    # Download the real Office files (the slow part - a few GB)
    Write-Host "Downloading Office (this can take a while)..." -ForegroundColor Cyan
    $downloadProc = Start-Process -FilePath $setupExe -ArgumentList "/download `"$xmlPath`"" -Wait -PassThru
    if ($downloadProc.ExitCode -ne 0) { throw "Office download step failed (exit code $($downloadProc.ExitCode))." }

    # Install/configure Office
    Write-Host "Installing Office..." -ForegroundColor Cyan
    $installProc = Start-Process -FilePath $setupExe -ArgumentList "/configure `"$xmlPath`"" -Wait -PassThru
    if ($installProc.ExitCode -ne 0) { throw "Office install step failed (exit code $($installProc.ExitCode))." }

    Write-Host "`nOffice installation completed." -ForegroundColor Green
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Stop-ScriptHere
