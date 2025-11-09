#!/usr/bin/env pwsh
# ==============================================================================
# Script: test-emoji-fix-validation.ps1
# Description: Test de validation des corrections d'emojis dans les scripts PowerShell
# Auteur: Roo Debug Mode
# Date: 2025-10-28
# ==============================================================================

# Configuration UTF-8 explicite
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

Write-Host "═════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  VALIDATION DES CORRECTIONS D'EMOJIS" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Liste des fichiers problématiques identifiés
$problematicFiles = @(
    "scripts\analyze-stashs.ps1",
    "scripts\backup-all-stashs.ps1", 
    "scripts\git\compare-sync-stashs.ps1",
    "scripts\git\02-phase2-verify-checksums-20251022.ps1",
    "scripts\git\03-phase2-examine-stash-content-20251022.ps1",
    "scripts\git\04-phase2-compare-sync-checksums-20251022.ps1",
    "scripts\git\05-phase2-final-analysis-20251022.ps1",
    "scripts\git\06-phase2-verify-migration-20251022.ps1",
    "scripts\git\07-phase2-classify-corrections-20251022.ps1",
    "scripts\git\08-phase2-extract-corrections-20251022.ps1",
    "RooSync\sync_roo_environment.ps1"
)

function Test-FileExecution {
    param(
        [string]$FilePath
    )
    
    Write-Host "Test: $FilePath" -ForegroundColor Yellow
    
    if (-not (Test-Path $FilePath)) {
        Write-Host "  ERREUR: Fichier non trouve: $FilePath" -ForegroundColor Red
        return $false
    }
    
    try {
        # Test de syntaxe PowerShell
        $syntaxCheck = pwsh -NoProfile -Command "try { . '$FilePath'; Write-Host 'SYNTAX_OK' } catch { Write-Host 'SYNTAX_ERROR'; exit 1 }" 2>&1
        
        if ($syntaxCheck -match "SYNTAX_OK") {
            Write-Host "  ✓ Syntaxe OK" -ForegroundColor Green
            return $true
        } else {
            Write-Host "  ✗ Erreur de syntaxe detectee" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "  ✗ Erreur lors du test: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Test-EmojiDetection {
    param(
        [string]$FilePath
    )
    
    try {
        $content = Get-Content $FilePath -Encoding UTF8 -Raw
        
        # Patterns d'emojis courants
        $emojiPatterns = @(
            "🏆", "✅", "❌", "⚠️", "ℹ️", "🚀", "💻", "⚙️", "🪲", "📁", "📄", "📦", "🔍", 
            "📊", "📋", "🔬", "🎯", "📈", "💡", "💾", "🔄", "⚙️", "🏗️", "📝", "🔧", "✨", 
            "🎪", "🎭", "🎬", "🔑", "🚫", "📡", "🔗", "📌", "📍", "🎨", "🧹", "🗑️"
        )
        
        $foundEmojis = @()
        foreach ($pattern in $emojiPatterns) {
            if ($content -match [regex]::Escape($pattern)) {
                $foundEmojis += $pattern
            }
        }
        
        if ($foundEmojis.Count -gt 0) {
            Write-Host "  Emojis detectes: $($foundEmojis -join ', ')" -ForegroundColor Yellow
            return $true
        } else {
            Write-Host "  Aucun emoji detecte" -ForegroundColor Green
            return $false
        }
    } catch {
        Write-Host "  Erreur de detection: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Apply-FixToSingleFile {
    param(
        [string]$FilePath
    )
    
    Write-Host "Application de la correction: $FilePath" -ForegroundColor Yellow
    
    try {
        # Lire le fichier original
        $originalContent = Get-Content $FilePath -Encoding UTF8 -Raw
        
        # Remplacer les emojis par des alternatives textuelles
        $fixedContent = $originalContent
        
        # Remplacements principaux
        $fixedContent = $fixedContent -replace "🏆", "[TROPHEE]"
        $fixedContent = $fixedContent -replace "✅", "[OK]"
        $fixedContent = $fixedContent -replace "❌", "[ERREUR]"
        $fixedContent = $fixedContent -replace "⚠️", "[ATTENTION]"
        $fixedContent = $fixedContent -replace "ℹ️", "[INFO]"
        $fixedContent = $fixedContent -replace "🚀", "[ROCKET]"
        $fixedContent = $fixedContent -replace "💻", "[ORDINATEUR]"
        $fixedContent = $fixedContent -replace "⚙️", "[PARAMETRES]"
        $fixedContent = $fixedContent -replace "🪲", "[DEBUG]"
        $fixedContent = $fixedContent -replace "📁", "[DOSSIER]"
        $fixedContent = $fixedContent -replace "📄", "[FICHIER]"
        $fixedContent = $fixedContent -replace "📦", "[STASH]"
        $fixedContent = $fixedContent -replace "🔍", "[RECHERCHE]"
        $fixedContent = $fixedContent -replace "📊", "[STATISTIQUES]"
        $fixedContent = $fixedContent -replace "📋", "[RAPPORT]"
        $fixedContent = $fixedContent -replace "🔬", "[ANALYSE]"
        $fixedContent = $fixedContent -replace "🎯", "[CIBLE]"
        $fixedContent = $fixedContent -replace "📈", "[STATS]"
        $fixedContent = $fixedContent -replace "💡", "[CONSEIL]"
        $fixedContent = $fixedContent -replace "💾", "[SAUVEGARDE]"
        $fixedContent = $fixedContent -replace "🔄", "[ROTATION]"
        $fixedContent = $fixedContent -replace "⚙️", "[CONFIG]"
        $fixedContent = $fixedContent -replace "🏗️", "[CONSTRUCTION]"
        $fixedContent = $fixedContent -replace "📝", "[DOCUMENTATION]"
        $fixedContent = $fixedContent -replace "🔧", "[OUTILS]"
        $fixedContent = $fixedContent -replace "✨", "[ETINCelles]"
        $fixedContent = $fixedContent -replace "🎪", "[MASQUE]"
        $fixedContent = $fixedContent -replace "🎭", "[THEATRE]"
        $fixedContent = $fixedContent -replace "🎬", "[CINEMA]"
        $fixedContent = $fixedContent -replace "🔑", "[CLE]"
        $fixedContent = $fixedContent -replace "🚫", "[INTERDIT]"
        $fixedContent = $fixedContent -replace "📡", "[GRAPHE]"
        $fixedContent = $fixedContent -replace "🔗", "[LIEN]"
        $fixedContent = $fixedContent -replace "📌", "[EPINGLE]"
        $fixedContent = $fixedContent -replace "📍", "[POSITION]"
        $fixedContent = $fixedContent -replace "🎨", "[DESIGN]"
        $fixedContent = $fixedContent -replace "🧹", "[NETTOYAGE]"
        $fixedContent = $fixedContent -replace "🗑️", "[SUPPRESSION]"
        
        # Sauvegarder l'original
        $backupPath = "$FilePath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $FilePath $backupPath -Force
        Write-Host "  Sauvegarde cree: $backupPath" -ForegroundColor Green
        
        # Ecrire le fichier corrige
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($fixedContent)
        [System.IO.File]::WriteAllBytes($FilePath, $bytes)
        
        Write-Host "  Correction appliquee avec succes" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "  Erreur lors de la correction: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Tests sur les fichiers problématiques
Write-Host "TESTS SUR LES FICHIERS PROBLEMATIQUES" -ForegroundColor White
Write-Host ""

$totalFiles = $problematicFiles.Count
$passedTests = 0
$failedTests = 0

foreach ($file in $problematicFiles) {
    Write-Host "──────────────────────────────────────────────────────────" -ForegroundColor Gray
    Write-Host ""
    
    # Test 1: Détection d'emojis
    $hasEmojis = Test-EmojiDetection -FilePath $file
    
    # Test 2: Test de syntaxe original
    $originalSyntax = Test-FileExecution -FilePath $file
    
    if ($hasEmojis -and -not $originalSyntax) {
        Write-Host "  Fichier affecte par des emojis - correction necessaire" -ForegroundColor Yellow
        
        # Appliquer la correction
        if (Apply-FixToSingleFile -FilePath $file) {
            # Test 3: Validation du fichier corrige
            $fixedSyntax = Test-FileExecution -FilePath $file
            if ($fixedSyntax) {
                $passedTests++
                Write-Host "  ✓ Fichier corrige et valide" -ForegroundColor Green
            } else {
                $failedTests++
                Write-Host "  ✗ Fichier corrige mais invalide" -ForegroundColor Red
            }
        } else {
            $failedTests++
            Write-Host "  ✗ Echec de la correction" -ForegroundColor Red
        }
    } elseif (-not $hasEmojis -and $originalSyntax) {
        Write-Host "  Fichier sans emojis - deja fonctionnel" -ForegroundColor Green
        $passedTests++
    } elseif ($hasEmojis -and $originalSyntax) {
        Write-Host "  Fichier avec emojis mais syntaxe OK - cas rare" -ForegroundColor Yellow
        $passedTests++
    } else {
        Write-Host "  Fichier sans emojis mais syntaxe invalide - autre probleme" -ForegroundColor Red
        $failedTests++
    }
}

Write-Host ""
Write-Host "═════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "RESULTATS DES TESTS" -ForegroundColor Cyan
Write-Host "═════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Fichiers testes: $totalFiles" -ForegroundColor White
Write-Host "Reussis: $passedTests" -ForegroundColor Green
Write-Host "Echecs: $failedTests" -ForegroundColor Red
Write-Host "Taux de succes: $([math]::Round(($passedTests / $totalFiles) * 100, 2))%" -ForegroundColor Yellow
Write-Host ""

if ($failedTests -eq 0) {
    Write-Host "✓ TOUS LES FICHIERS SONT CORRIGES ET VALIDES" -ForegroundColor Green
} else {
    Write-Host "✗ CERTAINS FICHIERS NECESSITENT UNE ATTENTION MANUELLE" -ForegroundColor Red
}

Write-Host ""
Write-Host "Test de validation termine" -ForegroundColor Cyan