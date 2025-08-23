# Test-SoftwareInstaller.ps1

# Unit tests for the SoftwareInstaller module

# Import the SoftwareInstaller module
Import-Module ..\..\src\modules\SoftwareInstaller.psm1

# Function to test the installation of software
function Test-InstallSoftware {
    param (
        [string]$softwareName,
        [string]$expectedResult
    )

    # Call the Install-Software function from the SoftwareInstaller module
    $result = Install-Software -Name $softwareName

    # Assert that the result matches the expected result
    if ($result -ne $expectedResult) {
        Write-Host "Test failed for $softwareName. Expected: $expectedResult, Got: $result"
    } else {
        Write-Host "Test passed for $softwareName."
    }
}

# Example tests
Test-InstallSoftware -softwareName "ExampleSoftware" -expectedResult "Installed"
Test-InstallSoftware -softwareName "AnotherSoftware" -expectedResult "Already Installed"