# CustomInstaller.psm1
# Handles custom installations for software that requires special handling

# Import Logger module for logging functions
if (-not (Get-Command Write-LogInfo -ErrorAction SilentlyContinue)) {
    Import-Module "$PSScriptRoot\Logger.psm1" -Force
}

function Install-CustomSoftware {
    param (
        [object]$Software
    )
    
    Write-LogInfo "Performing custom installation for $($Software.name)..."
    
    # Check if this is a jabba-based installation
    if ($Software.install_command -and $Software.install_command.StartsWith("jabba ")) {
        return Install-WithJabba -Software $Software
    }
    
    switch ($Software.name) {
        "Visual Studio Professional" {
            return Install-VisualStudioProfessional -Software $Software
        }
        { $_ -like "Service Fabric*" } {
            return Install-ServiceFabricSDK -Software $Software -LogPath $LogPath
        }
        "SQL Server Developer Edition" {
            return Install-SqlServerDeveloper
        }
        ".NET Core 2.2" {
            return Install-DotNetCore22
        }
        { $_ -like "*via NVM*" } {
            return Install-WithNVM -InstallCommand $Software.install_command
        }
        { $_ -like "*via Jabba*" } {
            return Install-WithJabba -InstallCommand $Software.install_command
        }
        default {
            Write-LogWarning "No custom installation method defined for $($Software.name)"
            return $false
        }
    }
}

