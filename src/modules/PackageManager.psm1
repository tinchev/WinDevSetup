# PackageManager.psm1
# Handles different package manager installations (Winget, Chocolatey)

# Import Logger module for logging functions
if (-not (Get-Command Write-LogInfo -ErrorAction SilentlyContinue)) {
    Import-Module "$PSScriptRoot\Logger.psm1" -Force
}

function Install-WithWinget {
    param (
        [string]$PackageId,
        [string]$Name
    )
    
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-LogWarning "Winget not available for $Name"
        return $false
    }
    
    $RunFolder = Get-CurrentRunFolder
    if (-not $RunFolder) {
        $RunFolder = "$PSScriptRoot\..\..\logs"
    }
    
    $LogFile = Join-Path $RunFolder "winget-$($Name -replace '[^\w\-_\.]', '_')-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    
    try {
        Write-LogInfo "Installing $Name via Winget... (Log: $(Split-Path $LogFile -Leaf))"
        
        $Result = Start-PackageInstallation -Command "winget" -Arguments "install --id `"$PackageId`" --silent --accept-source-agreements --accept-package-agreements --verbose" -Name $Name -LogFile $LogFile
        
        return $Result
    } catch {
        $ErrorMessage = "Exception during Winget installation of $Name : $_"
        Write-LogError $ErrorMessage
        $ErrorMessage | Out-File -FilePath $LogFile -Append -Encoding UTF8
        return $false
    }
}

function Install-WithChocolatey {
    param (
        [string]$PackageId,
        [string]$Name
    )
    
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-LogWarning "Chocolatey not available for $Name"
        return $false
    }
    
    $RunFolder = Get-CurrentRunFolder
    if (-not $RunFolder) {
        $RunFolder = "$PSScriptRoot\..\..\logs"
    }
    
    $LogFile = Join-Path $RunFolder "chocolatey-$($Name -replace '[^\w\-_\.]', '_')-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    
    try {
        Write-LogInfo "Installing $Name via Chocolatey... (Log: $(Split-Path $LogFile -Leaf))"
        
        $Result = Start-PackageInstallation -Command "choco" -Arguments "install `"$PackageId`" -y --verbose" -Name $Name -LogFile $LogFile
        
        return $Result
    } catch {
        $ErrorMessage = "Exception during Chocolatey installation of $Name : $_"
        Write-LogError $ErrorMessage
        $ErrorMessage | Out-File -FilePath $LogFile -Append -Encoding UTF8
        return $false
    }
}

