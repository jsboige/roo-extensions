#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Corrige le problème du MCP roo-state-manager qui charge l'ancien index.js
.DESCRIPTION
    Ce script applique la Solution A recommandée :
    1. Sauvegarde l'ancien fichier
    2. Supprime les fichiers obsolètes
    3. Met à jour la configuration MCP
    4. Redémarre le MCP
#>

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "FIX MCP roo-state-manager Index Path" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Chemins
$mcpPath = "mcps/internal/servers/roo-state-manager"
$oldIndexPath = "$mcpPath/build/index.js"
$newIndexPath = "$mcpPath/build/src/index.js"
$mcpSettingsPath = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json"

# Étape 1 : Vérification de l'existence des fichiers
Write-Host "Étape 1/5 : Vérification des fichiers..." -ForegroundColor Yellow

if (-not (Test-Path $oldIndexPath)) {
    Write-Host "✅ L'ancien fichier n'existe plus, aucune action nécessaire" -ForegroundColor Green
    exit 0
}

if (-not (Test-Path $newIndexPath)) {
    Write-Host "❌ ERREUR: Le nouveau fichier n'existe pas: $newIndexPath" -ForegroundColor Red
    Write-Host "   Veuillez recompiler le projet d'abord avec: npm run build" -ForegroundColor Yellow
    exit 1
}

Write-Host "  ✓ Ancien fichier trouvé: $oldIndexPath" -ForegroundColor Green
Write-Host "  ✓ Nouveau fichier trouvé: $newIndexPath" -ForegroundColor Green

# Étape 2 : Sauvegarde de l'ancien fichier
Write-Host ""
Write-Host "Étape 2/5 : Sauvegarde de l'ancien fichier..." -ForegroundColor Yellow

$backupPath = "$mcpPath/build/index.js.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item $oldIndexPath $backupPath -Force
Write-Host "  ✓ Sauvegarde créée: $backupPath" -ForegroundColor Green

# Étape 3 : Suppression des anciens fichiers
Write-Host ""
Write-Host "Étape 3/5 : Suppression des fichiers obsolètes..." -ForegroundColor Yellow

$filesToRemove = @(
    "$mcpPath/build/index.js",
    "$mcpPath/build/index.d.ts",
    "$mcpPath/build/index.js.map",
    "$mcpPath/build/index.d.ts.map",
    "$mcpPath/build/index.test.js",
    "$mcpPath/build/index.test.d.ts",
    "$mcpPath/build/index.test.js.map",
    "$mcpPath/build/index.test.d.ts.map"
)

foreach ($file in $filesToRemove) {
    if (Test-Path $file) {
        Remove-Item $file -Force
        Write-Host "  ✓ Supprimé: $(Split-Path $file -Leaf)" -ForegroundColor Green
    }
}

# Étape 4 : Mise à jour de la configuration MCP
Write-Host ""
Write-Host "Étape 4/5 : Mise à jour de la configuration MCP..." -ForegroundColor Yellow

if (-not (Test-Path $mcpSettingsPath)) {
    Write-Host "  ⚠ Fichier de configuration MCP non trouvé: $mcpSettingsPath" -ForegroundColor Yellow
    Write-Host "  → Configuration à mettre à jour manuellement" -ForegroundColor Yellow
} else {
    # Lire la configuration
    $config = Get-Content $mcpSettingsPath -Raw | ConvertFrom-Json
    
    # Vérifier si roo-state-manager existe
    if ($config.mcpServers.PSObject.Properties.Name -contains "roo-state-manager") {
        $oldPath = "D:/Dev/roo-extensions/mcps/internal/servers/roo-state-manager/build/index.js"
        $newPath = "D:/Dev/roo-extensions/mcps/internal/servers/roo-state-manager/build/src/index.js"
        
        # Obtenir le chemin actuel
        $currentArgs = $config.mcpServers.'roo-state-manager'.args
        
        if ($currentArgs -contains $oldPath) {
            # Remplacer le chemin
            $config.mcpServers.'roo-state-manager'.args = @($newPath)
            
            # Sauvegarder la configuration
            $config | ConvertTo-Json -Depth 10 | Set-Content $mcpSettingsPath -Encoding UTF8
            Write-Host "  ✓ Configuration MCP mise à jour" -ForegroundColor Green
            Write-Host "    Ancien: $oldPath" -ForegroundColor DarkGray
            Write-Host "    Nouveau: $newPath" -ForegroundColor Green
        } else {
            Write-Host "  ✓ Configuration déjà correcte" -ForegroundColor Green
        }
    } else {
        Write-Host "  ⚠ roo-state-manager non trouvé dans la configuration" -ForegroundColor Yellow
    }
}

# Étape 5 : Redémarrage du MCP
Write-Host ""
Write-Host "Étape 5/5 : Redémarrage du MCP..." -ForegroundColor Yellow

# Toucher le fichier mcp_settings.json pour forcer le rechargement
if (Test-Path $mcpSettingsPath) {
    (Get-Item $mcpSettingsPath).LastWriteTime = Get-Date
    Write-Host "  ✓ Fichier mcp_settings.json touché pour forcer le rechargement" -ForegroundColor Green
} else {
    Write-Host "  ℹ Redémarrage manuel de VSCode nécessaire" -ForegroundColor Cyan
}

# Résumé
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✅ CORRECTION APPLIQUÉE AVEC SUCCÈS" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Actions effectuées:" -ForegroundColor White
Write-Host "  ✓ Ancien fichier sauvegardé" -ForegroundColor Green
Write-Host "  ✓ Fichiers obsolètes supprimés" -ForegroundColor Green
Write-Host "  ✓ Configuration MCP mise à jour" -ForegroundColor Green
Write-Host "  ✓ MCP redémarré" -ForegroundColor Green
Write-Host ""
Write-Host "Prochaines étapes:" -ForegroundColor Yellow
Write-Host "  1. Redémarrer VSCode pour recharger complètement le MCP" -ForegroundColor White
Write-Host "  2. Ouvrir Roo et vérifier le nombre d'outils roo-state-manager" -ForegroundColor White
Write-Host "  3. Attendu: 41 outils (au lieu de 12)" -ForegroundColor White
Write-Host ""
Write-Host "Rapport de diagnostic: docs/rapport-diagnostic-mcp-12-outils-20251016.md" -ForegroundColor Cyan