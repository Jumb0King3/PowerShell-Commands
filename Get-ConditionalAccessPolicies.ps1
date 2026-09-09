# Get-ConditionalAccessPolicies.ps1
# Connects to Microsoft Graph if not already connected, then lists all
# Conditional Access policies in the tenant.
# Disconnects from Microsoft Graph when you exit.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Get-ConditionalAccessPolicies_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
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
        Connect-MgGraph -Scopes "Policy.Read.All" -NoWelcome -ErrorAction Stop
        Write-Host "Connected to Microsoft Graph." -ForegroundColor Green
    }
    catch {
        Write-Host "Error connecting to Microsoft Graph: $($_.Exception.Message)" -ForegroundColor Red
        Stop-Transcript | Out-Null
        Read-Host "`nPress Enter to close this window"
        return
    }
}

try {
    Write-Host "`nConditional Access Policies :" -ForegroundColor Cyan
    Get-MgIdentityConditionalAccessPolicy -All -ErrorAction Stop |
        Select-Object DisplayName, State, Id, CreatedDateTime, ModifiedDateTime |
        Sort-Object DisplayName |
        Format-Table -AutoSize
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Stop-ScriptHere
