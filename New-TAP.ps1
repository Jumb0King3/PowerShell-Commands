# New-TAP.ps1
# Connects to Microsoft Graph if not already connected, then creates a
# Temporary Access Pass (TAP) for a user.
# Disconnects from Microsoft Graph when you exit.
# Pressing Enter with no input at any prompt cancels.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "New-TAP_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

function Stop-ScriptHere {
    try {
        Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
        Write-Host "`nDisconnected from Microsoft Graph." -ForegroundColor Cyan
    }
    catch { }
    Write-Host "Log saved to: $logFile" -ForegroundColor Cyan
    Write-Host "IMPORTANT: The TAP value above is sensitive. Delete this log when it is no longer needed." -ForegroundColor Yellow
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
        Connect-MgGraph -Scopes "UserAuthenticationMethod.ReadWrite.All" -NoWelcome -ErrorAction Stop
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

$Lifetime = Read-Host "Enter the TAP lifetime in minutes, e.g. 60 (press Enter with no input to cancel)"
if ([string]::IsNullOrWhiteSpace($Lifetime)) {
    Write-Host "No lifetime entered. Cancelling." -ForegroundColor Yellow
    Stop-ScriptHere
    return
}

$UsableOnceAnswer = Read-Host "Should this TAP be one-time use only? Type YES or NO (press Enter with no input to cancel)"
if ([string]::IsNullOrWhiteSpace($UsableOnceAnswer)) {
    Write-Host "No answer entered. Cancelling." -ForegroundColor Yellow
    Stop-ScriptHere
    return
}
$IsUsableOnce = ($UsableOnceAnswer.ToUpper() -eq "YES")

$Body = @{
    lifetimeInMinutes = [int]$Lifetime
    isUsableOnce       = $IsUsableOnce
}

try {
    $Result = New-MgUserAuthenticationTemporaryAccessPassMethod -UserId $UPN -BodyParameter $Body -ErrorAction Stop

    Write-Host "`nTemporary Access Pass created for $UPN" -ForegroundColor Green
    Write-Host "TAP Value: $($Result.TemporaryAccessPass)" -ForegroundColor Yellow
    Write-Host "Lifetime Minutes: $($Result.LifetimeInMinutes)"
    Write-Host "Usable Once: $($Result.IsUsableOnce)"
    Write-Host "Start Date Time: $($Result.StartDateTime)"
    Write-Host "Is Usable: $($Result.IsUsable)"
}
catch {
    Write-Host "Error: Could not create TAP. $($_.Exception.Message)" -ForegroundColor Red
}

Stop-ScriptHere
