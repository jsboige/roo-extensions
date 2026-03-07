# Deploy-ClaudeMcpSettings.ps1
# Deploys win-cli and roo-state-manager MCPs to Claude Code settings.json
#
# This script configures Claude Code (NOT Roo) with the critical MCP tools:
# - win-cli: Fork local 0.2.0 for shell commands
# - roo-state-manager: For RooSync coordination and conversation management
#
# Usage:
#   .\deploy-claude-mcp-settings.ps1 [-MachineId <hostname>] [-WhatIf]
#
# Issue: #569 - Claude Code MCP config is separate from Roo config

param(
    [string]$MachineId = $env:COMPUTERNAME.ToLower(),
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

# Paths
$RepoRoot = (Get-Item "$PSScriptRoot\..\..").FullName
$WinCliPath = "$RepoRoot\mcps\external\win-cli\server\dist\index.js"
$WinCliConfigPath = "$RepoRoot\mcps\external\win-cli\config\win_cli_config.json"
$RooStatePath = "$RepoRoot\mcps\internal\servers\roo-state-manager\mcp-wrapper.cjs"
$RooStateCwd = "$RepoRoot\mcps\internal\servers\roo-state-manager\"
$SettingsPath = "$env:USERPROFILE\.claude\settings.json"

# Validate paths
if (-not (Test-Path $WinCliPath)) {
    Write-Error "win-cli not found at: $WinCliPath"
    exit 1
}
if (-not (Test-Path $RooStatePath)) {
    Write-Error "roo-state-manager not found at: $RooStatePath"
    exit 1
}

# Read existing settings or create new
if (Test-Path $SettingsPath) {
    $Settings = Get-Content $SettingsPath -Raw | ConvertFrom-Json
} else {
    $Settings = @{}
}

# Ensure mcpServers section exists
if (-not $Settings.mcpServers) {
    $Settings.mcpServers = @{}
}

# Configure win-cli (fork local 0.2.0)
$WinCliConfig = @{
    command = "node"
    args = @($WinCliPath)
    env = @{
        WIN_CLI_CONFIG_PATH = $WinCliConfigPath
    }
}
$Settings.mcpServers.'win-cli' = $WinCliConfig

# Configure roo-state-manager
$RooStateConfig = @{
    command = "node"
    args = @($RooStatePath)
    cwd = $RooStateCwd
    env = @{
        ROO_EXTENSIONS_PATH = $RepoRoot
        QDRANT_URL = "http://qdrant.myia.io:6333"
        QDRANT_COLLECTION = "roo-conversations"
        EMBEDDING_MODEL = "Alibaba-NLP/gte-Qwen2-1.5B-instruct"
        EMBEDDING_DIMENSIONS = "2560"
        EMBEDDING_API_BASE_URL = "http://embeddings.myia.io:11436/v1"
        EMBEDDING_API_KEY = "vllm-placeholder-key-2024"
    }
}

# MyIA-Web1 uses a different ROOSYNC_SHARED_PATH (Google account diff)
if ($MachineId -eq "myia-web1") {
    $RooStateConfig.env.ROOSYNC_SHARED_PATH = "C:\Drive\.shortcut-targets-by-id\1jEQqHabwXrIukTEI1vE05gWsJNYNNFVB\.shared-state"
} else {
    $RooStateConfig.env.ROOSYNC_SHARED_PATH = "G:\Mon Drive\Synchronisation\RooSync\.shared-state"
}

$Settings.mcpServers.'roo-state-manager' = $RooStateConfig

# Ensure CLAUDE_AUTOCOMPACT_PCT_OVERRIDE is set correctly (#502)
if (-not $Settings.env) {
    $Settings.env = @{}
}
if ($Settings.env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE -ne "75") {
    $Settings.env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE = "75"
    Write-Host "[FIX] CLAUDE_AUTOCOMPACT_PCT_OVERRIDE set to 75 (was $($Settings.env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE))" -ForegroundColor Yellow
}

# Output
$JsonOutput = $Settings | ConvertTo-Json -Depth 10

if ($WhatIf) {
    Write-Host "[WHATIF] Would write to: $SettingsPath" -ForegroundColor Cyan
    Write-Host $JsonOutput
    exit 0
}

# Backup existing
if (Test-Path $SettingsPath) {
    $BackupPath = "$SettingsPath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $SettingsPath $BackupPath
    Write-Host "[BACKUP] Created: $BackupPath" -ForegroundColor Green
}

# Write new settings
[System.IO.File]::WriteAllText($SettingsPath, $JsonOutput, [System.Text.UTF8Encoding]::new($false))

Write-Host "[SUCCESS] Claude Code MCP settings deployed for $MachineId" -ForegroundColor Green
Write-Host "[PATH] $SettingsPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Restart VS Code to load MCP servers"
Write-Host "  2. Verify with: execute_command(shell='powershell', command='echo OK')"
Write-Host "  3. Verify with: conversation_browser(action='current')"
