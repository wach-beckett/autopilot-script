#Requires -Version 5.1

# Set execution policy to bypass for this process only
Set-ExecutionPolicy Bypass -Scope Process -Force

# Define log file path
$LogFile = "C:\Windows\Temp\ImagingLog.txt"

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    "$(Get-Date): $Message" | Out-File -FilePath $LogFile -Append
}

Write-Log "Starting Autopilot enrollment."

# Prompt for Asset Tag, used as Group Tag
$assetTag = Read-Host -Prompt "Enter the Asset Tag for this device"
Write-Log "Asset Tag entered: $assetTag"

# Prepare PowerShell Gallery / PackageManagement
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
        Write-Log "NuGet provider not found. Installing NuGet provider."
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction Stop
        Write-Log "NuGet provider installed successfully."
    }

    $repo = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue

    if (-not $repo) {
        Write-Log "PSGallery repository not found. Registering default repository."
        Register-PSRepository -Default -ErrorAction Stop
    }

    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
    Write-Log "PSGallery is available and trusted."
}
catch {
    Write-Log "Error preparing PowerShell Gallery: $($_.Exception.Message)"
    Write-Host "Installation failed. See log for details: $LogFile"
    exit 1
}

# Install the Windows AutoPilot script
try {
    Install-Script `
        -Name Get-WindowsAutoPilotInfo `
        -Repository PSGallery `
        -Scope CurrentUser `
        -Force `
        -ErrorAction Stop

    Write-Log "Successfully installed AutoPilot script."
}
catch {
    Write-Log "Error installing AutoPilot script: $($_.Exception.Message)"
    Write-Host "Installation failed. See log for details: $LogFile"
    exit 1
}

# Find installed AutoPilot script
try {
    $scriptPath = Get-Command Get-WindowsAutoPilotInfo.ps1 -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty Source -First 1

    if ([string]::IsNullOrWhiteSpace($scriptPath)) {
        $scriptPath = Get-ChildItem `
            -Path "$env:USERPROFILE\Documents\WindowsPowerShell\Scripts" `
            -Filter "Get-WindowsAutoPilotInfo.ps1" `
            -Recurse `
            -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty FullName -First 1
    }

    if ([string]::IsNullOrWhiteSpace($scriptPath)) {
        throw "Could not locate Get-WindowsAutoPilotInfo.ps1 after installation."
    }

    Write-Log "AutoPilot script found at: $scriptPath"
}
catch {
    Write-Log "Error locating AutoPilot script: $($_.Exception.Message)"
    Write-Host "Installation failed. See log for details: $LogFile"
    exit 1
}

# Run Windows AutoPilot script with GroupTag, using Asset Tag
try {
    & $scriptPath -Online -GroupTag $assetTag -ErrorAction Stop

    Write-Log "Autopilot device information uploaded successfully with Asset Tag: $assetTag."
}
catch {
    Write-Log "Error running AutoPilot info script: $($_.Exception.Message)"
    Write-Host "Enrollment failed. See log for details: $LogFile"
    exit 1
}

Write-Log "Enrollment process initiated."
