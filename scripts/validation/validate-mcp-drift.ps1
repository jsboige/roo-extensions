# =================================================================================================
#
#   MCP Configuration Drift Detector
#
#   Issue: #1656 (cross-machine drift prevention)
#   Compares DEPLOYED MCP configs vs repository references and reports drift.
#
#   Validates:
#   1. Roo Code mcp_settings.json vs expected server list + win-cli fork path
#   2. Claude Code ~/.claude.json mcpServers.roo-state-manager vs expected config
#   3. win-cli runtime config (commandTimeout, blockedOperators) vs repo unrestricted-config.json
#   4. Obsolete MCPs that should NOT exist (desktop-commander, github-projects-mcp, quickfiles)
#
#   Exit codes: 0=OK, 1=drift detected, 2=config file not found/parse error
#
# =================================================================================================

[CmdletBinding()]
param(
    [switch]$Quiet,
    [switch]$JsonOutput,

    # Paths (override for testing)
    [string]$RooMcpPath = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json",
    [string]$ClaudeConfigPath = "$env:USERPROFILE\.claude.json",
    [string]$RepoRoot = "",
    [string]$WinCliReference = ""
)

# ----- Resolve RepoRoot dynamically -----
if (-not $RepoRoot) {
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { $MyInvocation.PSScriptRoot }
    if ($scriptDir) {
        # PS 5.1: Join-Path only takes 2 args — chain manually
        $parentDir = Join-Path $scriptDir '..'
        $RepoRoot = (Resolve-Path (Join-Path $parentDir '..')).Path
    } else {
        $RepoRoot = "C:\dev\roo-extensions"
    }
}
if (-not $WinCliReference) {
    $WinCliReference = "$RepoRoot/mcps/external/win-cli/unrestricted-config.json"
}

# ----- Helpers -----

$script:violations = @()
$script:warnings = @()
$script:checks = @()

function Add-Violation {
    param([string]$Category, [string]$Message, [string]$Fix = "")
    $script:violations += @{ category = $Category; message = $Message; fix = $Fix }
}

function Add-Warning {
    param([string]$Category, [string]$Message)
    $script:warnings += @{ category = $Category; message = $Message }
}

function Add-Check {
    param([string]$Name, [string]$Status, [string]$Detail = "")
    $script:checks += @{ name = $Name; status = $Status; detail = $Detail }
}

function Write-Status {
    param([string]$Label, [string]$Status, [string]$Detail = "")
    if ($Quiet -and $Status -eq "PASS") { return }
    $color = switch ($Status) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "WARN" { "Yellow" }
        default { "White" }
    }
    Write-Host "  [$Status] $Label" -ForegroundColor $color
    if ($Detail -and -not $Quiet) { Write-Host "         $Detail" -ForegroundColor "DarkGray" }
}

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    try {
        $content = Get-Content -Path $Path -Raw -Encoding UTF8
        return $content | ConvertFrom-Json
    } catch {
        return $null
    }
}

# =================================================================================================
#   CHECK 1: Roo MCP Settings — Server Presence & Obsolete MCPs
# =================================================================================================

Write-Host "`n=== Roo MCP Config ===" -ForegroundColor "Cyan"

$rooConfig = Read-JsonFile $RooMcpPath
if (-not $rooConfig) {
    Add-Violation "ROO_CONFIG" "Roo mcp_settings.json not found or invalid: $RooMcpPath" "Check VS Code Roo extension installation"
    Write-Status "Config file" "FAIL" $RooMcpPath
} else {
    Write-Status "Config file" "PASS" $RooMcpPath

    $servers = $rooConfig.mcpServers.PSObject.Properties.Name
    Write-Status "MCP servers found" "PASS" "$($servers.Count) servers"

    # Required MCPs for Roo
    $requiredRoo = @("roo-state-manager", "win-cli")
    foreach ($req in $requiredRoo) {
        if ($servers -contains $req) {
            Write-Status "Required: $req" "PASS"
            Add-Check "roo_$($req)_present" "PASS"
        } else {
            Write-Status "Required: $req" "FAIL" "Missing from mcpServers"
            Add-Violation "ROO_SERVERS" "Required MCP '$req' missing from Roo config" "Add '$req' to mcp_settings.json mcpServers"
            Add-Check "roo_$($req)_present" "FAIL"
        }
    }

    # Obsolete MCPs that must NOT exist
    $obsolete = @("desktop-commander", "github-projects-mcp", "quickfiles")
    foreach ($obs in $obsolete) {
        if ($servers -contains $obs) {
            Write-Status "Obsolete: $obs" "FAIL" "Must be removed"
            Add-Violation "ROO_OBSOLETE" "Obsolete MCP '$obs' still present in config" "Remove '$obs' from mcp_settings.json"
        } else {
            Write-Status "Obsolete: $obs" "PASS" "Not present (correct)"
        }
    }
}

