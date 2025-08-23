# Installation Guide for Windows Setup Automation Tool

## Introduction
This guide provides step-by-step instructions for installing and setting up the Windows Setup Automation Tool. This tool automates the process of configuring a Windows environment, including software installation, system configuration, and registry management.

## Prerequisites
Before you begin, ensure that you have the following:
- Windows operating system (Windows 10 or later recommended)
- PowerShell version 5.1 or later
- Administrative privileges to run the scripts

## Installation Steps

### Step 1: Clone the Repository
Clone the repository to your local machine using the following command:
```
git clone https://github.com/yourusername/windows-setup-automation.git
```

### Step 2: Navigate to the Project Directory
Change to the project directory:
```
cd windows-setup-automation
```

### Step 3: Run the Setup Script
Execute the main setup script to initiate the installation process:
```
powershell -ExecutionPolicy Bypass -File src/scripts/setup.ps1
```

### Step 4: Follow the Prompts
The setup script will guide you through the installation process. Follow the prompts to configure your preferences, including software installations and system settings.

### Step 5: Verify Installation
After the setup is complete, verify that the software and configurations have been applied correctly. You can check the logs in the `logs` directory for any errors or messages.

## Additional Configuration
For further customization, you can modify the configuration files located in the `configs` directory:
- `software-list.json`: Update the list of software to be installed.
- `registry-settings.json`: Adjust registry settings as needed.
- `windows-features.json`: Enable or disable specific Windows features.

## Conclusion
You have successfully installed and configured the Windows Setup Automation Tool. For more information on usage and advanced configurations, refer to the `configuration-reference.md` file in the `docs` directory.