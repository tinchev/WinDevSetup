# InstallationReporter.psm1
# Handles reporting and summary generation for installations

# Import Logger module for logging functions
if (-not (Get-Command Write-LogInfo -ErrorAction SilentlyContinue)) {
    Import-Module "$PSScriptRoot\Logger.psm1" -Force
}

function New-InstallationSummary {
    param (
        [string]$LogsDirectory = $null
    )
    
    Write-LogInfo "Creating installation summary..."
    
    # Use current run folder if available, otherwise default location
    if (-not $LogsDirectory) {
        $LogsDirectory = Get-CurrentRunFolder
        if (-not $LogsDirectory) {
            $LogsDirectory = "$PSScriptRoot\..\..\logs"
        }
    }
    
    $SummaryFile = Join-Path $LogsDirectory "installation-summary.txt"
    
    try {
        Write-SummaryHeader -SummaryFile $SummaryFile
        Write-LogFilesSummary -LogsDirectory $LogsDirectory -SummaryFile $SummaryFile
        Write-TroubleshootingTips -SummaryFile $SummaryFile
        
        Write-LogInfo "Installation summary created: $SummaryFile"
        return $SummaryFile
    } catch {
        Write-LogError "Failed to create installation summary: $_"
        return $null
    }
}

function Write-SummaryHeader {
    param ([string]$SummaryFile)
    
    "=== Windows Development Machine Setup - Installation Summary ===" | Out-File -FilePath $SummaryFile -Encoding UTF8
    "Generated: $(Get-Date)" | Out-File -FilePath $SummaryFile -Append -Encoding UTF8
    "" | Out-File -FilePath $SummaryFile -Append -Encoding UTF8
}

function Write-LogFilesSummary {
    param (
        [string]$LogsDirectory,
        [string]$SummaryFile
    )
    
    # Get all installation log files from current run
    $LogFiles = Get-ChildItem -Path $LogsDirectory -Filter "*.log" | Where-Object { $_.Name -match "(winget|chocolatey)-.*\.log" }
    
    if ($LogFiles) {
        "=== Individual Installation Logs ===" | Out-File -FilePath $SummaryFile -Append -Encoding UTF8
        
        foreach ($LogFile in $LogFiles | Sort-Object Name) {
            Write-LogFileSummary -LogFile $LogFile -SummaryFile $SummaryFile
        }
    } else {
        "No individual installation logs found in this run." | Out-File -FilePath $SummaryFile -Append -Encoding UTF8
    }
}

function Write-LogFileSummary {
    param (
        [System.IO.FileInfo]$LogFile,
        [string]$SummaryFile
    )
    
    $LogContent = Get-Content $LogFile.FullName -ErrorAction SilentlyContinue
    
    # Extract key information
    $StartTime = $LogContent | Where-Object { $_ -match "Start Time:" } | Select-Object -First 1
    $EndTime = $LogContent | Where-Object { $_ -match "End Time:" } | Select-Object -First 1
    $Duration = $LogContent | Where-Object { $_ -match "Total Duration:" } | Select-Object -First 1
    $ExitCode = $LogContent | Where-Object { $_ -match "Exit Code:" } | Select-Object -First 1
    
    "" | Out-File -FilePath $SummaryFile -Append -Encoding UTF8
    "Log File: $($LogFile.Name)" | Out-File -FilePath $SummaryFile -Append -Encoding UTF8
    if ($StartTime) { $StartTime | Out-File -FilePath $SummaryFile -Append -Encoding UTF8 }
    if ($EndTime) { $EndTime | Out-File -FilePath $SummaryFile -Append -Encoding UTF8 }
    if ($Duration) { $Duration | Out-File -FilePath $SummaryFile -Append -Encoding UTF8 }
    if ($ExitCode) { 
        $ExitCode | Out-File -FilePath $SummaryFile -Append -Encoding UTF8
        if ($ExitCode -match "Exit Code: 0") {
            "Status: SUCCESS" | Out-File -FilePath $SummaryFile -Append -Encoding UTF8
        } else {
            "Status: FAILED" | Out-File -FilePath $SummaryFile -Append -Encoding UTF8
        }
    }
    "-" * 40 | Out-File -FilePath $SummaryFile -Append -Encoding UTF8
}

function Write-TroubleshootingTips {
    param ([string]$SummaryFile)
    
    "" | Out-File -FilePath $SummaryFile -Append -Encoding UTF8
    "=== Troubleshooting Tips ===" | Out-File -FilePath $SummaryFile -Append -Encoding UTF8
    "1. Check individual log files in this run folder for detailed verbose output" | Out-File -FilePath $SummaryFile -Append -Encoding UTF8
    "2. Each installation has its own log file with complete verbose output" | Out-File -FilePath $SummaryFile -Append -Encoding UTF8
    "3. Failed installations may require manual intervention or system restart" | Out-File -FilePath $SummaryFile -Append -Encoding UTF8
    "4. Check Windows Event Logs for system-level issues" | Out-File -FilePath $SummaryFile -Append -Encoding UTF8
    "5. Verify internet connectivity for download failures" | Out-File -FilePath $SummaryFile -Append -Encoding UTF8
    "6. Logs are organized by run date/time in the logs directory" | Out-File -FilePath $SummaryFile -Append -Encoding UTF8
}

function Show-CategoryProgress {
    param (
        [array]$SoftwareList,
        [string]$Category,
        [int]$CurrentItem,
        [int]$SuccessCount
    )
    
    $TotalCount = $SoftwareList.Count
    $ProgressPercent = [math]::Round(($CurrentItem / $TotalCount) * 100)
    
    Write-LogInfo "========================================="
    Write-LogInfo "$Category Progress: [$CurrentItem/$TotalCount] ($ProgressPercent%)"
    Write-LogInfo "Successful installations: $SuccessCount"
    Write-LogInfo "========================================="
}

function Show-CategorySummary {
    param (
        [string]$Category,
        [int]$SuccessCount,
        [int]$TotalCount
    )
    
    Write-LogInfo "========================================="
    Write-LogInfo "$Category installation summary: $SuccessCount/$TotalCount successful"
    
    if ($SuccessCount -eq $TotalCount) {
        Write-LogSuccess "All $Category software installed successfully"
    } elseif ($SuccessCount -gt 0) {
        Write-LogWarning "Partial success: $($TotalCount - $SuccessCount) items failed"
    } else {
        Write-LogError "All $Category installations failed"
    }
    
    Write-LogInfo "========================================="
}

# Export functions
Export-ModuleMember -Function New-InstallationSummary, Show-CategoryProgress, Show-CategorySummary