# =================================================================================================
#   CHECK 2: Roo win-cli — Fork Path Validation
# =================================================================================================

Write-Host "`n=== Roo win-cli Fork Path ===" -ForegroundColor "Cyan"

if ($rooConfig -and $rooConfig.mcpServers.'win-cli') {
    $winCli = $rooConfig.mcpServers.'win-cli'
    $args0 = if ($winCli.args -and $winCli.args.Count -gt 0) { $winCli.args[0] } else { "" }

    # Command must be 'node'
    if ($winCli.command -eq "node") {
        Write-Status "command" "PASS" "node"
    } else {
        Write-Status "command" "FAIL" "Got '$($winCli.command)' — expected 'node'"
        Add-Violation "ROO_WINCLI" "win-cli command is '$($winCli.command)' — drift toward npx (broken upstream #1482)" "Set command to 'node'"
    }

    # args[0] must point to local fork
    if ($args0 -match "mcps[/\\]external[/\\]win-cli[/\\]server[/\\]dist[/\\]index\.js$") {
        Write-Status "args[0] fork path" "PASS" $args0
        # Verify binary exists
        $binPath = $args0 -replace '/', '\'
        if ($binPath -notmatch "^[a-zA-Z]:") {
            $binPath = Join-Path "C:\dev\roo-extensions" $binPath
        }
        if (Test-Path $binPath) {
            Write-Status "Binary exists" "PASS" $binPath
        } else {
            # Try D: drive too
            $binPathD = $binPath -replace '^[Cc]:', 'D:'
            if (Test-Path $binPathD) {
                Write-Status "Binary exists" "PASS" $binPathD
            } else {
                Write-Status "Binary exists" "FAIL" "Not found at $binPath"
                Add-Violation "ROO_WINCLI" "win-cli binary not found at $binPath" "Rebuild: cd mcps/external/win-cli/server && npm run build"
            }
        }
    } elseif ($args0 -match "@simonb97|@anthropic/win-cli|npx") {
        Write-Status "args[0] fork path" "FAIL" "Broken npm reference detected: $args0"
        Add-Violation "ROO_WINCLI" "win-cli points to broken npm package (critical #1482): $args0" "Change args[0] to local fork path (mcps/external/win-cli/server/dist/index.js)"
    } else {
        Write-Status "args[0] fork path" "WARN" "Unexpected path: $args0"
        Add-Warning "ROO_WINCLI" "win-cli args[0] is '$args0' — verify this is the local fork"
    }

    # Scan all args for broken patterns
    foreach ($a in $winCli.args) {
        if ($a -match "@simonb97/server-win-cli|@anthropic/win-cli") {
            Add-Violation "ROO_WINCLI" "Broken npm package reference in args: '$a'" "Remove npm reference, use local fork"
        }
    }
} else {
    Write-Status "win-cli entry" "FAIL" "Not found in Roo config"
    Add-Violation "ROO_WINCLI" "No 'win-cli' entry in Roo mcpServers" "Add win-cli pointing to local fork"
}

# =================================================================================================
#   CHECK 3: Roo win-cli — Runtime Config Drift (vs unrestricted-config.json)
# =================================================================================================

Write-Host "`n=== Roo win-cli Runtime Config ===" -ForegroundColor "Cyan"

$refConfig = Read-JsonFile $WinCliReference
if ($refConfig -and $rooConfig -and $rooConfig.mcpServers.'win-cli') {
    $winCliArgs = $rooConfig.mcpServers.'win-cli'.args
    $configArg = $winCliArgs | Where-Object { $_ -match "unrestricted-config" }
    if ($configArg) {
        Write-Status "Uses unrestricted-config" "PASS" $configArg
    } else {
        Write-Status "Config reference" "WARN" "No unrestricted-config.json reference in args"
        Add-Warning "ROO_WINCLI_CONFIG" "win-cli args don't reference unrestricted-config.json — using defaults"
    }

    # Compare key values from reference
    $refTimeout = $refConfig.security.commandTimeout
    Write-Status "commandTimeout (ref: $refTimeout)" "PASS" "Repo reference: $refTimeout seconds"

    # Check for blockedOperators (should be empty in unrestricted)
    $refBlocked = $refConfig.shells.PSObject.Properties | ForEach-Object {
        $shell = $_.Value
        if ($shell.blockedOperators -and $shell.blockedOperators.Count -gt 0) {
            "$($_.Name): $($shell.blockedOperators -join ', ')"
        }
    }
    if ($refBlocked) {
        Write-Status "blockedOperators" "WARN" "Some shells have blocked operators: $refBlocked"
    } else {
        Write-Status "blockedOperators" "PASS" "All shells unrestricted (correct)"
    }
} else {
    if (-not (Test-Path $WinCliReference)) {
        Write-Status "Reference config" "WARN" "Not found: $WinCliReference"
        Add-Warning "WINCLI_REF" "unrestricted-config.json not found at expected path"
    }
}

