# VirtualBox Testing Framework

This framework provides automated testing for the Windows setup automation tool using VirtualBox VMs.

## Overview

The testing framework focuses on **idempotency testing** - verifying that the setup script can be run multiple times without breaking anything and that it correctly detects already-installed software.

## Quick Start

### Prerequisites
1. **VirtualBox installed**: `winget install Oracle.VirtualBox`
2. **Windows 11 ISO downloaded** from Microsoft
3. **Administrator privileges** for PowerShell

### Setup Process (One-time)

1. **Create VM**:
   ```powershell
   .\test-virtualbox.ps1 -CreateVM -VMName Windows11-Test
   ```

2. **Install Windows** (manual step):
   ```powershell
   .\test-virtualbox.ps1 -InstallWindows -VMName Windows11-Test -WindowsISO "C:\path\to\windows11.iso"
   ```
   - Complete Windows installation in VirtualBox GUI
   - Create a user account (remember username/password for automation)

3. **Install Guest Additions** (for automation features):
   ```powershell
   .\test-virtualbox.ps1 -InstallGuestAdditions -VMName Windows11-Test
   ```
   - Install Guest Additions in the VM manually
   - Reboot VM when complete

4. **Create clean snapshot**:
   ```powershell
   .\test-virtualbox.ps1 -CreateSnapshot -VMName Windows11-Test
   ```

### Running Tests

#### Manual Testing
```powershell
.\test-virtualbox.ps1 -RunTest -VMName Windows11-Test
```
- Starts VM and provides instructions
- You manually run the setup script twice
- Good for debugging and observation

#### Automated Testing
```powershell
.\test-virtualbox.ps1 -RunTest -VMName Windows11-Test -Automated -VMUsername "Administrator" -VMPassword "YourPassword"
```
- Fully automated execution
- Measures precise timing
- Copies logs back from VM
- Provides pass/fail analysis

### Reset Between Tests
```powershell
.\test-virtualbox.ps1 -RestoreSnapshot -VMName Windows11-Test
```

## File Structure

```
tests/
├── virtualbox-test-config.json    # VM configurations
├── test-virtualbox.ps1            # Main test script
└── README.md                      # This file
```

## Configuration

The `virtualbox-test-config.json` file defines:

- **VM Specifications**: Memory, CPU, VRAM, disk size
- **Test Scenarios**: Currently focuses on idempotency testing

### VM Configurations

- **Windows11-Test**: 4GB RAM, 2 CPUs, 128MB VRAM (recommended)
- **Windows10-Test**: 2GB RAM, 1 CPU, 64MB VRAM (minimal)

## Test Results

### Successful Idempotency Test
- First run: ~30-45 minutes (fresh installations)
- Second run: ~5-10 minutes (should skip existing software)
- **Pass Criteria**: Second run < 30% of first run time

### What Gets Tested
- Software installation detection
- Package manager fallback (winget ↔ chocolatey)
- Custom installer logic
- Error handling and recovery
- Log file organization

## Troubleshooting

### VirtualBox Not Found
```
Error: VirtualBox is not installed or VBoxManage is not in PATH
```
**Solution**: Install VirtualBox: `winget install Oracle.VirtualBox`

### Guest Additions Required
```
Error: Guest Additions not ready after 3 minutes
```
**Solution**: Install Guest Additions manually in the VM first

### Authentication Issues
```
Error: Failed to copy setup files
```
**Solution**: Verify VM username/password are correct

## Commands Reference

### VM Management
```powershell
# List all VMs
.\test-virtualbox.ps1 -ListVMs

# Delete VM completely
.\test-virtualbox.ps1 -DeleteVM -VMName Windows11-Test

# Create new VM
.\test-virtualbox.ps1 -CreateVM -VMName Windows11-Test
```

### Snapshots
```powershell
# Create snapshot
.\test-virtualbox.ps1 -CreateSnapshot -VMName Windows11-Test

# Restore snapshot
.\test-virtualbox.ps1 -RestoreSnapshot -VMName Windows11-Test
```

### Testing
```powershell
# Manual test (interactive)
.\test-virtualbox.ps1 -RunTest -VMName Windows11-Test

# Automated test (unattended)
.\test-virtualbox.ps1 -RunTest -VMName Windows11-Test -Automated -VMUsername "User" -VMPassword "Pass"
```

## Benefits

✅ **Reliable Testing**: Clean VM state for each test
✅ **Automated Execution**: Unattended testing with precise metrics  
✅ **Idempotency Validation**: Ensures script safety for multiple runs
✅ **Log Collection**: Automatic retrieval of detailed logs
✅ **Reproducible**: Same test conditions every time

## Security Note

The framework requires VM passwords for automation. In production environments, consider using:
- Secure credential storage
- Environment variables
- PowerShell SecureString parameters

For testing purposes, the current string-based approach is acceptable.
