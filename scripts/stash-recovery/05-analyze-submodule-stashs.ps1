# ============================================================================
# Script: Analyse Détaillée des Stashs d'un Sous-Module
# Date: 2025-10-16
# Description: Analyse complète de chaque stash avec catégorisation
# ============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$SubmodulePath,
    
    [Parameter(Mandatory=$false)]
    [int]$StashIndex = -1
)

$ErrorActionPreference = "Continue"
$repoRoot = "d:/dev/roo-extensions"
$fullPath = Join-Path $repoRoot $SubmodulePath

Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║        ANALYSE DÉTAILLÉE DES STASHS - SOUS-MODULE      ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

if(-not (Test-Path $fullPath)) {
    Write-Host "❌ Erreur: Chemin introuvable - $fullPath" -ForegroundColor Red
    exit 1
}

Push-Location $fullPath

try {
    # Lister tous les stashs
    $stashList = git stash list 2>&1
    if($LASTEXITCODE -ne 0 -or -not $stashList) {
        Write-Host "✅ Aucun stash trouvé dans ce sous-module" -ForegroundColor Green
        Pop-Location
        exit 0
    }
    
    $stashes = $stashList -split "`n" | Where-Object { $_.Trim() -ne "" }
    
    Write-Host "📦 Sous-module: $SubmodulePath" -ForegroundColor Yellow
    Write-Host "📊 Nombre de stashs: $($stashes.Count)" -ForegroundColor White
    Write-Host ""
    
    $analysisResults = @()
    
    # Déterminer les stashs à analyser
    $stashesToAnalyze = if($StashIndex -ge 0) {
        @($stashes[$StashIndex])
    } else {
        $stashes
    }
    
    foreach($stashLine in $stashesToAnalyze) {
        # Extraire l'index du stash
        if($stashLine -match 'stash@\{(\d+)\}') {
            $idx = $matches[1]
        } else {
            continue
        }
        
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkGray
        Write-Host "🔍 ANALYSE: stash@{$idx}" -ForegroundColor Cyan
        Write-Host "───────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host $stashLine -ForegroundColor Gray
        Write-Host ""
        
        # Obtenir les détails du stash
        $stashShow = git stash show -p "stash@{$idx}" 2>&1
        $stashStats = git stash show --stat "stash@{$idx}" 2>&1
        
        Write-Host "📈 Statistiques:" -ForegroundColor Yellow
        foreach($line in ($stashStats -split "`n")) {
            if($line.Trim() -ne "") {
                Write-Host "   $line" -ForegroundColor White
            }
        }
        Write-Host ""
        
        # Analyser le contenu
        $filesChanged = @()
        $additions = 0
        $deletions = 0
        $hasNodeModules = $false
        $hasBuildArtifacts = $false
        $hasConfig = $false
        $hasSourceCode = $false
        $hasTests = $false
        $hasDocs = $false
        $hasTempFiles = $false
        
        foreach($line in ($stashShow -split "`n")) {
            # Détecter les fichiers modifiés
            if($line -match '^\+\+\+ b/(.+)$') {
                $file = $matches[1]
                $filesChanged += $file
                
                # Catégorisation
                if($file -match 'node_modules|package-lock\.json') { $hasNodeModules = $true }
                if($file -match 'dist/|build/|\.js\.map$') { $hasBuildArtifacts = $true }
                if($file -match '\.config\.|\.json$|\.env') { $hasConfig = $true }
                if($file -match '\.(ts|js|py)$' -and $file -notmatch '\.test\.|\.spec\.') { $hasSourceCode = $true }
                if($file -match '\.test\.|\.spec\.|/tests?/') { $hasTests = $true }
                if($file -match '\.md$|/docs?/') { $hasDocs = $true }
                if($file -match '\.tmp$|\.log$|\.cache') { $hasTempFiles = $true }
            }
            
            # Compter additions/suppressions
            if($line -match '^\+' -and $line -notmatch '^\+\+\+') { $additions++ }
            if($line -match '^-' -and $line -notmatch '^---') { $deletions++ }
        }
        
        # Catégorisation finale
        $category = "UNKNOWN"
        $priority = "BASSE"
        $recommendation = ""
        
        if($hasTempFiles -or $hasNodeModules) {
            $category = "🗑️ OBSOLÈTE"
            $priority = "IGNORER"
            $recommendation = "Contient des fichiers temporaires ou node_modules - À supprimer"
        }
        elseif($hasBuildArtifacts -and -not $hasSourceCode) {
            $category = "🗑️ BUILD_ARTIFACTS"
            $priority = "IGNORER"
            $recommendation = "Contient uniquement des artifacts de build - À supprimer"
        }
        elseif($hasSourceCode -or $hasTests) {
            $category = "✅ RÉCUPÉRABLE"
            $priority = "HAUTE"
            $recommendation = "Contient du code source ou des tests - À examiner en détail"
        }
        elseif($hasDocs) {
            $category = "⚠️ DOCUMENTATION"
            $priority = "MOYENNE"
            $recommendation = "Contient de la documentation - À évaluer"
        }
        elseif($hasConfig) {
            $category = "⚠️ CONFIGURATION"
            $priority = "MOYENNE"
            $recommendation = "Contient des fichiers de configuration - À évaluer"
        }
        else {
            $category = "⚠️ À_ÉVALUER"
            $priority = "BASSE"
            $recommendation = "Contenu mixte - Examen manuel requis"
        }
        
        Write-Host "🏷️  Catégorie: $category" -ForegroundColor $(
            if($category -like "*RÉCUPÉRABLE*") { 'Green' }
            elseif($category -like "*OBSOLÈTE*" -or $category -like "*BUILD_ARTIFACTS*") { 'Red' }
            else { 'Yellow' }
        )
        Write-Host "⚡ Priorité: $priority" -ForegroundColor $(
            if($priority -eq "HAUTE") { 'Red' }
            elseif($priority -eq "MOYENNE") { 'Yellow' }
            else { 'Gray' }
        )
        Write-Host "💡 Recommandation: $recommendation" -ForegroundColor Cyan
        Write-Host ""
        
        Write-Host "📁 Fichiers modifiés ($($filesChanged.Count)):" -ForegroundColor Yellow
        foreach($file in $filesChanged | Select-Object -First 20) {
            Write-Host "   • $file" -ForegroundColor Gray
        }
        if($filesChanged.Count -gt 20) {
            Write-Host "   ... et $($filesChanged.Count - 20) autres fichiers" -ForegroundColor DarkGray
        }
        Write-Host ""
        
        Write-Host "📊 Modifications:" -ForegroundColor Yellow
        Write-Host "   • Ajouts: $additions lignes" -ForegroundColor Green
        Write-Host "   • Suppressions: $deletions lignes" -ForegroundColor Red
        Write-Host ""
        
        # Stocker le résultat
        $analysisResults += [PSCustomObject]@{
            StashIndex = $idx
            StashLine = $stashLine
            Category = $category
            Priority = $priority
            Recommendation = $recommendation
            FilesChanged = $filesChanged
            Additions = $additions
            Deletions = $deletions
            HasSourceCode = $hasSourceCode
            HasTests = $hasTests
            HasDocs = $hasDocs
            HasConfig = $hasConfig
            HasNodeModules = $hasNodeModules
            HasBuildArtifacts = $hasBuildArtifacts
            HasTempFiles = $hasTempFiles
        }
    }
    
    # ============================================================================
    # RÉSUMÉ DE L'ANALYSE
    # ============================================================================
    
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                   RÉSUMÉ DE L'ANALYSE                   ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    $recuperables = ($analysisResults | Where-Object { $_.Category -like "*RÉCUPÉRABLE*" }).Count
    $aEvaluer = ($analysisResults | Where-Object { $_.Category -like "*ÉVALUER*" -or $_.Category -like "*DOCUMENTATION*" -or $_.Category -like "*CONFIGURATION*" }).Count
    $obsoletes = ($analysisResults | Where-Object { $_.Category -like "*OBSOLÈTE*" -or $_.Category -like "*BUILD_ARTIFACTS*" }).Count
    
    Write-Host "📊 Répartition:" -ForegroundColor White
    Write-Host "   • ✅ Récupérables: $recuperables" -ForegroundColor Green
    Write-Host "   • ⚠️  À évaluer: $aEvaluer" -ForegroundColor Yellow
    Write-Host "   • 🗑️  Obsolètes: $obsoletes" -ForegroundColor Red
    Write-Host ""
    
    if($recuperables -gt 0) {
        Write-Host "🎯 ACTIONS PRIORITAIRES:" -ForegroundColor Green
        $priorityStashs = $analysisResults | Where-Object { $_.Priority -eq "HAUTE" }
        foreach($stash in $priorityStashs) {
            Write-Host "   1. Examiner stash@{$($stash.StashIndex)} - $($stash.Recommendation)" -ForegroundColor White
        }
    }
    
    # ============================================================================
    # EXPORT DES RÉSULTATS
    # ============================================================================
    
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $outputDir = Join-Path $repoRoot "scripts/stash-recovery/results"
    if(-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    $safeSubmoduleName = $SubmodulePath -replace '[/\\:]', '-'
    $jsonOutput = Join-Path $outputDir "analysis-$safeSubmoduleName-$timestamp.json"
    $analysisResults | ConvertTo-Json -Depth 10 | Out-File $jsonOutput -Encoding UTF8
    
    Write-Host "`n📄 Analyse exportée:" -ForegroundColor Cyan
    Write-Host "   $jsonOutput" -ForegroundColor Gray
    
    Write-Host "`n✅ Analyse terminée avec succès" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════════`n" -ForegroundColor Cyan
    
} catch {
    Write-Host "`n❌ Erreur lors de l'analyse: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    exit 1
} finally {
    Pop-Location
}