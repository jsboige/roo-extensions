# Compare-SyncStashs.ps1
# Compare les 6 stashs sync_roo_environment.ps1 avec la version actuelle
# Identifie doublons et modifications uniques

param(
    [switch]$Detailed = $false
)

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  COMPARAISON STASHS SYNC_ROO_ENVIRONMENT.PS1 - PHASE 2" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$analysisDir = "docs/git/phase2-analysis"
$currentScript = Join-Path $analysisDir "current-sync-script.ps1"

# Les 6 stashs à analyser (nouveaux index après Phase 1)
$stashIndices = @(0, 1, 5, 7, 8, 9)

# Vérifier que les fichiers existent
if (-not (Test-Path $currentScript)) {
    Write-Host "❌ ERREUR: Version actuelle non trouvée: $currentScript" -ForegroundColor Red
    exit 1
}

Write-Host "📁 Répertoire d'analyse: $analysisDir" -ForegroundColor Gray
Write-Host "📄 Version actuelle: $currentScript" -ForegroundColor Gray
Write-Host ""

# Analyser chaque stash
$results = @()

foreach ($idx in $stashIndices) {
    $patchFile = Join-Path $analysisDir "stash${idx}-sync-diff.patch"
    
    if (-not (Test-Path $patchFile)) {
        Write-Host "⚠️  ATTENTION: Patch manquant pour stash@{$idx}" -ForegroundColor Yellow
        continue
    }
    
    Write-Host "🔍 Analyse stash@{$idx}..." -ForegroundColor Cyan
    
    # Lire le contenu du patch
    $patchContent = Get-Content $patchFile -Raw
    
    # Extraire les statistiques
    $additions = ($patchContent | Select-String '^\+[^+]' -AllMatches).Matches.Count
    $deletions = ($patchContent | Select-String '^\-[^-]' -AllMatches).Matches.Count
    
    # Identifier les fichiers modifiés
    $filesModified = @()
    if ($patchContent -match 'sync_roo_environment\.ps1') {
        $filesModified += "sync_roo_environment.ps1"
    }
    if ($patchContent -match 'sync_log\.txt') {
        $filesModified += "sync_log.txt"
    }
    
    $result = [PSCustomObject]@{
        StashIndex = $idx
        PatchFile = $patchFile
        Additions = $additions
        Deletions = $deletions
        FilesModified = $filesModified -join ", "
        TotalChanges = $additions + $deletions
    }
    
    $results += $result
    
    Write-Host "  ✓ $additions additions, $deletions suppressions" -ForegroundColor Gray
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  MATRICE DE COMPARAISON" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Afficher le tableau récapitulatif
$results | Format-Table -AutoSize StashIndex, Additions, Deletions, TotalChanges, FilesModified

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  ANALYSE DES PATTERNS" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Identifier les doublons potentiels (même nombre de changements)
$grouped = $results | Group-Object TotalChanges | Where-Object { $_.Count -gt 1 }

if ($grouped) {
    Write-Host "🔄 DOUBLONS POTENTIELS détectés:" -ForegroundColor Yellow
    foreach ($group in $grouped) {
        $indices = ($group.Group | Select-Object -ExpandProperty StashIndex) -join ", "
        Write-Host "   • Stashs @{$indices} : $($group.Name) changements" -ForegroundColor Yellow
    }
    Write-Host ""
}

# Identifier les stashs avec modifications uniques
$unique = $results | Group-Object TotalChanges | Where-Object { $_.Count -eq 1 }

if ($unique) {
    Write-Host "⭐ MODIFICATIONS UNIQUES détectées:" -ForegroundColor Green
    foreach ($item in $unique) {
        $stash = $item.Group[0]
        Write-Host "   • Stash@{$($stash.StashIndex)} : $($stash.TotalChanges) changements uniques" -ForegroundColor Green
    }
    Write-Host ""
}

# Recommandations
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  RECOMMANDATIONS" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "📋 Prochaines étapes suggérées:" -ForegroundColor White
Write-Host ""
Write-Host "1. Pour les DOUBLONS potentiels:" -ForegroundColor Yellow
Write-Host "   → Comparer le contenu réel des patchs" -ForegroundColor Gray
Write-Host "   → Conserver 1 seule version, dropper les autres" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Pour les MODIFICATIONS UNIQUES:" -ForegroundColor Green
Write-Host "   → Analyser le contenu avec 'git stash show -p stash@{X}'" -ForegroundColor Gray
Write-Host "   → Vérifier si déjà intégré dans version actuelle" -ForegroundColor Gray
Write-Host "   → Si non intégré → RÉCUPÉRER sélectivement" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Commandes utiles:" -ForegroundColor Cyan
Write-Host "   → Compare-Object (Get-Content patch1) (Get-Content patch2)" -ForegroundColor Gray
Write-Host "   → git diff HEAD:RooSync/sync_roo_environment.ps1 stash@{X}:sync_roo_environment.ps1" -ForegroundColor Gray
Write-Host ""

# Mode détaillé
if ($Detailed) {
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  ANALYSE DÉTAILLÉE DES PATCHS" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($idx in $stashIndices) {
        $patchFile = Join-Path $analysisDir "stash${idx}-sync-diff.patch"
        
        if (Test-Path $patchFile) {
            Write-Host "📄 stash@{$idx} - Contenu du patch:" -ForegroundColor Cyan
            $content = Get-Content $patchFile -TotalCount 30
            $content | ForEach-Object {
                if ($_ -match '^\+') {
                    Write-Host $_ -ForegroundColor Green
                } elseif ($_ -match '^\-') {
                    Write-Host $_ -ForegroundColor Red
                } else {
                    Write-Host $_ -ForegroundColor Gray
                }
            }
            Write-Host "   [... truncated, voir fichier complet]" -ForegroundColor DarkGray
            Write-Host ""
        }
    }
}

Write-Host "✅ Analyse terminée!" -ForegroundColor Green
Write-Host ""
Write-Host "💡 Pour analyse détaillée: .\compare-sync-stashs.ps1 -Detailed" -ForegroundColor Cyan
Write-Host ""