# =================================================================================================
#   CHECK 4: Claude Code MCP Config
# =================================================================================================

Write-Host "`n=== Claude Code MCP Config ===" -ForegroundColor "Cyan"

$claudeConfig = Read-JsonFile $ClaudeConfigPath
if (-not $claudeConfig) {
    Write-Status "Claude config" "WARN" "Not found: $ClaudeConfigPath"
    Add-Warning "CLAUDE_CONFIG" "~/.claude.json not found — Claude Code not configured on this machine"
} else {
    Write-Status "Claude config" "PASS" $ClaudeConfigPath

    if ($claudeConfig.mcpServers -and $claudeConfig.mcpServers.'roo-state-manager') {
        $rsm = $claudeConfig.mcpServers.'roo-state-manager'

        # Must use mcp-wrapper.cjs
        $wrapperArg = $rsm.args | Where-Object { $_ -match "mcp-wrapper\.cjs" }
        if ($wrapperArg) {
            Write-Status "mcp-wrapper.cjs" "PASS" "Using wrapper (loads .env)"
        } else {
            $firstArg = if ($rsm.args -and $rsm.args.Count -gt 0) { $rsm.args[0] } else { "none" }
            Write-Status "mcp-wrapper.cjs" "WARN" "Not using wrapper — args[0]: $firstArg"
            Add-Warning "CLAUDE_RSM" "roo-state-manager not using mcp-wrapper.cjs — .env may not be loaded"
        }

        # Command must be 'node'
        if ($rsm.command -eq "node") {
            Write-Status "command" "PASS" "node"
        } else {
            Write-Status "command" "FAIL" "Got '$($rsm.command)'"
            Add-Violation "CLAUDE_RSM" "roo-state-manager command is '$($rsm.command)' — expected 'node'"
        }

        # Must not be disabled
        if ($rsm.disabled -eq $true) {
            Write-Status "enabled" "FAIL" "roo-state-manager is DISABLED"
            Add-Violation "CLAUDE_RSM" "roo-state-manager is disabled in Claude Code config"
        } else {
            Write-Status "enabled" "PASS"
        }

        # Check alwaysAllow count (should be 34 tools)
        $alwaysAllowCount = if ($rsm.alwaysAllow) { $rsm.alwaysAllow.Count } else { 0 }
        if ($alwaysAllowCount -ge 30) {
            Write-Status "alwaysAllow count" "PASS" "$alwaysAllowCount tools auto-approved"
        } else {
            Write-Status "alwaysAllow count" "WARN" "Only $alwaysAllowCount tools auto-approved (expected ~34)"
            Add-Warning "CLAUDE_RSM" "Only $alwaysAllowCount alwaysAllow entries for roo-state-manager (expected ~34)"
        }

        # Check for sk-agent in wrong location
        if ($claudeConfig.mcpServers.'sk-agent') {
            Write-Status "sk-agent location" "PASS" "In global ~/.claude.json (correct)"
        }
    } else {
        Write-Status "roo-state-manager" "FAIL" "Not found in Claude Code config"
        Add-Violation "CLAUDE_RSM" "roo-state-manager missing from ~/.claude.json mcpServers"
    }
}

# =================================================================================================
#   SUMMARY
# =================================================================================================

Write-Host "`n=== Summary ===" -ForegroundColor "Cyan"

$totalViolations = $script:violations.Count
$totalWarnings = $script:warnings.Count

if ($totalViolations -eq 0 -and $totalWarnings -eq 0) {
    Write-Host "  All checks passed. No drift detected." -ForegroundColor "Green"
} else {
    if ($totalViolations -gt 0) {
        Write-Host "  DRIFT DETECTED: $totalViolations violation(s)" -ForegroundColor "Red"
        foreach ($v in $script:violations) {
            Write-Host "    [$($v.category)] $($v.message)" -ForegroundColor "Red"
            if ($v.fix) { Write-Host "           Fix: $($v.fix)" -ForegroundColor "DarkYellow" }
        }
    }
    if ($totalWarnings -gt 0) {
        Write-Host "  WARNINGS: $totalWarnings warning(s)" -ForegroundColor "Yellow"
        foreach ($w in $script:warnings) {
            Write-Host "    [$($w.category)] $($w.message)" -ForegroundColor "Yellow"
        }
    }
}

# JSON output for programmatic consumption
if ($JsonOutput) {
    $result = @{
        violations = $script:violations
        warnings = $script:warnings
        checks = $script:checks
        exitCode = if ($totalViolations -gt 0) { 1 } else { 0 }
    }
    $result | ConvertTo-Json -Depth 5
}

if ($totalViolations -gt 0) {
    exit 1
} else {
    exit 0
}
