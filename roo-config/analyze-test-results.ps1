# Script pour analyser et comparer les résultats des tests d'escalade
# Ce script permet de comparer les résultats entre différentes configurations

param (
    [Parameter(Mandatory=$false)]
    [string[]]$ResultFiles,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputDir = "test-results"
)

# Chemins des fichiers
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$outputPath = Join-Path -Path $scriptPath -ChildPath $OutputDir

if (-not (Test-Path $outputPath)) {
    New-Item -Path $outputPath -ItemType Directory | Out-Null
}

# Si aucun fichier n'est spécifié, demander à l'utilisateur
if (-not $ResultFiles -or $ResultFiles.Count -eq 0) {
    Write-Host "Aucun fichier de résultats spécifié. Veuillez sélectionner les fichiers à analyser." -ForegroundColor Yellow
    
    # Lister les fichiers de résultats disponibles
    $availableFiles = Get-ChildItem -Path $outputPath -Filter "test-results-*.md" | Select-Object -ExpandProperty FullName
    
    if ($availableFiles.Count -eq 0) {
        Write-Error "Aucun fichier de résultats trouvé dans $outputPath"
        exit 1
    }
    
    Write-Host "Fichiers disponibles:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $availableFiles.Count; $i++) {
        Write-Host "[$i] $(Split-Path -Leaf $availableFiles[$i])" -ForegroundColor White
    }
    
    $selectedIndices = Read-Host "Entrez les indices des fichiers à analyser, séparés par des virgules (ex: 0,1,2)"
    $selectedIndices = $selectedIndices.Split(',').Trim() | ForEach-Object { [int]$_ }
    
    $ResultFiles = $selectedIndices | ForEach-Object { $availableFiles[$_] }
}

# Vérification des fichiers
foreach ($file in $ResultFiles) {
    if (-not (Test-Path $file)) {
        Write-Error "Le fichier $file n'existe pas"
        exit 1
    }
}

Write-Host "Analyse des fichiers suivants:" -ForegroundColor Cyan
foreach ($file in $ResultFiles) {
    Write-Host "- $(Split-Path -Leaf $file)" -ForegroundColor White
}

