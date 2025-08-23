# Windows Development Machine Setup Script
# Self-contained script that doesn't require Git to be pre-installed
# Run as Administrator

#Requires -RunAsAdministrator

param(
    [switch]$SkipChocolatey,
    [switch]$SkipWinget,
    [switch]$SkipRepos,
    [string]$ConfigPath = "..\..\configs\software-list.json"
)

# Import necessary modules
$ModulePath = Split-Path -Parent $PSScriptRoot
Import-Module "$ModulePath\modules\Logger.psm1" -Force
Import-Module "$ModulePath\modules\SoftwareInstaller.psm1" -Force
Import-Module "$ModulePath\modules\RegistryManager.psm1" -Force
Import-Module "$ModulePath\modules\InstallationReporter.psm1" -Force

# Define validation functions directly (temporary workaround)
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

function Show-OverallInstallationStatus {
    param ([object]$Config)
    
    Write-LogInfo "========================================="
    Write-LogInfo "Pre-Installation Status Check"
    Write-LogInfo "========================================="
    
    $Categories = @('productivity', 'design', 'development', 'networking', 'runtimes')
    $TotalInstalled = 0
    $TotalSoftware = 0
    
    foreach ($Category in $Categories) {
        if ($Config.$Category) {
            Write-LogInfo "Checking $Category software ($($Config.$Category.Count) items)..."
            
            $InstalledCount = 0
            foreach ($Software in $Config.$Category) {
                if (Test-SoftwareInstalled -Software $Software) {
                    $InstalledCount++
                    Write-LogSuccess "✓ $($Software.name) is already installed"
                } else {
                    Write-LogInfo "○ $($Software.name) will be installed"
                }
            }
            
            $TotalInstalled += $InstalledCount
            $TotalSoftware += $Config.$Category.Count
            Write-LogInfo "$Category status: $InstalledCount/$($Config.$Category.Count) already installed"
            Write-LogInfo "-" * 50
        }
    }
    
    Write-LogInfo "========================================="
    Write-LogInfo "Overall Status: $TotalInstalled/$TotalSoftware software packages already installed"
    if ($TotalInstalled -eq $TotalSoftware) {
        Write-LogSuccess "All software is already installed! Script will verify and update as needed."
    } elseif ($TotalInstalled -gt 0) {
        Write-LogInfo "Will install $($TotalSoftware - $TotalInstalled) new packages and verify existing installations."
    } else {
        Write-LogInfo "Will install all $TotalSoftware software packages."
    }
    Write-LogInfo "========================================="
}

# Create organized log folder for this run
$BaseLogDirectory = "$PSScriptRoot\..\..\logs"
$RunFolder = New-LogRunFolder -BaseLogDirectory $BaseLogDirectory

# Initialize logging in the run folder
$LogPath = Join-Path $RunFolder "setup-main.log"
Initialize-Logger -LogPath $LogPath

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Install-PackageManagers {
    Write-LogInfo "Installing package managers..."
    
    # Install Chocolatey if not present and not skipped
    if (-not $SkipChocolatey) {
        if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
            Write-LogInfo "Installing Chocolatey..."
            try {
                Set-ExecutionPolicy Bypass -Scope Process -Force
                [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
                Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
                
                $MachinePath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
                $UserPath = [Environment]::GetEnvironmentVariable("PATH", "User")
                $env:PATH = $MachinePath + ";" + $UserPath

                Write-LogInfo "Chocolatey installed successfully"
            } catch {
                Write-LogError "Failed to install Chocolatey: $_"
            }
        } else {
            Write-LogInfo "Chocolatey already installed"
        }
    }
    
    # Ensure Winget is available (comes with Windows 10/11 by default)
    if (-not $SkipWinget) {
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-LogWarning "Winget not found. Please install App Installer from Microsoft Store"
        } else {
            Write-LogInfo "Winget is available"
        }
    }
}

function Install-Prerequisites {
    Write-LogInfo "Installing prerequisites..."
    
    # Install PowerShell modules if needed
    $RequiredModules = @('PowerShellGet', 'PackageManagement')
    
    foreach ($Module in $RequiredModules) {
        if (-not (Get-Module -ListAvailable -Name $Module)) {
            Write-LogInfo "Installing PowerShell module: $Module"
            Install-Module -Name $Module -Force -AllowClobber -Scope CurrentUser
        }
    }
}

function New-DevelopmentFolders {
    param([array]$Folders)
    
    Write-LogInfo "Creating development folders..."
    
    foreach ($Folder in $Folders) {
        $ExpandedPath = [Environment]::ExpandEnvironmentVariables($Folder)
        if (-not (Test-Path $ExpandedPath)) {
            Write-LogInfo "Creating folder: $ExpandedPath"
            try {
                New-Item -ItemType Directory -Path $ExpandedPath -Force | Out-Null
                Write-LogInfo "Created: $ExpandedPath"
            } catch {
                Write-LogError "Failed to create $ExpandedPath : $_"
            }
        } else {
            Write-LogInfo "Folder already exists: $ExpandedPath"
        }
    }
}

function Add-WindowsDefenderExclusions {
    param([array]$Exclusions)
    
    Write-LogInfo "Adding Windows Defender exclusions..."
    
    foreach ($Exclusion in $Exclusions) {
        $ExpandedPath = [Environment]::ExpandEnvironmentVariables($Exclusion)
        try {
            # Check if exclusion already exists
            $ExistingExclusions = Get-MpPreference | Select-Object -ExpandProperty ExclusionPath
            if ($ExistingExclusions -notcontains $ExpandedPath) {
                Add-MpPreference -ExclusionPath $ExpandedPath
                Write-LogInfo "Added Defender exclusion: $ExpandedPath"
            } else {
                Write-LogInfo "Defender exclusion already exists: $ExpandedPath"
            }
        } catch {
            Write-LogWarning "Failed to add Defender exclusion for $ExpandedPath : $_"
        }
    }
}

