# Deploy-ClaudeMcpSettings.ps1
# Deploys MCP servers to Claude Code ~/.claude.json (user scope)
#
# IMPORTANT: Claude Code MCP servers go in ~/.claude.json (user scope),
# NOT in ~/.claude/settings.json (which is for env/permissions/model only).
# See: https://code.claude.com/docs/en/settings#what-uses-scopes
#
# MCPs read their own .env / config files for credentials.
# This script only sets command/args/cwd — no secrets.
#
# Usage:
#   .\deploy-claude-mcp-settings.ps1 [-MachineId <hostname>] [-WhatIf]
#
# Issue: #569, #597 - Claude Code MCP scopes

param(
    [string]$MachineId = $env:COMPUTERNAME.ToLower(),
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

# Paths
$RepoRoot = (Get-Item "$PSScriptRoot\..\..").FullName
$WinCliPath = "$RepoRoot\mcps\external\win-cli\server\dist\index.js"
$RooStatePath = "$RepoRoot\mcps\internal\servers\roo-state-manager\mcp-wrapper.cjs"
$RooStateCwd = "$RepoRoot\mcps\internal\servers\roo-state-manager\"
$ClaudeJsonPath = "$env:USERPROFILE\.claude.json"
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

# --- Build MCP servers config (no credentials — MCPs load their own .env) ---

$McpServers = @{
    "win-cli" = @{
        command = "node"
        args = @($WinCliPath)
    }
    "roo-state-manager" = @{
        command = "node"
        args = @($RooStatePath)
        cwd = $RooStateCwd
    }
    "playwright" = @{
        command = "npx"
        args = @("-y", "@playwright/mcp")
    }
}

$McpServersJson = $McpServers | ConvertTo-Json -Depth 10

# --- Update ~/.claude.json (user scope - MCP servers only) ---

Write-Host "`n=== Claude Code MCP Deployment ===" -ForegroundColor Cyan
Write-Host "Machine: $MachineId" -ForegroundColor Cyan
Write-Host "Target:  $ClaudeJsonPath (user scope)" -ForegroundColor Cyan

if (Test-Path $ClaudeJsonPath) {
    $ClaudeJsonRaw = [System.IO.File]::ReadAllText($ClaudeJsonPath, [System.Text.UTF8Encoding]::new($false))
    $ClaudeJson = $ClaudeJsonRaw | ConvertFrom-Json
} else {
    Write-Error "~/.claude.json not found. Claude Code must be initialized first (run 'claude' once)."
    exit 1
}

# Replace only the mcpServers key
$ClaudeJson.mcpServers = $McpServers

# Use -Depth 10 to preserve array structure for args (PowerShell 5.1+)
$OutputJson = $ClaudeJson | ConvertTo-Json -Depth 10

if ($WhatIf) {
    Write-Host "`n[WHATIF] Would write mcpServers to: $ClaudeJsonPath" -ForegroundColor Cyan
    Write-Host "[WHATIF] MCP servers: $($McpServers.Keys -join ', ')" -ForegroundColor Cyan
    Write-Host "`n[WHATIF] mcpServers content:" -ForegroundColor Cyan
    Write-Host $McpServersJson
    exit 0
}

# Backup
$BackupPath = "$ClaudeJsonPath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item $ClaudeJsonPath $BackupPath
Write-Host "[BACKUP] Created: $BackupPath" -ForegroundColor Green

# Write (UTF-8 no BOM)
[System.IO.File]::WriteAllText($ClaudeJsonPath, $OutputJson, [System.Text.UTF8Encoding]::new($false))
Write-Host "[SUCCESS] mcpServers deployed to $ClaudeJsonPath" -ForegroundColor Green
Write-Host "[MCPs] $($McpServers.Keys -join ', ')" -ForegroundColor Green

# --- Ensure settings.json has correct env (separate scope) ---

if (Test-Path $SettingsPath) {
    $SettingsRaw = [System.IO.File]::ReadAllText($SettingsPath, [System.Text.UTF8Encoding]::new($false))
    $Settings = $SettingsRaw | ConvertFrom-Json

    $Changed = $false

    # Remove stale mcpServers from settings.json if present (#597)
    if ($Settings.PSObject.Properties['mcpServers']) {
        $Settings.PSObject.Properties.Remove('mcpServers')
        Write-Host "[FIX] Removed stale mcpServers from settings.json (wrong scope)" -ForegroundColor Yellow
        $Changed = $true
    }

    # Ensure compact settings (#502 baseline, #2173 model-aware defaults)
    # Default: 200k window / 90% threshold for worker machines (GLM/Qwen default model).
    # Spawn scripts override per model at runtime — these are machine-level defaults.
    # CAVEAT: A manual `claude -p` (outside spawn scripts) inherits these defaults,
    # which are tuned for GLM/Qwen. For Claude model manual sessions, pass env vars
    # explicitly: CLAUDE_CODE_AUTO_COMPACT_WINDOW=1000000 CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=25
    if (-not $Settings.PSObject.Properties['env']) {
        $Settings | Add-Member -NotePropertyName 'env' -NotePropertyValue @{}
    }
    # Guard: preserve a deliberate HIGHER threshold (e.g. ai-01 user override =99, 2026-06-01).
    # 90 is the fleet default; >=90 means "compact later" = always safe. Only correct a
    # missing value or a dangerously-low one (<90, e.g. the 50/75 that caused boucle #502).
    $currentPct = $Settings.env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE
    if (-not $currentPct -or ([int]$currentPct) -lt 90) {
        $Settings.env | Add-Member -NotePropertyName 'CLAUDE_AUTOCOMPACT_PCT_OVERRIDE' -NotePropertyValue "90" -Force
        Write-Host "[FIX] CLAUDE_AUTOCOMPACT_PCT_OVERRIDE set to 90 in settings.json (#2173)" -ForegroundColor Yellow
        $Changed = $true
    }
    if ($Settings.env.CLAUDE_CODE_AUTO_COMPACT_WINDOW -ne "200000") {
        $Settings.env | Add-Member -NotePropertyName 'CLAUDE_CODE_AUTO_COMPACT_WINDOW' -NotePropertyValue "200000" -Force
        Write-Host "[FIX] CLAUDE_CODE_AUTO_COMPACT_WINDOW set to 200000 in settings.json (#2173)" -ForegroundColor Yellow
        $Changed = $true
    }
    # MCP tool-call timeout (#2402 follow-up). Unset → Claude Code default ~180s strangles
    # dashboard auto-condensation (budgeted 720s in dashboard.ts) → append-hang fleet-wide.
    # 900s > 720s budget gives headroom. Applies to interactive sessions (spawn scripts set
    # this at runtime for scheduled workers).
    if ($Settings.env.MCP_TOOL_TIMEOUT -ne "900000") {
        $Settings.env | Add-Member -NotePropertyName 'MCP_TOOL_TIMEOUT' -NotePropertyValue "900000" -Force
        Write-Host "[FIX] MCP_TOOL_TIMEOUT set to 900000 in settings.json (#2402 condensation headroom)" -ForegroundColor Yellow
        $Changed = $true
    }

    if ($Changed) {
        $SettingsJson = $Settings | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($SettingsPath, $SettingsJson, [System.Text.UTF8Encoding]::new($false))
        Write-Host "[SUCCESS] settings.json updated (env only, no MCPs)" -ForegroundColor Green
    } else {
        Write-Host "[OK] settings.json already correct" -ForegroundColor Green
    }
}

Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "  1. Restart VS Code to load MCP servers"
Write-Host "  2. Verify with: conversation_browser(action='current')"
Write-Host "  3. Check #597 checklist on GitHub"