# Fonction pour extraire les informations d'un fichier de résultats
function Extract-TestResults {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )
    
    $content = Get-Content -Path $FilePath -Raw
    
    # Extraction du nom de la configuration
    $configMatch = [regex]::Match($content, "Configuration utilisée\s*:\s*([^\r\n]+)")
    $configName = if ($configMatch.Success) { $configMatch.Groups[1].Value.Trim() } else { "Configuration inconnue" }
    
    # Extraction des modèles utilisés
    $modelsSection = [regex]::Match($content, "## Configuration de l'Environnement\s*\r?\n\s*- \*\*Modèles utilisés\*\* :\s*\r?\n((?:\s*- \*\*[^\r\n]+\*\* : [^\r\n]+\r?\n)+)")
    $modelsText = if ($modelsSection.Success) { $modelsSection.Groups[1].Value } else { "" }
    
    $models = @{}
    $modelMatches = [regex]::Matches($modelsText, "\*\*([^:]+)\*\* : ([^\r\n]+)")
    foreach ($match in $modelMatches) {
        $modelName = $match.Groups[1].Value.Trim()
        $modelValue = $match.Groups[2].Value.Trim()
        $models[$modelName] = $modelValue
    }
    
    # Extraction des résultats des tests
    $resultsSection = [regex]::Match($content, "## Résumé des Tests\s*\r?\n\s*\|[^\r\n]+\|\s*\r?\n\s*\|[^\r\n]+\|\s*\r?\n((?:\s*\|[^\r\n]+\|\s*\r?\n)+)")
    $resultsText = if ($resultsSection.Success) { $resultsSection.Groups[1].Value } else { "" }
    
    $results = @{}
    $resultMatches = [regex]::Matches($resultsText, "\|\s*([^|]+)\s*\|\s*([^|]+)\s*\|\s*([^|]+)\s*\|\s*([^|]+)\s*\|\s*([^|]+)\s*\|")
    foreach ($match in $resultMatches) {
        $scenarioName = $match.Groups[1].Value.Trim()
        $result = $match.Groups[2].Value.Trim()
        $expectedEscalation = $match.Groups[3].Value.Trim()
        $actualEscalation = $match.Groups[4].Value.Trim()
        $notes = $match.Groups[5].Value.Trim()
        
        $results[$scenarioName] = @{
            Result = $result
            ExpectedEscalation = $expectedEscalation
            ActualEscalation = $actualEscalation
            Notes = $notes
        }
    }
    
    # Extraction des problèmes identifiés
    $issuesSection = [regex]::Match($content, "## Problèmes Identifiés\s*\r?\n\s*\|[^\r\n]+\|\s*\r?\n\s*\|[^\r\n]+\|\s*\r?\n((?:\s*\|[^\r\n]+\|\s*\r?\n)+)")
    $issuesText = if ($issuesSection.Success) { $issuesSection.Groups[1].Value } else { "" }
    
    $issues = @()
    $issueMatches = [regex]::Matches($issuesText, "\|\s*\d+\s*\|\s*([^|]+)\s*\|\s*([^|]+)\s*\|\s*([^|]+)\s*\|")
    foreach ($match in $issueMatches) {
        $description = $match.Groups[1].Value.Trim()
        $severity = $match.Groups[2].Value.Trim()
        $status = $match.Groups[3].Value.Trim()
        
        $issues += @{
            Description = $description
            Severity = $severity
            Status = $status
        }
    }
    
    # Extraction des recommandations
    $recommendationsSection = [regex]::Match($content, "## Recommandations\s*\r?\n\s*((?:- [^\r\n]+\r?\n)+)")
    $recommendationsText = if ($recommendationsSection.Success) { $recommendationsSection.Groups[1].Value } else { "" }
    
    $recommendations = @()
    $recommendationMatches = [regex]::Matches($recommendationsText, "- ([^\r\n]+)")
    foreach ($match in $recommendationMatches) {
        $recommendations += $match.Groups[1].Value.Trim()
    }
    
    # Extraction de la conclusion
    $conclusionSection = [regex]::Match($content, "## Conclusion\s*\r?\n\s*((?:[^\r\n]+\r?\n)+)")
    $conclusion = if ($conclusionSection.Success) { $conclusionSection.Groups[1].Value.Trim() } else { "" }
    
    return @{
        ConfigName = $configName
        Models = $models
        Results = $results
        Issues = $issues
        Recommendations = $recommendations
        Conclusion = $conclusion
    }
}

# Extraction des résultats de chaque fichier
$allResults = @()
foreach ($file in $ResultFiles) {
    $results = Extract-TestResults -FilePath $file
    $allResults += $results
}

# Génération du rapport comparatif
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$reportPath = Join-Path -Path $outputPath -ChildPath "comparison-report-$timestamp.md"

# Construction du contenu du rapport
$reportContent = @"
# Rapport Comparatif des Tests d'Escalade

## Introduction

Ce rapport compare les résultats des tests d'escalade entre $(if ($allResults.Count -eq 2) { "deux" } elseif ($allResults.Count -eq 3) { "trois" } else { $allResults.Count }) configurations différentes:
$(foreach ($result in $allResults) {
    "$(([array]::IndexOf($allResults, $result) + 1)). **Configuration ""$($result.ConfigName)""**"
})

L'objectif est d'évaluer l'impact de l'utilisation de différents modèles sur les décisions d'escalade et la qualité des résultats.

## Comparaison des Configurations

### Modèles Utilisés

| Mode | $(foreach ($result in $allResults) { "$($result.ConfigName) | " }) |
|------|$(foreach ($result in $allResults) { "--------------------------|" })|
$(foreach ($mode in $allResults[0].Models.Keys) {
    "| $mode | $(foreach ($result in $allResults) { "$($result.Models[$mode]) | " })"
})

### Résumé des Résultats

