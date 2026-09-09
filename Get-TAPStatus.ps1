# Get-TAPStatus.ps1
# Connects to Microsoft Graph if not already connected, then shows the
# Temporary Access Pass (TAP) status for a user.
# Disconnects from Microsoft Graph when you exit.
# Pressing Enter with no input at the prompt cancels.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Get-TAPStatus_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

function Stop-ScriptHere {
    try {
        Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
        Write-Host "`nDisconnected from Microsoft Graph." -ForegroundColor Cyan
    }
    catch { }
    Write-Host "Log saved to: $logFile" -ForegroundColor Cyan
    Stop-Transcript | Out-Null
    Read-Host "`nPress Enter to close this window"
}

$graphConnected = $false
try {
    $ctx = Get-MgContext -ErrorAction Stop
    if ($ctx) { $graphConnected = $true }
}
catch { $graphConnected = $false }

if (-not $graphConnected) {
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
        Write-Host "Microsoft Graph module not found. Installing (this can take a few minutes the first time)..." -ForegroundColor Cyan
        try {
            Install-Module -Name Microsoft.Graph -Scope CurrentUser -Force -ErrorAction Stop
        }
        catch {
            Write-Host "Error installing Microsoft Graph module: $($_.Exception.Message)" -ForegroundColor Red
            Stop-Transcript | Out-Null
            Read-Host "`nPress Enter to close this window"
            return
        }
    }

    try {
        Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
        Import-Module Microsoft.Graph.Identity.SignIns -ErrorAction Stop
        Connect-MgGraph -Scopes "UserAuthenticationMethod.Read.All" -NoWelcome -ErrorAction Stop
        Write-Host "Connected to Microsoft Graph." -ForegroundColor Green
    }
    catch {
        Write-Host "Error connecting to Microsoft Graph: $($_.Exception.Message)" -ForegroundColor Red
        Stop-Transcript | Out-Null
        Read-Host "`nPress Enter to close this window"
        return
    }
}

$UPN = Read-Host "`nEnter the user's UPN (press Enter with no input to cancel)"
if ([string]::IsNullOrWhiteSpace($UPN)) {
    Write-Host "No UPN entered. Cancelling." -ForegroundColor Yellow
    Stop-ScriptHere
    return
}

try {
    $TAP = Get-MgUserAuthenticationTemporaryAccessPassMethod -UserId $UPN -ErrorAction Stop

    if ($TAP) {
        Write-Host "`nTemporary Access Pass status for $UPN :" -ForegroundColor Cyan
        $TAP | Select-Object Id, CreatedDateTime, StartDateTime, LifetimeInMinutes, IsUsable, IsUsableOnce, MethodUsabilityReason | Format-List
    }
    else {
        Write-Host "`nNo Temporary Access Pass found for $UPN." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Stop-ScriptHere
