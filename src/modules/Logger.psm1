# Logger.psm1

# Logger.psm1
# Enhanced logging module with multiple log levels and file output

$Script:LogPath = $null
$Script:LogInitialized = $false
$Script:CurrentRunFolder = $null

function Initialize-Logger {
    param (
        [string]$LogPath
    )
    
    $Script:LogPath = $LogPath
    
    # Create log directory if it doesn't exist
    $LogDirectory = Split-Path $LogPath -Parent
    if (-not (Test-Path $LogDirectory)) {
        New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
    }
    
    # Initialize log file
    $InitMessage = "=== Windows Dev Machine Setup Log Started: $(Get-Date) ==="
    $InitMessage | Out-File -FilePath $LogPath -Encoding UTF8
    
    $Script:LogInitialized = $true
    Write-LogInfo "Logging initialized to: $LogPath"
}

function New-LogRunFolder {
    param (
        [string]$BaseLogDirectory
    )
    
    $RunTimestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $RunFolder = Join-Path $BaseLogDirectory "run-$RunTimestamp"
    
    if (-not (Test-Path $RunFolder)) {
        New-Item -ItemType Directory -Path $RunFolder -Force | Out-Null
    }
    
    $Script:CurrentRunFolder = $RunFolder
    return $RunFolder
}

function Get-CurrentRunFolder {
    return $Script:CurrentRunFolder
}

function Write-LogMessage {
    param (
        [string]$Message,
        [string]$Level = "INFO",
        [ConsoleColor]$Color = "White"
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $FormattedMessage = "[$Timestamp] [$Level] $Message"
    
    # Write to console with color
    Write-Host $FormattedMessage -ForegroundColor $Color
    
    # Write to log file if initialized
    if ($Script:LogInitialized -and $Script:LogPath) {
        $FormattedMessage | Out-File -FilePath $Script:LogPath -Append -Encoding UTF8
    }
}

function Write-LogInfo {
    param ([string]$Message)
    Write-LogMessage -Message $Message -Level "INFO" -Color "White"
}

function Write-LogWarning {
    param ([string]$Message)
    Write-LogMessage -Message $Message -Level "WARN" -Color "Yellow"
}

function Write-LogError {
    param ([string]$Message)
    Write-LogMessage -Message $Message -Level "ERROR" -Color "Red"
}

function Write-LogSuccess {
    param ([string]$Message)
    Write-LogMessage -Message $Message -Level "SUCCESS" -Color "Green"
}

function Write-LogDebug {
    param ([string]$Message)
    if ($env:DEBUG_MODE -eq "true") {
        Write-LogMessage -Message $Message -Level "DEBUG" -Color "Gray"
    }
}

# Legacy function for backward compatibility
function Write-Log {
    param ([string]$Message)
    Write-LogInfo -Message $Message
}

# Export functions
Export-ModuleMember -Function Initialize-Logger, New-LogRunFolder, Get-CurrentRunFolder, Write-LogInfo, Write-LogWarning, Write-LogError, Write-LogSuccess, Write-LogDebug, Write-Log

function Write-ErrorLog {
    param (
        [string]$Message
    )
    
    Write-Log -Message $Message -LogLevel "ERROR"
}

function Write-InfoLog {
    param (
        [string]$Message
    )
    
    Write-Log -Message $Message -LogLevel "INFO"
}

function Write-WarningLog {
    param (
        [string]$Message
    )
    
    Write-Log -Message $Message -LogLevel "WARNING"
}