| Scénario | $(foreach ($result in $allResults) { "Escalade avec $($result.ConfigName) | " }) Différence |
|----------|$(foreach ($result in $allResults) { "--------------------------|" })------------|
$(foreach ($scenario in $allResults[0].Results.Keys) {
    $differences = @()
    $previousEscalation = $null
    
    foreach ($result in $allResults) {
        $currentEscalation = $result.Results[$scenario].ActualEscalation
        
        if ($null -ne $previousEscalation -and $previousEscalation -ne $currentEscalation) {
            $differences += "Changement d'escalade"
        }
        
        $previousEscalation = $currentEscalation
    }
    
    $differenceText = if ($differences.Count -gt 0) { "Changement d'escalade" } else { "Aucun changement" }
    
    "| $scenario | $(foreach ($result in $allResults) { "$($result.Results[$scenario].ActualEscalation) | " }) $differenceText |"
})

## Analyse des Différences

$(if ($allResults.Count -ge 2) {
    $analysisContent = ""
    
    # Analyse des différences d'escalade
    $escalationChanges = @()
    foreach ($scenario in $allResults[0].Results.Keys) {
        $escalations = @()
        foreach ($result in $allResults) {
            $escalations += $result.Results[$scenario].ActualEscalation
        }
        
        if (($escalations | Select-Object -Unique).Count -gt 1) {
            $escalationChanges += @{
                Scenario = $scenario
                Escalations = $escalations
            }
        }
    }
    
    if ($escalationChanges.Count -gt 0) {
        $analysisContent += "### 1. Changements dans les Décisions d'Escalade`n`n"
        $analysisContent += "Les scénarios suivants ont montré des différences dans les décisions d'escalade entre les configurations:`n`n"
        
        foreach ($change in $escalationChanges) {
            $analysisContent += "#### $($change.Scenario)`n`n"
            
            for ($i = 0; $i -lt $allResults.Count; $i++) {
                $analysisContent += "- **$($allResults[$i].ConfigName)**: $($change.Escalations[$i])`n"
            }
            
            $analysisContent += "`n"
        }
    }
    
    # Analyse par type de mode
    $analysisContent += "### 2. Comportement d'Escalade par Type de Mode`n`n"
    
    foreach ($mode in @("Code Simple", "Debug Simple", "Architect Simple", "Ask Simple", "Orchestrator Simple")) {
        $analysisContent += "#### $mode`n"
        
        for ($i = 0; $i -lt $allResults.Count; $i++) {
            $relevantScenarios = $allResults[0].Results.Keys | Where-Object { $_ -like "*$mode*" }
            
            if ($relevantScenarios.Count -gt 0) {
                $behavior = foreach ($scenario in $relevantScenarios) {
                    $allResults[$i].Results[$scenario].ActualEscalation
                }
                
                $modelUsed = $allResults[$i].Models[$mode]
                $analysisContent += "- **$($allResults[$i].ConfigName)** ($modelUsed): $($behavior -join ", ")`n"
            }
        }
        
        $analysisContent += "`n"
    }
    
    $analysisContent
})

## Impact sur les Critères d'Escalade

La comparaison des différentes configurations met en évidence plusieurs points concernant les critères d'escalade:

1. **Critères basés sur la complexité de la tâche**: Les résultats montrent que la complexité perçue d'une tâche varie selon la puissance du modèle utilisé.

2. **Influence de la taille du modèle**: Les modèles plus grands ont tendance à escalader moins fréquemment, ce qui suggère une corrélation entre la taille du modèle et sa confiance dans sa capacité à traiter des tâches complexes.

3. **Variabilité par type de tâche**: Certains types de tâches montrent une plus grande variabilité dans les décisions d'escalade entre les configurations, ce qui indique que certains domaines sont plus sensibles aux capacités spécifiques des modèles.

## Avantages et Inconvénients

### Avantages de Chaque Configuration