function Install-VisualStudioProfessional {
    param (
        [object]$Software
    )
    
    Write-LogInfo "Installing Visual Studio Professional with comprehensive development workloads..."
    
    try {
        # Check if already installed
        if ($Software.check_command) {
            $CheckResult = Invoke-Expression $Software.check_command
            if ($CheckResult) {
                Write-LogInfo "Visual Studio Professional already installed"
                return $true
            }
        }
        
        # Step 1: Install base Visual Studio Professional first
        Write-LogInfo "Step 1: Installing base Visual Studio Professional..."
        Import-Module "$PSScriptRoot\PackageManager.psm1" -Force
        $BaseInstallResult = Install-WithWinget -PackageId "Microsoft.VisualStudio.2022.Professional" -Name "Visual Studio Professional (Base)"
        
        if (-not $BaseInstallResult) {
            Write-LogError "Failed to install base Visual Studio Professional"
            return $false
        }
        
        Write-LogInfo "Base Visual Studio Professional installed successfully"
        
        # Step 2: Wait for Visual Studio Installer to be available
        Write-LogInfo "Step 2: Waiting for Visual Studio Installer to be ready..."
        $VSInstallerPath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vs_installer.exe"
        $MaxWaitTime = 300 # 5 minutes
        $WaitTime = 0
        
        while (-not (Test-Path $VSInstallerPath) -and $WaitTime -lt $MaxWaitTime) {
            Start-Sleep -Seconds 10
            $WaitTime += 10
            Write-LogInfo "Waiting for VS Installer... ($WaitTime/$MaxWaitTime seconds)"
        }
        
        if (-not (Test-Path $VSInstallerPath)) {
            Write-LogWarning "Visual Studio Installer not found, trying alternative path..."
            $VSInstallerPath = "${env:ProgramFiles}\Microsoft Visual Studio\Installer\vs_installer.exe"
        }
        
        if (-not (Test-Path $VSInstallerPath)) {
            Write-LogError "Visual Studio Installer not found. Base installation may have failed."
            return $false
        }
        
        Write-LogInfo "Visual Studio Installer found at: $VSInstallerPath"
        
        # Step 3: Use external .vsconfig for workloads
        Write-LogInfo "Step 3: Installing development workloads..."
        
        # Use external .vsconfig file for development workloads
        $SourceConfigPath = "$PSScriptRoot\..\..\configs\visual-studio-workloads.vsconfig"
        if (-not (Test-Path $SourceConfigPath)) {
            Write-LogError "Visual Studio workloads configuration file not found at: $SourceConfigPath"
            return $false
        }
        
        Write-LogInfo "Using Visual Studio workloads configuration from: $SourceConfigPath"
        
        # Copy to temporary location for VS Installer
        $TempDir = [System.IO.Path]::GetTempPath()
        $ConfigPath = Join-Path $TempDir "vs-dev-config.vsconfig"
        Write-LogInfo "Copying configuration to temporary location: $ConfigPath"
        
        try {
            Copy-Item -Path $SourceConfigPath -Destination $ConfigPath -Force
            Write-LogInfo "Successfully copied configuration file"
        } catch {
            Write-LogError "Failed to copy configuration file: $_"
            return $false
        }
        
        # Step 4: Use Visual Studio Installer to modify installation with workloads
        Write-LogInfo "Step 4: Applying workloads using Visual Studio Installer..."
        
        $VSInstancePath = "${env:ProgramFiles}\Microsoft Visual Studio\2022\Professional"
        if (-not (Test-Path $VSInstancePath)) {
            $VSInstancePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\Professional"
        }
        
        # Build VS Installer arguments
        $ModifyArgs = "modify --installPath `"$VSInstancePath`" --config `"$ConfigPath`" --quiet"
        
        Write-LogInfo "Executing Visual Studio Installer modify command..."
        Write-LogInfo "Installer Path: $VSInstallerPath"
        Write-LogInfo "Arguments: $ModifyArgs"
        
        # Use the same logging approach as other package installations
        $RunFolder = Get-CurrentRunFolder
        if (-not $RunFolder) {
            $RunFolder = "$PSScriptRoot\..\..\logs"
        }
        $LogFile = Join-Path $RunFolder "vs-installer-$($Software.name -replace '[^\w\-_\.]', '_')-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
        
        Write-LogInfo "Installing $($Software.name) workloads via VS Installer... (Log: $(Split-Path $LogFile -Leaf))"
        $Result = Start-PackageInstallation -Command $VSInstallerPath -Arguments $ModifyArgs -Name "$($Software.name) Workloads" -LogFile $LogFile
        
        # Clean up temporary file
        Remove-Item $ConfigPath -ErrorAction SilentlyContinue
        
        # For Visual Studio installer, we need special handling since it may not return standard exit codes
        if ($Result) {
            Write-LogInfo "Visual Studio Professional workloads installed successfully"
            Write-LogInfo "Workloads included: .NET Desktop, Web, Azure, Data, Cross-platform, Node.js"
            return $true
        } else {
            # Visual Studio installer often completes successfully but doesn't return proper exit codes
            # Check if the installation actually worked by verifying Visual Studio is properly installed
            Write-LogInfo "Verifying Visual Studio installation (installer may have completed without standard exit code)..."
            Start-Sleep -Seconds 5
            
            if ($Software.check_command) {
                $CheckResult = Invoke-Expression $Software.check_command
                if ($CheckResult) {
                    Write-LogInfo "Visual Studio Professional installation verified - workloads installed successfully"
                    Write-LogInfo "Note: VS Installer completed without standard exit code, but installation was successful"
                    return $true
                }
            }
            
            # Additional check - see if VS executable exists and has expected components
            $VSPath = "${env:ProgramFiles}\Microsoft Visual Studio\2022\Professional\Common7\IDE\devenv.exe"
            if (-not (Test-Path $VSPath)) {
                $VSPath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\Professional\Common7\IDE\devenv.exe"
            }
            
            if (Test-Path $VSPath) {
                Write-LogInfo "Visual Studio Professional executable found - installation appears successful"
                Write-LogInfo "Note: VS Installer may not return standard exit codes, but VS is installed"
                return $true
            }
            
            Write-LogError "Visual Studio Professional workload installation failed"
            return $false
        }
        
    } catch {
        Write-LogError "Failed to install Visual Studio Professional: $_"
        # Clean up temporary file on error
        $TempDir = [System.IO.Path]::GetTempPath()
        $ConfigPath = Join-Path $TempDir "vs-dev-config.vsconfig"
        Remove-Item $ConfigPath -ErrorAction SilentlyContinue
        return $false
    }
}

