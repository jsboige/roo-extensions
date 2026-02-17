# update-autoapprovals.ps1 - Met à jour les alwaysAllow pour desktop-commander
#
# Issue #473 : Auto-approbations Roo - Agents schedulés bloqués sur demandes d'approbation
#
# DesktopCommanderMCP a 26 outils mais seuls 13-14 étaient en alwaysAllow,
# causant des blocages pour le scheduler Roo.
#
# Usage : .\update-autoapprovals.ps1

$ErrorActionPreference = "Stop"

# Chemin vers les settings Roo
$rooSettingsPath = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json"

if (-not (Test-Path $rooSettingsPath)) {
    Write-Error "Roo settings not found at: $rooSettingsPath"
    exit 1
}

# Lire les settings
$settings = Get-Content $rooSettingsPath -Raw | ConvertFrom-Json

# Liste complète des 26 outils desktop-commander
$allTools = @(
    "create_directory",
    "edit_block",
    "force_terminate",
    "get_config",
    "get_file_info",
    "get_more_search_results",
    "get_prompts",
    "get_recent_tool_calls",
    "get_usage_stats",
    "give_feedback_to_desktop_commander",
    "interact_with_process",
    "kill_process",
    "list_directory",
    "list_processes",
    "list_searches",
    "list_sessions",
    "move_file",
    "read_file",
    "read_multiple_files",
    "read_process_output",
    "set_config_value",
    "start_process",
    "start_search",
    "stop_search",
    "write_file",
    "write_pdf"
)

# Mettre à jour alwaysAllow pour desktop-commander
if ($settings.mcpServers.'desktop-commander') {
    $currentCount = ($settings.mcpServers.'desktop-commander'.alwaysAllow | Measure-Object).Count
    Write-Host "Current alwaysAllow count: $currentCount" -ForegroundColor Cyan

    if ($currentCount -lt 26) {
        Write-Host "Updating alwaysAllow with missing tools..." -ForegroundColor Yellow
        $settings.mcpServers.'desktop-commander'.alwaysAllow = $allTools

        # Sauvegarder l'ancien fichier
        $backupPath = "$rooSettingsPath.bak"
        Copy-Item $rooSettingsPath $backupPath
        Write-Host "Backup saved to: $backupPath" -ForegroundColor Green

        # Écrire les nouveaux settings
        $settings | ConvertTo-Json -Depth 10 | Set-Content $rooSettingsPath -Encoding UTF8
        Write-Host "Updated alwaysAllow: 26 tools" -ForegroundColor Green
        Write-Host "Please restart VS Code Roo to apply changes" -ForegroundColor Yellow
    } else {
        Write-Host "Already up to date (26 tools)" -ForegroundColor Green
    }
} else {
    Write-Error "desktop-commander not found in mcp_settings.json"
    exit 1
}

Write-Host "`nVerification:" -ForegroundColor Cyan
Write-Host "Tools: $($settings.mcpServers.'desktop-commander'.alwaysAllow -join ', ')" -ForegroundColor Gray
