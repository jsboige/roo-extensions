<#
.SYNOPSIS
    Script d'inventaire pour nettoyage MCP roo-state-manager - Sous-tâche 22B

.DESCRIPTION
    Inventorie les fichiers temporaires/obsolètes dans mcps/internal/servers/roo-state-manager
    - Logs temporaires (*.log, >7 jours)
    - Fichiers temporaires (*.tmp, *.bak, *.old)
    - Cache/debug directories
    - Rapports obsolètes
    
    Génère un rapport détaillé pour validation utilisateur avant cleanup

.NOTES
    Auteur: Sous-tâche 22B
    Date: 2025-10-24
    Phase: RooSync Phase 3 - Consolidation Tests + Nettoyage MCP
#>

$ErrorActionPreference = "Stop"
$basePath = "mcps/internal/servers/roo-state-manager"

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   INVENTAIRE NETTOYAGE MCP ROO-STATE-MANAGER" -ForegroundColor Cyan
Write-Host "   Sous-tâche 22B - Phase 2" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Vérifier que le répertoire existe
if (-not (Test-Path $basePath)) {
    Write-Host "❌ Répertoire MCP introuvable: $basePath" -ForegroundColor Red
    exit 1
}

Write-Host "📂 Répertoire analysé: $basePath" -ForegroundColor Yellow
Write-Host ""

# Initialiser compteurs
$totalFiles = 0
$totalSize = 0
$categories = @{
    "Logs temporaires (>7j)" = @()
    "Logs récents (<7j)" = @()
    "Fichiers temporaires" = @()
    "Rapports obsolètes" = @()
    "Autres" = @()
}

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

# Analyser fichiers logs
Write-Host "🔍 Analyse des fichiers logs..." -ForegroundColor Cyan

$logFiles = Get-ChildItem -Path $basePath -Recurse -File -Include "*.log" -ErrorAction SilentlyContinue | 
    Where-Object { $_.DirectoryName -notlike "*node_modules*" }

foreach ($file in $logFiles) {
    $age = (Get-Date) - $file.LastWriteTime
    $totalFiles++
    $totalSize += $file.Length
    
    if ($age.Days -gt 7) {
        $categories["Logs temporaires (>7j)"] += $file
    } else {
        $categories["Logs récents (<7j)"] += $file
    }
}

# Analyser fichiers temporaires
Write-Host "🔍 Analyse des fichiers temporaires (.tmp, .bak, .old)..." -ForegroundColor Cyan

$tempPatterns = @("*.tmp", "*.bak", "*.old")
foreach ($pattern in $tempPatterns) {
    $tempFiles = Get-ChildItem -Path $basePath -Recurse -File -Include $pattern -ErrorAction SilentlyContinue |
        Where-Object { $_.DirectoryName -notlike "*node_modules*" }
    
    foreach ($file in $tempFiles) {
        $totalFiles++
        $totalSize += $file.Length
        $categories["Fichiers temporaires"] += $file
    }
}

# Analyser rapports root (hors README, CHANGELOG, PHASE*.md, VALIDATION*.md)
Write-Host "🔍 Analyse des rapports root potentiellement obsolètes..." -ForegroundColor Cyan

$rootMdFiles = Get-ChildItem -Path $basePath -File -Include "*.md" -ErrorAction SilentlyContinue |
    Where-Object { 
        $_.Name -notmatch "^(README|CHANGELOG|PHASE|VALIDATION|REFACTORING|BATCH|GIT_SYNC|NEXT_SESSION|TEST_FAILURES|FUNCTIONAL_REDUNDANCY|PLAN-REORGANISATION-TESTS)" -and
        $_.Name -notmatch "PROJECT_FINAL_SYNTHESIS"
    }

foreach ($file in $rootMdFiles) {
    $totalFiles++
    $totalSize += $file.Length
    $categories["Rapports obsolètes"] += $file
}

# Analyser fichiers texte root
$rootTxtFiles = Get-ChildItem -Path $basePath -File -Include "*.txt" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne ".gitignore" }

foreach ($file in $rootTxtFiles) {
    $totalFiles++
    $totalSize += $file.Length
    $categories["Autres"] += $file
}

# Afficher résultats
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "   RÉSULTATS INVENTAIRE" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""

Write-Host "📊 Total fichiers analysés : $totalFiles" -ForegroundColor Yellow
Write-Host "💾 Taille totale           : $(Format-FileSize $totalSize)" -ForegroundColor Yellow
Write-Host ""

