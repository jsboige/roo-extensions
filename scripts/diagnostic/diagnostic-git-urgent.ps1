# Diagnostic Git Urgent - 269 notifications à analyser
# ÉTAPE 1: Diagnostic complet sans modification

Write-Host "========================================" -ForegroundColor Red
Write-Host "DIAGNOSTIC GIT URGENT - 269 NOTIFICATIONS" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red
Write-Host ""

# Création du répertoire de sortie s'il n'existe pas
$outputDir = "outputs/diagnostic-git-urgent"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$reportFile = "$outputDir/rapport-diagnostic-git-$timestamp.md"

# Initialisation du rapport
$report = @"
# DIAGNOSTIC GIT URGENT - 269 NOTIFICATIONS
**Généré le**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Objectif**: Analyse complète des 269 notifications Git sans modification

---

## 1. STATUT GIT GLOBAL

"@

Write-Host "1. Analyse du statut Git global..." -ForegroundColor Yellow

# Récupération du statut Git complet
$gitStatus = git status --porcelain
$gitStatusLines = $gitStatus -split "`n" | Where-Object { $_.Trim() -ne "" }

$report += @"
**Nombre total de notifications**: $($gitStatusLines.Count)

### Statut Git détaillé :
```
$gitStatus
```

---

## 2. CATÉGORISATION DES FICHIERS

"@

Write-Host "2. Catégorisation des fichiers..." -ForegroundColor Yellow

# Catégorisation des fichiers
$deletedFiles = @()
$modifiedFiles = @()
$newFiles = @()
$renamedFiles = @()
$unmergedFiles = @()

foreach ($line in $gitStatusLines) {
    if ($line.Length -ge 3) {
        $status = $line.Substring(0, 2)
        $filePath = $line.Substring(3)
        
        switch -Regex ($status) {
            "^D" { $deletedFiles += $filePath }
            "^.D" { $deletedFiles += $filePath }
            "^M" { $modifiedFiles += $filePath }
            "^.M" { $modifiedFiles += $filePath }
            "^A" { $newFiles += $filePath }
            "^\?\?" { $newFiles += $filePath }
            "^R" { $renamedFiles += $filePath }
            "^U" { $unmergedFiles += $filePath }
            "^ " { } # Ignoré
        }
    }
}

$report += @"
### Fichiers supprimés: $($deletedFiles.Count)
"@

