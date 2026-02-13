<#
.SYNOPSIS
    Deploy DesktopCommanderMCP configuration for Roo extensions.

.DESCRIPTION
    - Copies config template to ~/.claude-server-commander/config.json
    - Adds desktop-commander MCP to Roo's mcp_settings.json
    - Optionally removes win-cli MCP (Phase 3 migration)

.PARAMETER Action
    deploy   - Deploy DCMCP config + add to Roo MCP settings
    status   - Check DCMCP deployment status
    remove-wincli - Remove win-cli from Roo settings (after validation)

.EXAMPLE
    .\deploy-desktop-commander.ps1 -Action deploy
#>

param(
    [ValidateSet("deploy", "status", "remove-wincli")]
    [string]$Action = "deploy"
)

$ErrorActionPreference = "Stop"

# Paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path "$ScriptDir\..\..\..").Path
$ConfigTemplate = "$ScriptDir\..\config\desktop-commander-config.json"
$TargetDir = Join-Path $env:USERPROFILE ".claude-server-commander"
$TargetConfig = Join-Path $TargetDir "config.json"
$RooSettingsPath = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json"

function Deploy-DCMCP {
    Write-Host "=== Deploying DesktopCommanderMCP ===" -ForegroundColor Cyan

    # 1. Create config directory
    if (-not (Test-Path $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
        Write-Host "[OK] Created $TargetDir" -ForegroundColor Green
    }

    # 2. Copy config template (UTF-8 no BOM)
    $configContent = Get-Content $ConfigTemplate -Raw -Encoding UTF8
    [System.IO.File]::WriteAllText($TargetConfig, $configContent, [System.Text.UTF8Encoding]::new($false))
    Write-Host "[OK] Config deployed to $TargetConfig" -ForegroundColor Green

    # 3. Add to Roo MCP settings
    if (Test-Path $RooSettingsPath) {
        $settings = Get-Content $RooSettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json

        if (-not $settings.mcpServers.'desktop-commander') {
            $dcConfig = @{
                command = "npx"
                args = @("-y", "@wonderwhy-er/desktop-commander@latest")
                alwaysAllow = @(
                    "start_process",
                    "read_process_output",
                    "interact_with_process",
                    "force_terminate",
                    "list_sessions",
                    "list_processes",
                    "kill_process",
                    "read_file",
                    "write_file",
                    "edit_block",
                    "list_directory",
                    "get_file_info",
                    "start_search",
                    "get_config",
                    "set_config_value"
                )
                disabled = $false
            }
            $settings.mcpServers | Add-Member -NotePropertyName "desktop-commander" -NotePropertyValue $dcConfig -Force
            $json = $settings | ConvertTo-Json -Depth 10
            [System.IO.File]::WriteAllText($RooSettingsPath, $json, [System.Text.UTF8Encoding]::new($false))
            Write-Host "[OK] Added desktop-commander to Roo MCP settings" -ForegroundColor Green
        } else {
            Write-Host "[SKIP] desktop-commander already in Roo MCP settings" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[WARN] Roo MCP settings not found at $RooSettingsPath" -ForegroundColor Yellow
    }

    Write-Host "`n=== Deployment Complete ===" -ForegroundColor Green
    Write-Host "Action required: Restart VS Code to load the new MCP" -ForegroundColor Yellow
}

function Get-Status {
    Write-Host "=== DesktopCommanderMCP Status ===" -ForegroundColor Cyan

    # Config file
    if (Test-Path $TargetConfig) {
        $config = Get-Content $TargetConfig -Raw | ConvertFrom-Json
        Write-Host "[OK] Config exists: $TargetConfig" -ForegroundColor Green
        Write-Host "  defaultShell: $($config.defaultShell)"
        Write-Host "  blockedCommands: $($config.blockedCommands.Count) entries"
        Write-Host "  telemetryEnabled: $($config.telemetryEnabled)"
    } else {
        Write-Host "[MISSING] Config not found: $TargetConfig" -ForegroundColor Red
    }

    # Roo MCP settings
    if (Test-Path $RooSettingsPath) {
        $settings = Get-Content $RooSettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($settings.mcpServers.'desktop-commander') {
            $dc = $settings.mcpServers.'desktop-commander'
            $disabled = if ($dc.disabled) { "DISABLED" } else { "ENABLED" }
            Write-Host "[OK] In Roo MCP settings: $disabled" -ForegroundColor Green
            Write-Host "  alwaysAllow: $($dc.alwaysAllow.Count) tools"
        } else {
            Write-Host "[MISSING] Not in Roo MCP settings" -ForegroundColor Red
        }

        # Win-cli status
        if ($settings.mcpServers.'win-cli') {
            $wc = $settings.mcpServers.'win-cli'
            $disabled = if ($wc.disabled) { "DISABLED" } else { "ENABLED" }
            Write-Host "[INFO] win-cli: $disabled" -ForegroundColor Cyan
        }
    }
}

function Remove-WinCli {
    Write-Host "=== Removing win-cli from Roo MCP settings ===" -ForegroundColor Yellow

    if (Test-Path $RooSettingsPath) {
        $settings = Get-Content $RooSettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json

        if ($settings.mcpServers.'win-cli') {
            # Disable instead of remove (safer)
            $settings.mcpServers.'win-cli'.disabled = $true
            $json = $settings | ConvertTo-Json -Depth 10
            [System.IO.File]::WriteAllText($RooSettingsPath, $json, [System.Text.UTF8Encoding]::new($false))
            Write-Host "[OK] win-cli disabled in Roo MCP settings" -ForegroundColor Green
            Write-Host "Action required: Restart VS Code" -ForegroundColor Yellow
        } else {
            Write-Host "[SKIP] win-cli not found in settings" -ForegroundColor Yellow
        }
    }
}

switch ($Action) {
    "deploy"        { Deploy-DCMCP }
    "status"        { Get-Status }
    "remove-wincli" { Remove-WinCli }
}
