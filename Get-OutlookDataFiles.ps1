# Get-OutlookDataFiles.ps1
# Searches standard Outlook data file locations for .ost, .pst, and .nst
# files and reports their size and last-modified date.

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Get-OutlookDataFiles_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

function Format-ReadableSize {
    param([AllowNull()][double]$Bytes)
    if ($null -eq $Bytes -or $Bytes -lt 0) { return 'Unknown' }
    if ($Bytes -lt 1KB) { return "{0:N0} B" -f $Bytes }
    if ($Bytes -lt 1MB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    if ($Bytes -lt 1GB) { return "{0:N2} MB" -f ($Bytes / 1GB) }
    if ($Bytes -lt 1TB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    return "{0:N2} TB" -f ($Bytes / 1TB)
}

Write-Host "Collecting Outlook data file information for $env:COMPUTERNAME ..." -ForegroundColor Cyan

$searchPaths = @("$env:LOCALAPPDATA\Microsoft\Outlook", "$env:USERPROFILE\Documents\Outlook Files")

try {
    $files = foreach ($searchPath in $searchPaths) {
        if (Test-Path $searchPath) {
            Get-ChildItem -Path $searchPath -File -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.Extension -in @(".ost", ".pst", ".nst") }
        }
    }
    $files = @($files)

    if ($files.Count -eq 0) {
        Write-Host "No OST, PST or NST files were found." -ForegroundColor Yellow
    }
    else {
        $files |
            Select-Object Name, Extension, @{Name = "Size"; Expression = { Format-ReadableSize $_.Length }}, LastWriteTime, FullName |
            Sort-Object Length -Descending |
            Format-Table -AutoSize
    }
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
Stop-Transcript | Out-Null
Read-Host "`nPress Enter to close this window"
