# Export-UserSummary.ps1
# Connects to Microsoft Graph if not already connected, then pulls a full
# "everything about this user" report in one pass: User Info, MFA Status,
# Temporary Access Pass, Licenses Assigned, Registered Devices, and Group
# Memberships - saved as one combined report instead of six separate ones.
# Disconnects from Microsoft Graph when you exit.
# Pressing Enter with no input at the prompt cancels.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Export-UserSummary_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
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

# --- Ensure connected to Microsoft Graph ---
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
        Import-Module Microsoft.Graph.Users -ErrorAction Stop
        Import-Module Microsoft.Graph.Identity.SignIns -ErrorAction Stop
        Connect-MgGraph -Scopes "User.Read.All", "Directory.Read.All", "Group.Read.All", "UserAuthenticationMethod.Read.All" -NoWelcome -ErrorAction Stop
        Write-Host "Connected to Microsoft Graph." -ForegroundColor Green
    }
    catch {
        Write-Host "Error connecting to Microsoft Graph: $($_.Exception.Message)" -ForegroundColor Red
        Stop-Transcript | Out-Null
        Read-Host "`nPress Enter to close this window"
        return
    }
}

function Convert-AuthMethodName($ODataType) {
    switch -Wildcard ($ODataType) {
        "*microsoftAuthenticatorAuthenticationMethod"  { "Microsoft Authenticator" }
        "*phoneAuthenticationMethod"                   { "Phone / SMS / Voice" }
        "*fido2AuthenticationMethod"                   { "FIDO2 Security Key" }
        "*windowsHelloForBusinessAuthenticationMethod" { "Windows Hello for Business" }
        "*temporaryAccessPassAuthenticationMethod"     { "Temporary Access Pass" }
        "*passwordAuthenticationMethod"                { "Password" }
        "*emailAuthenticationMethod"                   { "Email" }
        "*softwareOathAuthenticationMethod"            { "Software OATH Token" }
        default                                        { $ODataType }
    }
}

function Write-Section($Title, $Body) {
    Write-Host "`n===== $Title =====" -ForegroundColor Cyan
    Write-Host $Body
}

$UPN = Read-Host "`nEnter the user's UPN (press Enter with no input to cancel)"
if ([string]::IsNullOrWhiteSpace($UPN)) {
    Write-Host "No UPN entered. Cancelling." -ForegroundColor Yellow
    Stop-ScriptHere
    return
}

Write-Host "`nUser Summary for $UPN" -ForegroundColor Cyan
Write-Host "Generated: $(Get-Date)"

# ----- User Info -----
try {
    $user = Get-MgUser -UserId $UPN -Property Id,DisplayName,UserPrincipalName,Mail,AccountEnabled,CreatedDateTime,Department,JobTitle,OfficeLocation,MobilePhone,BusinessPhones -ErrorAction Stop
    $body = $user | Select-Object DisplayName, UserPrincipalName, Mail, AccountEnabled, CreatedDateTime, Department, JobTitle, OfficeLocation, MobilePhone, BusinessPhones, Id | Format-List | Out-String
}
catch { $body = "FAILED: $($_.Exception.Message)" }
Write-Section "User Info" $body

# ----- MFA Status -----
try {
    $methods = Get-MgUserAuthenticationMethod -UserId $UPN -ErrorAction Stop
    $body = ($methods | ForEach-Object {
        $odataType = $_.AdditionalProperties.'@odata.type'
        [PSCustomObject]@{ Method = Convert-AuthMethodName $odataType; MethodType = $odataType; Id = $_.Id }
    } | Format-Table -AutoSize | Out-String)
}
catch { $body = "FAILED: $($_.Exception.Message)" }
Write-Section "MFA Status" $body

# ----- Temporary Access Pass -----
try {
    $tap = Get-MgUserAuthenticationTemporaryAccessPassMethod -UserId $UPN -ErrorAction Stop
    $body = if ($tap) {
        $tap | Select-Object Id, CreatedDateTime, StartDateTime, LifetimeInMinutes, IsUsable, IsUsableOnce, MethodUsabilityReason | Format-List | Out-String
    } else { "No Temporary Access Pass found." }
}
catch { $body = "FAILED: $($_.Exception.Message)" }
Write-Section "Temporary Access Pass" $body

# ----- Licenses Assigned -----
try {
    $licences = Get-MgUserLicenseDetail -UserId $UPN -All -ErrorAction Stop
    $body = if ($licences) {
        $licences | Select-Object SkuPartNumber, SkuId | Sort-Object SkuPartNumber | Format-Table -AutoSize | Out-String
    } else { "No licenses found." }
}
catch { $body = "FAILED: $($_.Exception.Message)" }
Write-Section "Licenses Assigned" $body

# ----- Registered Devices -----
try {
    $devices = Get-MgUserRegisteredDevice -UserId $UPN -All -ErrorAction Stop
    $body = if ($devices) {
        $devices | ForEach-Object {
            [PSCustomObject]@{
                DeviceName      = $_.AdditionalProperties.displayName
                OperatingSystem = $_.AdditionalProperties.operatingSystem
                TrustType       = $_.AdditionalProperties.trustType
                AccountEnabled  = $_.AdditionalProperties.accountEnabled
                LastSignIn      = $_.AdditionalProperties.approximateLastSignInDateTime
            }
        } | Sort-Object DeviceName | Format-Table -AutoSize | Out-String
    } else { "No registered devices found." }
}
catch { $body = "FAILED: $($_.Exception.Message)" }
Write-Section "Registered Devices" $body

# ----- Group Memberships -----
try {
    $memberships = Get-MgUserMemberOf -UserId $UPN -All -ErrorAction Stop
    $body = if ($memberships) {
        $memberships | ForEach-Object {
            [PSCustomObject]@{
                DisplayName = $_.AdditionalProperties.displayName
                Type        = $_.AdditionalProperties.'@odata.type'
                Mail        = $_.AdditionalProperties.mail
            }
        } | Sort-Object DisplayName | Format-Table -AutoSize | Out-String
    } else { "No group memberships found." }
}
catch { $body = "FAILED: $($_.Exception.Message)" }
Write-Section "Group Memberships" $body

Stop-ScriptHere