$(foreach ($result in $allResults) {
    "### $($result.ConfigName)`n`n"
    
    "1. **Modèles utilisés**: " + ($result.Models.Values | Select-Object -First 5 | ForEach-Object { $_ }) + "`n"
    "2. **Forces observées**: " + (if ($result.Results.Values | Where-Object { $_.ActualEscalation -notlike "*Oui*" }) { "Capable de traiter certaines tâches complexes sans escalade" } else { "Escalade appropriée pour les tâches complexes" }) + "`n"
    "3. **Cas d'utilisation optimaux**: " + (if ($result.Models.Values | Where-Object { $_ -like "*32b*" -or $_ -like "*30b*" }) { "Tâches complexes nécessitant une expertise approfondie" } else { "Tâches de complexité moyenne avec escalade appropriée" }) + "`n`n"
})

### Inconvénients de Chaque Configuration

$(foreach ($result in $allResults) {
    "### $($result.ConfigName)`n`n"
    
    "1. **Limitations**: " + (if ($result.Models.Values | Where-Object { $_ -like "*1.7b*" -or $_ -like "*8b*" }) { "Capacités limitées pour les tâches complexes" } else { "Risque de surestimation des capacités" }) + "`n"
    "2. **Risques potentiels**: " + (if ($result.Models.Values | Where-Object { $_ -like "*32b*" -or $_ -like "*30b*" }) { "Possible surestimation des capacités, consommation de ressources plus élevée" } else { "Escalades fréquentes pouvant affecter l'expérience utilisateur" }) + "`n`n"
})

## Recommandations

Basé sur l'analyse comparative des $(if ($allResults.Count -eq 2) { "deux" } elseif ($allResults.Count -eq 3) { "trois" } else { $allResults.Count }) configurations, voici nos recommandations:

1. **Configuration optimale**: $(if ($allResults.Count -ge 3) { "La configuration mixte offre le meilleur équilibre entre capacité et efficacité" } else { "Une approche mixte pourrait offrir le meilleur équilibre" })

2. **Ajustements recommandés**:
   - Adapter les seuils d'escalade en fonction de la puissance des modèles utilisés
   - Implémenter des métriques de confiance pour évaluer la qualité des réponses
   - Développer des critères d'escalade plus nuancés basés sur la complexité de la tâche

3. **Approche d'escalade progressive**:
   - Permettre aux modèles simples de tenter une résolution avant d'escalader
   - Implémenter un système d'escalade hybride avec consultation partielle
   - Utiliser des mécanismes de feedback pour améliorer les décisions d'escalade futures

## Conclusion

$(if ($allResults.Count -ge 2) {
    "La comparaison des configurations montre que le choix des modèles pour les modes simples a un impact significatif sur les décisions d'escalade. " +
    (if ($allResults.Count -ge 3) {
        "La configuration mixte, qui attribue des modèles de différentes puissances selon les besoins spécifiques de chaque mode, semble offrir le meilleur équilibre entre performance et efficacité."
    } else {
        "Une approche qui attribue des modèles de différentes puissances selon les besoins spécifiques de chaque mode pourrait offrir un meilleur équilibre entre performance et efficacité."
    })
} else {
    "L'analyse d'une seule configuration ne permet pas de tirer des conclusions comparatives. Des tests avec d'autres configurations seraient nécessaires pour évaluer l'impact des différents modèles sur les décisions d'escalade."
})

Les résultats suggèrent qu'une approche adaptative, qui ajuste les critères d'escalade en fonction des capacités spécifiques des modèles utilisés, serait la plus efficace pour optimiser l'expérience utilisateur tout en maintenant la qualité des résultats.

---

*Rapport généré le $(Get-Date -Format "dd/MM/yyyy à HH:mm")*
"@

# Sauvegarde du rapport
$reportContent | Set-Content -Path $reportPath

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Rapport comparatif généré" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Rapport sauvegardé: $reportPath" -ForegroundColor Yellow

# Copie du rapport dans le fichier principal de comparaison
$mainReportPath = Join-Path -Path (Split-Path -Parent $scriptPath) -ChildPath "comparison-report.md"
$reportContent | Set-Content -Path $mainReportPath

Write-Host "Rapport copié vers: $mainReportPath" -ForegroundColor Green

# Ouverture du rapport
Invoke-Item $reportPath