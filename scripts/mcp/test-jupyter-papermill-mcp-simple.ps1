#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test d'intégration MCP simplifié pour le serveur Jupyter-Papermill consolidé
    
.DESCRIPTION
    Version simplifiée des tests d'intégration MCP
    
.PARAMETER Environment 
    Nom de l'environnement conda (défaut: mcp-jupyter-py310)
#>

param(
    [string]$Environment = "mcp-jupyter-py310"
)

# Configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Couleurs
$Green = "`e[32m"
$Red = "`e[31m"
$Yellow = "`e[33m"
$Blue = "`e[34m"
$Reset = "`e[0m"

function Write-ColoredOutput {
    param([string]$Message, [string]$Color = $Reset)
    Write-Host "${Color}${Message}${Reset}"
}

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-ColoredOutput "=" * 60 $Blue
    Write-ColoredOutput "  $Title" $Blue
    Write-ColoredOutput "=" * 60 $Blue
}

# === TESTS ===
Write-Section "TEST INTÉGRATION MCP - JUPYTER-PAPERMILL"

$testResults = @{}
$scriptDir = Split-Path -Parent $MyInvocation.ScriptName
$serverPath = Join-Path (Split-Path -Parent (Split-Path -Parent $scriptDir)) "mcps\internal\servers\jupyter-papermill-mcp-server"

Write-ColoredOutput "📍 Serveur: $serverPath" $Blue

# Test 1: Environnement conda
Write-Section "1. VÉRIFICATION ENVIRONNEMENT CONDA"
try {
    $condaInfo = conda info --envs 2>$null | Select-String $Environment
    if ($condaInfo) {
        Write-ColoredOutput "✅ Environnement conda '$Environment' trouvé" $Green
        $testResults["conda"] = $true
    } else {
        Write-ColoredOutput "❌ Environnement conda '$Environment' non trouvé" $Red
        $testResults["conda"] = $false
    }
} catch {
    Write-ColoredOutput "❌ Erreur conda: $_" $Red
    $testResults["conda"] = $false
}

# Test 2: Structure du serveur
Write-Section "2. VÉRIFICATION STRUCTURE SERVEUR"
$requiredFiles = @("main.py", "pyproject.toml")
$requiredDirs = @("papermill_mcp")

$structureOk = $true
foreach ($file in $requiredFiles) {
    $filePath = Join-Path $serverPath $file
    if (Test-Path $filePath) {
        Write-ColoredOutput "✅ $file présent" $Green
    } else {
        Write-ColoredOutput "❌ $file manquant" $Red
        $structureOk = $false
    }
}

foreach ($dir in $requiredDirs) {
    $dirPath = Join-Path $serverPath $dir
    if (Test-Path $dirPath) {
        Write-ColoredOutput "✅ $dir/ présent" $Green
    } else {
        Write-ColoredOutput "❌ $dir/ manquant" $Red
        $structureOk = $false
    }
}

$testResults["structure"] = $structureOk

# Test 3: Test d'importation Python simple
Write-Section "3. TEST IMPORTATION PYTHON"
if ($testResults["conda"]) {
    try {
        Push-Location $serverPath
        # Création d'un fichier Python temporaire
        $tempPyFile = Join-Path $env:TEMP "test_import_$(Get-Random).py"
        @'
try:
    from papermill_mcp import main
    print('IMPORT_SUCCESS')
except Exception as e:
    print('IMPORT_ERROR:' + str(e))
'@ | Out-File -FilePath $tempPyFile -Encoding UTF8
        
        $importTest = & conda run -n $Environment --no-capture-output python $tempPyFile 2>&1
        Remove-Item $tempPyFile -ErrorAction SilentlyContinue
        
        if ($importTest -match "IMPORT_SUCCESS") {
            Write-ColoredOutput "✅ Importation du serveur réussie" $Green
            $testResults["import"] = $true
        } else {
            Write-ColoredOutput "❌ Erreur d'importation: $importTest" $Red
            $testResults["import"] = $false
        }
    } catch {
        Write-ColoredOutput "❌ Erreur test importation: $_" $Red
        $testResults["import"] = $false
    } finally {
        Pop-Location
    }
} else {
    Write-ColoredOutput "⚠️ Test d'importation ignoré (conda non disponible)" $Yellow
    $testResults["import"] = $false
}

