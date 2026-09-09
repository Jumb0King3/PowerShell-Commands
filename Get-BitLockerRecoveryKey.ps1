# Get-BitLockerRecoveryKey.ps1
# Connects to Microsoft Graph if not already connected, then looks up a
# BitLocker recovery password in Entra ID by Recovery Key ID.
# Disconnects from Microsoft Graph when you exit.
# Pressing Enter with no input at the prompt cancels.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Get-BitLockerRecoveryKey_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
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
        Connect-MgGraph -Scopes "BitlockerKey.Read.All" -NoWelcome -ErrorAction Stop
        Write-Host "Connected to Microsoft Graph." -ForegroundColor Green
    }
    catch {
        Write-Host "Error connecting to Microsoft Graph: $($_.Exception.Message)" -ForegroundColor Red
        Stop-Transcript | Out-Null
        Read-Host "`nPress Enter to close this window"
        return
    }
}

$RecoveryKeyId = Read-Host "`nEnter the BitLocker Recovery Key ID (press Enter with no input to cancel)"
if ([string]::IsNullOrWhiteSpace($RecoveryKeyId)) {
    Write-Host "No Recovery Key ID entered. Cancelling." -ForegroundColor Yellow
    Stop-ScriptHere
    return
}

try {
    Write-Host "`nSearching Entra BitLocker recovery keys..." -ForegroundColor Cyan
    $key = Get-MgInformationProtectionBitlockerRecoveryKey -Filter "keyIdentifier eq '$RecoveryKeyId'" -ErrorAction Stop

    if (-not $key) {
        Write-Host "No matching BitLocker recovery key found." -ForegroundColor Yellow
    }
    else {
        $recoveryPassword = Get-MgInformationProtectionBitlockerRecoveryKey -BitlockerRecoveryKeyId $key.Id -Property key -ErrorAction Stop

        Write-Host "`nRecovery Key ID: $RecoveryKeyId" -ForegroundColor Cyan
        Write-Host "Recovery Password: $($recoveryPassword.Key)" -ForegroundColor Green
        Write-Host "Device ID: $($key.DeviceId)"
        Write-Host "Created: $($key.CreatedDateTime)"
    }
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Stop-ScriptHere
