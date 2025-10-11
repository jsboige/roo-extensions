# Script d'analyse simplifié des chemins codés en dur
# Version: 1.0 - Approche robuste

param(
    [switch]$Verbose = $false
)

Write-Host "=== ANALYSE DES CHEMINS CODÉS EN DUR ===" -ForegroundColor Green
Write-Host "Répertoire: $(Get-Location)" -ForegroundColor Cyan

# Patterns à rechercher
$patterns = @(
    "d:/roo-extensions",
    "c:/dev/roo-extensions", 
    "d:\\roo-extensions",
    "c:\\dev\\roo-extensions"
)

$results = @()
$totalFiles = 0
$affectedFiles = 0

# Extensions de fichiers à analyser
$extensions = @("*.ps1", "*.json", "*.md")

foreach ($ext in $extensions) {
    Write-Host "`nRecherche dans les fichiers $ext..." -ForegroundColor Yellow
    
    try {
        $files = Get-ChildItem -Path . -Filter $ext -Recurse -ErrorAction SilentlyContinue | 
                 Where-Object { $_.FullName -notmatch "\\\.git\\" -and $_.Name -ne "analyze-paths-simple.ps1" }
        
        foreach ($file in $files) {
            $totalFiles++
            if ($Verbose) {
                Write-Host "  Analyse: $($file.Name)" -ForegroundColor Gray
            }
            
            try {
                $content = Get-Content -Path $file.FullName -Raw -ErrorAction SilentlyContinue
                if ($content) {
                    $fileHasIssues = $false
                    
                    foreach ($pattern in $patterns) {
                        if ($content -match [regex]::Escape($pattern)) {
                            $fileHasIssues = $true
                            $lines = $content -split "`n"
                            for ($i = 0; $i -lt $lines.Count; $i++) {
                                if ($lines[$i] -match [regex]::Escape($pattern)) {
                                    $results += [PSCustomObject]@{
                                        File = $file.FullName.Replace((Get-Location).Path + "\", "")
                                        Line = $i + 1
                                        Content = $lines[$i].Trim()
                                        Pattern = $pattern
                                        Type = $file.Extension
                                    }
                                }
                            }
                        }
                    }
                    
                    if ($fileHasIssues) {
                        $affectedFiles++
                        Write-Host "  ⚠️  Problème détecté: $($file.Name)" -ForegroundColor Red
                    }
                }
            } catch {
                Write-Host "  ❌ Erreur lecture: $($file.Name)" -ForegroundColor Red
            }
        }
    } catch {
        Write-Host "Erreur lors de la recherche $ext : $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Affichage des résultats
Write-Host "`n=== RÉSULTATS ===" -ForegroundColor Green
Write-Host "Fichiers analysés: $totalFiles" -ForegroundColor Cyan
Write-Host "Fichiers avec problèmes: $affectedFiles" -ForegroundColor Yellow
Write-Host "Total occurrences: $($results.Count)" -ForegroundColor Red

if ($results.Count -gt 0) {
    Write-Host "`n=== DÉTAILS DES PROBLÈMES ===" -ForegroundColor Yellow
    
    # Grouper par fichier
    $groupedResults = $results | Group-Object File
    
    foreach ($group in $groupedResults) {
        Write-Host "`n📄 $($group.Name)" -ForegroundColor Cyan
        foreach ($item in $group.Group) {
            Write-Host "   Ligne $($item.Line): $($item.Pattern)" -ForegroundColor Red
            Write-Host "   → $($item.Content)" -ForegroundColor Gray
        }
    }
    
    # Analyse par type
    Write-Host "`n=== RÉPARTITION PAR TYPE ===" -ForegroundColor Yellow
    $byType = $results | Group-Object Type
    foreach ($type in $byType) {
        Write-Host "$($type.Name): $($type.Count) occurrences" -ForegroundColor Cyan
    }
    
    # Fichiers critiques
    $criticalFiles = $results | Where-Object { $_.File -match "sync_roo_environment\.ps1|config\.json|servers\.json" }
    if ($criticalFiles) {
        Write-Host "`n=== FICHIERS CRITIQUES ===" -ForegroundColor Red
        foreach ($critical in $criticalFiles) {
            Write-Host "🚨 $($critical.File) - Ligne $($critical.Line)" -ForegroundColor Red
        }
    }
    
    # Recommandations
    Write-Host "`n=== RECOMMANDATIONS ===" -ForegroundColor Green
    Write-Host "1. 🔧 Remplacer les chemins absolus par `$PSScriptRoot" -ForegroundColor Yellow
    Write-Host "2. 📝 Utiliser des chemins relatifs dans les configurations" -ForegroundColor Yellow
    Write-Host "3. ⚙️  Créer des variables d'environnement pour les chemins" -ForegroundColor Yellow
    Write-Host "4. 🧪 Tester sur différents environnements" -ForegroundColor Yellow
    
} else {
    Write-Host "`n✅ Aucun chemin codé en dur détecté!" -ForegroundColor Green
}

Write-Host "`n=== FIN DE L'ANALYSE ===" -ForegroundColor Green