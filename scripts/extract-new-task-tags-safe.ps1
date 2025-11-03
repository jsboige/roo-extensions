<#
.SYNOPSIS
    Extraction sécurisée des balises <new_task> d'une tâche parent avec streaming

.DESCRIPTION
    Script PowerShell pour extraire toutes les balises <new_task> d'une tâche parent
    et vérifier la relation avec une tâche enfant. Utilise le streaming pour éviter
    les débordements mémoire (buffer max 8 KB).

.PARAMETER ParentTaskId
    ID de la tâche parent (ex: 20251025_012516_aXeVSCjf)

.PARAMETER ChildTaskId
    ID de la tâche enfant (ex: 20251025_015155_kfbDPGSg)

.EXAMPLE
    pwsh -NoProfile -ExecutionPolicy Bypass -File "scripts/extract-new-task-tags-safe.ps1" `
      -ParentTaskId "20251025_012516_aXeVSCjf" `
      -ChildTaskId "20251025_015155_kfbDPGSg"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ParentTaskId,
    
    [Parameter(Mandatory=$true)]
    [string]$ChildTaskId
)

$ErrorActionPreference = "Stop"

# Configuration
$storageRoot = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks"
$reportPath = "docs\NEW-TASK-EXTRACTION-REPORT-20251025.md"
$bufferSize = 8192  # 8 KB
$overlapSize = 1024 # 1 KB de chevauchement pour les balises fragmentées

Write-Host "=== Extraction des balises <new_task> ===" -ForegroundColor Cyan
Write-Host "Parent Task ID: $ParentTaskId" -ForegroundColor Yellow
Write-Host "Child Task ID: $ChildTaskId" -ForegroundColor Yellow
Write-Host ""

# Étape 1: Localisation des fichiers
Write-Host "[1/5] Localisation des fichiers de conversation..." -ForegroundColor Cyan

$parentDir = Get-ChildItem -Path $storageRoot -Directory | Where-Object { $_.Name -like "$ParentTaskId*" } | Select-Object -First 1
if (-not $parentDir) {
    Write-Error "Répertoire parent introuvable pour l'ID: $ParentTaskId"
}

$childDir = Get-ChildItem -Path $storageRoot -Directory | Where-Object { $_.Name -like "$ChildTaskId*" } | Select-Object -First 1
if (-not $childDir) {
    Write-Error "Répertoire enfant introuvable pour l'ID: $ChildTaskId"
}

$parentApiHistoryPath = Join-Path $parentDir.FullName "api_conversation_history.json"
$childApiHistoryPath = Join-Path $childDir.FullName "api_conversation_history.json"

if (-not (Test-Path $parentApiHistoryPath)) {
    Write-Error "Fichier parent introuvable: $parentApiHistoryPath"
}

if (-not (Test-Path $childApiHistoryPath)) {
    Write-Error "Fichier enfant introuvable: $childApiHistoryPath"
}

$parentFileSize = (Get-Item $parentApiHistoryPath).Length
Write-Host "  ✓ Fichier parent trouvé: $([math]::Round($parentFileSize / 1MB, 2)) MB" -ForegroundColor Green
Write-Host "  ✓ Fichier enfant trouvé" -ForegroundColor Green
Write-Host ""

# Étape 2: Extraction de l'instruction enfant
Write-Host "[2/5] Extraction de l'instruction enfant..." -ForegroundColor Cyan

$childContent = Get-Content $childApiHistoryPath -Raw -Encoding UTF8 | ConvertFrom-Json
$childInstruction = ""

# Recherche de l'instruction dans le premier message utilisateur
foreach ($msg in $childContent) {
    if ($msg.role -eq "user" -and $msg.content) {
        foreach ($content in $msg.content) {
            if ($content.type -eq "text" -and $content.text) {
                $childInstruction = $content.text
                break
            }
        }
        if ($childInstruction) { break }
    }
}

if (-not $childInstruction) {
    Write-Error "Instruction enfant introuvable dans le fichier"
}

