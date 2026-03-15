<#
.SYNOPSIS
    Win-cli command patterns module for scheduler workflows.

.DESCRIPTION
    Common WIN-CLI command patterns for shell operations used across
    all scheduler workflows. Provides standardized wrappers around execute_command.

.EXAMPLE
    Invoke-WinCliCommand -Shell "powershell" -Command "echo Hello"
#>

function Invoke-WinCliCommand {
    <#
    .SYNOPSIS
        Executes a shell command via win-cli MCP.

    .DESCRIPTION
        Wrapper around execute_command with error handling and logging.

    .PARAMETER Shell
        Shell type: powershell, cmd, bash (default: powershell)

    .PARAMETER Command
        Command to execute

    .PARAMETER Timeout
        Timeout in seconds (default: 30)

    .PARAMETER NoLog
        Skip logging to INTERCOM (default: false)
    #>
    [OutputType([hashtable])]
    param(
        [ValidateSet('powershell', 'cmd', 'bash')]
        [string]$Shell = "powershell",

        [Parameter(Mandatory=$true)]
        [string]$Command,

        [int]$Timeout = 30,

        [switch]$NoLog
    )

    $result = @{
        Success = $false
        Output = ""
        Error = ""
        ExitCode = -1
    }

    try {
        # Execute command via win-cli
        $output = execute_command -shell $Shell -command $Command

        if ($LASTEXITCODE -ne $null) {
            $result.ExitCode = $LASTEXITCODE
        }

        $result.Output = $output
        $result.Success = ($result.ExitCode -eq 0)

        if (-not $NoLog) {
            if ($result.Success) {
                Write-INTERCOMMessage -Type "INFO" -Title "Command executed" -Content "**Command:** $Command`n`n**Exit code:** $($result.ExitCode)" -SuppressOutput
            } else {
                Write-INTERCOMError -ErrorTitle "Command failed" -ErrorMessage "Command failed with exit code $($result.ExitCode)" -ErrorDetails $output
                $result.Error = $output
            }
        }
    } catch {
        $result.Error = $_.Exception.Message
        $result.Success = $false

        if (-not $NoLog) {
            Write-INTERCOMError -ErrorTitle "Command exception" -ErrorMessage "Exception executing command" -ErrorDetails $_.Exception.Message
        }
    }

    return $result
}

<#
.SYNOPSIS
    Executes a Git command via win-cli.

.DESCRIPTION
    Specialized wrapper for Git commands with common error handling.

.PARAMETER GitCommand
    Git command to execute (without "git" prefix)

.PARAMETER Timeout
    Timeout in seconds (default: 60)
#>
function Invoke-GitCommand {
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$GitCommand,

        [int]$Timeout = 60
    )

    return Invoke-WinCliCommand -Shell "powershell" -Command "git $GitCommand" -Timeout $Timeout
}

<#
.SYNOPSIS
    Gets the current Git branch.

.DESCRIPTION
    Returns the name of the current Git branch.
#>
function Get-GitBranch {
    [OutputType([string])]
    param()

    $result = Invoke-GitCommand -GitCommand "rev-parse --abbrev-ref HEAD" -NoLog
    if ($result.Success) {
        return $result.Output.Trim()
    }
    return "unknown"
}

<#
.SYNOPSIS
    Checks if the Git workspace is clean.

.DESCRIPTION
    Returns true if there are no uncommitted changes.
#>
function Test-GitWorkspaceClean {
    [OutputType([bool])]
    param()

    $result = Invoke-GitCommand -GitCommand "status --porcelain" -NoLog
    return ($result.Success -and [string]::IsNullOrWhiteSpace($result.Output))
}

<#
.SYNOPSIS
    Gets the Git commit hash.

.DESCRIPTION
    Returns the short commit hash of HEAD.

.PARAMETER Length
    Length of hash (default: 8)
#>
function Get-GitCommitHash {
    [OutputType([string])]
    param(
        [int]$Length = 8
    )

    $result = Invoke-GitCommand -GitCommand "rev-parse --short=$Length HEAD" -NoLog
    if ($result.Success) {
        return $result.Output.Trim()
    }
    return "unknown"
}

<#
.SYNOPSIS
    Gets the current working directory.

.DESCRIPTION
    Returns the current working directory via win-cli.
#>
function Get-WorkingDirectory {
    [OutputType([string])]
    param()

    $result = Invoke-WinCliCommand -Shell "powershell" -Command "Get-Location" -NoLog
    if ($result.Success) {
        return $result.Output.Trim()
    }
    return $PWD.Path
}

