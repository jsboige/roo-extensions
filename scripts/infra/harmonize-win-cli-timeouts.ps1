# harmonize-win-cli-timeouts.ps1 — Verify and fix win-cli timeouts (#2333)
# Usage: ./harmonize-win-cli-timeouts.ps1 [-Minimum 600] [-Fix]
[CmdletBinding(SupportsShouldProcess)]
param(
    [int]$Minimum = 600,
    [switch]$Fix
)

$ErrorActionPreference = 'Stop'
$exitCode = 0

function Write-Result {
    param([string]$Level, [string]$Status, [string]$Message)
    $color = switch ($Status) {
        'OK'    { 'Green' }
        'WARN'  { 'Yellow' }
        'FIXED' { 'Cyan' }
        default { 'White' }
    }
    Write-Host "[$Status] $Level : $Message" -ForegroundColor $color
}

# --- Level 1: win-cli internal config (~/.win-cli-mcp/config.json) ---
$internalBase = Join-Path $env:USERPROFILE '.win-cli-mcp'
$internalConfigPath = Join-Path $internalBase 'config.json'

if (Test-Path $internalConfigPath) {
    $internalConfig = Get-Content $internalConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $commandTimeout = $internalConfig.security.commandTimeout

    if ($commandTimeout -lt $Minimum) {
        Write-Result 'win-cli-internal' 'WARN' "commandTimeout = ${commandTimeout}s (minimum: ${Minimum}s)"
        if ($Fix -and $PSCmdlet.ShouldProcess($internalConfigPath, "Set commandTimeout to $Minimum")) {
            $internalConfig.security.commandTimeout = $Minimum
            $json = $internalConfig | ConvertTo-Json -Depth 10
            [System.IO.File]::WriteAllText($internalConfigPath, $json, [System.Text.UTF8Encoding]::new($false))
            Write-Result 'win-cli-internal' 'FIXED' "commandTimeout set to ${Minimum}s"
        } else {
            $exitCode = 1
        }
    } else {
        Write-Result 'win-cli-internal' 'OK' "commandTimeout = ${commandTimeout}s"
    }
} else {
    Write-Result 'win-cli-internal' 'OK' "No runtime override (using repo default 600s)"
}

# --- Level 2: Roo MCP transport timeout ---
$rooMcpPath = "$env:APPDATA/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json"

if (Test-Path $rooMcpPath) {
    $rooConfig = Get-Content $rooMcpPath -Raw -Encoding UTF8 | ConvertFrom-Json

    if ($rooConfig.mcpServers.'win-cli') {
        $transportTimeout = $rooConfig.mcpServers.'win-cli'.timeout

        if ($null -eq $transportTimeout) {
            Write-Result 'roo-transport' 'WARN' 'No timeout field defined (undefined = no limit OR transport default)'
        } elseif ($transportTimeout -lt $Minimum) {
            Write-Result 'roo-transport' 'WARN' "timeout = ${transportTimeout}s (minimum: ${Minimum}s)"
            if ($Fix -and $PSCmdlet.ShouldProcess($rooMcpPath, "Set win-cli timeout to $Minimum")) {
                $rooConfig.mcpServers.'win-cli'.timeout = $Minimum
                $json = $rooConfig | ConvertTo-Json -Depth 10
                [System.IO.File]::WriteAllText($rooMcpPath, $json, [System.Text.UTF8Encoding]::new($false))
                Write-Result 'roo-transport' 'FIXED' "timeout set to ${Minimum}s"
            } else {
                $exitCode = 1
            }
        } else {
            Write-Result 'roo-transport' 'OK' "timeout = ${transportTimeout}s"
        }
    } else {
        Write-Result 'roo-transport' 'OK' 'No win-cli entry in mcp_settings.json'
    }
} else {
    Write-Result 'roo-transport' 'OK' 'No Roo mcp_settings.json found (not a Roo machine)'
}

# --- Summary ---
if ($exitCode -eq 0) {
    Write-Host "`nAll win-cli timeouts conform (>= ${Minimum}s)." -ForegroundColor Green
} else {
    Write-Host "`nSome timeouts below ${Minimum}s — re-run with -Fix to auto-correct." -ForegroundColor Yellow
}

exit $exitCode
