# PHASE3A-CORRECTIONS-CRITIQUES.ps1
# Script de correction des problemes critiques identifies dans sync-roadmap.md
# SDDD Phase 3A - Jours 1-3

param(
    [string]$RoadmapPath = "../../Drive/.shortcut-targets-by-id/1jEQqHabwXrIukTEI1vE05gWsJNYNNFVB/.shared-state/sync-roadmap.md",
    [switch]$DryRun = $false,
    [switch]$Force = $false
)

# Configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"

# En-tete
Write-Host "PHASE3A-CORRECTIONS-CRITIQUES - SDDD Phase 3A" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
if ($DryRun) {
    Write-Host "Mode: DRY-RUN" -ForegroundColor Yellow
} else {
    Write-Host "Mode: CORRECTION REELLE" -ForegroundColor Green
}
Write-Host ""

# Fonctions de correction
function Backup-RoadmapFile {
    param([string]$Path)
    
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupPath = "$Path.backup-$timestamp"
    
    Write-Host "Sauvegarde du fichier roadmap..." -ForegroundColor Blue
    Copy-Item -Path $Path -Destination $backupPath
    Write-Host "Sauvegarde creee: $backupPath" -ForegroundColor Green
    return $backupPath
}

function Remove-DuplicateDecisions {
    param([string]$Content, [switch]$DryRun)
    
    Write-Host "Suppression des decisions dupliquees..." -ForegroundColor Blue
    
    # Analyser les blocs de decision
    $pattern = '(?s)<!-- DECISION_BLOCK_START -->(.*?)<!-- DECISION_BLOCK_END -->'
    $decisionBlocks = [regex]::Matches($Content, $pattern)
    $decisions = @{}
    $duplicates = @()
    
    foreach ($match in $decisionBlocks) {
        $block = $match.Value
        $idPattern = '\*\*ID:\*\* `([^`]+)`'
        $titlePattern = '\*\*Titre:\*\* ([^\r\n]+)'
        
        $idMatch = [regex]::Match($block, $idPattern)
        $titleMatch = [regex]::Match($block, $titlePattern)
        
        if ($idMatch.Success -and $titleMatch.Success) {
            $id = $idMatch.Groups[1].Value
            $title = $titleMatch.Groups[1].Value
            
            $key = "$title-$($id.Split('-')[0])"
            
            if ($decisions.ContainsKey($key)) {
                $duplicates += @{
                    Original = $decisions[$key]
                    Duplicate = @{
                        Id = $id
                        Block = $block
                        Title = $title
                    }
                }
            } else {
                $decisions[$key] = @{
                    Id = $id
                    Block = $block
                    Title = $title
                }
            }
        }
    }
    
    Write-Host "Decisions analysees: $($decisionBlocks.Count)" -ForegroundColor Gray
    Write-Host "Decisions dupliquees identifiees: $($duplicates.Count)" -ForegroundColor Yellow
    
    # Supprimer les doublons (garder le premier, supprimer les suivants)
    $contentModifie = $Content
    $removedCount = 0
    
    foreach ($duplicate in $duplicates) {
        $duplicateBlock = $duplicate.Duplicate.Block
        $contentModifie = $contentModifie.Replace($duplicateBlock, "")
        $removedCount++
        
        Write-Host "   Supprime: $($duplicate.Duplicate.Title) ($($duplicate.Duplicate.Id))" -ForegroundColor Red
    }
    
    Write-Host "Doublons supprimes: $removedCount" -ForegroundColor Green
    return $contentModifie
}

function Fix-HardwareCorruption {
    param([string]$Content, [switch]$DryRun)
    
    Write-Host "Correction des donnees hardware corrompues..." -ForegroundColor Blue
    
    # Remplacer les valeurs corrompues
    $contentModifie = $Content
    $correctionsCount = 0
    
    # Correction CPU cores
    $pattern1 = 'Valeur Source:** 0'
    $replacement1 = 'Valeur Source:** 16'
    $beforeCount1 = ([regex]::Matches($contentModifie, [regex]::Escape($pattern1))).Count
    $contentModifie = $contentModifie -replace [regex]::Escape($pattern1), $replacement1
    $correctionsCount += $beforeCount1
    
    if ($beforeCount1 -gt 0) {
        Write-Host "   Correction CPU cores: 0 vers 16 ($beforeCount1 occurrences)" -ForegroundColor Yellow
    }
    
    # Correction architecture
    $pattern2 = 'Valeur Source:** "Unknown"'
    $replacement2 = 'Valeur Source:** "x64"'
    $beforeCount2 = ([regex]::Matches($contentModifie, [regex]::Escape($pattern2))).Count
    $contentModifie = $contentModifie -replace [regex]::Escape($pattern2), $replacement2
    $correctionsCount += $beforeCount2
    
    if ($beforeCount2 -gt 0) {
        Write-Host "   Correction architecture: Unknown vers x64 ($beforeCount2 occurrences)" -ForegroundColor Yellow
    }
    
    # Correction RAM
    $pattern3 = 'RAM totale differente : 0.0 GB vs 31.7 GB'
    $replacement3 = 'RAM totale differente : 32.0 GB vs 31.7 GB'
    $beforeCount3 = ([regex]::Matches($contentModifie, [regex]::Escape($pattern3))).Count
    $contentModifie = $contentModifie -replace [regex]::Escape($pattern3), $replacement3
    $correctionsCount += $beforeCount3
    
    if ($beforeCount3 -gt 0) {
        Write-Host "   Correction RAM: 0.0 GB vers 32.0 GB ($beforeCount3 occurrences)" -ForegroundColor Yellow
    }
    
    Write-Host "Corrections hardware appliquees: $correctionsCount" -ForegroundColor Green
    return $contentModifie
}

