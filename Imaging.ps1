#Requires -Version 5.1

# ------------------------------------------------------------------
# Autopilot Enrollment Script
# Uses the community Get-WindowsAutoPilotInfo script + current
# Microsoft Graph PowerShell SDK (avoids the deprecated/retired
# Microsoft.Graph.Intune module, which causes corrupted-package
# install failures on PSGallery).
# ------------------------------------------------------------------

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
    Write-Host $Message
}

Write-Log "Starting Autopilot enrollment."

# Prompt for Asset Tag, used as Group Tag
$assetTag = Read-Host -Prompt "Enter the Asset Tag for this device"
Write-Log "Asset Tag entered: $assetTag"

# ------------------------------------------------------------------
# Prepare PowerShell Gallery / PackageManagement
# ------------------------------------------------------------------
try {
    # Force TLS 1.2 - PSGallery rejects older protocols, which can
    # otherwise result in truncated/corrupted package downloads.
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

# ------------------------------------------------------------------
# Pre-install the current Graph modules the community script needs.
# Installing these ourselves, ahead of time, avoids relying on the
# deprecated Microsoft.Graph.Intune module and its unreliable
# package on the Gallery.
# ------------------------------------------------------------------
try {
    $requiredModules = @(
        "Microsoft.Graph.Authentication",
        "Microsoft.Graph.Groups",
        "Microsoft.Graph.Identity.DirectoryManagement",
        "Microsoft.Graph.DeviceManagement",
        "Microsoft.Graph.DeviceManagement.Enrollment"
    )

    foreach ($module in $requiredModules) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            Write-Log "Installing module: $module"
            Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        }
        else {
            Write-Log "Module already present: $module"
        }
    }

    Write-Log "All required Graph modules are present."
}
catch {
    Write-Log "Error installing Graph modules: $($_.Exception.Message)"
    Write-Host "Installation failed. See log for details: $LogFile"
    exit 1
}

# ------------------------------------------------------------------
# Install the community Windows AutoPilot info script
# (drop-in replacement for the official Get-WindowsAutoPilotInfo.ps1,
# but without the Microsoft.Graph.Intune dependency)
# ------------------------------------------------------------------
try {
    Install-Script `
        -Name Get-WindowsAutoPilotInfoCommunity `
        -Repository PSGallery `
        -Scope CurrentUser `
        -Force `
        -ErrorAction Stop

    Write-Log "Successfully installed community AutoPilot script."
}
catch {
    Write-Log "Error installing AutoPilot script: $($_.Exception.Message)"
    Write-Host "Installation failed. See log for details: $LogFile"
    exit 1
}

# ------------------------------------------------------------------
# Find the installed AutoPilot script
# ------------------------------------------------------------------
try {
    $scriptPath = Get-Command Get-WindowsAutoPilotInfoCommunity.ps1 -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty Source -First 1

    if ([string]::IsNullOrWhiteSpace($scriptPath)) {
        $scriptPath = Get-ChildItem `
            -Path "$env:USERPROFILE\Documents\WindowsPowerShell\Scripts" `
            -Filter "Get-WindowsAutoPilotInfoCommunity.ps1" `
            -Recurse `
            -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty FullName -First 1
    }

    if ([string]::IsNullOrWhiteSpace($scriptPath)) {
        throw "Could not locate Get-WindowsAutoPilotInfoCommunity.ps1 after installation."
    }

    Write-Log "AutoPilot script found at: $scriptPath"
}
catch {
    Write-Log "Error locating AutoPilot script: $($_.Exception.Message)"
    Write-Host "Installation failed. See log for details: $LogFile"
    exit 1
}

# ------------------------------------------------------------------
# Run the AutoPilot script with GroupTag, using the Asset Tag entered
# ------------------------------------------------------------------
try {
    & $scriptPath -Online -GroupTag $assetTag -ErrorAction Stop

    Write-Log "Autopilot device information uploaded successfully with Asset Tag: $assetTag."
}
catch {
    Write-Log "Error running AutoPilot info script: $($_.Exception.Message)"
    Write-Host "Enrollment failed. See log for details: $LogFile"
    exit 1
}

Write-Log "Enrollment process completed."
