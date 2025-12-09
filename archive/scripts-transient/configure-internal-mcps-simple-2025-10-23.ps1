# Script de configuration des MCPs internes dans mcp_settings.json
# Date: 2025-10-23
# Objectif: Ajouter les configurations des MCPs internes au fichier mcp_settings.json

Write-Host "=== CONFIGURATION DES MCPs INTERNES ===" -ForegroundColor Green
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Yellow
Write-Host ""

# Chemin du fichier mcp_settings.json
$mcpSettingsPath = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json"

# Vérifier si le fichier existe
if (-not (Test-Path $mcpSettingsPath)) {
    Write-Host "ERREUR: Fichier mcp_settings.json non trouvé à $mcpSettingsPath" -ForegroundColor Red
    exit 1
}

# Lire le fichier JSON
try {
    $mcpSettings = Get-Content $mcpSettingsPath -Raw | ConvertFrom-Json
    Write-Host "Fichier mcp_settings.json chargé avec succès" -ForegroundColor Green
} catch {
    Write-Host "ERREUR: Impossible de lire le fichier mcp_settings.json" -ForegroundColor Red
    exit 1
}

# Configuration des MCPs internes
$internalMcpConfigs = @{
    "quickfiles-server" = @{
        "command" = "node"
        "args" = @("C:\dev\roo-extensions\mcps\internal\servers\quickfiles-server\build\index.js")
        "env" = @{}
        "disabled" = $false
        "autoApprove" = @()
        "alwaysAllow" = @(
            "read_multiple_files",
            "write_multiple_files",
            "batch_file_operations"
        )
    }
    "jinavigator-server" = @{
        "command" = "node"
        "args" = @("C:\dev\roo-extensions\mcps\internal\servers\jinavigator-server\dist\index.js")
        "env" = @{}
        "disabled" = $false
        "autoApprove" = @()
        "alwaysAllow" = @(
            "convert_to_markdown",
            "web_to_markdown",
            "extract_content"
        )
    }
    "jupyter-mcp-server" = @{
        "command" = "node"
        "args" = @("C:\dev\roo-extensions\mcps\internal\servers\jupyter-mcp-server\dist\index.js")
        "env" = @{
            "JUPYTER_PATH" = "C:\Users\jsboi\AppData\Roaming\jupyter"
        }
        "disabled" = $false
        "autoApprove" = @()
        "alwaysAllow" = @(
            "execute_notebook",
            "list_notebooks",
            "get_cell_output",
            "create_notebook",
            "save_notebook"
        )
    }
    "jupyter-papermill-mcp-server" = @{
        "command" = "python"
        "args" = @("-m", "jupyter_papermill_mcp.server")
        "env" = @{
            "PYTHONPATH" = "C:\dev\roo-extensions\mcps\internal\servers\jupyter-papermill-mcp-server"
        }
        "disabled" = $false
        "autoApprove" = @()
        "alwaysAllow" = @(
            "execute_papermill",
            "parameterize_notebook",
            "schedule_execution",
            "get_execution_status"
        )
    }
    "github-projects-mcp" = @{
        "command" = "node"
        "args" = @("C:\dev\roo-extensions\mcps\internal\servers\github-projects-mcp\dist\index.js")
        "env" = @{
            "GITHUB_TOKEN" = ""
        }
        "disabled" = $false
        "autoApprove" = @()
        "alwaysAllow" = @(
            "list_projects",
            "create_project",
            "update_project",
            "get_project_columns",
            "create_project_column"
        )
    }
    "roo-state-manager" = @{
        "command" = "node"
        "args" = @("C:\dev\roo-extensions\mcps\internal\servers\roo-state-manager\build\index.js")
        "env" = @{
            "ROO_STATE_PATH" = "C:\dev\roo-extensions\.roo-state"
            "LOG_LEVEL" = "info"
        }
        "disabled" = $false
        "autoApprove" = @()
        "alwaysAllow" = @(
            "get_conversation_history",
            "save_conversation_state",
            "search_conversations",
            "export_conversations",
            "manage_state"
        )
    }
}

# Ajouter les configurations des MCPs internes
$addedCount = 0
foreach ($mcpName in $internalMcpConfigs.Keys) {
    if (-not $mcpSettings.mcpServers.ContainsKey($mcpName)) {
        Write-Host "Ajout de $mcpName..." -ForegroundColor Cyan
        $mcpSettings.mcpServers[$mcpName] = $internalMcpConfigs[$mcpName]
        $addedCount++
    } else {
        Write-Host "$mcpName existe deja, mise a jour..." -ForegroundColor Yellow
        $mcpSettings.mcpServers[$mcpName] = $internalMcpConfigs[$mcpName]
        $addedCount++
    }
}

# Sauvegarder le fichier avec une sauvegarde de l'ancienne version
$backupPath = "$mcpSettingsPath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item $mcpSettingsPath $backupPath
Write-Host "Sauvegarde creee: $backupPath" -ForegroundColor Gray

# Écrire le nouveau fichier
try {
    $mcpSettings | ConvertTo-Json -Depth 10 | Set-Content $mcpSettingsPath
    Write-Host "Fichier mcp_settings.json mis a jour avec succes" -ForegroundColor Green
} catch {
    Write-Host "ERREUR: Impossible d'ecrire le fichier mcp_settings.json" -ForegroundColor Red
    Write-Host "Restauration de la sauvegarde..." -ForegroundColor Yellow
    Copy-Item $backupPath $mcpSettingsPath
    exit 1
}

# Resume
Write-Host ""
Write-Host "=== RESUME ===" -ForegroundColor Magenta
Write-Host "MCPs internes ajoutes/mis a jour: $addedCount" -ForegroundColor Green
Write-Host "Total MCPs configures: $($mcpSettings.mcpServers.Count)" -ForegroundColor Green
Write-Host ""
Write-Host "MCPs internes configures:" -ForegroundColor Yellow
$internalMcpConfigs.Keys | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }

Write-Host ""
Write-Host "=== VALIDATION ===" -ForegroundColor Cyan
Write-Host "Verification des chemins des fichiers compiles..." -ForegroundColor Gray

$pathsToCheck = @(
    "C:\dev\roo-extensions\mcps\internal\servers\quickfiles-server\build\index.js",
    "C:\dev\roo-extensions\mcps\internal\servers\jinavigator-server\dist\index.js",
    "C:\dev\roo-extensions\mcps\internal\servers\jupyter-mcp-server\dist\index.js",
    "C:\dev\roo-extensions\mcps\internal\servers\github-projects-mcp\dist\index.js",
    "C:\dev\roo-extensions\mcps\internal\servers\roo-state-manager\build\index.js"
)

$allPathsValid = $true
foreach ($path in $pathsToCheck) {
    if (Test-Path $path) {
        Write-Host "✓ $path" -ForegroundColor Green
    } else {
        Write-Host "✗ $path" -ForegroundColor Red
        $allPathsValid = $false
    }
}

if ($allPathsValid) {
    Write-Host ""
    Write-Host "✅ Tous les chemins des fichiers compiles sont valides" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "⚠️ Certains chemins de fichiers compiles sont invalides" -ForegroundColor Yellow
}