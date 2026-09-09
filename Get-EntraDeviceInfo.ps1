# Get-EntraDeviceInfo.ps1
# Connects to Microsoft Graph if not already connected, then looks up an
# Entra ID device by name and shows its details and registered owner(s).
# Disconnects from Microsoft Graph when you exit.
# Pressing Enter with no input at the prompt cancels.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Get-EntraDeviceInfo_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
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
        Import-Module Microsoft.Graph.Identity.DirectoryManagement -ErrorAction Stop
        Connect-MgGraph -Scopes "Device.Read.All", "Directory.Read.All" -NoWelcome -ErrorAction Stop
        Write-Host "Connected to Microsoft Graph." -ForegroundColor Green
    }
    catch {
        Write-Host "Error connecting to Microsoft Graph: $($_.Exception.Message)" -ForegroundColor Red
        Stop-Transcript | Out-Null
        Read-Host "`nPress Enter to close this window"
        return
    }
}

$DeviceName = Read-Host "`nEnter the device name (press Enter with no input to cancel)"
if ([string]::IsNullOrWhiteSpace($DeviceName)) {
    Write-Host "No device name entered. Cancelling." -ForegroundColor Yellow
    Stop-ScriptHere
    return
}

$EscapedDeviceName = $DeviceName.Replace("'", "''")

try {
    Write-Host "`nSearching Entra for $DeviceName ..." -ForegroundColor Cyan

    $Devices = @(Get-MgDevice -Filter "displayName eq '$EscapedDeviceName'" `
        -Property "id,deviceId,displayName,accountEnabled,operatingSystem,operatingSystemVersion,trustType,profileType,isCompliant,isManaged,approximateLastSignInDateTime" `
        -All -ErrorAction Stop)

    if ($Devices.Count -eq 0) {
        Write-Host "No Entra device found with the name $DeviceName." -ForegroundColor Yellow
    }
    else {
        foreach ($Device in $Devices) {
            $Owners = @(Get-MgDeviceRegisteredOwner -DeviceId $Device.Id -All -ErrorAction SilentlyContinue)
            $OwnerNames = foreach ($Owner in $Owners) {
                if ($Owner.AdditionalProperties.userPrincipalName) { $Owner.AdditionalProperties.userPrincipalName }
                elseif ($Owner.AdditionalProperties.displayName) { $Owner.AdditionalProperties.displayName }
                else { $Owner.Id }
            }

            [PSCustomObject]@{
                DisplayName            = $Device.DisplayName
                GraphObjectId          = $Device.Id
                EntraDeviceId          = $Device.DeviceId
                AccountEnabled         = $Device.AccountEnabled
                OperatingSystem        = $Device.OperatingSystem
                OperatingSystemVersion = $Device.OperatingSystemVersion
                TrustType              = $Device.TrustType
                ProfileType            = $Device.ProfileType
                IsManaged              = $Device.IsManaged
                IsCompliant            = $Device.IsCompliant
                ApproximateLastSignIn  = $Device.ApproximateLastSignInDateTime
                RegisteredOwner        = ($OwnerNames -join ", ")
            } | Format-List
        }
    }
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Stop-ScriptHere