$childInstructionPreview = $childInstruction.Substring(0, [Math]::Min(100, $childInstruction.Length))
Write-Host "  ✓ Instruction enfant extraite ($($childInstruction.Length) caractères)" -ForegroundColor Green
Write-Host "  Preview: $childInstructionPreview..." -ForegroundColor Gray
Write-Host ""

# Étape 3: Streaming et extraction des balises <new_task>
Write-Host "[3/5] Streaming du fichier parent et extraction des balises..." -ForegroundColor Cyan

$startTime = Get-Date
$extractedTags = @()
$buffer = New-Object char[] $bufferSize
$overlap = ""
$totalRead = 0

$reader = [System.IO.StreamReader]::new($parentApiHistoryPath, [System.Text.Encoding]::UTF8)

try {
    while (($read = $reader.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $chunk = $overlap + (-join $buffer[0..($read-1)])
        $totalRead += $read
        
        # Extraction des balises <new_task>...</new_task>
        $regex = [regex]::new('<new_task>(.*?)</new_task>', [System.Text.RegularExpressions.RegexOptions]::Singleline)
        $matches = $regex.Matches($chunk)
        
        foreach ($match in $matches) {
            $extractedTags += $match.Groups[1].Value.Trim()
        }
        
        # Conserver un chevauchement pour les balises fragmentées
        if ($chunk.Length -gt $overlapSize) {
            $overlap = $chunk.Substring($chunk.Length - $overlapSize)
        } else {
            $overlap = $chunk
        }
        
        # Affichage de la progression
        $progressPercent = [math]::Round(($totalRead / $parentFileSize) * 100, 1)
        Write-Progress -Activity "Extraction des balises" -Status "$progressPercent% - $($extractedTags.Count) balises trouvées" -PercentComplete $progressPercent
    }
} finally {
    $reader.Close()
    Write-Progress -Activity "Extraction des balises" -Completed
}

$duration = (Get-Date) - $startTime
Write-Host "  ✓ Extraction terminée en $([math]::Round($duration.TotalSeconds, 2)) secondes" -ForegroundColor Green
Write-Host "  ✓ Nombre de balises <new_task> trouvées: $($extractedTags.Count)" -ForegroundColor Green
Write-Host ""

# Étape 4: Analyse de matching
Write-Host "[4/5] Analyse de matching avec l'instruction enfant..." -ForegroundColor Cyan

function Get-SimilarityScore {
    param(
        [string]$str1,
        [string]$str2
    )
    
    # Score de similarité simple basé sur les mots communs
    $words1 = $str1.ToLower() -split '\s+' | Where-Object { $_.Length -gt 3 }
    $words2 = $str2.ToLower() -split '\s+' | Where-Object { $_.Length -gt 3 }
    
    $commonWords = $words1 | Where-Object { $words2 -contains $_ }
    $totalWords = [Math]::Max($words1.Count, $words2.Count)
    
    if ($totalWords -eq 0) { return 0 }
    return [math]::Round(($commonWords.Count / $totalWords) * 100, 2)
}

$matchingResults = @()
$bestMatchIndex = -1
$bestMatchScore = 0

for ($i = 0; $i -lt $extractedTags.Count; $i++) {
    $tag = $extractedTags[$i]
    $score = Get-SimilarityScore -str1 $tag -str2 $childInstruction
    
    $matchingResults += [PSCustomObject]@{
        Index = $i + 1
        Score = $score
        TagPreview = $tag.Substring(0, [Math]::Min(150, $tag.Length)) + "..."
    }
    
    if ($score -gt $bestMatchScore) {
        $bestMatchScore = $score
        $bestMatchIndex = $i
    }
}

Write-Host "  ✓ Meilleur matching: Balise #$($bestMatchIndex + 1) avec score de $bestMatchScore%" -ForegroundColor $(if ($bestMatchScore -gt 50) { "Green" } else { "Yellow" })
Write-Host ""

# Étape 5: Génération du rapport
Write-Host "[5/5] Génération du rapport markdown..." -ForegroundColor Cyan

$reportContent = @"
# Rapport d'extraction des balises <new_task>

**Date**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")  
**Parent Task**: $ParentTaskId  
**Child Task**: $ChildTaskId  

---

## Statistiques

- **Nombre de balises <new_task> trouvées**: $($extractedTags.Count)
- **Taille du fichier parent**: $([math]::Round($parentFileSize / 1MB, 2)) MB
- **Durée du traitement**: $([math]::Round($duration.TotalSeconds, 2)) secondes
- **Buffer utilisé**: $bufferSize octets (8 KB)
- **Chevauchement**: $overlapSize octets (1 KB)

---

## Instruction enfant

``````
$childInstruction
``````

---

## Analyse de matching

- **Matching trouvé**: $(if ($bestMatchScore -gt 50) { "✅ Oui" } else { "⚠️ Incertain" })
- **Index de la balise correspondante**: #$($bestMatchIndex + 1)
- **Score de similarité**: **$bestMatchScore%**

### Scores par balise

| # | Score | Preview |
|---|-------|---------|
"@

foreach ($result in $matchingResults) {
    $emoji = if ($result.Score -eq $bestMatchScore) { "🎯" } elseif ($result.Score -gt 30) { "✅" } else { "⚠️" }
    $reportContent += "`n| $emoji $($result.Index) | $($result.Score)% | $($result.TagPreview) |"
}

$reportContent += @"

---

## Balises extraites (détail)

"@

for ($i = 0; $i -lt $extractedTags.Count; $i++) {
    $tag = $extractedTags[$i]
    $score = $matchingResults[$i].Score
    $emoji = if ($score -eq $bestMatchScore) { "🎯" } elseif ($score -gt 30) { "✅" } else { "⚠️" }
    
    $reportContent += @"

### $emoji Balise #$($i + 1)

**Score de matching avec l'enfant**: $score%

``````xml
<new_task>
$tag
</new_task>
``````

---

"@
}

$reportContent += @"

## Conclusion

"@

if ($bestMatchScore -gt 70) {
    $reportContent += "✅ **Matching confirmé** - La balise #$($bestMatchIndex + 1) correspond très probablement à l'instruction enfant (score: $bestMatchScore%)."
} elseif ($bestMatchScore -gt 50) {
    $reportContent += "⚠️ **Matching probable** - La balise #$($bestMatchIndex + 1) semble correspondre à l'instruction enfant, mais avec un score moyen (score: $bestMatchScore%)."
} else {
    $reportContent += "❌ **Matching incertain** - Aucune balise ne correspond clairement à l'instruction enfant (meilleur score: $bestMatchScore%)."
}

$reportContent += @"


### Recommandations

1. Vérifier manuellement la balise #$($bestMatchIndex + 1) pour confirmer le matching
2. Si le score est faible, examiner les autres balises avec scores > 30%
3. Vérifier que l'instruction enfant n'a pas été modifiée après sa création

---

**Rapport généré par**: extract-new-task-tags-safe.ps1  
**Version du script**: 1.0.0  
**Date d'exécution**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@

# Sauvegarde du rapport
$reportContent | Out-File -FilePath $reportPath -Encoding UTF8 -Force

Write-Host "  ✓ Rapport généré: $reportPath" -ForegroundColor Green
Write-Host ""

# Résumé final
Write-Host "=== Résumé ===" -ForegroundColor Cyan
Write-Host "✓ Script exécuté avec succès" -ForegroundColor Green
Write-Host "✓ $($extractedTags.Count) balises <new_task> extraites" -ForegroundColor Green
Write-Host "✓ Meilleur matching: Balise #$($bestMatchIndex + 1) ($bestMatchScore%)" -ForegroundColor Green
Write-Host "✓ Rapport disponible: $reportPath" -ForegroundColor Green
Write-Host ""

# Affichage des 30 premières lignes du rapport
Write-Host "=== Aperçu du rapport (30 premières lignes) ===" -ForegroundColor Cyan
Get-Content $reportPath -TotalCount 30 -Encoding UTF8
Write-Host "..." -ForegroundColor Gray
Write-Host ""

Write-Host "Exécution terminée !" -ForegroundColor Green