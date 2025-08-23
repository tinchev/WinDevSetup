# Logging Structure

## Overview
The setup script now uses an organized logging structure that creates a separate folder for each run, making it easy to track and troubleshoot installations.

## Log Organization

```
logs/
├── run-20250823-111856/          # Run folder (YYYYMMDD-HHMMSS)
│   ├── setup-main.log            # Main setup script log
│   ├── winget-Git-20250823-111857.log           # Individual winget installation
│   ├── chocolatey-VisualStudio-20250823-111902.log  # Individual chocolatey installation
│   └── installation-summary.txt  # Summary report for this run
└── run-20250823-104521/          # Previous run
    ├── setup-main.log
    └── ...
```

## Log Types

### Main Setup Log (`setup-main.log`)
- Clean, focused output showing overall progress
- Step-by-step execution flow
- High-level success/failure information
- Easy to read for quick status overview

### Individual Installation Logs
- **Winget logs**: `winget-{SoftwareName}-{Timestamp}.log`
- **Chocolatey logs**: `chocolatey-{SoftwareName}-{Timestamp}.log`
- **Custom installer logs**: `custom-{SoftwareName}-{Timestamp}.log`

Each individual log contains:
- Complete verbose output from the package manager
- Real-time progress tracking
- Detailed error messages
- Installation duration and exit codes
- Full command arguments used

### Installation Summary (`installation-summary.txt`)
- Overview of all installations in the run
- Success/failure counts by category
- Links to individual log files
- Troubleshooting tips and recommendations

## Benefits

### Clean Terminal Experience
- Main terminal shows only essential progress information
- No verbose package manager output cluttering the display
- Easy to follow overall progress

### Detailed Troubleshooting
- Every installation has complete verbose logs
- Real-time capture of all output and errors
- Easy to find specific installation issues
- Historical tracking of all runs

### Organized History
- Each run is self-contained in its own folder
- Easy to compare different run results
- No mixing of logs from different executions
- Clean separation for analysis

## Example Usage

After running the setup script, you can:

1. **Check overall progress**: Look at the main terminal output
2. **Review run summary**: Open `logs/run-{timestamp}/installation-summary.txt`
3. **Debug specific failures**: Open the individual log file for failed installations
4. **Compare runs**: Navigate between different run folders
5. **Clean up old runs**: Remove entire run folders when no longer needed

## Log File Locations

The current run's logs are stored in: `{script-directory}/logs/run-{YYYYMMDD-HHMMSS}/`

You can find the exact location printed in the terminal when the script starts:
```
[2025-08-23 11:18:56] [INFO] Logging initialized to: ...\logs\run-20250823-111856\setup-main.log
```
