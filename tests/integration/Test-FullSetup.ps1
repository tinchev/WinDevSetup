# Test-FullSetup.ps1

# Integration test for the full setup process of the Windows Setup Automation Tool

# Import necessary modules
Import-Module ../src/modules/Logger.psm1
Import-Module ../src/modules/SoftwareInstaller.psm1
Import-Module ../src/modules/RegistryManager.psm1

# Function to run the full setup process
function Run-FullSetup {
    # Log the start of the setup process
    Log-Message "Starting full setup process..."

    # Run the setup script
    & ../src/scripts/setup.ps1

    # Verify software installation
    $softwareList = Get-Content ../configs/software-list.json | ConvertFrom-Json
    foreach ($software in $softwareList) {
        if (-not (Check-SoftwareInstalled $software.name)) {
            Log-Message "Software $($software.name) is not installed."
            return $false
        }
    }

    # Verify registry settings
    $registrySettings = Get-Content ../configs/registry-settings.json | ConvertFrom-Json
    foreach ($setting in $registrySettings) {
        if (-not (Check-RegistryValue $setting.path $setting.name $setting.value)) {
            Log-Message "Registry setting $($setting.path)\$($setting.name) is not set correctly."
            return $false
        }
    }

    # Verify Windows features
    $windowsFeatures = Get-Content ../configs/windows-features.json | ConvertFrom-Json
    foreach ($feature in $windowsFeatures) {
        if (-not (Get-WindowsFeature -Name $feature.name).Installed) {
            Log-Message "Windows feature $($feature.name) is not enabled."
            return $false
        }
    }

    # Log the successful completion of the setup process
    Log-Message "Full setup process completed successfully."
    return $true
}

# Run the full setup and capture the result
$result = Run-FullSetup

# Output the result of the integration test
if ($result) {
    Write-Host "Integration test passed."
} else {
    Write-Host "Integration test failed."
}