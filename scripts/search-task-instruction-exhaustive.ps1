<#
.SYNOPSIS
    Recherche exhaustive d'une chaîne d'instruction dans toutes les tâches Roo
.DESCRIPTION
    Scanne récursivement tous les fichiers du répertoire des tâches pour trouver
    une chaîne d'instruction spécifique. Génère un rapport détaillé des occurrences.
.PARAMETER SearchPattern
    Chaîne exacte à rechercher (insensible à la casse)
.PARAMETER TasksDirectory
    Répertoire racine des tâches
.PARAMETER OutputReport
    Chemin du fichier de rapport (optionnel)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$SearchPattern,
    
    [Parameter(Mandatory=$false)]
    [string]$TasksDirectory = "C:\Users\jsboi\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputReport = "docs/exhaustive-search-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
)

# Initialisation
$startTime = Get-Date
Write-Host "🔍 Recherche exhaustive lancée..." -ForegroundColor Cyan
Write-Host "Répertoire: $TasksDirectory" -ForegroundColor Gray
Write-Host "Pattern: $SearchPattern" -ForegroundColor Gray
Write-Host ""

# Compteurs
$totalFiles = 0
$totalTasks = 0
$matchedFiles = @()

# Extensions de fichiers à scanner
$fileExtensions = @("*.json", "*.md", "*.txt")

# Énumération des tâches (sous-répertoires)
$taskDirs = Get-ChildItem -Path $TasksDirectory -Directory -ErrorAction SilentlyContinue
$totalTasks = $taskDirs.Count

Write-Host "📊 Tâches détectées: $totalTasks" -ForegroundColor Yellow
Write-Host ""

# Barre de progression
$progress = 0

foreach ($taskDir in $taskDirs) {
    $progress++
    $percentComplete = [math]::Round(($progress / $totalTasks) * 100, 2)
    
    Write-Progress -Activity "Scan des tâches" `
                   -Status "Tâche $progress/$totalTasks ($percentComplete%)" `
                   -PercentComplete $percentComplete
    
    # Scan de tous les fichiers dans la tâche
    foreach ($ext in $fileExtensions) {
        $files = Get-ChildItem -Path $taskDir.FullName -Filter $ext -Recurse -File -ErrorAction SilentlyContinue
        
        foreach ($file in $files) {
            $totalFiles++
            
            try {
                # Lecture du contenu
                $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8 -ErrorAction Stop
                
                # Recherche insensible à la casse
                if ($content -match [regex]::Escape($SearchPattern)) {
                    $matchedFiles += [PSCustomObject]@{
                        TaskId = $taskDir.Name
                        FilePath = $file.FullName
                        RelativePath = $file.FullName.Replace($TasksDirectory, "")
                        FileName = $file.Name
                        FileSize = $file.Length
                    }
                    
                    Write-Host "✅ MATCH trouvé!" -ForegroundColor Green
                    Write-Host "   Tâche: $($taskDir.Name)" -ForegroundColor White
                    Write-Host "   Fichier: $($file.Name)" -ForegroundColor Gray
                    Write-Host ""
                }
            }
            catch {
                Write-Host "⚠️ Erreur lecture: $($file.FullName)" -ForegroundColor DarkYellow
            }
        }
    }
}

Write-Progress -Activity "Scan des tâches" -Completed

# Calcul du temps d'exécution
$endTime = Get-Date
$duration = $endTime - $startTime

# Résultats
Write-Host ""
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "📈 RÉSULTATS DE LA RECHERCHE EXHAUSTIVE" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Tâches scannées:     $totalTasks" -ForegroundColor White
Write-Host "Fichiers scannés:    $totalFiles" -ForegroundColor White
Write-Host "Occurrences trouvées: $($matchedFiles.Count)" -ForegroundColor $(if ($matchedFiles.Count -eq 0) { "Red" } elseif ($matchedFiles.Count -eq 1) { "Green" } else { "Yellow" })
Write-Host "Durée:               $($duration.TotalSeconds) secondes" -ForegroundColor Gray
Write-Host ""

if ($matchedFiles.Count -gt 0) {
    Write-Host "📂 FICHIERS CORRESPONDANTS:" -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($match in $matchedFiles) {
        Write-Host "  Tâche ID: $($match.TaskId)" -ForegroundColor White
        Write-Host "  Fichier:  $($match.FileName)" -ForegroundColor Gray
        Write-Host "  Chemin:   $($match.RelativePath)" -ForegroundColor DarkGray
        Write-Host "  Taille:   $([math]::Round($match.FileSize / 1KB, 2)) KB" -ForegroundColor DarkGray
        Write-Host ""
    }
} else {
    Write-Host "❌ AUCUNE OCCURRENCE TROUVÉE" -ForegroundColor Red
}

# Génération du rapport Markdown
$reportContent = @"
# Rapport de Recherche Exhaustive - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Paramètres de Recherche

- **Répertoire**: ``$TasksDirectory``
- **Pattern**: ```
$SearchPattern
```
- **Extensions scannées**: $($fileExtensions -join ', ')

## Résultats

- **Tâches scannées**: $totalTasks
- **Fichiers scannés**: $totalFiles
- **Occurrences trouvées**: $($matchedFiles.Count)
- **Durée d'exécution**: $($duration.TotalSeconds) secondes

## Fichiers Correspondants

"@

if ($matchedFiles.Count -gt 0) {
    foreach ($match in $matchedFiles) {
        $reportContent += @"

### Tâche: ``$($match.TaskId)``

- **Fichier**: ``$($match.FileName)``
- **Chemin relatif**: ``$($match.RelativePath)``
- **Taille**: $([math]::Round($match.FileSize / 1KB, 2)) KB

"@
    }
} else {
    $reportContent += "`n**Aucune occurrence trouvée.**`n"
}

$reportContent += @"

## Conclusion

$(if ($matchedFiles.Count -eq 0) {
    "❌ La chaîne recherchée n'apparaît dans aucune tâche du système."
} elseif ($matchedFiles.Count -eq 1) {
    "✅ La chaîne apparaît uniquement dans la tâche ``$($matchedFiles[0].TaskId)`` (comportement attendu)."
} else {
    "⚠️ La chaîne apparaît dans $($matchedFiles.Count) tâches différentes (inattendu - possible duplication)."
})

"@

# Sauvegarde du rapport
$reportContent | Out-File -FilePath $OutputReport -Encoding UTF8
Write-Host "📄 Rapport sauvegardé: $OutputReport" -ForegroundColor Green
Write-Host ""

# Retourne les résultats pour usage programmatique
return $matchedFiles