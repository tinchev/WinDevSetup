# Configure Registry Script for Windows Setup Automation Tool

# This script manages the configuration of Windows registry settings based on the provided registry-settings.json file.
# It uses the RegistryManager module for registry operations.

# Import the RegistryManager module
Import-Module ../modules/RegistryManager.psm1

# Load the registry settings from the configuration file
$registrySettingsPath = "../configs/registry-settings.json"
$registrySettings = Get-Content -Raw -Path $registrySettingsPath | ConvertFrom-Json

# Iterate through each registry setting and apply it
foreach ($setting in $registrySettings) {
    $keyPath = $setting.KeyPath
    $valueName = $setting.ValueName
    $valueData = $setting.ValueData
    $valueType = $setting.ValueType

    # Set the registry value using the RegistryManager module
    Set-RegistryValue -KeyPath $keyPath -ValueName $valueName -ValueData $valueData -ValueType $valueType
}

# Log the completion of the registry configuration
Write-Host "Registry configuration completed successfully."