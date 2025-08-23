# Configuration Reference for Windows Setup Automation Tool

## Overview
This document provides detailed information about the configuration files used in the Windows Setup Automation Tool. Each configuration file plays a crucial role in defining the behavior and settings of the automation process.

## Configuration Files

### 1. software-list.json
This JSON file contains a list of software to be installed during the setup process. Each entry should include the software name and the corresponding installation command.

**Example Structure:**
```json
{
  "software": [
    {
      "name": "SoftwareName1",
      "installCommand": "command_to_install_software1"
    },
    {
      "name": "SoftwareName2",
      "installCommand": "command_to_install_software2"
    }
  ]
}
```

### 2. registry-settings.json
This JSON file defines the registry settings that will be configured during the setup. Each entry should specify the registry path, name, and value.

**Example Structure:**
```json
{
  "registrySettings": [
    {
      "path": "HKLM\\Software\\Example",
      "name": "SettingName",
      "value": "SettingValue"
    },
    {
      "path": "HKCU\\Software\\Example",
      "name": "AnotherSettingName",
      "value": "AnotherSettingValue"
    }
  ]
}
```

### 3. windows-features.json
This JSON file specifies which Windows features should be enabled or disabled. Each entry should indicate the feature name and its desired state.

**Example Structure:**
```json
{
  "features": [
    {
      "name": "FeatureName1",
      "enabled": true
    },
    {
      "name": "FeatureName2",
      "enabled": false
    }
  ]
}
```

## Conclusion
Ensure that the configuration files are correctly formatted and located in the `configs` directory. The setup process will read these files to determine the software to install, registry settings to apply, and Windows features to enable or disable. For any issues or questions regarding the configuration, refer to the `troubleshooting.md` document in the `docs` directory.