# Script pour capturer les logs exhaustifs de build_skeleton_cache
# Date: 2025-10-22

$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "CAPTURE LOGS PHASE 3 - Investigation Bug" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Chemin du serveur MCP
$mcpServerPath = "D:\Dev\roo-extensions\mcps\internal\servers\roo-state-manager\build\index.js"

# Vérifier que le build existe
if (-not (Test-Path $mcpServerPath)) {
    Write-Host "ERREUR: Fichier build introuvable: $mcpServerPath" -ForegroundColor Red
    exit 1
}

Write-Host "Serveur MCP: $mcpServerPath" -ForegroundColor Green
Write-Host ""

# Créer un script Node.js pour appeler l'outil directement
$testScript = @'
const path = require('path');

// Simuler l'environnement MCP
process.env.ROO_DEBUG_INSTRUCTIONS = '1';

async function runTest() {
    try {
        // Importer dynamiquement le module ES
        const serverModule = await import('file://' + path.resolve('D:/Dev/roo-extensions/mcps/internal/servers/roo-state-manager/build/index.js').replace(/\\/g, '/'));
        
        console.log('[TEST] Module importé avec succès');
        
        // Le serveur MCP devrait exporter ses handlers
        // On cherche build_skeleton_cache tool
        console.log('[TEST] Recherche du tool build_skeleton_cache...');
        
        // Pour tester directement, on importe le tool
        const toolModule = await import('file://' + path.resolve('D:/Dev/roo-extensions/mcps/internal/servers/roo-state-manager/build/tools/cache/build-skeleton-cache.tool.js').replace(/\\/g, '/'));
        
        console.log('[TEST] Tool importé:', Object.keys(toolModule));
        
        // Appeler le tool avec les arguments
        const args = {
            force_rebuild: true,
            task_ids: ['18141742-f376-4053-8e1f-804d79daaf6d']
        };
        
        console.log('[TEST] Lancement avec args:', JSON.stringify(args, null, 2));
        console.log('[TEST] ========================================');
        console.log('[TEST] DÉBUT CAPTURE LOGS');
        console.log('[TEST] ========================================');
        
        const result = await toolModule.buildSkeletonCacheTool.handler(args);
        
        console.log('[TEST] ========================================');
        console.log('[TEST] FIN CAPTURE LOGS');
        console.log('[TEST] ========================================');
        console.log('[TEST] Résultat:', JSON.stringify(result, null, 2));
        
    } catch (error) {
        console.error('[TEST] ERREUR:', error);
        console.error('[TEST] Stack:', error.stack);
        process.exit(1);
    }
}

runTest();
'@

# Sauvegarder le script temporaire
$tempScriptPath = "D:\Dev\roo-extensions\scripts\validation\temp-test-phase3.mjs"
$testScript | Out-File -FilePath $tempScriptPath -Encoding UTF8

Write-Host "Script de test créé: $tempScriptPath" -ForegroundColor Green
Write-Host ""
Write-Host "Lancement du test avec capture complète des logs..." -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Lancer le script Node.js
$output = node $tempScriptPath 2>&1 | Out-String

# Afficher la sortie
Write-Host $output

# Sauvegarder dans un fichier pour analyse
$logPath = "D:\Dev\roo-extensions\outputs\phase3-debug-logs-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$output | Out-File -FilePath $logPath -Encoding UTF8

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Logs sauvegardés dans: $logPath" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

# Nettoyer le script temporaire
Remove-Item -Path $tempScriptPath -Force

Write-Host ""
Write-Host "Analyse rapide des logs capturés:" -ForegroundColor Yellow
Write-Host ""

# Extraire les lignes critiques
$criticalLines = $output -split "`n" | Where-Object {
    $_ -match '\[ENGINE-PHASE|CACHE-ENGINE|CACHE-PHASE3'
}

if ($criticalLines.Count -gt 0) {
    Write-Host "Lignes critiques trouvées ($($criticalLines.Count)):" -ForegroundColor Green
    $criticalLines | ForEach-Object {
        Write-Host "  $_"
    }
} else {
    Write-Host "ATTENTION: Aucune ligne critique trouvée!" -ForegroundColor Red
    Write-Host "Les logs ajoutés n'apparaissent pas dans la sortie." -ForegroundColor Red
}

Write-Host ""
Write-Host "Fichier complet des logs: $logPath" -ForegroundColor Cyan