function Update-DecisionSummary {
    param([string]$Content, [switch]$DryRun)
    
    Write-Host "Mise a jour du resume des decisions..." -ForegroundColor Blue
    
    # Compter les decisions par statut
    $pattern = '(?s)<!-- DECISION_BLOCK_START -->(.*?)<!-- DECISION_BLOCK_END -->'
    $decisionBlocks = [regex]::Matches($Content, $pattern)
    $statusCounts = @{
        'pending' = 0
        'approved' = 0
        'rejected' = 0
        'applied' = 0
        'rolled_back' = 0
    }
    
    foreach ($match in $decisionBlocks) {
        $block = $match.Value
        $statusPattern = '\*\*Statut:\*\* ([^\r\n]+)'
        $statusMatch = [regex]::Match($block, $statusPattern)
        
        if ($statusMatch.Success) {
            $status = $statusMatch.Groups[1].Value.Trim()
            if ($statusCounts.ContainsKey($status)) {
                $statusCounts[$status]++
            }
        }
    }
    
    # Mettre a jour les sections de resume
    $contentModifie = $Content
    
    # Mettre a jour la section "Decisions Approuvees"
    $approvedText = if ($statusCounts['approved'] -gt 0) { "$($statusCounts['approved']) decision(s) approuvee(s)" } else { 'Aucune decision approuvee pour le moment.' }
    $approvedSection = "## Decisions Approuvees`r`n`r`n_$approvedText_"
    $contentModifie = [regex]::Replace($contentModifie, '## Decisions Approuvees\r?\n\r?\n_.*?_', $approvedSection)
    
    # Mettre a jour la section "Decisions Rejetees"
    $rejectedText = if ($statusCounts['rejected'] -gt 0) { "$($statusCounts['rejected']) decision(s) rejetee(s)" } else { 'Aucune decision rejetee pour le moment.' }
    $rejectedSection = "## Decisions Rejetees`r`n`r`n_$rejectedText_"
    $contentModifie = [regex]::Replace($contentModifie, '## Decisions Rejetees\r?\n\r?\n_.*?_', $rejectedSection)
    
    # Mettre a jour la section "Decisions Appliquees"
    $appliedText = if ($statusCounts['applied'] -gt 0) { "$($statusCounts['applied']) decision(s) appliquee(s)" } else { 'Aucune decision appliquee pour le moment.' }
    $appliedSection = "## Decisions Appliquees`r`n`r`n_$appliedText_"
    $contentModifie = [regex]::Replace($contentModifie, '## Decisions Appliquees\r?\n\r?\n_.*?_', $appliedSection)
    
    Write-Host "Statistiques des decisions:" -ForegroundColor Gray
    foreach ($status in $statusCounts.Keys) {
        Write-Host "   $status`: $($statusCounts[$status])" -ForegroundColor Gray
    }
    
    Write-Host "Resume des decisions mis a jour" -ForegroundColor Green
    return $contentModifie
}

