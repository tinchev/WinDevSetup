# Enable Features Script for Windows Setup Automation Tool

# This script enables or disables specific Windows features as defined in the windows-features.json configuration file.

# Import necessary modules
Import-Module ..\modules\Logger.psm1
Import-Module ..\modules\RegistryManager.psm1

# Load the configuration file
$featuresConfigPath = "..\configs\windows-features.json"
$featuresConfig = Get-Content -Raw -Path $featuresConfigPath | ConvertFrom-Json

# Function to enable or disable Windows features
function Enable-WindowsFeature {
    param (
        [string]$FeatureName,
        [bool]$Enable
    )

    if ($Enable) {
        Write-Log "Enabling feature: $FeatureName"
        Enable-WindowsOptionalFeature -Online -FeatureName $FeatureName -All -NoRestart
    } else {
        Write-Log "Disabling feature: $FeatureName"
        Disable-WindowsOptionalFeature -Online -FeatureName $FeatureName -NoRestart
    }
}

# Iterate through the features defined in the configuration
foreach ($feature in $featuresConfig.features) {
    Enable-WindowsFeature -FeatureName $feature.name -Enable $feature.enable
}

# Restart the system if required
if ($featuresConfig.restartRequired) {
    Write-Log "A restart is required to apply changes. Restarting now..."
    Restart-Computer -Force
} else {
    Write-Log "No restart required."
}