function Enable-WindowsFeatures {
    param([array]$Features)
    
    Write-LogInfo "Enabling Windows features..."
    
    foreach ($Feature in $Features) {
        try {
            $FeatureState = Get-WindowsOptionalFeature -Online -FeatureName $Feature -ErrorAction SilentlyContinue
            if ($FeatureState -and $FeatureState.State -eq "Disabled") {
                Write-LogInfo "Enabling Windows feature: $Feature"
                Enable-WindowsOptionalFeature -Online -FeatureName $Feature -All -NoRestart
                Write-LogInfo "Enabled: $Feature"
            } elseif ($FeatureState -and $FeatureState.State -eq "Enabled") {
                Write-LogInfo "Windows feature already enabled: $Feature"
            } else {
                Write-LogWarning "Windows feature not found: $Feature"
            }
        } catch {
            Write-LogError "Failed to enable Windows feature $Feature : $_"
        }
    }
}

function Install-Repositories {
    param([array]$Repositories)
    
    if ($SkipRepos) {
        Write-LogInfo "Skipping repository setup"
        return
    }
    
    Write-LogInfo "Setting up repositories..."
    
    # Ensure Git is installed before cloning repositories
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-LogWarning "Git not available for repository cloning. Install Git first and run again."
        return
    }
    
    foreach ($Repo in $Repositories) {
        if ($Repo.url -and $Repo.local_path) {
            $LocalPath = [Environment]::ExpandEnvironmentVariables($Repo.local_path)
            
            if (-not (Test-Path $LocalPath)) {
                Write-LogInfo "Cloning repository: $($Repo.name)"
                try {
                    $ParentPath = Split-Path $LocalPath -Parent
                    if (-not (Test-Path $ParentPath)) {
                        New-Item -ItemType Directory -Path $ParentPath -Force | Out-Null
                    }
                    
                    git clone $Repo.url $LocalPath
                    Write-LogInfo "Successfully cloned: $($Repo.name)"
                } catch {
                    Write-LogError "Failed to clone $($Repo.name): $_"
                }
            } else {
                Write-LogInfo "Repository already exists: $($Repo.name)"
            }
        }
    }
}

function Start-Setup {
    Write-LogInfo "========================================="
    Write-LogInfo "Windows Development Machine Setup Started"
    Write-LogInfo "========================================="
    
    if (-not (Test-Administrator)) {
        Write-LogError "This script must be run as Administrator"
        exit 1
    }
    
    # Load configuration
    $ConfigFullPath = Join-Path $PSScriptRoot $ConfigPath
    if (-not (Test-Path $ConfigFullPath)) {
        Write-LogError "Configuration file not found: $ConfigFullPath"
        exit 1
    }
    
    try {
        $Config = Get-Content $ConfigFullPath -Raw | ConvertFrom-Json
        Write-LogInfo "Configuration loaded successfully"
    } catch {
        Write-LogError "Failed to parse configuration file: $_"
        exit 1
    }
    
    # Step 1: Install prerequisites and package managers
    Write-LogInfo "Step 1: Installing prerequisites..."
    Install-Prerequisites
    Install-PackageManagers
    
    # Step 2: Create development folders
    Write-LogInfo "Step 2: Creating development folders..."
    if ($Config.system_configuration.folders_to_create) {
        New-DevelopmentFolders -Folders $Config.system_configuration.folders_to_create
    }
    
    # Step 3: Configure Windows Defender exclusions
    Write-LogInfo "Step 3: Configuring Windows Defender exclusions..."
    if ($Config.system_configuration.windows_defender_exclusions) {
        Add-WindowsDefenderExclusions -Exclusions $Config.system_configuration.windows_defender_exclusions
    }
    
    # Step 4: Enable Windows features
    Write-LogInfo "Step 4: Enabling Windows features..."
    if ($Config.system_configuration.windows_features) {
        Enable-WindowsFeatures -Features $Config.system_configuration.windows_features
    }
    
    # Step 5: Check installation status before proceeding
    Write-LogInfo "Step 5: Checking current software installation status..."
    Show-OverallInstallationStatus -Config $Config
    
    # Step 6: Install software by category
    Write-LogInfo "Step 6: Installing software..."
    
    $Categories = @('productivity', 'design', 'development', 'networking', 'runtimes')
    foreach ($Category in $Categories) {
        if ($Config.$Category) {
            Write-LogInfo "Installing $Category software..."
            Install-SoftwareCategory -SoftwareList $Config.$Category -Category $Category
        }
    }
    
    # Step 7: Setup repositories (optional)
    Write-LogInfo "Step 7: Setting up repositories..."
    if ($Config._repositories -and -not $SkipRepos) {
        Install-Repositories -Repositories $Config._repositories
    }
    
    Write-LogInfo "========================================="
    Write-LogInfo "Windows Development Machine Setup Completed"
    Write-LogInfo "Log file: $LogPath"
    
    # Generate installation summary
    Write-LogInfo "Generating installation summary..."
    $SummaryFile = New-InstallationSummary
    if ($SummaryFile) {
        Write-LogInfo "Installation summary: $SummaryFile"
    }
    
    Write-LogInfo "========================================="
    
    # Check if restart is needed
    if (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -ErrorAction SilentlyContinue) {
        Write-LogWarning "A restart is required to complete the installation."
        $Restart = Read-Host "Would you like to restart now? (Y/N)"
        if ($Restart -eq 'Y' -or $Restart -eq 'y') {
            Restart-Computer -Force
        }
    }
}

# Start the setup process
Start-Setup
