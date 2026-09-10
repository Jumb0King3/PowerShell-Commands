# Get-MappedDrives.ps1
# Reports SMB mapped drives, pinned network location shortcuts, and local
# volumes with usage stats.
#
# NOTE: Simplified from the original - this version only collects and
# reports drive information. It does NOT modify the registry or offer to
# reboot the machine (the original had an interactive "set
# EnableLinkedConnections and reboot?" prompt, which isn't appropriate for
# an unattended diagnostic script).

$logFolder = Join-Path $env:USERPROFILE "Documents\Scripts Logs"
if (-not (Test-Path $logFolder)) { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logFolder "Get-MappedDrives_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
Start-Transcript -Path $logFile | Out-Null

function Format-ReadableSize {
    param([AllowNull()][double]$Bytes)
    if ($null -eq $Bytes -or $Bytes -lt 0) { return 'Unknown' }
    if ($Bytes -lt 1KB) { return "{0:N0} B" -f $Bytes }
    if ($Bytes -lt 1MB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    if ($Bytes -lt 1GB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -lt 1TB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    return "{0:N2} TB" -f ($Bytes / 1TB)
}

if (-not ("NetworkStorage.NativeMethods" -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
namespace NetworkStorage {
public static class NativeMethods {
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool GetDiskFreeSpaceEx(string directoryName, out ulong freeBytesAvailable, out ulong totalNumberOfBytes, out ulong totalNumberOfFreeBytes);
}
}
"@
}

function Get-StorageStatistics {
    param([Parameter(Mandatory)][string]$Path)
    [uint64]$freeBytes = 0; [uint64]$totalBytes = 0; [uint64]$unusedBytes = 0
    try {
        if ([NetworkStorage.NativeMethods]::GetDiskFreeSpaceEx($Path, [ref]$freeBytes, [ref]$totalBytes, [ref]$unusedBytes)) {
            return [PSCustomObject]@{ Used = Format-ReadableSize ($totalBytes - $freeBytes); Free = Format-ReadableSize $freeBytes; Total = Format-ReadableSize $totalBytes }
        }
    } catch {}
    return [PSCustomObject]@{ Used = "N/A"; Free = "N/A"; Total = "N/A" }
}

Write-Host "Collecting mapped drive information for $env:COMPUTERNAME ..." -ForegroundColor Cyan

try {
    Write-Host "`n===== SMB MAPPINGS =====" -ForegroundColor Cyan

    $logicalDisks = @{}
    Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType = 4" -ErrorAction SilentlyContinue |
        ForEach-Object { $logicalDisks[$_.DeviceID] = $_ }

    $detected = $false
    try { $mappings = Get-SmbMapping -ErrorAction Stop } catch { $mappings = $null }

    if ($mappings -and $mappings.Count -gt 0) {
        Write-Host "Detected using: Get-SmbMapping"
        $mappings | ForEach-Object {
            $logicalDisk = $logicalDisks[$_.LocalPath]
            $storage = Get-StorageStatistics -Path $_.LocalPath
            [PSCustomObject]@{
                LocalPath = $_.LocalPath; RemotePath = $_.RemotePath; Status = $_.Status; UserName = $_.UserName
                FileSystemLabel = if ($logicalDisk) { $logicalDisk.VolumeName } else { "" }
                Used = $storage.Used; Free = $storage.Free; Total = $storage.Total
            }
        } | Format-Table -AutoSize
        $detected = $true
    }

    if (-not $detected) {
        Write-Host "No SMB mapped drives found (via Get-SmbMapping)." -ForegroundColor Yellow
    }

    Write-Host "`n===== NETWORK LOCATIONS =====" -ForegroundColor Cyan

    $networkShortcutsFolder = Join-Path $env:APPDATA "Microsoft\Windows\Network Shortcuts"
    $networkLocations = @()
    if (Test-Path $networkShortcutsFolder) {
        $networkLocations = Get-ChildItem -Path $networkShortcutsFolder -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.PSIsContainer } |
            ForEach-Object {
                $shortcut = Get-ChildItem -Path $_.FullName -Filter "*.lnk" -File -ErrorAction SilentlyContinue | Select-Object -First 1
                $targetPath = $_.FullName
                if ($shortcut) { $targetPath = (New-Object -ComObject WScript.Shell).CreateShortcut($shortcut.FullName).TargetPath }
                $storage = Get-StorageStatistics -Path $targetPath
                [PSCustomObject]@{ Name = $_.Name; Path = $targetPath; Used = $storage.Used; Free = $storage.Free; Total = $storage.Total }
            }
    }

    if ($networkLocations) {
        $networkLocations | Sort-Object Name | Format-Table -AutoSize
    } else {
        Write-Host "No network locations found." -ForegroundColor Yellow
    }

    Write-Host "`n===== VOLUMES =====" -ForegroundColor Cyan

    Get-Volume | Where-Object { $_.DriveLetter } |
        Select-Object `
            @{ Name = "Drive"; Expression = { "$($_.DriveLetter):" } },
            FileSystemLabel, FileSystem,
            @{ Name = "Used"; Expression = { if ($_.Size -and $null -ne $_.SizeRemaining) { Format-ReadableSize ($_.Size - $_.SizeRemaining) } else { "Unknown" } } },
            @{ Name = "Free"; Expression = { if ($null -ne $_.SizeRemaining) { Format-ReadableSize $_.SizeRemaining } else { "Unknown" } } },
            @{ Name = "Total"; Expression = { if ($_.Size) { Format-ReadableSize $_.Size } else { "Unknown" } } } |
        Sort-Object Drive | Format-Table -AutoSize
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan
Stop-Transcript | Out-Null
Read-Host "`nPress Enter to close this window"
