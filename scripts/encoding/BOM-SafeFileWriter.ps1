<#
.SYNOPSIS
    Helper functions for BOM-safe file writing in PowerShell.
.DESCRIPTION
    Provides functions to write files without UTF-8 BOM.
    This is critical for avoiding JSON parsing errors and other BOM-related issues.
    PowerShell's Add-Content/Set-Content with -Encoding UTF8 adds BOM in PS 5.1.
    Use these functions instead for BOM-safe writes.
.NOTES
    Auteur: Roo Architect
    Date: 2026-03-13
    Version: 1.0
    Issue: #664 - [BUG] BOM UTF-8 récurrent dans mcp_settings.json
#>

<#
.SYNOPSIS
    Appends content to a file without BOM.
.PARAMETER Path
    The file path to append to.
.PARAMETER Value
    The content to append.
.PARAMETER NewLine
    If specified, adds a newline after the content (default: true).
.EXAMPLE
    Write-FileBOMSafe -Path "log.txt" -Value "Log entry"
#>
function Write-FileBOMSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        [Parameter(Mandatory=$true)]
        [string]$Value,
        [switch]$NoNewLine
    )

    # Create parent directory if it doesn't exist
    $parentDir = Split-Path $Path -Parent
    if ($parentDir -and -not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    $content = if (Test-Path $Path) {
        [System.IO.File]::ReadAllText($Path)
    } else {
        ""
    }

    $content += $Value
    if (-not $NoNewLine) {
        $content += "`r`n"
    }

    [System.IO.File]::WriteAllText($Path, $content, [System.Text.UTF8Encoding]::new($false))
}

<#
.SYNOPSIS
    Writes content to a file (overwrites) without BOM.
.PARAMETER Path
    The file path to write to.
.PARAMETER Value
    The content to write.
.EXAMPLE
    Set-FileBOMSafe -Path "config.json" -Value '{"key": "value"}'
#>
function Set-FileBOMSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        [Parameter(Mandatory=$true)]
        [string]$Value
    )

    # Create parent directory if it doesn't exist
    $parentDir = Split-Path $Path -Parent
    if ($parentDir -and -not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    [System.IO.File]::WriteAllText($Path, $Value, [System.Text.UTF8Encoding]::new($false))
}

<#
.SYNOPSIS
    Logs a message to a file without BOM.
.PARAMETER Message
    The message to log.
.PARAMETER Level
    The log level (INFO, WARN, ERROR, SUCCESS).
.PARAMETER Path
    The log file path (optional, uses default if not specified).
#>
function Write-LogBOMSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Path = $null
    )

    if (-not $Path) {
        $Path = "logs\BOM-SafeLog-$(Get-Date -Format 'yyyyMMdd').log"
    }

    $entry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"

    # Create logs directory if it doesn't exist
    $logDir = Split-Path $Path -Parent
    if ($logDir -and -not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    Write-FileBOMSafe -Path $Path -Value $entry

    # Also write to host with colors
    Write-Host $entry -ForegroundColor $(if ($Level -eq "ERROR") { "Red" } elseif ($Level -eq "WARN") { "Yellow" } elseif ($Level -eq "SUCCESS") { "Green" } else { "Cyan" })
}

# Export functions
Export-ModuleMember -Function Write-FileBOMSafe, Set-FileBOMSafe, Write-LogBOMSafe
