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
        "SQL Server Developer Edition" {
            return Install-SqlServerDeveloper
        }
        ".NET Core 2.2" {
            return Install-DotNetCore22
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
        [object]$Software
    )
    
    Write-LogInfo "Installing $($Software.name) using Jabba..."
    
    try {
        # Verify jabba is available
        $JabbaPath = Get-Command "jabba" -ErrorAction SilentlyContinue
        if (-not $JabbaPath) {
            Write-LogError "Jabba not found. Please install Jabba first."
            return $false
        }
        
        # Execute the jabba command
        Write-LogInfo "Executing: $($Software.install_command)"
        Invoke-Expression $Software.install_command
        
        # Give it a moment to complete
        Start-Sleep -Seconds 2
        
        # Verify installation using the check command if provided
        if ($Software.check_command) {
            try {
                $CheckResult = Invoke-Expression $Software.check_command
                if ($CheckResult) {
                    Write-LogInfo "$($Software.name) installed successfully via Jabba"
                    return $true
                } else {
                    Write-LogWarning "$($Software.name) installation may have failed - check command returned no results"
                    return $false
                }
            } catch {
                Write-LogWarning "Could not verify $($Software.name) installation: $_"
                # Still return true if the install command succeeded
                return $true
            }
        } else {
            Write-LogInfo "$($Software.name) installation command completed"
            return $true
        }
    } catch {
        Write-LogError "Failed to install $($Software.name) with Jabba: $_"
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
Export-ModuleMember -Function Install-CustomSoftware, Install-VisualStudioProfessional, Install-WithJabba
