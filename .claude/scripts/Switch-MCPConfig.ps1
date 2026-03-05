<#
.SYNOPSIS
    Bascule entre différentes configurations MCP pour debugger les doublons d'outils

.DESCRIPTION
    Ce script permet de tester différentes combinaisons de serveurs MCP pour identifier
    lequel cause l'erreur "Tool names must be unique" dans Claude Code VS Code.

    NOTE: github-projects-mcp a été retiré (déprécié #368, remplacé par gh CLI)

.PARAMETER Config
    Configuration à activer:
    - none: Aucun MCP (test baseline)
    - jupyter: Jupyter seul
    - roo: RooSync seul
    - jupyter-roo: Jupyter + RooSync
    - all: Tous les MCPs (config complète)
    - restore: Restaurer la config sauvegardée

.EXAMPLE
    .\Switch-MCPConfig.ps1 -Config none
    Désactive tous les MCPs

.EXAMPLE
    .\Switch-MCPConfig.ps1 -Config jupyter
    Active uniquement le serveur Jupyter

.EXAMPLE
    .\Switch-MCPConfig.ps1 -Config all
    Active tous les serveurs MCP
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('none', 'jupyter', 'roo', 'roo-direct', 'jupyter-roo', 'all', 'restore')]
    [string]$Config
)

$claudeJsonPath = "$env:USERPROFILE\.claude.json"
$backupPath = "$env:USERPROFILE\.claude.json.backup"

# Vérifier que le fichier existe
if (-not (Test-Path $claudeJsonPath)) {
    Write-Error "Fichier $claudeJsonPath non trouvé !"
    exit 1
}

# Charger le JSON
$claudeConfig = Get-Content $claudeJsonPath -Raw | ConvertFrom-Json

# Sauvegarder si pas déjà fait
if (-not (Test-Path $backupPath)) {
    Write-Host "💾 Sauvegarde de la config actuelle vers $backupPath" -ForegroundColor Cyan
    Copy-Item $claudeJsonPath $backupPath
}

# Définir les configs MCP (github-projects-mcp retiré - déprécié #368)
$mcpConfigs = @{
    jupyter = @{
        command = "conda"
        args = @(
            "run",
            "-n",
            "mcp-jupyter-py310",
            "--no-capture-output",
            "python",
            "-m",
            "papermill_mcp.main"
        )
        cwd = "D:/Dev/roo-extensions/mcps/internal/servers/jupyter-papermill-mcp-server"
        env = @{}
    }
    'roo-state-manager' = @{
        command = "node"
        args = @(
            "D:/Dev/roo-extensions/mcps/internal/servers/roo-state-manager/mcp-wrapper.cjs"
        )
        cwd = "D:/Dev/roo-extensions/mcps/internal/servers/roo-state-manager/"
        env = @{
            ROOSYNC_MACHINE_ID = "myia-po-2023"
            NOTIFICATIONS_MIN_PRIORITY = "HIGH"
            QDRANT_API_KEY = "4f89edd5-90f7-4ee0-ac25-9185e9835c44"
            NOTIFICATIONS_CHECK_INBOX = "true"
            QDRANT_URL = "https://qdrant.myia.io"
            NOTIFICATIONS_ENABLED = "true"
            ROOSYNC_AUTO_SYNC = "false"
            ROOSYNC_SHARED_PATH = "G:/Mon Drive/Synchronisation/RooSync/.shared-state"
            QDRANT_COLLECTION_NAME = "roo_tasks_semantic_index"
            NOTIFICATIONS_FILTER_CONFIG = "./config/notification-filters.json"
            ROOSYNC_CONFLICT_STRATEGY = "manual"
            ROOSYNC_LOG_LEVEL = "info"
            OPENAI_API_KEY = $env:OPENAI_API_KEY  # Use environment variable
            OPENAI_CHAT_MODEL_ID = "gpt-5-mini"
        }
    }
    'roo-state-manager-direct' = @{
        command = "node"
        args = @(
            "D:/Dev/roo-extensions/mcps/internal/servers/roo-state-manager/build/index.js"
        )
        cwd = "D:/Dev/roo-extensions/mcps/internal/servers/roo-state-manager/"
        env = @{
            ROOSYNC_MACHINE_ID = "myia-po-2023"
            ROOSYNC_SHARED_PATH = "G:/Mon Drive/Synchronisation/RooSync/.shared-state"
            ROOSYNC_LOG_LEVEL = "info"
        }
    }
}

