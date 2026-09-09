# Copy-UserFolder.ps1
# Prompts for source folder, destination folder, username, and ticket number,
# then runs the robocopy command. Pressing Enter with no input at any prompt cancels.

$sourcePath = Read-Host "Enter the source folder path (this is the location to copy FROM) (press Enter with no input to cancel)"
if ([string]::IsNullOrWhiteSpace($sourcePath)) {
    Write-Host "No source path entered. Cancelling." -ForegroundColor Yellow
    return
}

$destPath = Read-Host "Enter the destination folder path (this is the location to copy TO) (press Enter with no input to cancel)"
if ([string]::IsNullOrWhiteSpace($destPath)) {
    Write-Host "No destination path entered. Cancelling." -ForegroundColor Yellow
    return
}

$username = Read-Host "Enter the username (press Enter with no input to cancel)"
if ([string]::IsNullOrWhiteSpace($username)) {
    Write-Host "No username entered. Cancelling." -ForegroundColor Yellow
    return
}

$ticketNumber = Read-Host "Enter the ticket number (press Enter with no input to cancel)"
if ([string]::IsNullOrWhiteSpace($ticketNumber)) {
    Write-Host "No ticket number entered. Cancelling." -ForegroundColor Yellow
    return
}

$logPath = "C:\Robocopy Logs\$username-ID$ticketNumber.txt"

robocopy "$sourcePath" "$destPath" *.* /COPY:DAT /DCOPY:DAT /E /W:1 /R:10 /MT:25 /log:"$logPath"