# Test 4: Vérification des outils consolidés
Write-Section "4. VÉRIFICATION OUTILS CONSOLIDÉS"
$toolsPath = Join-Path $serverPath "papermill_mcp\tools"
if (Test-Path $toolsPath) {
    $toolFiles = Get-ChildItem $toolsPath -Filter "*_tools.py"
    $totalTools = 0
    
    foreach ($file in $toolFiles) {
        $content = Get-Content $file.FullName -Raw
        $matches = [regex]::Matches($content, '@app\.tool\(\)')
        $count = $matches.Count
        $totalTools += $count
        
        $moduleName = $file.BaseName -replace '_tools$', ''
        Write-ColoredOutput "  📦 $moduleName : $count outils" $Blue
    }
    
    Write-ColoredOutput "📊 Total: $totalTools outils consolidés" $Green
    $testResults["tools_count"] = $totalTools
    $testResults["tools"] = ($totalTools -ge 25) # Au moins 25 outils attendus
} else {
    Write-ColoredOutput "❌ Répertoire tools/ non trouvé" $Red
    $testResults["tools"] = $false
    $testResults["tools_count"] = 0
}

# Résumé des résultats
Write-Section "RÉSUMÉ DES TESTS"
$successCount = ($testResults.Values | Where-Object { $_ -eq $true }).Count
$totalCount = $testResults.Count - 1 # -1 pour tools_count qui n'est pas un booléen

$globalScore = [Math]::Round(($successCount / $totalCount) * 100, 1)

Write-ColoredOutput "📊 Tests réussis: $successCount/$totalCount" $Blue
Write-ColoredOutput "📊 Score global: $globalScore%" $Blue
Write-ColoredOutput "🔧 Outils consolidés: $($testResults["tools_count"])" $Blue

if ($globalScore -ge 80) {
    Write-ColoredOutput "🎉 INTÉGRATION MCP VALIDÉE" $Green
    $finalStatus = "SUCCESS"
} elseif ($globalScore -ge 60) {
    Write-ColoredOutput "⚠️ INTÉGRATION MCP PARTIELLE" $Yellow
    $finalStatus = "PARTIAL"
} else {
    Write-ColoredOutput "❌ INTÉGRATION MCP ÉCHOUÉE" $Red
    $finalStatus = "FAILED"
}

# Génération d'un rapport simple
$reportPath = Join-Path $PWD "test-mcp-integration-simple-report.md"
$report = @"
# RAPPORT TEST INTÉGRATION MCP SIMPLIFIÉ
**Date**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Statut**: $finalStatus
**Score**: $globalScore%

## Résultats détaillés
- Environnement conda: $(if ($testResults["conda"]) { "✅ OK" } else { "❌ KO" })
- Structure serveur: $(if ($testResults["structure"]) { "✅ OK" } else { "❌ KO" })
- Importation Python: $(if ($testResults["import"]) { "✅ OK" } else { "❌ KO" })
- Outils consolidés: $(if ($testResults["tools"]) { "✅ OK ($($testResults["tools_count"]) outils)" } else { "❌ KO" })

## Conclusion
$(if ($finalStatus -eq "SUCCESS") {
    "✅ Le serveur Jupyter-Papermill consolidé est prêt pour les tests d'intégration complets."
} elseif ($finalStatus -eq "PARTIAL") {
    "⚠️ Le serveur présente quelques problèmes mais reste fonctionnel."
} else {
    "❌ Des corrections sont nécessaires avant la mise en production."
})
"@

$report | Out-File -FilePath $reportPath -Encoding UTF8
Write-ColoredOutput "📄 Rapport généré: $reportPath" $Magenta

exit $(if ($finalStatus -eq "SUCCESS") { 0 } elseif ($finalStatus -eq "PARTIAL") { 1 } else { 2 })