# Détail par catégorie
foreach ($category in $categories.Keys) {
    $files = $categories[$category]
    $count = $files.Count
    
    if ($count -gt 0) {
        $categorySize = ($files | Measure-Object -Property Length -Sum).Sum
        
        Write-Host "┌─ $category" -ForegroundColor Cyan
        Write-Host "│  Fichiers: $count" -ForegroundColor White
        Write-Host "│  Taille  : $(Format-FileSize $categorySize)" -ForegroundColor White
        Write-Host "│" -ForegroundColor Cyan
        
        foreach ($file in $files | Sort-Object Length -Descending | Select-Object -First 10) {
            $relativePath = $file.FullName -replace [regex]::Escape((Get-Location).Path + "\"), ""
            $fileSize = Format-FileSize $file.Length
            $age = [math]::Round(((Get-Date) - $file.LastWriteTime).TotalDays, 1)
            
            Write-Host "│  • $relativePath" -ForegroundColor Gray
            Write-Host "│    Taille: $fileSize | Âge: $age jours | Modifié: $($file.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))" -ForegroundColor DarkGray
        }
        
        if ($count -gt 10) {
            Write-Host "│  ... et $($count - 10) autres fichiers" -ForegroundColor DarkGray
        }
        
        Write-Host "└─" -ForegroundColor Cyan
        Write-Host ""
    }
}

# Recommandations
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host "   RECOMMANDATIONS" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host ""

$cleanupCandidates = $categories["Logs temporaires (>7j)"].Count + 
                     $categories["Fichiers temporaires"].Count

if ($cleanupCandidates -gt 0) {
    $cleanupSize = ($categories["Logs temporaires (>7j)"] + $categories["Fichiers temporaires"] | 
                    Measure-Object -Property Length -Sum).Sum
    
    Write-Host "✅ NETTOYAGE RECOMMANDÉ:" -ForegroundColor Green
    Write-Host "   • $cleanupCandidates fichiers à supprimer" -ForegroundColor White
    Write-Host "   • $(Format-FileSize $cleanupSize) d'espace libérable" -ForegroundColor White
    Write-Host ""
}

if ($categories["Rapports obsolètes"].Count -gt 0) {
    Write-Host "⚠️  VÉRIFICATION MANUELLE:" -ForegroundColor Yellow
    Write-Host "   • $($categories["Rapports obsolètes"].Count) rapports markdown root détectés" -ForegroundColor White
    Write-Host "   • Vérifier si ces rapports sont obsolètes avant suppression" -ForegroundColor White
    Write-Host ""
}

if ($categories["Logs récents (<7j)"].Count -gt 0) {
    Write-Host "ℹ️  LOGS RÉCENTS CONSERVÉS:" -ForegroundColor Cyan
    Write-Host "   • $($categories["Logs récents (<7j)"].Count) logs récents (<7j) seront conservés" -ForegroundColor White
    Write-Host ""
}

# Génération rapport détaillé
$reportPath = "scripts/roosync/22B-mcp-cleanup-report-20251024.md"
Write-Host "📄 Génération rapport détaillé: $reportPath" -ForegroundColor Cyan

$reportContent = @"
# Rapport Inventaire Nettoyage MCP - Sous-tâche 22B

**Date**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Répertoire**: $basePath

---

## Résumé Exécutif

- **Fichiers analysés**: $totalFiles
- **Taille totale**: $(Format-FileSize $totalSize)
- **Fichiers nettoyables**: $cleanupCandidates ($(Format-FileSize $cleanupSize))

---

## Détail par Catégorie

"@

foreach ($category in $categories.Keys) {
    $files = $categories[$category]
    $count = $files.Count
    
    if ($count -gt 0) {
        $categorySize = ($files | Measure-Object -Property Length -Sum).Sum
        
        $reportContent += @"

### $category

- **Nombre**: $count fichiers
- **Taille**: $(Format-FileSize $categorySize)

| Fichier | Taille | Âge (jours) | Dernière modification |
|---------|--------|-------------|----------------------|
"@
        
        foreach ($file in $files | Sort-Object Length -Descending) {
            $relativePath = $file.FullName -replace [regex]::Escape((Get-Location).Path + "\"), ""
            $fileSize = Format-FileSize $file.Length
            $age = [math]::Round(((Get-Date) - $file.LastWriteTime).TotalDays, 1)
            $lastMod = $file.LastWriteTime.ToString('yyyy-MM-dd HH:mm')
            
            $reportContent += "`n| ``$relativePath`` | $fileSize | $age | $lastMod |"
        }
        
        $reportContent += "`n"
    }
}

$reportContent += @"

---

## Recommandations

### Nettoyage Automatique (Sécurisé)

Les fichiers suivants peuvent être supprimés automatiquement :

- **Logs temporaires (>7 jours)**: $($categories["Logs temporaires (>7j)"].Count) fichiers
- **Fichiers temporaires (.tmp, .bak, .old)**: $($categories["Fichiers temporaires"].Count) fichiers

**Total espace libérable**: $(Format-FileSize $cleanupSize)

### Vérification Manuelle Requise

- **Rapports obsolètes**: $($categories["Rapports obsolètes"].Count) fichiers markdown root
- **Autres fichiers**: $($categories["Autres"].Count) fichiers

### Conservation

- **Logs récents (<7 jours)**: $($categories["Logs récents (<7j)"].Count) fichiers conservés

---

## Prochaines Étapes

1. **Backup pré-nettoyage**: Créer backup dans ``backups/mcp-cleanup-20251024/``
2. **Exécuter nettoyage**: Script ``22B-execute-mcp-cleanup-20251024.ps1``
3. **Mettre à jour .gitignore**: Ajouter patterns pour éviter futurs fichiers temporaires
4. **Commit Phase 2**: Documenter nettoyage réalisé

---

*Rapport généré automatiquement par ``22B-inventory-mcp-cleanup-20251024.ps1``*
"@

$reportContent | Out-File -FilePath $reportPath -Encoding UTF8 -Force

Write-Host "✅ Rapport sauvegardé: $reportPath" -ForegroundColor Green
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   INVENTAIRE TERMINÉ" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan