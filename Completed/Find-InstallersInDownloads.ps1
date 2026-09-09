# Find-InstallersInDownloads.ps1
# Scans Downloads folders of all local "sysadmin*" accounts on this server
# for .exe or .msi files - useful for finding an installer a colleague may have used.

$path = "C:\Users\"
$administrators = (Get-ChildItem -Path $path | Where-Object {$_.Name -like "sysadmin*"}).Name

foreach ($user in $administrators) {
    Write-Host $user -ForegroundColor Cyan
    $downloadsFolder = $path + $user + "\Downloads"

    if (Test-Path $downloadsFolder) {
        (Get-ChildItem -Path $downloadsFolder -File | Where-Object {($_.Name -like "*.exe") -or ($_.Name -like "*.msi")}).Name
    }
    else {
        Write-Host "  (No Downloads folder found or access denied)" -ForegroundColor DarkGray
    }
}