function Start-PackageInstallation {
    param (
        [string]$Command,
        [string]$Arguments,
        [string]$Name,
        [string]$LogFile
    )
    
    Write-LogInfo "Progress: Starting $Command installation for $Name"
    
    $StartTime = Get-Date
    
    # Initialize log file
    Initialize-InstallationLog -LogFile $LogFile -Command $Command -Arguments $Arguments -Name $Name
    
    try {
        "=== COMMAND OUTPUT ===" | Out-File -FilePath $LogFile -Append -Encoding UTF8
        
        # Create a script block to run the command and capture output
        $ScriptBlock = {
            param($Cmd, $Arguments, $LogFile)
            try {
                # Execute the command and capture both output and errors
                $Output = & $Cmd $Arguments.Split(' ') 2>&1
                
                # Write output to log file in real-time
                foreach ($Line in $Output) {
                    $TimeStamp = Get-Date -Format 'HH:mm:ss'
                    if ($Line -is [System.Management.Automation.ErrorRecord]) {
                        "[$TimeStamp] ERROR: $($Line.ToString())" | Out-File -FilePath $LogFile -Append -Encoding UTF8
                    } else {
                        "[$TimeStamp] $($Line.ToString())" | Out-File -FilePath $LogFile -Append -Encoding UTF8
                    }
                }
                
                return $LASTEXITCODE
            } catch {
                "[$TimeStamp] EXCEPTION: $_" | Out-File -FilePath $LogFile -Append -Encoding UTF8
                return 1
            }
        }
        
        # Start the installation in a background job so we can monitor progress
        $InstallJob = Start-Job -ScriptBlock $ScriptBlock -ArgumentList $Command, $Arguments, $LogFile
        
        # Monitor progress
        $ProgressCounter = 0
        while ($InstallJob.State -eq 'Running') {
            $ProgressCounter++
            $Elapsed = (Get-Date) - $StartTime
            Write-LogInfo "Progress: $Name installation running... ($([math]::Floor($Elapsed.TotalSeconds))s elapsed)"
            
            Start-Sleep -Seconds 5
            
            # Log periodic status to file
            "Progress check $ProgressCounter - Elapsed: $([math]::Floor($Elapsed.TotalSeconds))s" | Out-File -FilePath $LogFile -Append -Encoding UTF8
            
            # Timeout warnings
            if ($Elapsed.TotalMinutes -gt 10) {
                Write-LogWarning "$Name installation is taking longer than 10 minutes. Continuing to wait..."
                "WARNING: Installation exceeded 10 minutes" | Out-File -FilePath $LogFile -Append -Encoding UTF8
            }
            
            # Hard timeout after 20 minutes
            if ($Elapsed.TotalMinutes -gt 20) {
                Write-LogError "$Name installation timed out after 20 minutes"
                Stop-Job $InstallJob
                Remove-Job $InstallJob
                "ERROR: Installation killed due to 20-minute timeout" | Out-File -FilePath $LogFile -Append -Encoding UTF8
                return $false
            }
        }
        
        # Get the result
        $ExitCode = Receive-Job $InstallJob
        Remove-Job $InstallJob
        
        # Finalize log
        "" | Out-File -FilePath $LogFile -Append -Encoding UTF8
        "=== INSTALLATION SUMMARY ===" | Out-File -FilePath $LogFile -Append -Encoding UTF8
        "Exit Code: $ExitCode" | Out-File -FilePath $LogFile -Append -Encoding UTF8
        "End Time: $(Get-Date)" | Out-File -FilePath $LogFile -Append -Encoding UTF8
        "Total Duration: $([math]::Floor(((Get-Date) - $StartTime).TotalSeconds))s" | Out-File -FilePath $LogFile -Append -Encoding UTF8
        
        # Handle winget-specific exit codes
        $IsSuccess = $false
        if ($Command -eq "winget") {
            $IsSuccess = Test-WingetExitCode -ExitCode $ExitCode -LogFile $LogFile -Name $Name
        } elseif ($Command -eq "choco") {
            $IsSuccess = ($ExitCode -eq 0)
        } else {
            $IsSuccess = ($ExitCode -eq 0)
        }
        
        if ($IsSuccess) {
            Write-LogInfo "Installation completed successfully (took $([math]::Floor(((Get-Date) - $StartTime).TotalSeconds))s)"
            return $true
        } else {
            Write-LogWarning "Installation failed (Exit Code: $ExitCode)"
            Write-LogInfo "Check detailed log: $LogFile"
            return $false
        }
        
    } catch {
        $ErrorMsg = "Failed to execute $Command installation: $_"
        Write-LogError $ErrorMsg
        $ErrorMsg | Out-File -FilePath $LogFile -Append -Encoding UTF8
        return $false
    }
}

function Test-WingetExitCode {
    param (
        [int]$ExitCode,
        [string]$LogFile,
        [string]$Name
    )
    
    # Winget exit codes documentation:
    # 0: Success
    # -1978335189 (0x8A15002B): No applicable upgrade found
    # -1978335212 (0x8A150014): No packages found matching input criteria
    # -1978335210 (0x8A150016): Package already installed at highest version
    # -1978335211 (0x8A150015): Multiple packages found matching input criteria
    
    switch ($ExitCode) {
        0 {
            "SUCCESS: Package installed successfully" | Out-File -FilePath $LogFile -Append -Encoding UTF8
            return $true
        }
        -1978335189 {
            "SUCCESS: Package already up-to-date (no upgrade needed)" | Out-File -FilePath $LogFile -Append -Encoding UTF8
            Write-LogInfo "$Name is already up-to-date"
            return $true
        }
        -1978335210 {
            "SUCCESS: Package already installed at highest version" | Out-File -FilePath $LogFile -Append -Encoding UTF8
            Write-LogInfo "$Name is already installed at the latest version"
            return $true
        }
        -1978335212 {
            "FAILURE: No packages found matching criteria" | Out-File -FilePath $LogFile -Append -Encoding UTF8
            return $false
        }
        -1978335211 {
            "FAILURE: Multiple packages found - criteria too broad" | Out-File -FilePath $LogFile -Append -Encoding UTF8
            return $false
        }
        default {
            "FAILURE: Unknown exit code $ExitCode" | Out-File -FilePath $LogFile -Append -Encoding UTF8
            return $false
        }
    }
}

function Initialize-InstallationLog {
    param (
        [string]$LogFile,
        [string]$Command,
        [string]$Arguments,
        [string]$Name
    )
    
    "=== $Command Installation Log for $Name ===" | Out-File -FilePath $LogFile -Encoding UTF8
    "Start Time: $(Get-Date)" | Out-File -FilePath $LogFile -Append -Encoding UTF8
    "Command: $Command $Arguments" | Out-File -FilePath $LogFile -Append -Encoding UTF8
    "Package: $Name" | Out-File -FilePath $LogFile -Append -Encoding UTF8
    "" | Out-File -FilePath $LogFile -Append -Encoding UTF8
}

# Export functions
Export-ModuleMember -Function Install-WithWinget, Install-WithChocolatey, Start-PackageInstallation
