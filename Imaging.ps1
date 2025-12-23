# Set the execution policy to bypass
Set-ExecutionPolicy Bypass -Scope Process -Force

# Define log file path
$LogFile = "C:\Windows\Temp\ImagingLog.txt"

# Start logging
Write-Output "$(Get-Date): Starting Autopilot enrollment." | Out-File $LogFile -Append

# Prompt for Asset Tag (used as Group Tag)
$assetTag = Read-Host -Prompt "Enter the Asset Tag for this device"
Write-Output "$(Get-Date): Asset Tag entered: $assetTag" | Out-File $LogFile -Append

# Install the Windows AutoPilot script
try {
    Install-Script -Name Get-WindowsAutoPilotInfo -Force -ErrorAction Stop
    Write-Output "$(Get-Date): Successfully installed AutoPilot script." | Out-File $LogFile -Append
}
catch {
    Write-Output "$(Get-Date): Error installing AutoPilot script: $_" | Out-File $LogFile -Append
    Write-Host "Installation failed. See log for details: $LogFile"
    exit 1
}

# Run Windows AutoPilot script with GroupTag (Asset Tag)
try {   
    Write-Output "$(Get-Date): Autopilot device information uploaded successfully with Asset Tag: $assetTag." | Out-File $LogFile -Append
}
catch {
    Write-Output "$(Get-Date): Error running AutoPilot info script: $_" | Out-File $LogFile -Append
    exit 1
}

Write-Output "$(Get-Date): Enrollment process initiated." | Out-File $LogFile -Append

