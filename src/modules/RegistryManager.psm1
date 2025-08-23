# RegistryManager.psm1

function Get-RegistryValue {
    param (
        [string]$Path,
        [string]$Name
    )
    try {
        $value = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
        return $value.$Name
    } catch {
        Write-Error "Failed to get registry value: $_"
        return $null
    }
}

function Set-RegistryValue {
    param (
        [string]$Path,
        [string]$Name,
        [string]$Value,
        [string]$Type = 'String'
    )
    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -ErrorAction Stop
        Write-Host "Successfully set registry value: $Name = $Value"
    } catch {
        Write-Error "Failed to set registry value: $_"
    }
}

function Remove-RegistryValue {
    param (
        [string]$Path,
        [string]$Name
    )
    try {
        Remove-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
        Write-Host "Successfully removed registry value: $Name"
    } catch {
        Write-Error "Failed to remove registry value: $_"
    }
}

function Get-RegistryKeys {
    param (
        [string]$Path
    )
    try {
        return Get-ChildItem -Path $Path -ErrorAction Stop
    } catch {
        Write-Error "Failed to get registry keys: $_"
        return @()
    }
}