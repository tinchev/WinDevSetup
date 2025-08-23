# Validation.ps1

function Validate-Input {
    param (
        [string]$input,
        [string]$type
    )

    switch ($type) {
        'software' {
            if (-not [string]::IsNullOrWhiteSpace($input) -and $input -match '^[\w\s-]+$') {
                return $true
            }
            else {
                return $false
            }
        }
        'registry' {
            if (-not [string]::IsNullOrWhiteSpace($input) -and $input -match '^[\w\\]+$') {
                return $true
            }
            else {
                return $false
            }
        }
        default {
            return $false
        }
    }
}

function Validate-ConfigFile {
    param (
        [string]$filePath
    )

    if (Test-Path $filePath) {
        $content = Get-Content $filePath -ErrorAction Stop | Out-String
        if ($content -match '^\s*[\[\{]') {
            return $true
        }
    }
    return $false
}