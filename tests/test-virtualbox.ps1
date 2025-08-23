#Requires -RunAsAdministrator

param(
    [string]$VMName = "Windows11-Test",
    [string]$WindowsISO,
    [string]$VMUsername = "Administrator",
    [string]$VMPassword,
    [switch]$CreateVM,
    [switch]$InstallWindows,
    [switch]$InstallGuestAdditions,
    [switch]$CreateSnapshot,
    [switch]$RestoreSnapshot,
    [switch]$RunTest,
    [switch]$Automated,
    [switch]$DeleteVM,
    [switch]$ListVMs,
    [string]$ConfigFile = "virtualbox-test-config.json"
)

# Import modules
# Test should be independent - no module dependencies
# Using built-in PowerShell functions only

# Initialize simple logging
$script:LogFile = $null
$script:TestStartTime = Get-Date

function Initialize-TestLogging {
    param([string]$TestName = "virtualbox-test")
    
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $logDir = Join-Path $PSScriptRoot "logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    
    $script:LogFile = Join-Path $logDir "$TestName-$timestamp.log"
    Write-TestLog "INFO" "Test logging initialized: $script:LogFile"
}

function Write-TestLog {
    param(
        [string]$Level,
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to console with colors
    switch ($Level) {
        "INFO" { Write-Host $logEntry -ForegroundColor White }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
        "WARN" { Write-Host $logEntry -ForegroundColor Yellow }
        "ERROR" { Write-Host $logEntry -ForegroundColor Red }
        default { Write-Host $logEntry }
    }
    
    # Write to log file if initialized
    if ($script:LogFile) {
        $logEntry | Out-File -FilePath $script:LogFile -Append -Encoding UTF8
    }
}

# Initialize logging
Initialize-TestLogging

function Test-VirtualBoxInstalled {
    try {
        # First try to find VBoxManage in PATH
        $vboxManage = Get-Command VBoxManage -ErrorAction SilentlyContinue
        if ($vboxManage) {
            Write-TestLog "INFO" "VirtualBox installation verified: $($vboxManage.Source)"
            return $vboxManage.Source
        }
        
        # If not in PATH, check common installation directories
        $possiblePaths = @(
            "${env:ProgramFiles}\Oracle\VirtualBox\VBoxManage.exe",
            "${env:ProgramFiles(x86)}\Oracle\VirtualBox\VBoxManage.exe",
            "$env:VBOX_INSTALL_PATH\VBoxManage.exe"
        )
        
        foreach ($path in $possiblePaths) {
            if ($path -and (Test-Path $path)) {
                Write-TestLog "INFO" "VirtualBox installation found: $path"
                Write-TestLog "INFO" "Adding VirtualBox directory to session PATH"
                $vboxDir = Split-Path $path -Parent
                $env:PATH = "$vboxDir;$env:PATH"
                return $path
            }
        }
        
        # Try to get installation path from registry
        try {
            $regPath = Get-ItemProperty -Path "HKLM:\SOFTWARE\Oracle\VirtualBox" -Name "InstallDir" -ErrorAction SilentlyContinue
            if ($regPath -and $regPath.InstallDir) {
                $vboxManagePath = Join-Path $regPath.InstallDir "VBoxManage.exe"
                if (Test-Path $vboxManagePath) {
                    Write-TestLog "INFO" "VirtualBox installation found via registry: $vboxManagePath"
                    Write-TestLog "INFO" "Adding VirtualBox directory to session PATH"
                    $env:PATH = "$($regPath.InstallDir);$env:PATH"
                    return $vboxManagePath
                }
            }
        }
        catch {
            # Registry lookup failed, continue
        }
        
        Write-TestLog "ERROR" "VirtualBox is not installed or VBoxManage.exe not found"
        Write-TestLog "INFO" "Please install VirtualBox from: https://www.virtualbox.org/wiki/Downloads"
        Write-TestLog "INFO" "Or add VirtualBox installation directory to your PATH environment variable"
        return $false
    }
    catch {
        Write-TestLog "ERROR" "Failed to verify VirtualBox: $($_.Exception.Message)"
        return $false
    }
}

function Get-TestConfig {
    param([string]$ConfigPath)
    
    $fullConfigPath = Join-Path $PSScriptRoot $ConfigPath
    if (-not (Test-Path $fullConfigPath)) {
        Write-TestLog "ERROR" "Configuration file not found: $fullConfigPath"
        return $null
    }
    
    try {
        $config = Get-Content $fullConfigPath | ConvertFrom-Json
        Write-TestLog "INFO" "Loaded test configuration from: $fullConfigPath"
        return $config
    }
    catch {
        Write-TestLog "ERROR" "Failed to parse configuration: $($_.Exception.Message)"
        return $null
    }
}

function New-TestVM {
    param(
        [string]$Name,
        [PSCustomObject]$Config
    )
    
    Write-TestLog "INFO" "Creating VirtualBox VM: $Name"
    Write-TestLog "INFO" "Configuration: $($Config.memory)MB RAM, $($Config.cpus) CPUs, $($Config.vram)MB VRAM, $($Config.disk_size)MB disk"
    
    try {
        # Check if VM already exists
        $existingVMs = & VBoxManage list vms 2>$null
        if ($existingVMs -match $Name) {
            Write-TestLog "WARN" "VM '$Name' already exists. Use -DeleteVM first to recreate."
            return $false
        }
        
        # Create VM
        & VBoxManage createvm --name $Name --ostype $Config.os_type --register
        if ($LASTEXITCODE -ne 0) { throw "Failed to create VM" }
        
        # Configure VM settings using config values
        & VBoxManage modifyvm $Name --memory $Config.memory --cpus $Config.cpus
        & VBoxManage modifyvm $Name --vram $Config.vram --accelerate3d on --accelerate2dvideo on       
        & VBoxManage modifyvm $Name --nic1 nat
        & VBoxManage modifyvm $Name --clipboard bidirectional
        & VBoxManage modifyvm $Name --draganddrop bidirectional
        
        # Create and attach hard disk
        $vmFolder = "$env:USERPROFILE\VirtualBox VMs\$Name"
        $vdiPath = "$vmFolder\$Name.vdi"
        
        & VBoxManage createhd --filename $vdiPath --size $Config.disk_size --format VDI
        if ($LASTEXITCODE -ne 0) { throw "Failed to create hard disk" }
        
        # Add storage controller
        & VBoxManage storagectl $Name --name "SATA Controller" --add sata --controller IntelAHCI
        & VBoxManage storageattach $Name --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium $vdiPath
        
        # Add DVD drive for Windows installation
        & VBoxManage storagectl $Name --name "IDE Controller" --add ide --controller PIIX4
        & VBoxManage storageattach $Name --storagectl "IDE Controller" --port 1 --device 0 --type dvddrive --medium emptydrive
        
        Write-TestLog "SUCCESS" "VM '$Name' created successfully"
        Write-TestLog "INFO" "VM Path: $vmFolder"
        
        return $true
    }
    catch {
        Write-TestLog "ERROR" "Failed to create VM '$Name': $($_.Exception.Message)"
        return $false
    }
}

function Install-WindowsInVM {
    param(
        [string]$VMName,
        [string]$ISOPath
    )
    
    if (-not $ISOPath -or -not (Test-Path $ISOPath)) {
        Write-TestLog "ERROR" "Windows ISO path required and must exist: $ISOPath"
        Write-TestLog "INFO" "Download Windows 11 ISO from: https://www.microsoft.com/software-download/windows11"
        return $false
    }
    
    Write-TestLog "INFO" "Installing Windows in VM: $VMName"
    Write-TestLog "INFO" "Using ISO: $ISOPath"
    
    try {
        # Attach ISO to DVD drive
        & VBoxManage storageattach $VMName --storagectl "IDE Controller" --port 1 --device 0 --type dvddrive --medium $ISOPath
        
        # Start VM for Windows installation
        Write-TestLog "INFO" "Starting VM for Windows installation..."
        Write-TestLog "INFO" "Please complete Windows installation manually in the VirtualBox GUI"
        Write-TestLog "INFO" "After installation, run: .\test-virtualbox.ps1 -VMName $VMName -CreateSnapshot"
        
        & VBoxManage startvm $VMName
        
        return $true
    }
    catch {
        Write-TestLog "ERROR" "Failed to start Windows installation: $($_.Exception.Message)"
        return $false
    }
}

function Install-GuestAdditions {
    param([string]$VMName)
    
    Write-TestLog "INFO" "Installing VirtualBox Guest Additions in VM: $VMName"
    
    try {
        # Get VirtualBox installation path
        $vboxPath = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Oracle\VirtualBox" -Name "InstallDir" -ErrorAction SilentlyContinue).InstallDir
        if (-not $vboxPath) {
            $vboxPath = "${env:ProgramFiles}\Oracle\VirtualBox\"
        }
        
        $guestAdditionsISO = Join-Path $vboxPath "VBoxGuestAdditions.iso"
        
        if (-not (Test-Path $guestAdditionsISO)) {
            Write-TestLog "ERROR" "Guest Additions ISO not found at: $guestAdditionsISO"
            return $false
        }
        
        # Insert Guest Additions CD
        & VBoxManage controlvm $VMName dvd attach $guestAdditionsISO
        
        Write-TestLog "INFO" "Guest Additions ISO attached. Please install manually:"
        Write-TestLog "INFO" "1. In VM, go to D:\ (or CD drive)"
        Write-TestLog "INFO" "2. Run VBoxWindowsAdditions.exe as Administrator"
        Write-TestLog "INFO" "3. Reboot VM when installation completes"
        Write-TestLog "INFO" "4. Create snapshot after Guest Additions are installed"
        
        return $true
    }
    catch {
        Write-TestLog "ERROR" "Failed to attach Guest Additions: $($_.Exception.Message)"
        return $false
    }
}

function Copy-SetupScriptToVM {
    param(
        [string]$VMName,
        [string]$Username = "Administrator",
        [string]$Password = "YourVMPassword"
    )
    
    Write-TestLog "INFO" "Copying setup script to VM: $VMName"
    
    try {
        $setupScript = Join-Path $PSScriptRoot "..\src\scripts\setup.ps1"
        if (-not (Test-Path $setupScript)) {
            Write-TestLog "ERROR" "Setup script not found: $setupScript"
            return $false
        }
        
        # Create temp directory in VM
        & VBoxManage guestcontrol $VMName run --exe "cmd.exe" --username $Username --password $Password --wait-stdout --wait-stderr -- "/c" "mkdir C:\temp"
        
        # Copy setup script to VM
        & VBoxManage guestcontrol $VMName copyto $setupScript --target-directory "C:\temp\" --username $Username --password $Password
        if ($LASTEXITCODE -ne 0) { throw "Failed to copy setup script" }
        
        # Copy entire src directory for modules
        $srcPath = Join-Path $PSScriptRoot "..\src"
        
        & VBoxManage guestcontrol $VMName copyto $srcPath --target-directory "C:\temp\" --recursive --username $Username --password $Password
        if ($LASTEXITCODE -ne 0) { throw "Failed to copy setup files" }
        
        # Copy configs directory
        $configsPath = Join-Path $PSScriptRoot "..\configs"
        
        & VBoxManage guestcontrol $VMName copyto $configsPath --target-directory "C:\temp\" --recursive --username $Username --password $Password
        if ($LASTEXITCODE -ne 0) { throw "Failed to copy config files" }
        
        Write-TestLog "SUCCESS" "Setup files copied to C:\temp\ in VM"
        return $true
    }
    catch {
        Write-TestLog "ERROR" "Failed to copy files to VM: $($_.Exception.Message)"
        return $false
    }
}

function Start-AutomatedIdempotencyTest {
    param(
        [string]$VMName,
        [string]$Username = "Administrator", 
        [string]$Password
    )
    
    if (-not $Password) {
        Write-TestLog "ERROR" "VM password required for automated testing. Use -VMPassword parameter."
        return $false
    }
    
    Write-TestLog "INFO" "=== Starting AUTOMATED Idempotency Test ==="
    Write-TestLog "INFO" "VM: $VMName"
    Write-TestLog "INFO" "This will run completely automated!"
    Write-TestLog "INFO" "============================================="
    
    try {
        # Start VM
        Write-TestLog "INFO" "Starting VM: $VMName"
        & VBoxManage startvm $VMName --type headless  # Headless for automation
        
        # Wait for VM to boot
        Write-TestLog "INFO" "Waiting for VM to boot (120 seconds)..."
        Start-Sleep -Seconds 120
        
        # Wait for VM to be ready for guest control
        Write-TestLog "INFO" "Waiting for Guest Additions to be ready..."
        $retries = 0
        do {
            Start-Sleep -Seconds 10
            $guestProps = & VBoxManage guestproperty enumerate $VMName 2>$null
            $guestReady = $guestProps -match "GuestAdditionsRunLevel"
            $retries++
        } while (-not $guestReady -and $retries -lt 18) # 3 minutes max
        
        if (-not $guestReady) {
            throw "Guest Additions not ready after 3 minutes"
        }
        
        # Copy setup files to VM
        Write-TestLog "INFO" "Copying setup files to VM..."
        $copyResult = Copy-SetupScriptToVM -VMName $VMName -Username $Username -Password $Password
        if (-not $copyResult) { throw "Failed to copy setup files" }
        
        # Set execution policy
        Write-TestLog "INFO" "Setting PowerShell execution policy in VM..."
        & VBoxManage guestcontrol $VMName run --exe "powershell.exe" --username $Username --password $Password --wait-stdout --wait-stderr -- "-Command" "Set-ExecutionPolicy RemoteSigned -Force"
        
        # FIRST RUN - Execute setup script
        Write-TestLog "INFO" "=== FIRST RUN: Executing setup script ==="
        $firstRunStart = Get-Date
        
        & VBoxManage guestcontrol $VMName run --exe "powershell.exe" --username $Username --password $Password --wait-stdout --wait-stderr -- "-File" "C:\temp\src\scripts\setup.ps1"
        
        $firstRunDuration = (Get-Date) - $firstRunStart
        Write-TestLog "INFO" "First run completed in: $($firstRunDuration.TotalMinutes.ToString('F1')) minutes"
        
        if ($LASTEXITCODE -ne 0) {
            Write-TestLog "WARN" "First run had non-zero exit code: $LASTEXITCODE"
        }
        
        # Wait a bit between runs
        Write-TestLog "INFO" "Waiting 30 seconds before second run..."
        Start-Sleep -Seconds 30
        
        # SECOND RUN - Execute setup script again (idempotency test)
        Write-TestLog "INFO" "=== SECOND RUN: Testing idempotency ==="
        $secondRunStart = Get-Date
        
        & VBoxManage guestcontrol $VMName run --exe "powershell.exe" --username $Username --password $Password --wait-stdout --wait-stderr -- "-File" "C:\temp\src\scripts\setup.ps1"
        
        $secondRunDuration = (Get-Date) - $secondRunStart
        Write-TestLog "INFO" "Second run completed in: $($secondRunDuration.TotalMinutes.ToString('F1')) minutes"
        
        if ($LASTEXITCODE -ne 0) {
            Write-TestLog "WARN" "Second run had non-zero exit code: $LASTEXITCODE"
        }
        
        # Copy logs back from VM
        Write-TestLog "INFO" "Copying logs from VM..."
        $logFolder = Join-Path (Get-CurrentRunFolder) "vm-logs"
        New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
        
        & VBoxManage guestcontrol $VMName copyfrom "C:\temp\logs\" --target-directory $logFolder --recursive --username $Username --password $Password 2>$null
        
        # Results summary
        Write-TestLog "SUCCESS" "=== AUTOMATED IDEMPOTENCY TEST RESULTS ==="
        Write-TestLog "INFO" "First run duration: $($firstRunDuration.TotalMinutes.ToString('F1')) minutes"
        Write-TestLog "INFO" "Second run duration: $($secondRunDuration.TotalMinutes.ToString('F1')) minutes"
        
        if ($secondRunDuration.TotalMinutes -lt ($firstRunDuration.TotalMinutes * 0.3)) {
            Write-TestLog "SUCCESS" "✅ IDEMPOTENCY PASSED: Second run was significantly faster ($($secondRunDuration.TotalMinutes.ToString('F1'))min vs $($firstRunDuration.TotalMinutes.ToString('F1'))min)"
        } else {
            Write-TestLog "WARN" "⚠️ IDEMPOTENCY CONCERN: Second run took $($secondRunDuration.TotalMinutes.ToString('F1')) minutes (should be much faster)"
        }
        
        Write-TestLog "INFO" "VM logs copied to: $logFolder"
        Write-TestLog "SUCCESS" "Automated idempotency test completed!"
        
        return $true
    }
    catch {
        Write-TestLog "ERROR" "Automated test failed: $($_.Exception.Message)"
        return $false
    }
    finally {
        # Power off VM
        Write-TestLog "INFO" "Powering off VM..."
        & VBoxManage controlvm $VMName acpipowerbutton 2>$null
        Start-Sleep -Seconds 30
        & VBoxManage controlvm $VMName poweroff 2>$null
    }
}

function New-VMSnapshot {
    param(
        [string]$VMName,
        [string]$SnapshotName = "clean-installed"
    )
    
    Write-TestLog "INFO" "Creating snapshot '$SnapshotName' for VM '$VMName'"
    
    try {
        # Shutdown VM if running
        $vmState = & VBoxManage showvminfo $VMName --machinereadable | Select-String "VMState="
        if ($vmState -match 'running') {
            Write-TestLog "INFO" "Shutting down VM before snapshot..."
            & VBoxManage controlvm $VMName acpipowerbutton
            Start-Sleep -Seconds 30
        }
        
        # Create snapshot
        & VBoxManage snapshot $VMName take $SnapshotName --description "Clean Windows installation - ready for idempotency testing"
        if ($LASTEXITCODE -ne 0) { throw "Failed to create snapshot" }
        
        Write-TestLog "SUCCESS" "Snapshot '$SnapshotName' created successfully"
        return $true
    }
    catch {
        Write-TestLog "ERROR" "Failed to create snapshot: $($_.Exception.Message)"
        return $false
    }
}

function Restore-VMSnapshot {
    param(
        [string]$VMName,
        [string]$SnapshotName = "clean-installed"
    )
    
    Write-TestLog "INFO" "Restoring VM '$VMName' to snapshot '$SnapshotName'"
    
    try {
        # Power off VM if running
        & VBoxManage controlvm $VMName poweroff 2>$null
        Start-Sleep -Seconds 5
        
        # Restore snapshot
        & VBoxManage snapshot $VMName restore $SnapshotName
        if ($LASTEXITCODE -ne 0) { throw "Failed to restore snapshot" }
        
        Write-TestLog "SUCCESS" "VM restored to snapshot '$SnapshotName'"
        return $true
    }
    catch {
        Write-TestLog "ERROR" "Failed to restore snapshot: $($_.Exception.Message)"
        return $false
    }
}

function Start-ManualIdempotencyTest {
    param([string]$VMName)
    
    Write-TestLog "INFO" "=== Starting MANUAL Idempotency Test ==="
    Write-TestLog "INFO" "VM: $VMName"
    Write-TestLog "INFO" "Test: Run setup script twice to verify idempotency"
    Write-TestLog "INFO" "Expected Duration: ~50 minutes"
    Write-TestLog "INFO" "======================================"
    
    try {
        # Start VM
        Write-TestLog "INFO" "Starting VM: $VMName"
        & VBoxManage startvm $VMName
        
        # Wait for VM to boot
        Write-TestLog "INFO" "Waiting for VM to boot (90 seconds)..."
        Start-Sleep -Seconds 90
        
        # Instructions for manual testing
        Write-TestLog "INFO" @"

=== IDEMPOTENCY TEST INSTRUCTIONS ===

1. VM '$VMName' is now running
2. Log into Windows
3. Copy your setup script to the VM
4. Run PowerShell as Administrator
5. Execute: Set-ExecutionPolicy RemoteSigned -Force

6. FIRST RUN - Execute: C:\temp\src\scripts\setup.ps1
   - Let it complete fully
   - Note any installations and time taken

7. SECOND RUN - Execute: C:\temp\src\scripts\setup.ps1
   - Should detect existing installations
   - Should skip already installed software
   - Should complete much faster
   - Should not break anything

8. Verify both runs completed successfully
9. Check logs show "already installed" messages on second run

Press Enter when idempotency testing is complete...
"@
        
        Read-Host
        
        # Power off VM
        Write-TestLog "INFO" "Powering off VM..."
        & VBoxManage controlvm $VMName acpipowerbutton
        Start-Sleep -Seconds 30
        & VBoxManage controlvm $VMName poweroff 2>$null
        
        Write-TestLog "SUCCESS" "Manual idempotency test completed"
        return $true
    }
    catch {
        Write-TestLog "ERROR" "Manual test failed: $($_.Exception.Message)"
        return $false
    }
}

function Remove-TestVM {
    param([string]$VMName)
    
    Write-TestLog "INFO" "Deleting VM: $VMName"
    
    try {
        # Power off if running
        & VBoxManage controlvm $VMName poweroff 2>$null
        Start-Sleep -Seconds 5
        
        # Delete VM and all files
        & VBoxManage unregistervm $VMName --delete
        if ($LASTEXITCODE -ne 0) { throw "Failed to delete VM" }
        
        Write-TestLog "SUCCESS" "VM '$VMName' deleted successfully"
        return $true
    }
    catch {
        Write-TestLog "ERROR" "Failed to delete VM: $($_.Exception.Message)"
        return $false
    }
}

function Show-VMs {
    Write-TestLog "INFO" "Available VirtualBox VMs:"
    & VBoxManage list vms
    
    Write-TestLog "INFO" "`nRunning VMs:"
    & VBoxManage list runningvms
}

# Main execution
try {
    Write-TestLog "INFO" "VirtualBox Idempotency Testing for Windows Setup Automation"
    
    # Verify VirtualBox installation
    if (-not (Test-VirtualBoxInstalled)) {
        exit 1
    }
    
    # Load configuration
    $config = Get-TestConfig -ConfigPath $ConfigFile
    if (-not $config) {
        exit 1
    }
    
    # Handle operations
    if ($ListVMs) {
        Show-VMs
        exit 0
    }
    
    if ($DeleteVM) {
        Remove-TestVM -VMName $VMName
        exit 0
    }
    
    if ($CreateVM) {
        $vmConfig = $config.test_vms.$VMName
        if (-not $vmConfig) {
            Write-TestLog "ERROR" "VM configuration not found: $VMName"
            Write-TestLog "INFO" "Available VMs: $($config.test_vms.PSObject.Properties.Name -join ', ')"
            exit 1
        }
        
        $result = New-TestVM -Name $VMName -Config $vmConfig
        if (-not $result) { exit 1 }
        
        Write-TestLog "INFO" "Next steps:"
        Write-TestLog "INFO" "1. Install Windows: .\test-virtualbox.ps1 -VMName $VMName -InstallWindows -WindowsISO 'path\to\windows.iso'"
        Write-TestLog "INFO" "2. Install Guest Additions: .\test-virtualbox.ps1 -VMName $VMName -InstallGuestAdditions"
        Write-TestLog "INFO" "3. Create snapshot: .\test-virtualbox.ps1 -VMName $VMName -CreateSnapshot"
        Write-TestLog "INFO" "4. Run test: .\test-virtualbox.ps1 -VMName $VMName -RunTest [-Automated -VMPassword 'password']"
        exit 0
    }
    
    if ($InstallWindows) {
        Install-WindowsInVM -VMName $VMName -ISOPath $WindowsISO
        exit 0
    }
    
    if ($InstallGuestAdditions) {
        Install-GuestAdditions -VMName $VMName
        exit 0
    }
    
    if ($CreateSnapshot) {
        New-VMSnapshot -VMName $VMName
        exit 0
    }
    
    if ($RestoreSnapshot) {
        Restore-VMSnapshot -VMName $VMName
        exit 0
    }
    
    if ($RunTest) {
        if ($Automated) {
            Start-AutomatedIdempotencyTest -VMName $VMName -Username $VMUsername -Password $VMPassword
        } else {
            Start-ManualIdempotencyTest -VMName $VMName
        }
        exit 0
    }
    
    # Default: Show help
    Write-TestLog "INFO" @"
VirtualBox Idempotency Testing Usage:

=== SETUP (One-time) ===
1. Create VM:
   .\test-virtualbox.ps1 -CreateVM -VMName Windows11-Test

2. Install Windows:
   .\test-virtualbox.ps1 -InstallWindows -VMName Windows11-Test -WindowsISO "C:\path\to\windows11.iso"

3. Install Guest Additions (for automation):
   .\test-virtualbox.ps1 -InstallGuestAdditions -VMName Windows11-Test

4. Create snapshot:
   .\test-virtualbox.ps1 -CreateSnapshot -VMName Windows11-Test

=== TESTING ===
5a. Manual idempotency test:
    .\test-virtualbox.ps1 -RunTest -VMName Windows11-Test

5b. Automated idempotency test:
    .\test-virtualbox.ps1 -RunTest -VMName Windows11-Test -Automated -VMUsername "Administrator" -VMPassword "YourPassword"

6. Reset for next test:
   .\test-virtualbox.ps1 -RestoreSnapshot -VMName Windows11-Test

=== MANAGEMENT ===
List VMs: .\test-virtualbox.ps1 -ListVMs
Delete VM: .\test-virtualbox.ps1 -DeleteVM -VMName Windows11-Test

Available VMs: $($config.test_vms.PSObject.Properties.Name -join ', ')
"@
}
catch {
    Write-TestLog "ERROR" "Script execution failed: $($_.Exception.Message)"
    exit 1
}
