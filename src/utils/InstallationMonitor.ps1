# Installation Monitor Utility
# Helper script to monitor and troubleshoot stuck installations

param(
    [switch]$ListRunning,
    [switch]$CheckLogs,
    [string]$LogsDirectory = "..\..\logs",
    [int]$TimeoutMinutes = 20
)

function Get-RunningInstallations {
    Write-Host "Checking for running installation processes..." -ForegroundColor Yellow
    
    $Processes = @()
    
    # Check for Winget processes
    $WingetProcesses = Get-Process -Name "winget" -ErrorAction SilentlyContinue
    if ($WingetProcesses) {
        $Processes += $WingetProcesses | Select-Object Name, Id, StartTime, @{Name="Type";Expression={"Winget"}}
    }
    
    # Check for Chocolatey processes
    $ChocoProcesses = Get-Process -Name "chocolatey*" -ErrorAction SilentlyContinue
    if ($ChocoProcesses) {
        $Processes += $ChocoProcesses | Select-Object Name, Id, StartTime, @{Name="Type";Expression={"Chocolatey"}}
    }
    
    # Check for common installer processes
    $InstallerNames = @("msiexec", "setup", "install", "*.exe")
    foreach ($InstallerName in $InstallerNames) {
        $InstallerProcesses = Get-Process -Name $InstallerName -ErrorAction SilentlyContinue
        if ($InstallerProcesses) {
            $Processes += $InstallerProcesses | Select-Object Name, Id, StartTime, @{Name="Type";Expression={"Installer"}}
        }
    }
    
    if ($Processes.Count -gt 0) {
        Write-Host "Found $($Processes.Count) running installation processes:" -ForegroundColor Green
        $Processes | Format-Table -AutoSize
        
        # Check for long-running processes
        $LongRunning = $Processes | Where-Object { $_.StartTime -and ((Get-Date) - $_.StartTime).TotalMinutes -gt $TimeoutMinutes }
        if ($LongRunning) {
            Write-Host "`nLong-running processes (over $TimeoutMinutes minutes):" -ForegroundColor Red
            $LongRunning | Format-Table -AutoSize
        }
    } else {
        Write-Host "No installation processes currently running." -ForegroundColor Green
    }
    
    return $Processes
}

function Get-RecentLogs {
    param([string]$LogsDir)
    
    Write-Host "Checking recent installation logs..." -ForegroundColor Yellow
    
    if (-not (Test-Path $LogsDir)) {
        Write-Host "Logs directory not found: $LogsDir" -ForegroundColor Red
        return
    }
    
    $Today = Get-Date -Format "yyyyMMdd"
    $RecentLogs = Get-ChildItem -Path $LogsDir -Filter "*$Today*.log" | 
                  Where-Object { $_.Name -match "(winget|chocolatey)-.*\.log" } |
                  Sort-Object LastWriteTime -Descending
    
    if ($RecentLogs) {
        Write-Host "Recent installation logs (today):" -ForegroundColor Green
        
        foreach ($Log in $RecentLogs | Select-Object -First 10) {
            $Age = (Get-Date) - $Log.LastWriteTime
            $AgeText = if ($Age.TotalHours -lt 1) { 
                "$([math]::Floor($Age.TotalMinutes))m ago" 
            } else { 
                "$([math]::Floor($Age.TotalHours))h ago" 
            }
            
            Write-Host "  $($Log.Name) - $AgeText" -ForegroundColor White
            
            # Check if log indicates ongoing installation
            $LastLines = Get-Content $Log.FullName -Tail 5 -ErrorAction SilentlyContinue
            $HasExitCode = $LastLines | Where-Object { $_ -match "Exit Code:" }
            
            if (-not $HasExitCode) {
                Write-Host "    ⚠ This installation may still be running" -ForegroundColor Yellow
            } else {
                $ExitCode = $HasExitCode | Select-Object -Last 1
                if ($ExitCode -match "Exit Code: 0") {
                    Write-Host "    ✓ Installation completed successfully" -ForegroundColor Green
                } else {
                    Write-Host "    ✗ Installation failed: $ExitCode" -ForegroundColor Red
                }
            }
        }
        
        Write-Host "`nTo view a specific log:" -ForegroundColor Cyan
        Write-Host "  Get-Content `"$LogsDir\<logfile>`" | more" -ForegroundColor Gray
    } else {
        Write-Host "No recent installation logs found." -ForegroundColor Yellow
    }
}

function Show-TroubleshootingTips {
    Write-Host "`n=== Troubleshooting Tips ===" -ForegroundColor Cyan
    Write-Host "1. Check Task Manager for hung installer processes" -ForegroundColor White
    Write-Host "2. Look for UAC prompts that might be hidden" -ForegroundColor White
    Write-Host "3. Check Windows Event Viewer for application errors" -ForegroundColor White
    Write-Host "4. Verify internet connectivity for download issues" -ForegroundColor White
    Write-Host "5. Check disk space availability" -ForegroundColor White
    Write-Host "6. Temporarily disable antivirus if blocking installations" -ForegroundColor White
    Write-Host "`n=== Common Solutions ===" -ForegroundColor Cyan
    Write-Host "• Kill stuck processes: Stop-Process -Id <ProcessId> -Force" -ForegroundColor Gray
    Write-Host "• Clear package manager cache:" -ForegroundColor Gray
    Write-Host "  - Winget: winget source reset" -ForegroundColor Gray
    Write-Host "  - Chocolatey: choco cache -r" -ForegroundColor Gray
    Write-Host "• Restart package managers:" -ForegroundColor Gray
    Write-Host "  - Restart PowerShell session" -ForegroundColor Gray
    Write-Host "  - Run setup script again" -ForegroundColor Gray
}

# Main execution
Write-Host "=== Installation Monitor ===" -ForegroundColor Cyan
Write-Host "Monitoring Windows Setup Automation installations`n" -ForegroundColor White

if ($ListRunning) {
    Get-RunningInstallations
}

if ($CheckLogs) {
    Get-RecentLogs -LogsDir (Resolve-Path $LogsDirectory).Path
}

if (-not $ListRunning -and -not $CheckLogs) {
    # Default: show both
    Get-RunningInstallations
    Write-Host ""
    Get-RecentLogs -LogsDir (Resolve-Path $LogsDirectory).Path
}

Show-TroubleshootingTips

Write-Host "`nTo run this monitor again:" -ForegroundColor Cyan
Write-Host "  .\InstallationMonitor.ps1 -ListRunning -CheckLogs" -ForegroundColor Gray