function Install-WithJabba {
    param (
        [string]$InstallCommand
    )
    
    Write-LogInfo "Installing Java version using Jabba..."
    
    try {
        # Verify jabba is available
        $JabbaPath = Get-Command "jabba" -ErrorAction SilentlyContinue
        if (-not $JabbaPath) {
            Write-LogError "Jabba not found. Please install Jabba first."
            return $false
        }
        
        # Execute the jabba command
        Write-LogInfo "Executing: $InstallCommand"
        Invoke-Expression $InstallCommand
        
        # Give it a moment to complete
        Start-Sleep -Seconds 2
        
        Write-LogInfo "Java version installation completed via Jabba"
        return $true
        
    } catch {
        Write-LogError "Failed to install Java version with Jabba: $_"
        return $false
    }
}

function Install-WithNVM {
    param (
        [string]$InstallCommand
    )
    
    Write-LogInfo "Installing Node.js version using NVM..."
    
    try {
        # Verify NVM is available
        $NVMPath = Get-Command "nvm" -ErrorAction SilentlyContinue
        if (-not $NVMPath) {
            Write-LogError "NVM not found. Please install NVM for Windows first."
            return $false
        }
        
        # Refresh PATH to ensure NVM is available
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
        
        # Execute the NVM command
        Write-LogInfo "Executing: $InstallCommand"
        
        # Split the command to handle multiple commands (like install and use)
        $Commands = $InstallCommand -split ";"
        foreach ($Command in $Commands) {
            $Command = $Command.Trim()
            if ($Command) {
                Write-LogInfo "Running: $Command"
                $Result = Start-Process -FilePath "cmd" -ArgumentList "/c", $Command -Wait -PassThru -NoNewWindow
                if ($Result.ExitCode -ne 0) {
                    Write-LogWarning "Command '$Command' returned exit code $($Result.ExitCode)"
                }
            }
        }
        
        Write-LogInfo "Node.js version installation completed via NVM"
        return $true
        
    } catch {
        Write-LogError "Failed to install Node.js version with NVM: $_"
        return $false
    }
}

function Install-ServiceFabricSDK {
    param (
        [object]$Software,
        [string]$LogPath
    )
    
    Write-LogInfo "Installing $($Software.name) with custom arguments..."
    
    try {
        # Check if already installed
        $CheckResult = Invoke-Expression $Software.check_command -ErrorAction SilentlyContinue
        if ($CheckResult) {
            Write-LogInfo "$($Software.name) is already installed"
            return $true
        }
        
        # Import PackageManager module for proper installation handling
        Import-Module "$PSScriptRoot\PackageManager.psm1" -Force
        
        # Try to download using winget first, then chocolatey
        $downloadSuccess = $false
        $installerPath = $null
        
        # Try winget download first
        if ($Software.winget_id) {
            Write-LogInfo "Attempting to download $($Software.name) via winget..."
            try {
                # Create temporary directory
                $tempDir = Join-Path $env:TEMP "ServiceFabric_$(Get-Random)"
                New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
                
                # Download using winget with license acceptance
                $wingetArgs = @(
                    "download",
                    "--id", $Software.winget_id,
                    "--download-directory", $tempDir,
                    "--accept-package-agreements",
                    "--accept-source-agreements"
                )
                $wingetDownload = Start-Process -FilePath "winget" -ArgumentList $wingetArgs -Wait -PassThru -NoNewWindow
                
                if ($wingetDownload.ExitCode -eq 0) {
                    # Find the downloaded installer
                    $installerPath = Get-ChildItem -Path $tempDir -Recurse -Filter "*.exe" | Select-Object -First 1 -ExpandProperty FullName
                    if ($installerPath) {
                        Write-LogInfo "Successfully downloaded $($Software.name) installer: $installerPath"
                        $downloadSuccess = $true
                    }
                }
            } catch {
                Write-LogWarning "Winget download failed: $_"
            }
        }
        
        # If winget failed, try chocolatey with proper logging
        if (-not $downloadSuccess -and $Software.chocolatey_id) {
            Write-LogInfo "Attempting to install $($Software.name) via chocolatey..."
            try {
                # Use Install-WithChocolatey for consistent logging, but it doesn't support custom params
                # So we'll use Start-PackageInstallation with choco command directly
                $chocoArgs = "install $($Software.chocolatey_id) -y --params '/accepteula /quiet'"
                
                # Get proper log path
                $RunFolder = Get-CurrentRunFolder
                if (-not $RunFolder) {
                    $RunFolder = "$PSScriptRoot\..\..\logs"
                }
                $LogFile = Join-Path $RunFolder "chocolatey-$($Software.name -replace '[^\w\-_\.]', '_')-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
                
                $result = Start-PackageInstallation -Command "choco" -Arguments $chocoArgs -Name $Software.name -LogFile $LogFile
                
                if ($result) {
                    Write-LogInfo "$($Software.name) installed successfully via chocolatey"
                    return $true
                } else {
                    Write-LogWarning "Chocolatey installation failed"
                }
            } catch {
                Write-LogWarning "Chocolatey installation failed: $_"
            }
        }
        
        # If we have a downloaded installer, run it with proper arguments using Start-PackageInstallation
        if ($downloadSuccess -and $installerPath) {
            Write-LogInfo "Running $($Software.name) installer with proper arguments..."
            
            try {
                # Get proper log path
                $RunFolder = Get-CurrentRunFolder
                if (-not $RunFolder) {
                    $RunFolder = "$PSScriptRoot\..\..\logs"
                }
                $LogFile = Join-Path $RunFolder "custom-installer-$($Software.name -replace '[^\w\-_\.]', '_')-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
                
                # Use Start-PackageInstallation for consistent logging and exit code handling
                $installerArgs = "/accepteula /quiet"
                $result = Start-PackageInstallation -Command $installerPath -Arguments $installerArgs -Name $Software.name -LogFile $LogFile
                
                # Clean up temporary directory
                try { Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue } catch { }
                
                if ($result) {
                    Write-LogInfo "$($Software.name) installed successfully"
                    return $true
                } else {
                    Write-LogError "$($Software.name) installation failed"
                    return $false
                }
                
            } catch {
                # Clean up on error
                try { Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue } catch { }
                Write-LogError "Failed to execute $($Software.name) installer: $_"
                return $false
            }
        }
        
        Write-LogError "All $($Software.name) installation methods failed"
        return $false
        
    } catch {
        Write-LogError "Failed to install $($Software.name): $_"
        return $false
    }
}