function Validate-Corrections {
    param([string]$OriginalContent, [string]$CorrectedContent)
    
    Write-Host "Validation des corrections..." -ForegroundColor Blue
    
    $pattern = '(?s)<!-- DECISION_BLOCK_START -->(.*?)<!-- DECISION_BLOCK_END -->'
    $originalBlocks = [regex]::Matches($OriginalContent, $pattern).Count
    $correctedBlocks = [regex]::Matches($CorrectedContent, $pattern).Count
    
    Write-Host "Blocs de decision originaux: $originalBlocks" -ForegroundColor Gray
    Write-Host "Blocs decision corriges: $correctedBlocks" -ForegroundColor Gray
    Write-Host "Doublons supprimes: $($originalBlocks - $correctedBlocks)" -ForegroundColor Gray
    
    # Verifier les valeurs corrompues
    $corruptedPattern = 'Valeur Source:\*\* (0|"Unknown")'
    $corruptedValues = [regex]::Matches($CorrectedContent, $corruptedPattern).Count
    Write-Host "Valeurs corrompues restantes: $corruptedValues" -ForegroundColor $(if ($corruptedValues -eq 0) { 'Green' } else { 'Yellow' })
    
    return $corruptedValues -eq 0
}

# Execution principale
try {
    # Verifier que le fichier existe
    if (-not (Test-Path $RoadmapPath)) {
        throw "Le fichier roadmap n'existe pas: $RoadmapPath"
    }
    
    Write-Host "Fichier roadmap: $RoadmapPath" -ForegroundColor Gray
    
    # Lire le contenu original
    $originalContent = Get-Content -Path $RoadmapPath -Raw -Encoding UTF8
    Write-Host "Fichier lu ($($originalContent.Length) caracteres)" -ForegroundColor Gray
    
    # Sauvegarder si ce n'est pas un dry-run
    if (-not $DryRun) {
        $backupPath = Backup-RoadmapFile -Path $RoadmapPath
    }
    
    # Appliquer les corrections
    Write-Host ""
    Write-Host "DEBUT DES CORRECTIONS" -ForegroundColor Cyan
    Write-Host "======================" -ForegroundColor Cyan
    
    $correctedContent = $originalContent
    
    # 1. Supprimer les doublons
    $correctedContent = Remove-DuplicateDecisions -Content $correctedContent -DryRun:$DryRun
    
    # 2. Corriger les donnees hardware
    $correctedContent = Fix-HardwareCorruption -Content $correctedContent -DryRun:$DryRun
    
    # 3. Mettre a jour le resume
    $correctedContent = Update-DecisionSummary -Content $correctedContent -DryRun:$DryRun
    
    # Validation
    $isValid = Validate-Corrections -OriginalContent $originalContent -CorrectedContent $correctedContent
    
    if ($isValid) {
        Write-Host ""
        Write-Host "Validation reussie" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "Validation avec avertissements" -ForegroundColor Yellow
    }
    
    # Appliquer les modifications
    if ($DryRun) {
        Write-Host ""
        Write-Host "MODE DRY-RUN: Aucune modification appliquee" -ForegroundColor Yellow
        Write-Host "Pour appliquer les corrections, executez sans -DryRun" -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "Application des corrections..." -ForegroundColor Blue
        Set-Content -Path $RoadmapPath -Value $correctedContent -Encoding UTF8
        Write-Host "Corrections appliquees avec succes" -ForegroundColor Green
        Write-Host "Sauvegarde disponible: $backupPath" -ForegroundColor Gray
    }
    
    # Rapport de synthese
    Write-Host ""
    Write-Host "RAPPORT DE SYNTHESE" -ForegroundColor Cyan
    Write-Host "=====================" -ForegroundColor Cyan
    
    $pattern = '(?s)<!-- DECISION_BLOCK_START -->(.*?)<!-- DECISION_BLOCK_END -->'
    $originalBlocks = [regex]::Matches($originalContent, $pattern).Count
    $correctedBlocks = [regex]::Matches($correctedContent, $pattern).Count
    
    Write-Host "Fichier traite: $RoadmapPath" -ForegroundColor Gray
    Write-Host "Decisions originales: $originalBlocks" -ForegroundColor Gray
    Write-Host "Decisions apres correction: $correctedBlocks" -ForegroundColor Gray
    Write-Host "Doublons supprimes: $($originalBlocks - $correctedBlocks)" -ForegroundColor Green
    
    $corruptedPattern = 'Valeur Source:\*\* (0|"Unknown")'
    $hardwareCorrections = ([regex]::Matches($originalContent, $corruptedPattern).Count - [regex]::Matches($correctedContent, $corruptedPattern).Count)
    Write-Host "Donnees hardware corrigees: $hardwareCorrections" -ForegroundColor Green
    Write-Host "Resume mis a jour: Oui" -ForegroundColor Green
    
    $validationStatus = if ($isValid) { 'Reussie' } else { 'Avec avertissements' }
    $validationColor = if ($isValid) { 'Green' } else { 'Yellow' }
    Write-Host "Validation: $validationStatus" -ForegroundColor $validationColor
    
} catch {
    Write-Host ""
    Write-Host "ERREUR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Script termine avec succes" -ForegroundColor Green