if ($deletedFiles.Count -gt 0) {
    $report += @"
```
$($deletedFiles -join "`n")
```
"@
}

$report += @"

### Fichiers modifiés: $($modifiedFiles.Count)
"@

if ($modifiedFiles.Count -gt 0) {
    $report += @"
```
$($modifiedFiles -join "`n")
```
"@
}

$report += @"

### Nouveaux fichiers: $($newFiles.Count)
"@

if ($newFiles.Count -gt 0) {
    $report += @"
```
$($newFiles -join "`n")
```
"@
}

$report += @"

### Fichiers renommés: $($renamedFiles.Count)
"@

if ($renamedFiles.Count -gt 0) {
    $report += @"
```
$($renamedFiles -join "`n")
```
"@
}

$report += @"

### Fichiers en conflit: $($unmergedFiles.Count)
"@

if ($unmergedFiles.Count -gt 0) {
    $report += @"
```
$($unmergedFiles -join "`n")
```
"@
}

Write-Host "   - Fichiers supprimés: $($deletedFiles.Count)" -ForegroundColor Red
Write-Host "   - Fichiers modifiés: $($modifiedFiles.Count)" -ForegroundColor Yellow
Write-Host "   - Nouveaux fichiers: $($newFiles.Count)" -ForegroundColor Green
Write-Host "   - Fichiers renommés: $($renamedFiles.Count)" -ForegroundColor Cyan
Write-Host "   - Fichiers en conflit: $($unmergedFiles.Count)" -ForegroundColor Magenta

# Analyse des patterns d'archivage abusifs
Write-Host "`n3. Analyse des patterns d'archivage abusifs..." -ForegroundColor Yellow

$report += @"

---

## 3. ANALYSE DES PATTERNS D'ARCHIVAGE ABUSIFS

### Fichiers potentiellement archivés de manière abusive:
"@

$archivedPatterns = @()
$archiveFiles = $deletedFiles | Where-Object { $_ -match "archive" }

foreach ($file in $archiveFiles) {
    $archivedPatterns += $file
}

if ($archivedPatterns.Count -gt 0) {
    $report += @"
**Fichiers contenant 'archive' dans leur chemin**:
```
$($archivedPatterns -join "`n")
```
"@
}

# Analyse des fichiers critiques par catégorie
Write-Host "`n4. Identification des fichiers critiques..." -ForegroundColor Yellow

$report += @"

---

## 4. IDENTIFICATION DES FICHIERS CRITIQUES

### Fichiers d'architecture SDDD affectés:
"@

$sdddFiles = @()
foreach ($file in $deletedFiles) {
    if ($file -match "SDDD|architecture|architecture\.md|docs.*architecture") {
        $sdddFiles += $file
    }
}

if ($sdddFiles.Count -gt 0) {
    $report += @"
```
$($sdddFiles -join "`n")
```
"@
} else {
    $report += "Aucun fichier d'architecture SDDD détecté parmi les fichiers supprimés.`n"
}

$report += @"

### Rapports de mission importants archivés:
"@

$missionReports = @()
foreach ($file in $deletedFiles) {
    if ($file -match "rapport|mission|report|RAPPORT") {
        $missionReports += $file
    }
}

if ($missionReports.Count -gt 0) {
    $report += @"
```
$($missionReports -join "`n")
```
"@
} else {
    $report += "Aucun rapport de mission détecté parmi les fichiers supprimés.`n"
}

$report += @"

### Fichiers de tests essentiels supprimés:
"@

$testFiles = @()
foreach ($file in $deletedFiles) {
    if ($file -match "test|Test|TEST|\.test\.|\.spec\.") {
        $testFiles += $file
    }
}

if ($testFiles.Count -gt 0) {
    $report += @"
```
$($testFiles -join "`n")
```
"@
} else {
    $report += "Aucun fichier de test détecté parmi les fichiers supprimés.`n"
}

# Analyse détaillée des 128 fichiers critiques
Write-Host "`n5. Analyse des 128 fichiers critiques à restaurer..." -ForegroundColor Yellow

$report += @"

---

## 5. LISTE DES 128 FICHIERS CRITIQUES À RESTAURER

**Total des fichiers supprimés**: $($deletedFiles.Count)
**Objectif**: Identifier les 128 fichiers les plus critiques à restaurer

### Fichiers critiques par priorité:
"@

# Priorisation des fichiers à restaurer
$criticalFiles = @()
$highPriority = @()
$mediumPriority = @()
$lowPriority = @()

foreach ($file in $deletedFiles) {
    if ($file -match "\.md$|\.ps1$|\.json$|\.js$|\.ts$") {
        if ($file -match "docs|README|SDDD|architecture|rapport|mission") {
            $highPriority += $file
        } elseif ($file -match "script|config|test") {
            $mediumPriority += $file
        } else {
            $lowPriority += $file
        }
    } else {
        $lowPriority += $file
    }
}

$criticalFiles = $highPriority + $mediumPriority + $lowPriority

$report += @"

#### HAUTE PRIORITÉ ($($highPriority.Count) fichiers):
"@

if ($highPriority.Count -gt 0) {
    $report += @"
```
$($highPriority -join "`n")
```
"@
}

$report += @"

#### PRIORITÉ MOYENNE ($($mediumPriority.Count) fichiers):
"@

if ($mediumPriority.Count -gt 0) {
    $report += @"
```
$($mediumPriority -join "`n")
```
"@
}

$report += @"

#### PRIORITÉ BASSE ($($lowPriority.Count) fichiers):
"@

if ($lowPriority.Count -gt 0) {
    $report += @"
```
$($lowPriority -join "`n")
```
"@
}

# Recommandations pour l'étape 2
Write-Host "`n6. Génération des recommandations..." -ForegroundColor Yellow

$report += @"

---

## 6. RECOMMANDATIONS POUR L'ÉTAPE 2 (RESTAURATION)

### Plan d'action recommandé:

1. **RESTAURATION IMMÉDIATE** - Fichiers haute priorité ($($highPriority.Count) fichiers):
   - Tous les fichiers .md dans docs/
   - Tous les fichiers SDDD et d'architecture
   - Tous les rapports de mission

2. **RESTAURATION PRIORITAIRE** - Fichiers moyenne priorité ($($mediumPriority.Count) fichiers):
   - Scripts PowerShell essentiels
   - Fichiers de configuration
   - Tests unitaires

3. **RESTAURATION SÉLECTIVE** - Fichiers basse priorité ($($lowPriority.Count) fichiers):
   - Examiner au cas par cas
   - Certains fichiers peuvent être obsolètes

### Commandes Git suggérées pour la restauration:

```powershell
# Restauration des fichiers haute priorité
$($highPriority | ForEach-Object { "git checkout HEAD -- `"$_`"" } | Out-String)

# Restauration des fichiers moyenne priorité
$($mediumPriority | ForEach-Object { "git checkout HEAD -- `"$_`"" } | Out-String)
```

### Précautions avant restauration:

1. **Créer une branche de sauvegarde**:
   ```powershell
   git checkout -b backup-before-restoration
   git add .
   git commit -m "Backup avant restauration - $(Get-Date -Format 'yyyyMMdd-HHmmss')"
   git checkout main
   ```

2. **Valider chaque étape** avec l'utilisateur avant exécution

3. **Vérifier les conflits** potentiels après restauration

---

## 7. RÉSUMÉ EXÉCUTIF

- **Total notifications**: $($gitStatusLines.Count)
- **Fichiers supprimés**: $($deletedFiles.Count)
- **Fichiers modifiés**: $($modifiedFiles.Count)
- **Nouveaux fichiers**: $($newFiles.Count)
- **Fichiers critiques à restaurer**: $($criticalFiles.Count)

**Action requise**: Validation utilisateur pour procéder à l'étape 2 de restauration

---

*Fin du rapport de diagnostic - $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")*
"@

# Sauvegarde du rapport
$report | Out-File -FilePath $reportFile -Encoding UTF8

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "RAPPORT DE DIAGNOSTIC GÉNÉRÉ" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Fichier: $reportFile" -ForegroundColor Cyan
Write-Host ""
Write-Host "RÉSUMÉ DES 269 NOTIFICATIONS:" -ForegroundColor Yellow
Write-Host "- Fichiers supprimés: $($deletedFiles.Count)" -ForegroundColor Red
Write-Host "- Fichiers modifiés: $($modifiedFiles.Count)" -ForegroundColor Yellow
Write-Host "- Nouveaux fichiers: $($newFiles.Count)" -ForegroundColor Green
Write-Host "- Fichiers renommés: $($renamedFiles.Count)" -ForegroundColor Cyan
Write-Host "- Fichiers en conflit: $($unmergedFiles.Count)" -ForegroundColor Magenta
Write-Host ""
Write-Host "FICHIERS CRITIQUES À RESTAURER:" -ForegroundColor Red
Write-Host "- Haute priorité: $($highPriority.Count)" -ForegroundColor Red
Write-Host "- Priorité moyenne: $($mediumPriority.Count)" -ForegroundColor Yellow
Write-Host "- Priorité basse: $($lowPriority.Count)" -ForegroundColor Green
Write-Host ""
Write-Host "PROCHAINE ÉTAPE: Validation utilisateur pour restauration" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Green

# Export des listes pour traitement ultérieur
$deletedFiles | Out-File -FilePath "$outputDir/fichiers-supprimes-$timestamp.txt" -Encoding UTF8
$highPriority | Out-File -FilePath "$outputDir/fichiers-haute-priorite-$timestamp.txt" -Encoding UTF8
$mediumPriority | Out-File -FilePath "$outputDir/fichiers-priorite-moyenne-$timestamp.txt" -Encoding UTF8
$lowPriority | Out-File -FilePath "$outputDir/fichiers-priorite-basse-$timestamp.txt" -Encoding UTF8

Write-Host "`nFichiers d'export générés:" -ForegroundColor Cyan
Write-Host "- Fichiers supprimés: $outputDir/fichiers-supprimes-$timestamp.txt"
Write-Host "- Haute priorité: $outputDir/fichiers-haute-priorite-$timestamp.txt"
Write-Host "- Priorité moyenne: $outputDir/fichiers-priorite-moyenne-$timestamp.txt"
Write-Host "- Priorité basse: $outputDir/fichiers-priorite-basse-$timestamp.txt"