# Fonction pour créer un objet mcpServers vide compatible
function Get-EmptyMcpServers {
    return [PSCustomObject]@{}
}

# Appliquer la configuration demandée
$claudeConfig.mcpServers = Get-EmptyMcpServers

switch ($Config) {
    'none' {
        Write-Host "❌ Désactivation de tous les MCPs" -ForegroundColor Yellow
    }
    'jupyter' {
        Write-Host "✅ Activation: Jupyter seul" -ForegroundColor Green
        $claudeConfig.mcpServers | Add-Member -NotePropertyName 'jupyter' -NotePropertyValue $mcpConfigs['jupyter']
    }
    'roo' {
        Write-Host "✅ Activation: RooSync seul (avec wrapper)" -ForegroundColor Green
        $claudeConfig.mcpServers | Add-Member -NotePropertyName 'roo-state-manager' -NotePropertyValue $mcpConfigs['roo-state-manager']
    }
    'roo-direct' {
        Write-Host "✅ Activation: RooSync SANS wrapper (tous les outils)" -ForegroundColor Yellow
        $claudeConfig.mcpServers | Add-Member -NotePropertyName 'roo-state-manager' -NotePropertyValue $mcpConfigs['roo-state-manager-direct']
    }
    'jupyter-roo' {
        Write-Host "✅ Activation: Jupyter + RooSync" -ForegroundColor Green
        $claudeConfig.mcpServers | Add-Member -NotePropertyName 'jupyter' -NotePropertyValue $mcpConfigs['jupyter']
        $claudeConfig.mcpServers | Add-Member -NotePropertyName 'roo-state-manager' -NotePropertyValue $mcpConfigs['roo-state-manager']
    }
    'all' {
        Write-Host "✅ Activation: Tous les MCPs" -ForegroundColor Green
        $claudeConfig.mcpServers | Add-Member -NotePropertyName 'jupyter' -NotePropertyValue $mcpConfigs['jupyter']
        $claudeConfig.mcpServers | Add-Member -NotePropertyName 'roo-state-manager' -NotePropertyValue $mcpConfigs['roo-state-manager']
    }
    'restore' {
        Write-Host "♻️  Restauration de la config sauvegardée" -ForegroundColor Cyan
        if (Test-Path $backupPath) {
            Copy-Item $backupPath $claudeJsonPath -Force
            Write-Host "✅ Config restaurée depuis $backupPath" -ForegroundColor Green
            Write-Host ""
            Write-Host "⚠️  Redémarrez VS Code pour appliquer les changements" -ForegroundColor Yellow
            exit 0
        } else {
            Write-Error "Backup non trouvé : $backupPath"
            exit 1
        }
    }
}

# Sauvegarder le fichier mis à jour
$claudeConfig | ConvertTo-Json -Depth 10 | Set-Content $claudeJsonPath -Encoding UTF8

Write-Host ""
Write-Host "✅ Configuration appliquée : $Config" -ForegroundColor Green
Write-Host "📄 Fichier: $claudeJsonPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "⚠️  Redémarrez complètement VS Code pour appliquer les changements" -ForegroundColor Yellow
Write-Host ""
Write-Host "📋 Prochaines étapes de debug:" -ForegroundColor Cyan
Write-Host "  1. Fermer VS Code complètement (Ctrl+Q)"
Write-Host "  2. Relancer VS Code"
Write-Host "  3. Ouvrir une conversation dans l'extension Claude Code"
Write-Host "  4. Noter si l'erreur apparaît ou non"
Write-Host ""
Write-Host "💡 Commandes utiles:" -ForegroundColor Cyan
Write-Host "  .\Switch-MCPConfig.ps1 -Config none        # Tester sans aucun MCP"
Write-Host "  .\Switch-MCPConfig.ps1 -Config jupyter     # Tester Jupyter seul"
Write-Host "  .\Switch-MCPConfig.ps1 -Config roo         # Tester RooSync seul"
Write-Host "  .\Switch-MCPConfig.ps1 -Config all         # Réactiver tous"
Write-Host "  .\Switch-MCPConfig.ps1 -Config restore     # Restaurer backup"
