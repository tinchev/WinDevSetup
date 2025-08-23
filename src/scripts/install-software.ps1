# Install Software Script for Windows Setup Automation Tool

# This script handles the installation of specified software listed in the configuration files.
# It utilizes the SoftwareInstaller module for the installation process.

# Import the SoftwareInstaller module
Import-Module ../modules/SoftwareInstaller.psm1

# Load the software list from the configuration file
$softwareListPath = "../configs/software-list.json"
$softwareList = Get-Content -Raw -Path $softwareListPath | ConvertFrom-Json

# Iterate through each software entry and install it
foreach ($software in $softwareList.software) {
    Write-Host "Installing $($software.name)..."
    $installationResult = Install-Software -Name $software.name -Command $software.installCommand

    if ($installationResult) {
        Write-Host "$($software.name) installed successfully."
    } else {
        Write-Host "Failed to install $($software.name)."
    }
}