<#
.SYNOPSIS
    Reads a file via win-cli.

.DESCRIPTION
    Reads the contents of a file using PowerShell Get-Content.

.PARAMETER Path
    Path to the file

.PARAMETER Encoding
    File encoding (default: UTF8)
#>
function Read-WinCliFile {
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [string]$Encoding = "UTF8"
    )

    $command = "Get-Content -Path '$Path' -Encoding $Encoding -Raw"
    $result = Invoke-WinCliCommand -Shell "powershell" -Command $command -NoLog

    if ($result.Success) {
        return $result.Output
    }

    return ""
}

<#
.SYNOPSIS
    Writes a file via win-cli.

.DESCRIPTION
    Writes content to a file using PowerShell Set-Content.

.PARAMETER Path
    Path to the file

.PARAMETER Content
    Content to write

.PARAMETER Encoding
    File encoding (default: UTF8)
#>
function Write-WinCliFile {
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$true)]
        [string]$Content,

        [string]$Encoding = "UTF8"
    )

    $escapedContent = $Content -replace '"', '`"'
    $command = "Set-Content -Path '$Path' -Value `"$escapedContent`" -Encoding $Encoding"

    $result = Invoke-WinCliCommand -Shell "powershell" -Command $command
    return $result.Success
}

<#
.SYNOPSIS
    Lists files in a directory via win-cli.

.DESCRIPTION
    Returns a list of files in the specified directory.

.PARAMETER Path
    Directory path (default: current directory)

.PARAMETER Filter
    File filter (default: *)

.PARAMETER Recurse
    Include subdirectories (default: false)
#>
function Get-WinCliFiles {
    [OutputType([string[]])]
    param(
        [string]$Path = ".",

        [string]$Filter = "*",

        [switch]$Recurse
    )

    $recurseArg = if ($Recurse) { "-Recurse" } else { "" }
    $command = "Get-ChildItem -Path '$Path' -Filter $Filter $recurseArg -File -Name | Select-Object -First 100"

    $result = Invoke-WinCliCommand -Shell "powershell" -Command $command -NoLog

    if ($result.Success -and $result.Output) {
        return $result.Output -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    }

    return @()
}

<#
.SYNOPSIS
    Checks if a file exists via win-cli.

.DESCRIPTION
    Returns true if the specified file exists.

.PARAMETER Path
    Path to the file
#>
function Test-WinCliFileExists {
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    $command = "Test-Path '$Path' -PathType Leaf"
    $result = Invoke-WinCliCommand -Shell "powershell" -Command $command -NoLog

    if ($result.Success -and $result.Output) {
        return $result.Output.Trim() -eq "True"
    }

    return $false
}

<#
.SYNOPSIS
    Gets file metadata via win-cli.

.DESCRIPTION
    Returns file metadata (size, modified date, etc.).

.PARAMETER Path
    Path to the file
#>
function Get-WinCliFileMetadata {
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    $command = "Get-ItemProperty -Path '$Path' | Select-Object Length, LastWriteTimeModified, CreationTime | ConvertTo-Json"
    $result = Invoke-WinCliCommand -Shell "powershell" -Command $command -NoLog

    $metadata = @{
        Path = $Path
        Exists = Test-WinCliFileExists -Path $Path
        Size = 0
        LastModified = $null
        Created = $null
    }

    if ($result.Success -and $result.Output) {
        try {
            $json = $result.Output | ConvertFrom-Json
            if ($json.Length) { $metadata.Size = [int]$json.Length }
            if ($json.LastWriteTimeModified) { $metadata.LastModified = $json.LastWriteTimeModified }
            if ($json.CreationTime) { $metadata.Created = $json.CreationTime }
        } catch {
            # JSON parsing failed, return default metadata
        }
    }

    return $metadata
}

# Import INTERCOMReporting module for Write-INTERCOMMessage and Write-INTERCOMError
Import-Module (Join-Path $PSScriptRoot "INTERCOMReporting.psm1") -ErrorAction SilentlyContinue

Export-ModuleMember -Function Invoke-WinCliCommand, Invoke-GitCommand, Get-GitBranch, Test-GitWorkspaceClean, Get-GitCommitHash, Get-WorkingDirectory, Read-WinCliFile, Write-WinCliFile, Get-WinCliFiles, Test-WinCliFileExists, Get-WinCliFileMetadata
