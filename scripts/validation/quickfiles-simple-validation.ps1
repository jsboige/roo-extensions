<#
.SYNOPSIS
    Script de validation simple du MCP QuickFiles
.DESCRIPTION
    Validation rapide de la compilation et des corrections des descriptions
.VERSION
    1.0.0
.DATE
    2025-11-02
#>

# Configuration
$ErrorActionPreference = "Stop"

Write-Host "=== VALIDATION MCP QUICKFILES ===" -ForegroundColor Cyan
Write-Host "Début: $(Get-Date)" -ForegroundColor Gray

# Étape 1: Compilation
Write-Host "`n1. COMPILATION" -ForegroundColor Yellow
Set-Location "mcps/internal/servers/quickfiles-server"

try {
    $BuildResult = & npm run build 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Compilation réussie" -ForegroundColor Green
    } else {
        Write-Host "❌ Compilation échouée" -ForegroundColor Red
        Write-Host $BuildResult -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ Exception compilation: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Étape 2: Validation des descriptions
Write-Host "`n2. VALIDATION DES DESCRIPTIONS" -ForegroundColor Yellow

$SourceFile = Get-Content -Path "src/index.ts" -Raw

# Vérification émojis
if ($SourceFile -match 'list_directory_contents.*📁') {
    Write-Host "✅ Émojis présents dans list_directory_contents" -ForegroundColor Green
} else {
    Write-Host "❌ Émojis manquants dans list_directory_contents" -ForegroundColor Red
}

# Vérification descriptions professionnelles
if ($SourceFile -match 'professionnelles') {
    Write-Host "✅ Descriptions professionnelles présentes" -ForegroundColor Green
} else {
    Write-Host "❌ Descriptions professionnelles manquantes" -ForegroundColor Red
}

# Vérification absence métriques
if ($SourceFile -notmatch 'performance|metrics') {
    Write-Host "✅ Métriques inutiles supprimées" -ForegroundColor Green
} else {
    Write-Host "❌ Métriques inutiles encore présentes" -ForegroundColor Red
}

# Étape 3: Tests simples
Write-Host "`n3. TESTS SIMPLIFIÉS" -ForegroundColor Yellow

# Test build files
if (Test-Path "build/index.js") {
    Write-Host "✅ Fichier build/index.js présent" -ForegroundColor Green
} else {
    Write-Host "❌ Fichier build/index.js manquant" -ForegroundColor Red
}

# Test package.json
if (Test-Path "package.json") {
    Write-Host "✅ Fichier package.json présent" -ForegroundColor Green
} else {
    Write-Host "❌ Fichier package.json manquant" -ForegroundColor Red
}

# Étape 4: Git status
Write-Host "`n4. STATUS GIT" -ForegroundColor Yellow
Set-Location "../../../"

$GitStatus = & git status --porcelain mcps/internal/servers/quickfiles-server/ 2>&1
if ($GitStatus) {
    Write-Host "📝 Fichiers modifiés détectés:" -ForegroundColor Cyan
    Write-Host $GitStatus -ForegroundColor Gray
} else {
    Write-Host "ℹ️ Aucun fichier modifié détecté" -ForegroundColor Gray
}

# Résumé
Write-Host "`n=== RÉSUMÉ ===" -ForegroundColor Cyan
Write-Host "Compilation: ✅ Succès" -ForegroundColor Green
Write-Host "Validations: Vérifier ci-dessus" -ForegroundColor Yellow
Write-Host "Prochaine étape: git add && git commit && git push" -ForegroundColor Gray

Write-Host "`nFin: $(Get-Date)" -ForegroundColor Gray