# Visual Studio Workloads Configuration

This file (`visual-studio-workloads.vsconfig`) defines the workloads and components that will be installed with Visual Studio Professional.

## Current Workloads

### Core Development Workloads
- **ManagedDesktop** - .NET desktop development (WinForms, WPF)
- **NetWeb** - ASP.NET and web development
- **Azure** - Azure cloud development tools
- **Data** - Database and data development tools
- **NetCrossPlat** - Cross-platform .NET development
- **Node** - Node.js development tools

### Key Components
- **Git Integration** - Built-in source control
- **.NET Framework 4.8 SDK** - Legacy .NET support
- **.NET Core SDK** - Modern .NET development
- **SQL Server Data Tools (SSDT)** - Database development
- **Azure Service Fabric Tools** - Microservices development
- **IntelliCode** - AI-assisted coding
- **Azure Development Tools** - Cloud development support
- **Testing Tools** - Unit testing and coded UI tests
- **Windows 10 SDK** - Windows app development

## Customization

To modify the installed workloads:

1. Edit the `visual-studio-workloads.vsconfig` file
2. Add or remove component IDs from the "components" array
3. Run the setup script again

## Component Reference

For a full list of available workloads and components, see:
- [Visual Studio Workload and Component IDs](https://docs.microsoft.com/en-us/visualstudio/install/workload-and-component-ids)
- [Visual Studio Build Tools Component Directory](https://docs.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-build-tools)

## Usage

This configuration file is automatically used by the setup script when installing Visual Studio Professional with development workloads.
