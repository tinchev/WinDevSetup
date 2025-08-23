# Bootstrap Script for Windows Development Machine Setup
# This script can be run without any prerequisites (including Git)
# It will download or ensure the setup files are available and then run the main setup

#Requires -RunAsAdministrator

param(
    [string]$GitHubRepo = "tinchev/WinDevSetup",  # Update with your actual repo
    [string]$Branch = "main",
    [switch]$LocalFiles,
    [switch]$SkipDownload
)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Windows Development Machine Setup Bootstrap" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Download-SetupFiles {
    param(
        [string]$Repo,
        [string]$Branch,
        [string]$DestinationPath
    )
    
    Write-Host "Downloading setup files from GitHub..." -ForegroundColor Yellow
    
    try {
        # Create destination directory
        if (-not (Test-Path $DestinationPath)) {
            New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
        }
        
        # Download the repository as ZIP
        $ZipUrl = "https://github.com/$Repo/archive/$Branch.zip"
        $ZipPath = Join-Path $env:TEMP "setup-files.zip"
        
        Write-Host "Downloading from: $ZipUrl"
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath -UseBasicParsing
        
        # Extract ZIP file
        Write-Host "Extracting files..."
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $env:TEMP)
        
        # Move files to destination
        $ExtractedPath = Join-Path $env:TEMP "WinDevSetup-$Branch"
        if (Test-Path $ExtractedPath) {
            Get-ChildItem $ExtractedPath | Copy-Item -Destination $DestinationPath -Recurse -Force
            Write-Host "Setup files downloaded successfully" -ForegroundColor Green
            
            # Clean up
            Remove-Item $ZipPath -Force -ErrorAction SilentlyContinue
            Remove-Item $ExtractedPath -Recurse -Force -ErrorAction SilentlyContinue
            
            return $true
        } else {
            Write-Host "Failed to find extracted files" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "Failed to download setup files: $_" -ForegroundColor Red
        return $false
    }
}

function Start-Bootstrap {
    # Check if running as administrator
    if (-not (Test-Administrator)) {
        Write-Host "This script must be run as Administrator" -ForegroundColor Red
        Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
        Read-Host "Press Enter to exit"
        exit 1
    }
    
    # Determine setup path
    $SetupPath = $PSScriptRoot
    if (-not $SetupPath) {
        $SetupPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
    }
    
    # Check if we need to download files
    $MainSetupScript = Join-Path $SetupPath "src\scripts\setup.ps1"
    
    if (-not (Test-Path $MainSetupScript) -and -not $SkipDownload) {
        if ($LocalFiles) {
            Write-Host "Local files requested but setup.ps1 not found at: $MainSetupScript" -ForegroundColor Red
            Write-Host "Please ensure all setup files are present or remove -LocalFiles parameter" -ForegroundColor Yellow
            exit 1
        }
        
        Write-Host "Setup files not found locally. Downloading..." -ForegroundColor Yellow
        if (-not (Download-SetupFiles -Repo $GitHubRepo -Branch $Branch -DestinationPath $SetupPath)) {
            Write-Host "Failed to download setup files. Exiting." -ForegroundColor Red
            exit 1
        }
    }
    
    # Verify main setup script exists
    if (-not (Test-Path $MainSetupScript)) {
        Write-Host "Main setup script not found at: $MainSetupScript" -ForegroundColor Red
        Write-Host "Please check your file paths or re-download the setup files" -ForegroundColor Yellow
        exit 1
    }
    
    # Run the main setup script
    Write-Host "`nStarting main setup process..." -ForegroundColor Green
    Write-Host "Setup script: $MainSetupScript" -ForegroundColor Gray
    
    try {
        & $MainSetupScript @PSBoundParameters
        Write-Host "`nBootstrap completed successfully!" -ForegroundColor Green
    } catch {
        Write-Host "Setup failed: $_" -ForegroundColor Red
        Write-Host "Check the log files for more details" -ForegroundColor Yellow
        exit 1
    }
}

# Show usage if help is requested
if ($args -contains "-?" -or $args -contains "-h" -or $args -contains "-help") {
    Write-Host @"
Windows Development Machine Setup Bootstrap

USAGE:
    .\bootstrap.ps1 [parameters]

PARAMETERS:
    -GitHubRepo     GitHub repository in format 'owner/repo'
    -Branch         Branch to download (default: main)
    -LocalFiles     Use local files instead of downloading
    -SkipDownload   Skip file download and use existing files
    -SkipChocolatey Skip Chocolatey installations
    -SkipWinget     Skip Winget installations      

EXAMPLES:
    # Download and run setup
    .\bootstrap.ps1

    # Use local files
    .\bootstrap.ps1 -LocalFiles

    # Use custom repository
    .\bootstrap.ps1 -GitHubRepo "myorg/my-setup-repo"

    # Skip certain installation types
    .\bootstrap.ps1 -SkipChocolatey

"@
    exit 0
}

# Start the bootstrap process
Start-Bootstrap
