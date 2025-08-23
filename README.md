# Windows Development Machine Setup Automation

A comprehensive, self-contained PowerShell script to automate the setup of a Windows development environment. This script is designed to be **resilient** and **idempotent** - it can be run multiple times safely and will only install what's missing.

## Features

✅ **Self-contained** - No Git required to start  
✅ **Idempotent** - Safe to run multiple times  
✅ **Multiple package managers** - Winget, Chocolatey, custom installers  
✅ **Organized logging** - Timestamped run folders with detailed logs  
✅ **Smart exit code handling** - Handles various installer behaviors  
✅ **Visual Studio workloads** - Configurable via external .vsconfig file  
✅ **Java version management** - Via Jabba for multiple JDK versions  
✅ **Windows Defender exclusions** - For development folders  
✅ **Automatic folder creation** - Repos and other dev directories  
✅ **Reboot detection** - Handles software requiring system restart  
✅ **Microsoft Store app support** - Installs Store apps via winget  

## Quick Start

### Option 1: Bootstrap Script (Recommended)
Run this single command as Administrator to download and execute the setup:

```powershell
# Download bootstrap script and run
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/tinchev/WinDevSetup/main/bootstrap.ps1" -OutFile "$env:TEMP\bootstrap.ps1" -UseBasicParsing; & "$env:TEMP\bootstrap.ps1"
```

### Option 2: Manual Download
1. Download/clone this repository
2. Open PowerShell as Administrator
3. Navigate to the project directory
4. Run: `.\src\scripts\setup.ps1`

## What Gets Installed

### Productivity Tools
- Microsoft Office (includes OneNote)
- Figma

### Development Tools
- Git
- Visual Studio Code  
- Visual Studio Professional (with comprehensive development workloads)
- Docker Desktop
- Android Studio
- Node.js
- Service Fabric SDK & Runtime
- SQL Server Developer Edition
- Jabba (Java Version Manager)

### .NET Runtimes & SDKs
- .NET Framework 4.6.1, 4.8
- .NET Core 2.2, 3.1
- .NET 6, 8

### Java Development Kits (via Jabba)
- Java 8, 11, 17, 21 (managed by Jabba)

### Node.js Runtimes (via NVM)
- Node.js 14.6.1, 20.1 (managed by NVM)

### Virtualization Tools
- Oracle VirtualBox (for testing and development VMs)

### Networking Tools
- Azure VPN Client (Microsoft Store)
- OpenVPN Connect

### System Configuration
- Creates `C:\Repos` folder
- Adds Windows Defender exclusions for development folders
- Enables Windows features (WSL, Containers, etc.)

## Configuration

The software list and settings are defined in:

- **`configs/software-list.json`** - Main software configuration
- **`configs/visual-studio-workloads.vsconfig`** - Visual Studio workloads and components  
- **`configs/registry-settings.json`** - Registry modifications
- **`configs/windows-features.json`** - Windows features to enable

You can customize:
- Software packages to install
- Package manager preferences (Winget vs Chocolatey)  
- Visual Studio workloads and components
- Java versions to install via Jabba
- Folders to create
- Windows Defender exclusions
- Windows features to enable

## Logging

All installation activities are logged with organized structure:

```
logs/
└── run-YYYYMMDD-HHMMSS/
    ├── setup-main.log                    # Main installation log
    ├── installation-summary.txt          # Summary of results
    ├── winget-PackageName-timestamp.log  # Individual package logs
    ├── chocolatey-PackageName-timestamp.log
    └── vs-installer-timestamp.log        # Visual Studio workload logs
```

### Log Features:
- **Timestamped runs** - Each execution gets its own folder
- **Detailed command output** - Captures verbose installer output
- **Progress tracking** - Real-time installation progress
- **Error diagnostics** - Comprehensive error reporting
- **Exit code analysis** - Smart handling of different installer behaviors


## Requirements

- Windows 10/11
- PowerShell 5.1 or later
- Administrator privileges
- Internet connection

## Safety Features

- **Idempotency**: Checks if software is already installed before attempting installation
- **Smart exit code handling**: Recognizes "already installed" and other non-error conditions
- **Error handling**: Graceful failure with detailed logging
- **Rollback safe**: Won't break existing installations
- **Multiple attempts**: Falls back between Winget and Chocolatey automatically
- **Installation validation**: Verifies installations completed successfully
- **Reboot detection**: Identifies when system restart is required
- **Windows Store integration**: Handles Microsoft Store apps via winget
- **Background job logging**: Captures installer output without blocking UI

## Customization for Your Organization

1. **Update software list** in `configs/software-list.json`
2. **Modify Visual Studio workloads** in `configs/visual-studio-workloads.vsconfig`
3. **Configure Java versions** by updating Jabba installation entries
4. **Adjust Windows Defender exclusions** for your specific paths
5. **Add custom installation logic** in `src/modules/CustomInstaller.psm1`
6. **Update registry settings** in `configs/registry-settings.json`

## Advanced Features

### Visual Studio Workloads
The script uses a comprehensive .vsconfig file to install:
- .NET Desktop Development (WinForms, WPF)
- ASP.NET and Web Development
- Azure Development Tools  
- Data Storage and Processing
- Cross-platform .NET Development
- Node.js Development
- Git Integration and IntelliCode

### Java Version Management
Uses Jabba for flexible Java version management:
- Install multiple JDK versions simultaneously
- Switch between Java versions easily
- Automatic Java 21 as default version

### Smart Package Management
- **Winget-first approach** with Chocolatey fallback
- **Exit code intelligence** - recognizes when packages are already installed
- **Microsoft Store integration** - installs Store apps seamlessly
- **Custom installer support** - handles special installation requirements

## Troubleshooting

### Script Execution Policy
**Problem**: The setup script fails to run due to script execution policy restrictions.  
**Solution**: Open PowerShell as an administrator and run the following command to allow script execution:
```powershell
Set-ExecutionPolicy RemoteSigned
```
After changing the policy, try running the setup script again.

### Common Issues
- **Run as Administrator**: Most installations require elevated privileges
- **Check organized logs**: Each run creates a timestamped folder in `logs/`
- **Review individual package logs**: Each installer has detailed output logs
- **Internet connectivity**: Required for downloading packages
- **Windows version**: Some features require Windows 10/11
- **Antivirus interference**: Check Windows Defender exclusions
- **Visual Studio installation**: Uses two-step process (base install + workloads)
- **Already installed packages**: Script recognizes and skips existing software
- **Reboot requirements**: Some packages (SQL Server, VS) may require restart

## Contributing

1. Test changes on a clean Windows VM
2. Update configuration files as needed
3. Add appropriate logging
4. Test idempotency (run script multiple times)
5. Update documentation

## License

This project is licensed under the MIT License - see the LICENSE file for details.