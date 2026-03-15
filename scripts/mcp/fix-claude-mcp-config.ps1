# Fix Claude Code MCP Configuration for roo-state-manager
#
# Problem: Claude Code only exposes management tools, not operational tools
# Solution: Update alwaysAllow list with all 42 tools from reference
# Usage: .\scripts\mcp\fix-claude-mcp-config.ps1

#requires -version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Paths
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$ReferenceConfig = Join-Path $ProjectRoot "roo-config\mcp\reference-alwaysallow.json"
$ClaudeConfigPath = "$env:USERPROFILE\.claude.json"

# Colors
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

Write-ColorOutput Cyan "=================================================="
Write-ColorOutput Cyan "Fix Claude Code MCP Config - roo-state-manager"
Write-ColorOutput Cyan "=================================================="
Write-Output ""

# Step 1: Check reference config exists
if (-not (Test-Path $ReferenceConfig)) {
    Write-ColorOutput Red "ERROR: Reference config not found: $ReferenceConfig"
    exit 1
}
Write-ColorOutput Green "OK Reference config found: $ReferenceConfig"

# Step 2: Load reference alwaysAllow for roo-state-manager
$ReferenceJson = Get-Content $ReferenceConfig -Raw | ConvertFrom-Json
$mcpRef = $ReferenceJson.mcpServers
$DesiredAlwaysAllow = $null

foreach ($key in $mcpRef.psobject.Properties.Name) {
    if ($key -eq 'roo-state-manager') {
        $DesiredAlwaysAllow = $mcpRef.$key.alwaysAllow
        break
    }
}

if (-not $DesiredAlwaysAllow) {
    Write-ColorOutput Red "ERROR: No alwaysAllow found for roo-state-manager in reference"
    exit 1
}
Write-ColorOutput Green "OK Found $($DesiredAlwaysAllow.Count) tools in reference alwaysAllow"

# Step 3: Check if Claude config exists
if (-not (Test-Path $ClaudeConfigPath)) {
    Write-ColorOutput Yellow "WARNING: Claude config not found: $ClaudeConfigPath"
    Write-ColorOutput Yellow "Launch Claude Code once, then run this script again."
    exit 0
}
Write-ColorOutput Green "OK Claude config found: $ClaudeConfigPath"

# Step 4: Backup existing config
$BackupPath = "$ClaudeConfigPath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item $ClaudeConfigPath $BackupPath
Write-ColorOutput Green "OK Backup created: $BackupPath"

# Step 5: Load and update Claude config
$ClaudeConfig = Get-Content $ClaudeConfigPath -Raw | ConvertFrom-Json

# Check if roo-state-manager MCP is configured
$mcpServers = $ClaudeConfig.mcpServers
$RooMcpKey = $null
$RooMcp = $null

foreach ($key in $mcpServers.psobject.Properties.Name) {
    if ($key -eq 'roo-state-manager') {
        $RooMcpKey = $key
        $RooMcp = $mcpServers.$key
        break
    }
}

if (-not $RooMcpKey) {
    Write-ColorOutput Yellow "WARNING: roo-state-manager not configured in Claude Code"
    Write-ColorOutput Yellow "Please add the MCP server first via Claude Code Settings"
    exit 1
}

# Get current alwaysAllow
$CurrentAlwaysAllow = $RooMcp.alwaysAllow
if (-not $CurrentAlwaysAllow) {
    $CurrentAlwaysAllow = @()
}

# Compare
$MissingTools = $DesiredAlwaysAllow | Where-Object { $_ -notin $CurrentAlwaysAllow }

if ($MissingTools.Count -eq 0) {
    Write-ColorOutput Green "OK All tools already in alwaysAllow - no changes needed"
    Write-Output "Current tool count: $($CurrentAlwaysAllow.Count)"
    exit 0
}

Write-ColorOutput Yellow "WARNING: Missing $($MissingTools.Count) tools in alwaysAllow:"
$MissingTools | ForEach-Object { Write-Output "  - $_" }

# Step 6: Update alwaysAllow - use Add-Member since property may not exist
$mcpServerObj = $ClaudeConfig.mcpServers.$RooMcpKey
if ($mcpServerObj.PSObject.Properties.Name -contains 'alwaysAllow') {
    $mcpServerObj.alwaysAllow = $DesiredAlwaysAllow
} else {
    $mcpServerObj | Add-Member -MemberType NoteProperty -Name 'alwaysAllow' -Value $DesiredAlwaysAllow -Force
}

# Step 7: Write updated config
$ClaudeConfigJson = $ClaudeConfig | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($ClaudeConfigPath, $ClaudeConfigJson, [System.Text.Encoding]::UTF8)

Write-ColorOutput Green "OK Config updated"
Write-Output ""
Write-ColorOutput Cyan "=================================================="
Write-ColorOutput Green "SUCCESS - MCP config fixed!"
Write-ColorOutput Cyan "=================================================="
Write-Output ""
Write-ColorOutput Yellow "NEXT STEPS:"
Write-Output "1. Restart VS Code completely (close all windows)"
Write-Output "2. Start a new Claude Code conversation"
Write-Output "3. Verify roosync_* tools are available (check system-reminders)"
Write-Output ""
Write-ColorOutput Green "Tool count: $($CurrentAlwaysAllow.Count) -> $($DesiredAlwaysAllow.Count)"
Write-Output "Backup: $BackupPath"
