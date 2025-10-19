#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Diagnostique les exports du MCP roo-state-manager (version simplifiée)
.DESCRIPTION
    Analyse statiquement les exports disponibles dans le build
#>

$ErrorActionPreference = "Stop"

Write-Host "=== DIAGNOSTIC DES EXPORTS MCP roo-state-manager ===" -ForegroundColor Cyan
Write-Host ""

$mcpPath = "mcps/internal/servers/roo-state-manager"
$toolsIndexPath = "$mcpPath/build/src/tools/index.js"

# Test si le build existe
if (-not (Test-Path $toolsIndexPath)) {
    Write-Host "❌ ERREUR: Le fichier $toolsIndexPath n'existe pas" -ForegroundColor Red
    exit 1
}

Write-Host "📦 Analyse des exports dans le build..." -ForegroundColor Yellow
Write-Host ""

# Lire le contenu du fichier
$content = Get-Content $toolsIndexPath -Raw

# Extraire tous les exports (export * from, export {, etc.)
$exportLines = $content -split "`n" | Where-Object { $_ -match "^\s*export" -and $_ -notmatch "^//" }

Write-Host "📋 Lignes d'export trouvées:" -ForegroundColor Cyan
$exportLines | ForEach-Object {
    Write-Host "  $_"
}

Write-Host ""
Write-Host "🔍 Analyse des modules exportés..." -ForegroundColor Yellow

# Compter les exports par catégorie
$categories = @{
    'storage' = 0
    'conversation' = 0
    'task' = 0
    'search' = 0
    'export' = 0
    'indexing' = 0
    'summary' = 0
    'roosync' = 0
    'cache' = 0
    'repair' = 0
    'direct' = 0
}

foreach ($line in $exportLines) {
    if ($line -match "from '\./storage") { $categories['storage']++ }
    elseif ($line -match "from '\./conversation") { $categories['conversation']++ }
    elseif ($line -match "from '\./task") { $categories['task']++ }
    elseif ($line -match "from '\./search") { $categories['search']++ }
    elseif ($line -match "from '\./export") { $categories['export']++ }
    elseif ($line -match "from '\./indexing") { $categories['indexing']++ }
    elseif ($line -match "from '\./summary") { $categories['summary']++ }
    elseif ($line -match "from '\./roosync") { $categories['roosync']++ }
    elseif ($line -match "from '\./cache") { $categories['cache']++ }
    elseif ($line -match "from '\./repair") { $categories['repair']++ }
    else { $categories['direct']++ }
}

Write-Host "📊 Exports par catégorie:" -ForegroundColor Cyan
$categories.GetEnumerator() | Sort-Object Name | ForEach-Object {
    Write-Host "  $($_.Key): $($_.Value) ligne(s)"
}

# Analyser chaque sous-module
Write-Host ""
Write-Host "🔍 Analyse détaillée des sous-modules..." -ForegroundColor Yellow

$submodules = @(
    'storage',
    'conversation', 
    'task',
    'search',
    'export',
    'indexing',
    'summary',
    'roosync',
    'cache',
    'repair'
)

$totalTools = 0

foreach ($module in $submodules) {
    $modulePath = "$mcpPath/build/src/tools/$module/index.js"
    if (Test-Path $modulePath) {
        $moduleContent = Get-Content $modulePath -Raw
        
        # Compter les exports individuels (pas les re-exports)
        $toolDefinitions = ($moduleContent | Select-String -Pattern "Tool\s*=\s*\{" -AllMatches).Matches.Count
        $toolMetadata = ($moduleContent | Select-String -Pattern "ToolMetadata\s*=\s*\{" -AllMatches).Matches.Count
        $toolHandlers = ($moduleContent | Select-String -Pattern "export\s+(const|function)" -AllMatches).Matches.Count
        
        $moduleTotal = [Math]::Max($toolDefinitions, [Math]::Max($toolMetadata, $toolHandlers))
        $totalTools += $moduleTotal
        
        Write-Host "  ✓ $module : ~$moduleTotal outil(s)"
    } else {
        Write-Host "  ⚠ $module : module non trouvé" -ForegroundColor Yellow
    }
}

# Compter les exports directs (non catégorisés)
$directExports = ($content | Select-String -Pattern "export.*from '\.\/(read-vscode-logs|rebuild-and-restart|manage-mcp-settings|get_mcp_best_practices|view-conversation-tree)" -AllMatches).Matches.Count
$totalTools += $directExports

Write-Host "  ✓ direct : $directExports outil(s)"

Write-Host ""
Write-Host "📊 ESTIMATION TOTALE: ~$totalTools outils exportés" -ForegroundColor Green

# Vérifier les outils désactivés (commentés)
$disabledLines = $content -split "`n" | Where-Object { $_ -match "^//" -and $_ -match "export" }
if ($disabledLines) {
    Write-Host ""
    Write-Host "⚠️  Exports désactivés (commentés):" -ForegroundColor Yellow
    $disabledLines | ForEach-Object {
        Write-Host "  $_" -ForegroundColor DarkGray
    }
}

# Analyser le registry pour voir combien d'outils sont enregistrés
Write-Host ""
Write-Host "🔍 Analyse du registry..." -ForegroundColor Yellow

$registryPath = "$mcpPath/build/src/tools/registry.js"
if (Test-Path $registryPath) {
    $registryContent = Get-Content $registryPath -Raw
    
    # Compter les outils enregistrés dans la fonction registerListToolsHandler
    $listToolsSection = $registryContent -match 'tools:\s*\[(.*?)\]' -replace '(?s).*tools:\s*\[(.*?)\].*', '$1'
    
    # Compter les entrées (chaque ligne avec toolExports ou nom d'outil)
    $registeredCount = ($registryContent | Select-String -Pattern "toolExports\.|name:\s*'|name:\s*toolExports\." -AllMatches).Matches.Count
    
    # Ajouter le spread operator roosyncTools
    if ($registryContent -match '\.\.\.toolExports\.roosyncTools') {
        Write-Host "  ✓ Registry contient le spread ...toolExports.roosyncTools"
        # RooSync a 9 outils
        $roosyncCount = 9
        Write-Host "    → Cela devrait ajouter $roosyncCount outils RooSync"
    }
    
    Write-Host "  ✓ Registry : ~$registeredCount outils + spread RooSync"
}

Write-Host ""
Write-Host "💾 Analyse terminée" -ForegroundColor Green