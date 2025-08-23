# Troubleshooting Guide for Windows Setup Automation Tool

## Common Issues and Solutions

### Issue 1: Script Execution Policy
**Problem:** The setup script fails to run due to script execution policy restrictions.  
**Solution:** Open PowerShell as an administrator and run the following command to allow script execution:
```
Set-ExecutionPolicy RemoteSigned
```
After changing the policy, try running the setup script again.

### Issue 2: Missing Software
**Problem:** Some software listed in the `software-list.json` file fails to install.  
**Solution:** Ensure that the software names and installation commands in the `software-list.json` file are correct. Verify that the software is available for installation on your system.

### Issue 3: Registry Configuration Errors
**Problem:** The registry settings do not apply as expected.  
**Solution:** Check the `registry-settings.json` file for correct formatting and valid registry paths. Ensure that you have administrative privileges to modify the registry.

### Issue 4: Windows Features Not Enabled
**Problem:** Certain Windows features do not enable after running the setup.  
**Solution:** Review the `windows-features.json` file to ensure that the features are correctly specified. Some features may require a system restart to take effect.

### Issue 5: Log Files Indicate Errors
**Problem:** The log files in the `logs` directory show errors during the setup process.  
**Solution:** Review the log files for specific error messages. Common issues may include missing dependencies or incorrect configurations. Address the issues as indicated in the logs.

## Additional Resources
For further assistance, refer to the `installation-guide.md` and `configuration-reference.md` files in the `docs` directory. You can also seek help from the project's GitHub repository or community forums.