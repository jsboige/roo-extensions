#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Diagnostique les exports du MCP roo-state-manager
.DESCRIPTION
    Vérifie quels exports sont disponibles dans le build et lesquels sont manquants
#>

$ErrorActionPreference = "Stop"

Write-Host "=== DIAGNOSTIC DES EXPORTS MCP roo-state-manager ===" -ForegroundColor Cyan
Write-Host ""

$mcpPath = "mcps/internal/servers/roo-state-manager"

# Test si le build existe
if (-not (Test-Path "$mcpPath/build/src/tools/index.js")) {
    Write-Host "❌ ERREUR: Le fichier build/src/tools/index.js n'existe pas" -ForegroundColor Red
    exit 1
}

Write-Host "📦 Analyse des exports disponibles dans le build..." -ForegroundColor Yellow

# Obtenir le chemin absolu
$absoluteMcpPath = Resolve-Path $mcpPath | Select-Object -ExpandProperty Path
$toolsIndexPath = Join-Path $absoluteMcpPath "build\src\tools\index.js"

# Convertir en chemin URL pour Node.js ESM
$toolsIndexUrl = "file:///" + $toolsIndexPath.Replace("\", "/")

# Créer un script Node.js temporaire pour lister les exports
$nodeScript = @"
import * as tools from '$toolsIndexUrl';

const exports = Object.keys(tools).sort();
console.log(JSON.stringify({
    count: exports.length,
    exports: exports
}, null, 2));
"@

$tempFile = [System.IO.Path]::GetTempFileName() + ".mjs"
Set-Content -Path $tempFile -Value $nodeScript -Encoding UTF8

try {
    $result = node $tempFile 2>&1 | Out-String
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ ERREUR lors de l'analyse des exports:" -ForegroundColor Red
        Write-Host $result
        exit 1
    }
    
    $data = $result | ConvertFrom-Json
    
    Write-Host "✅ Exports trouvés: $($data.count)" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 Liste des exports:" -ForegroundColor Cyan
    $data.exports | ForEach-Object {
        Write-Host "  - $_"
    }
    
    # Exports attendus dans le registry (ligne 8-101 de registry.js)
    $expectedInRegistry = @(
        'detectStorageTool',
        'getStorageStatsTool',
        'listConversationsTool',
        'buildSkeletonCacheDefinition',
        'getTaskTreeTool',
        'debugTaskParsingTool',
        'searchTasksSemanticTool',
        'debugAnalyzeTool',
        'viewConversationTree',
        'readVscodeLogs',
        'manageMcpSettings',
        'indexTaskSemanticTool',
        'resetQdrantCollectionTool',
        'rebuildAndRestart',
        'getMcpBestPractices',
        'rebuildTaskIndexFixed',
        'diagnoseConversationBomTool',
        'repairConversationBomTool',
        'exportTasksXmlTool',
        'exportConversationXmlTool',
        'exportProjectXmlTool',
        'configureXmlExportTool',
        'generateTraceSummaryTool',
        'generateClusterSummaryTool',
        'exportConversationJsonTool',
        'exportConversationCsvTool',
        'viewTaskDetailsTool',
        'getRawConversationTool',
        'getConversationSynthesisTool',
        'exportTaskTreeMarkdownTool',
        'handleBuildSkeletonCache',
        'handleGetTaskTree',
        'handleSearchTasksSemanticFallback',
        'handleDiagnoseSemanticIndex',
        'handleDebugTaskParsing',
        'handleGenerateTraceSummary',
        'handleGenerateClusterSummary',
        'handleExportTasksXml',
        'handleExportConversationXml',
        'handleExportProjectXml',
        'handleConfigureXmlExport',
        'handleGetConversationSynthesis',
        'handleExportTaskTreeMarkdown',
        'roosyncTools',
        'roosyncGetStatus',
        'roosyncCompareConfig',
        'roosyncListDiffs',
        'roosyncApproveDecision',
        'roosyncRejectDecision',
        'roosyncApplyDecision',
        'roosyncRollbackDecision',
        'roosyncGetDecisionDetails',
        'roosyncInit'
    )
    
    Write-Host ""
    Write-Host "🔍 Vérification des exports requis par le registry..." -ForegroundColor Yellow
    
    $missing = @()
    foreach ($expected in $expectedInRegistry) {
        if ($data.exports -notcontains $expected) {
            $missing += $expected
        }
    }
    
    if ($missing.Count -eq 0) {
        Write-Host "✅ Tous les exports requis sont présents!" -ForegroundColor Green
    } else {
        Write-Host "❌ Exports MANQUANTS ($($missing.Count)):" -ForegroundColor Red
        $missing | ForEach-Object {
            Write-Host "  - $_" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "📊 RÉSUMÉ:" -ForegroundColor Cyan
    Write-Host "  Exports disponibles: $($data.count)"
    Write-Host "  Exports requis: $($expectedInRegistry.Count)"
    Write-Host "  Exports manquants: $($missing.Count)"
    
    # Sauvegarder le rapport
    $reportPath = "outputs/diagnostic-exports-mcp-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $reportData = @{
        timestamp = Get-Date -Format "o"
        available_count = $data.count
        required_count = $expectedInRegistry.Count
        missing_count = $missing.Count
        available_exports = $data.exports
        required_exports = $expectedInRegistry
        missing_exports = $missing
    }
    
    New-Item -ItemType Directory -Force -Path "outputs" | Out-Null
    $reportData | ConvertTo-Json -Depth 10 | Set-Content -Path $reportPath -Encoding UTF8
    Write-Host ""
    Write-Host "💾 Rapport sauvegardé: $reportPath" -ForegroundColor Green
    
    exit $missing.Count
    
} finally {
    Remove-Item -Path $tempFile -ErrorAction SilentlyContinue
}