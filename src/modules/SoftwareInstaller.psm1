# SoftwareInstaller.psm1
# Main software installation orchestrator - coordinates between other modules

# Import Logger module for logging functions
if (-not (Get-Command Write-LogInfo -ErrorAction SilentlyContinue)) {
    Import-Module "$PSScriptRoot\Logger.psm1" -Force
}

# Import required modules
Import-Module "$PSScriptRoot\PackageManager.psm1" -Force
Import-Module "$PSScriptRoot\CustomInstaller.psm1" -Force
Import-Module "$PSScriptRoot\InstallationReporter.psm1" -Force

# Define validation functions directly to avoid module import issues
function Test-SoftwareInstalled {
    param ([object]$Software)
    
    if (-not $Software.check_command) {
        return $false
    }
    
    try {
        $CheckResult = Invoke-Expression $Software.check_command -ErrorAction SilentlyContinue
        return [bool]$CheckResult
    } catch {
        return $false
    }
}

function Test-Prerequisites {
    param ([object]$Software)
    return $true  # Simplified for now
}

function Test-PendingReboot {
    try {
        # Check various registry locations for pending reboots
        $PendingReboot = $false
        
        # Check Component Based Servicing
        if (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -ErrorAction SilentlyContinue) {
            $PendingReboot = $true
        }
        
        # Check Windows Update
        if (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -ErrorAction SilentlyContinue) {
            $PendingReboot = $true
        }
        
        # Check Pending File Rename Operations
        if (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "PendingFileRenameOperations" -ErrorAction SilentlyContinue) {
            $PendingReboot = $true
        }
        
        return $PendingReboot
    } catch {
        return $false
    }
}

function Install-SingleSoftware {
    param (
        [object]$Software
    )
    
    Write-LogInfo "Processing: $($Software.name)"
    
    # Check if already installed
    if (Test-SoftwareInstalled -Software $Software) {
        Write-LogInfo "$($Software.name) is already installed"
        return $true
    }
    
    # Check for pending reboots for certain software types
    $RebootRequiredSoftware = @('SQL Server', 'Visual Studio')
    $NeedsRebootCheck = $RebootRequiredSoftware | Where-Object { $Software.name -like "*$_*" }
    
    if ($NeedsRebootCheck -and (Test-PendingReboot)) {
        Write-LogWarning "$($Software.name) requires a system reboot before installation. Skipping for now."
        Write-LogInfo "Please restart your system and run the setup script again to install $($Software.name)"
        return $false
    }
    
    # Check prerequisites
    if (-not (Test-Prerequisites -Software $Software)) {
        Write-LogWarning "$($Software.name) prerequisites not met - skipping installation"
        return $false
    }
    
    # Handle custom installations
    if ($Software.custom_install) {
        return Install-CustomSoftware -Software $Software
    }
    
    # Try standard installation methods in order of preference
    $Success = $false
    
    # Try Winget first
    if ($Software.winget_id -and -not $Success) {
        $Success = Install-WithWinget -PackageId $Software.winget_id -Name $Software.name
    }
    
    # Try Chocolatey as fallback
    if ($Software.chocolatey_id -and -not $Success) {
        $Success = Install-WithChocolatey -PackageId $Software.chocolatey_id -Name $Software.name
    }
    
    if (-not $Success) {
        Write-LogError "Failed to install $($Software.name) with any available method"
    }
    
    return $Success
}

function Install-SoftwareCategory {
    param (
        [array]$SoftwareList,
        [string]$Category
    )
    
    Write-LogInfo "========================================="
    Write-LogInfo "Installing $Category software category ($($SoftwareList.Count) items)"
    Write-LogInfo "========================================="
    
    $SuccessCount = 0
    $TotalCount = $SoftwareList.Count
    $CurrentItem = 0
    
    foreach ($Software in $SoftwareList) {
        $CurrentItem++
        $ProgressPercent = [math]::Round(($CurrentItem / $TotalCount) * 100)
        
        Write-LogInfo "[$CurrentItem/$TotalCount] ($ProgressPercent%) Processing: $($Software.name)"
        
        if (Install-SingleSoftware -Software $Software) {
            $SuccessCount++
            Write-LogSuccess "Successfully installed $($Software.name)"
        } else {
            Write-LogError "Failed to install $($Software.name)"
        }
        
        Write-LogInfo "Category Progress: $SuccessCount/$CurrentItem completed successfully"
        Write-LogInfo "-" * 50
    }
    
    Show-CategorySummary -Category $Category -SuccessCount $SuccessCount -TotalCount $TotalCount
    
    # Refresh environment variables after installations
    $MachinePath = [Environment]::GetEnvironmentVariable("PATH","Machine")
    $UserPath = [Environment]::GetEnvironmentVariable("PATH","User")
    $env:PATH = $MachinePath + ";" + $UserPath
}

function Install-SoftwareList {
    param (
        [string]$ConfigFilePath
    )

    if (Test-Path $ConfigFilePath) {
        try {
            $Config = Get-Content $ConfigFilePath -Raw | ConvertFrom-Json
            
            $Categories = @('productivity', 'design', 'development', 'networking', 'runtimes')
            foreach ($Category in $Categories) {
                if ($Config.$Category) {
                    Install-SoftwareCategory -SoftwareList $Config.$Category -Category $Category
                }
            }
        } catch {
            Write-LogError "Failed to parse configuration file: $($_.Exception.Message)"
        }
    } else {
        Write-LogError "Configuration file not found: $ConfigFilePath"
    }
}

# Export functions
Export-ModuleMember -Function Install-SingleSoftware, Install-SoftwareCategory, Install-SoftwareList, Test-SoftwareInstalled, Test-Prerequisites, Test-PendingReboot
