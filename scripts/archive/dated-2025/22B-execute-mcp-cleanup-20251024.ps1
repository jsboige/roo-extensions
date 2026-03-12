<#
.SYNOPSIS
    Script d'exécution nettoyage MCP roo-state-manager - Sous-tâche 22B

.DESCRIPTION
    Exécute le nettoyage des fichiers temporaires/obsolètes identifiés par l'inventaire
    - Backup automatique pré-nettoyage
    - Suppression sécurisée avec confirmation
    - Rapport post-nettoyage
    
.PARAMETER DryRun
    Mode simulation (affiche actions sans les exécuter)

.NOTES
    Auteur: Sous-tâche 22B
    Date: 2025-10-24
    Phase: RooSync Phase 3 - Consolidation Tests + Nettoyage MCP
#>

param(
    [switch]$DryRun = $false
)

$ErrorActionPreference = "Stop"
$basePath = "mcps/internal/servers/roo-state-manager"
$backupPath = "backups/mcp-cleanup-20251024"

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   EXÉCUTION NETTOYAGE MCP ROO-STATE-MANAGER" -ForegroundColor Cyan
Write-Host "   Sous-tâche 22B - Phase 2" -ForegroundColor Cyan
if ($DryRun) {
    Write-Host "   MODE: DRY-RUN (Simulation)" -ForegroundColor Yellow
} else {
    Write-Host "   MODE: PRODUCTION" -ForegroundColor Red
}
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Vérifier que l'inventaire a été exécuté
$reportPath = "scripts/roosync/22B-mcp-cleanup-report-20251024.md"
if (-not (Test-Path $reportPath)) {
    Write-Host "❌ Rapport d'inventaire introuvable: $reportPath" -ForegroundColor Red
    Write-Host "   Veuillez exécuter d'abord: 22B-inventory-mcp-cleanup-20251024.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Rapport d'inventaire trouvé: $reportPath" -ForegroundColor Green
Write-Host ""

# Fonction pour formater la taille
function Format-FileSize {
    param([long]$Size)
    
    if ($Size -gt 1MB) {
        return "{0:N2} MB" -f ($Size / 1MB)
    } elseif ($Size -gt 1KB) {
        return "{0:N2} KB" -f ($Size / 1KB)
    } else {
        return "$Size octets"
    }
}

# Collecter fichiers à nettoyer
Write-Host "🔍 Collecte des fichiers à nettoyer..." -ForegroundColor Cyan
Write-Host ""

$filesToClean = @()

# Logs temporaires (>7 jours)
$oldLogs = Get-ChildItem -Path $basePath -Recurse -File -Include "*.log" -ErrorAction SilentlyContinue |
    Where-Object { 
        $_.DirectoryName -notlike "*node_modules*" -and
        ((Get-Date) - $_.LastWriteTime).Days -gt 7
    }

foreach ($file in $oldLogs) {
    $filesToClean += @{
        File = $file
        Category = "Logs temporaires (>7j)"
        Reason = "Log ancien ($(((Get-Date) - $file.LastWriteTime).Days) jours)"
    }
}

# Fichiers temporaires
$tempPatterns = @("*.tmp", "*.bak", "*.old")
foreach ($pattern in $tempPatterns) {
    $tempFiles = Get-ChildItem -Path $basePath -Recurse -File -Include $pattern -ErrorAction SilentlyContinue |
        Where-Object { $_.DirectoryName -notlike "*node_modules*" }
    
    foreach ($file in $tempFiles) {
        $filesToClean += @{
            File = $file
            Category = "Fichiers temporaires"
            Reason = "Extension temporaire ($($file.Extension))"
        }
    }
}

# Afficher résumé
$totalFiles = $filesToClean.Count
$totalSize = ($filesToClean.File | Measure-Object -Property Length -Sum).Sum

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host "   RÉSUMÉ NETTOYAGE" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host ""
Write-Host "📊 Fichiers à supprimer : $totalFiles" -ForegroundColor White
Write-Host "💾 Espace à libérer     : $(Format-FileSize $totalSize)" -ForegroundColor White
Write-Host ""

# Détail par catégorie
$categories = $filesToClean | Group-Object -Property Category
foreach ($category in $categories) {
    Write-Host "┌─ $($category.Name)" -ForegroundColor Cyan
    Write-Host "│  Fichiers: $($category.Count)" -ForegroundColor White
    
    foreach ($item in $category.Group) {
        $relativePath = $item.File.FullName -replace [regex]::Escape((Get-Location).Path + "\"), ""
        $fileSize = Format-FileSize $item.File.Length
        
        Write-Host "│  • $relativePath" -ForegroundColor Gray
        Write-Host "│    Taille: $fileSize | Raison: $($item.Reason)" -ForegroundColor DarkGray
    }
    
    Write-Host "└─" -ForegroundColor Cyan
    Write-Host ""
}

# Phase 1: Backup
if (-not $DryRun) {
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "   PHASE 1: BACKUP PRÉ-NETTOYAGE" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    
    if (Test-Path $backupPath) {
        Write-Host "⚠️  Le répertoire de backup existe déjà: $backupPath" -ForegroundColor Yellow
        $confirm = Read-Host "   Écraser le backup existant? (o/N)"
        if ($confirm -ne "o") {
            Write-Host "❌ Opération annulée par l'utilisateur" -ForegroundColor Red
            exit 0
        }
        Remove-Item -Path $backupPath -Recurse -Force
    }
    
    Write-Host "📦 Création backup dans: $backupPath" -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
    
    foreach ($item in $filesToClean) {
        $file = $item.File
        $relativePath = $file.FullName -replace [regex]::Escape((Get-Location).Path + "\"), ""
        $backupFilePath = Join-Path $backupPath $relativePath
        $backupFileDir = Split-Path $backupFilePath -Parent
        
        if (-not (Test-Path $backupFileDir)) {
            New-Item -ItemType Directory -Path $backupFileDir -Force | Out-Null
        }
        
        Copy-Item -Path $file.FullName -Destination $backupFilePath -Force
        Write-Host "  ✓ Backup: $relativePath" -ForegroundColor DarkGray
    }
    
    Write-Host ""
    Write-Host "✅ Backup créé avec succès: $totalFiles fichiers" -ForegroundColor Green
    Write-Host ""
}

# Phase 2: Nettoyage
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Red
Write-Host "   PHASE 2: NETTOYAGE" -ForegroundColor Red
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Red
Write-Host ""

if ($DryRun) {
    Write-Host "🔍 MODE DRY-RUN: Simulation des suppressions..." -ForegroundColor Yellow
} else {
    Write-Host "⚠️  ATTENTION: Les fichiers vont être supprimés définitivement" -ForegroundColor Red
    Write-Host "   (Backup disponible dans: $backupPath)" -ForegroundColor Yellow
    Write-Host ""
    
    $confirm = Read-Host "   Confirmer la suppression de $totalFiles fichiers? (o/N)"
    if ($confirm -ne "o") {
        Write-Host "❌ Opération annulée par l'utilisateur" -ForegroundColor Red
        exit 0
    }
    Write-Host ""
}

$deletedCount = 0
$deletedSize = 0

foreach ($item in $filesToClean) {
    $file = $item.File
    $relativePath = $file.FullName -replace [regex]::Escape((Get-Location).Path + "\"), ""
    
    if ($DryRun) {
        Write-Host "  [DRY-RUN] Supprimerait: $relativePath" -ForegroundColor Yellow
    } else {
        try {
            Remove-Item -Path $file.FullName -Force
            Write-Host "  ✓ Supprimé: $relativePath" -ForegroundColor DarkGreen
            $deletedCount++
            $deletedSize += $file.Length
        } catch {
            Write-Host "  ✗ ERREUR: $relativePath" -ForegroundColor Red
            Write-Host "    $($_.Exception.Message)" -ForegroundColor DarkRed
        }
    }
}

Write-Host ""

# Résumé final
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "   RÉSUMÉ FINAL" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""

if ($DryRun) {
    Write-Host "🔍 MODE DRY-RUN: Aucune modification effectuée" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Fichiers qui seraient supprimés: $totalFiles" -ForegroundColor White
    Write-Host "Espace qui serait libéré      : $(Format-FileSize $totalSize)" -ForegroundColor White
} else {
    Write-Host "✅ Nettoyage terminé avec succès" -ForegroundColor Green
    Write-Host ""
    Write-Host "Fichiers supprimés  : $deletedCount / $totalFiles" -ForegroundColor White
    Write-Host "Espace libéré       : $(Format-FileSize $deletedSize)" -ForegroundColor White
    Write-Host "Backup disponible   : $backupPath" -ForegroundColor White
}

Write-Host ""

# Prochaines étapes
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   PROCHAINES ÉTAPES" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

if (-not $DryRun) {
    Write-Host "1. Vérifier .gitignore pour patterns temporaires" -ForegroundColor White
    Write-Host "2. Ajouter entrées .gitignore si nécessaire" -ForegroundColor White
    Write-Host "3. Commit Phase 2 avec message détaillé" -ForegroundColor White
    Write-Host "4. Créer documentation finale consolidation" -ForegroundColor White
} else {
    Write-Host "1. Exécuter en mode production: .\22B-execute-mcp-cleanup-20251024.ps1" -ForegroundColor White
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   NETTOYAGE $(if ($DryRun) {'SIMULÉ'} else {'TERMINÉ'})" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan