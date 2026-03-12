# Script de validation de la hiérarchie des squelettes
# Mission Finale - Test Rebuild Timeout 300s
# Date: 2025-10-22

param(
    [string]$ParentTaskId = "cb7e564f-152f-48e3-8eff-f424d7ebc6bd",
    [string]$ChildTaskId = "18141742-f376-4053-8e1f-804d79daaf6d"
)

$ErrorActionPreference = "Stop"
$baseDir = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks\.skeletons"

Write-Host "`n=== VALIDATION HIÉRARCHIE SQUELETTES ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray

# Fonction pour afficher les détails d'un fichier
function Show-SkeletonDetails {
    param([string]$TaskId, [string]$Label)
    
    Write-Host "`n--- $Label ($TaskId) ---" -ForegroundColor Yellow
    $filePath = Join-Path $baseDir "$TaskId.json"
    
    if (-not (Test-Path $filePath)) {
        Write-Host "❌ FICHIER INTROUVABLE: $filePath" -ForegroundColor Red
        return $null
    }
    
    $file = Get-Item $filePath
    Write-Host "✅ Fichier trouvé" -ForegroundColor Green
    Write-Host "   Taille: $([math]::Round($file.Length/1KB, 2)) KB"
    Write-Host "   Dernière modification: $($file.LastWriteTime)"
    
    try {
        $content = Get-Content $filePath -Raw -Encoding UTF8 | ConvertFrom-Json
        Write-Host "   JSON valide: ✅" -ForegroundColor Green
        return $content
    }
    catch {
        Write-Host "   ❌ ERREUR JSON: $_" -ForegroundColor Red
        return $null
    }
}

# Fonction pour vérifier les métadonnées hiérarchiques
function Test-HierarchyMetadata {
    param($ParentContent, $ChildContent, $ParentId, $ChildId)
    
    Write-Host "`n=== VALIDATION MÉTADONNÉES ===" -ForegroundColor Cyan
    
    # Test 1: Parent contient childTaskInstructionPrefixes
    Write-Host "`n[TEST 1] Parent -> childTaskInstructionPrefixes" -ForegroundColor Yellow
    if ($ParentContent.childTaskInstructionPrefixes) {
        $prefixCount = $ParentContent.childTaskInstructionPrefixes.Count
        Write-Host "   ✅ Champ présent: $prefixCount préfixes" -ForegroundColor Green
        
        # Recherche du préfixe de l'enfant
        $childPrefixFound = $false
        foreach ($prefix in $ParentContent.childTaskInstructionPrefixes) {
            if ($prefix -like "bonjour. nous sommes à la dernière étape*") {
                Write-Host "   ✅ Préfixe enfant trouvé: '$($prefix.Substring(0, [Math]::Min(60, $prefix.Length)))...'" -ForegroundColor Green
                $childPrefixFound = $true
                break
            }
        }
        
        if (-not $childPrefixFound) {
            Write-Host "   ⚠️ Préfixe spécifique de l'enfant NON trouvé" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "   ❌ Champ ABSENT" -ForegroundColor Red
    }
    
    # Test 2: Enfant contient parentTaskId
    Write-Host "`n[TEST 2] Enfant -> parentTaskId" -ForegroundColor Yellow
    if ($ChildContent.PSObject.Properties.Name -contains "parentTaskId") {
        if ($ChildContent.parentTaskId -eq $ParentId) {
            Write-Host "   ✅ Champ présent et CORRECT: $($ChildContent.parentTaskId)" -ForegroundColor Green
            return $true
        }
        elseif ($ChildContent.parentTaskId) {
            Write-Host "   ⚠️ Champ présent mais INCORRECT: $($ChildContent.parentTaskId)" -ForegroundColor Yellow
            Write-Host "      Attendu: $ParentId" -ForegroundColor Gray
            return $false
        }
        else {
            Write-Host "   ❌ Champ présent mais NULL" -ForegroundColor Red
            return $false
        }
    }
    else {
        Write-Host "   ❌ Champ ABSENT (Phase 3 échouée)" -ForegroundColor Red
        
        # Recherche dans tout le fichier
        Write-Host "`n   Recherche dans le JSON complet..." -ForegroundColor Gray
        $jsonText = $ChildContent | ConvertTo-Json -Depth 10
        if ($jsonText -match "parentTaskId") {
            Write-Host "   ⚠️ Le terme 'parentTaskId' apparaît dans le JSON" -ForegroundColor Yellow
        }
        else {
            Write-Host "   ❌ Aucune trace de 'parentTaskId' dans le fichier" -ForegroundColor Red
        }
        
        return $false
    }
}

# Exécution principale
try {
    # Lecture des squelettes
    $parentContent = Show-SkeletonDetails -TaskId $ParentTaskId -Label "SQUELETTE PARENT"
    $childContent = Show-SkeletonDetails -TaskId $ChildTaskId -Label "SQUELETTE ENFANT"
    
    if (-not $parentContent -or -not $childContent) {
        Write-Host "`n❌ IMPOSSIBLE DE VALIDER: Fichiers manquants ou invalides" -ForegroundColor Red
        exit 1
    }
    
    # Validation hiérarchique
    $hierarchyValid = Test-HierarchyMetadata -ParentContent $parentContent -ChildContent $childContent -ParentId $ParentTaskId -ChildId $ChildTaskId
    
    # Résultat final
    Write-Host "`n=== RÉSULTAT FINAL ===" -ForegroundColor Cyan
    if ($hierarchyValid) {
        Write-Host "✅ SUCCÈS COMPLET: La hiérarchie est correctement établie" -ForegroundColor Green
        exit 0
    }
    else {
        Write-Host "❌ ÉCHEC: La relation parent-enfant n'est PAS persistée" -ForegroundColor Red
        Write-Host "`nPhase échouée: Phase 3 (Persistence)" -ForegroundColor Yellow
        exit 2
    }
}
catch {
    Write-Host "`n❌ ERREUR CRITIQUE: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    exit 99
}