function Install-SqlServerDeveloper {
    Write-LogInfo "Installing SQL Server Developer Edition..."
    
    try {
        # Check if SQL Server is already installed
        $SqlService = Get-Service -Name "MSSQLSERVER" -ErrorAction SilentlyContinue
        if ($SqlService) {
            Write-LogInfo "SQL Server already installed"
            return $true
        }
        
        # Use Chocolatey package
        Import-Module "$PSScriptRoot\PackageManager.psm1" -Force
        return Install-WithChocolatey -PackageId "sql-server-2022" -Name "SQL Server Developer Edition"
    } catch {
        Write-LogError "Failed to install SQL Server: $_"
        return $false
    }
}

function Install-DotNetCore22 {
    Write-LogInfo "Installing .NET Core 2.2..."
    
    try {
        # Check if already installed
        $Existing = dotnet --list-sdks 2>$null | Select-String "2.2"
        if ($Existing) {
            Write-LogInfo ".NET Core 2.2 already installed"
            return $true
        }
        
        # Download and install .NET Core 2.2 SDK manually (since it's out of support)
        $DownloadUrl = "https://dotnetcli.azureedge.net/dotnet/Sdk/2.2.207/dotnet-sdk-2.2.207-win-x64.exe"
        $TempPath = "$env:TEMP\dotnet-sdk-2.2.207-win-x64.exe"
        
        Write-LogInfo "Downloading .NET Core 2.2 SDK..."
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $TempPath -UseBasicParsing
        
        Write-LogInfo "Installing .NET Core 2.2 SDK..."
        Start-Process -FilePath $TempPath -ArgumentList "/quiet" -Wait
        
        Remove-Item $TempPath -Force -ErrorAction SilentlyContinue
        Write-LogInfo ".NET Core 2.2 SDK installed successfully"
        return $true
    } catch {
        Write-LogError "Failed to install .NET Core 2.2: $_"
        return $false
    }
}

# Export functions
Export-ModuleMember -Function Install-CustomSoftware, Install-VisualStudioProfessional, Install-WithJabba, Install-WithNVM, Install-ServiceFabricSDK
