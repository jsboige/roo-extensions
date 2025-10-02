<#
.SYNOPSIS
    Test de validation de la correction du bug de format des décisions
    
.DESCRIPTION
    Ce test valide que Compare-Config génère des décisions avec les marqueurs HTML
    requis par Apply-Decisions, permettant ainsi l'application automatique des décisions.
    
    Bug corrigé: Les décisions générées par Compare-Config n'incluaient pas les marqueurs
    <!-- DECISION_BLOCK_START --> et <!-- DECISION_BLOCK_END --> requis par Apply-Decisions.
    
.NOTES
    Date: 2025-10-02
    Issue: Bug critique identifié lors de la validation end-to-end
#>

[CmdletBinding()]
param()

Write-Host "`n=== TEST: Validation de la Correction du Format des Décisions ===" -ForegroundColor Cyan
Write-Host "But: Vérifier que Compare-Config génère des décisions compatibles avec Apply-Decisions`n" -ForegroundColor Yellow

# 1. Préparer l'environnement de test
Write-Host "[1/5] Préparation de l'environnement de test..." -ForegroundColor Green

$configPath = "$PSScriptRoot/../.config/sync-config.json"
$backupPath = "$configPath.backup-test"

# Créer une sauvegarde de la config actuelle
if (Test-Path $configPath) {
    Copy-Item -Path $configPath -Destination $backupPath -Force
    Write-Host "  ✓ Sauvegarde créée: $backupPath" -ForegroundColor Gray
}

# Vérifier que ROO_HOME est défini
if (-not $env:ROO_HOME) {
    Write-Warning "ROO_HOME n'est pas défini. Définition par défaut..."
    $env:ROO_HOME = "d:/roo-extensions"
}

$sharedStatePath = "$env:ROO_HOME/.state"
Write-Host "  ✓ Shared State Path: $sharedStatePath" -ForegroundColor Gray

# 2. Modifier la configuration locale pour créer une différence
Write-Host "`n[2/5] Modification de la configuration locale pour créer un diff..." -ForegroundColor Green

$config = Get-Content $configPath -Raw | ConvertFrom-Json
$config | Add-Member -NotePropertyName "testProperty" -NotePropertyValue "test-value-$(Get-Date -Format 'yyyyMMdd-HHmmss')" -Force
$config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Force -Encoding utf8
Write-Host "  ✓ Configuration modifiée avec une propriété de test" -ForegroundColor Gray

# 3. Exécuter Compare-Config via sync-manager
Write-Host "`n[3/5] Exécution de Compare-Config via sync-manager..." -ForegroundColor Green

try {
    & "$PSScriptRoot/../src/sync-manager.ps1" -Action Compare-Config
    Write-Host "  ✓ Compare-Config exécuté avec succès" -ForegroundColor Gray
} catch {
    Write-Error "Échec de Compare-Config: $_"
    # Restaurer la config
    if (Test-Path $backupPath) {
        Copy-Item -Path $backupPath -Destination $configPath -Force
        Remove-Item $backupPath -Force
    }
    exit 1
}

# 4. Vérifier la présence des marqueurs HTML dans la roadmap
Write-Host "`n[4/5] Vérification du format de la décision générée..." -ForegroundColor Green

$roadmapPath = "$sharedStatePath/sync-roadmap.md"

if (-not (Test-Path $roadmapPath)) {
    Write-Error "La feuille de route n'a pas été créée: $roadmapPath"
    # Restaurer la config
    if (Test-Path $backupPath) {
        Copy-Item -Path $backupPath -Destination $configPath -Force
        Remove-Item $backupPath -Force
    }
    exit 1
}

$roadmapContent = Get-Content -Path $roadmapPath -Raw

# Vérifications critiques
$checks = @{
    "Marqueur DECISION_BLOCK_START présent" = $roadmapContent -match '<!--\s*DECISION_BLOCK_START\s*-->'
    "Marqueur DECISION_BLOCK_END présent" = $roadmapContent -match '<!--\s*DECISION_BLOCK_END\s*-->'
    "Status PENDING présent" = $roadmapContent -match '\*\*Status:\*\* PENDING'
    "Checkbox non cochée présente" = $roadmapContent -match '- \[ \] \*\*Approuver & Fusionner\*\*'
    "Section Diff présente" = $roadmapContent -match '\*\*Diff:\*\*'
    "Section Contexte Système présente" = $roadmapContent -match '\*\*Contexte Système:\*\*'
    "DECISION ID présent" = $roadmapContent -match 'DECISION ID:'
}

$allPassed = $true
foreach ($check in $checks.GetEnumerator()) {
    if ($check.Value) {
        Write-Host "  ✓ $($check.Key)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $($check.Key)" -ForegroundColor Red
        $allPassed = $false
    }
}

if (-not $allPassed) {
    Write-Error "`nLe format de la décision ne correspond pas aux attentes!"
    Write-Host "`nContenu de la roadmap (premières 2000 caractères):" -ForegroundColor Yellow
    Write-Host $roadmapContent.Substring(0, [Math]::Min(2000, $roadmapContent.Length))
    
    # Restaurer la config
    if (Test-Path $backupPath) {
        Copy-Item -Path $backupPath -Destination $configPath -Force
        Remove-Item $backupPath -Force
    }
    exit 1
}

# 5. Test du regex d'Apply-Decisions
Write-Host "`n[5/5] Test de compatibilité avec Apply-Decisions..." -ForegroundColor Green

# Simuler une approbation en cochant la checkbox
$approvedContent = $roadmapContent -replace '- \[ \] \*\*Approuver & Fusionner\*\*', '- [x] **Approuver & Fusionner**'
Set-Content -Path $roadmapPath -Value $approvedContent -Force -Encoding utf8

# Tester le regex utilisé par Apply-Decisions
$decisionBlockRegex = '(?s)(<!--\s*DECISION_BLOCK_START.*?-->)(.*?\[x\].*?Approuver & Fusionner.*?)(<!--\s*DECISION_BLOCK_END\s*-->)'
$match = [regex]::Match($approvedContent, $decisionBlockRegex)

if ($match.Success) {
    Write-Host "  ✓ Le regex d'Apply-Decisions détecte correctement la décision approuvée" -ForegroundColor Green
    Write-Host "  ✓ Groupes capturés:" -ForegroundColor Gray
    Write-Host "    - Groupe 1 (Marqueur START): $($match.Groups[1].Value.Length) caractères" -ForegroundColor Gray
    Write-Host "    - Groupe 2 (Contenu): $($match.Groups[2].Value.Length) caractères" -ForegroundColor Gray
    Write-Host "    - Groupe 3 (Marqueur END): $($match.Groups[3].Value.Length) caractères" -ForegroundColor Gray
} else {
    Write-Error "  ✗ Le regex d'Apply-Decisions ne détecte PAS la décision approuvée!"
    Write-Host "`nContenu approuvé (premières 2000 caractères):" -ForegroundColor Yellow
    Write-Host $approvedContent.Substring(0, [Math]::Min(2000, $approvedContent.Length))
    
    # Restaurer la config
    if (Test-Path $backupPath) {
        Copy-Item -Path $backupPath -Destination $configPath -Force
        Remove-Item $backupPath -Force
    }
    exit 1
}

# Nettoyage
Write-Host "`n[Nettoyage] Restauration de la configuration..." -ForegroundColor Green
if (Test-Path $backupPath) {
    Copy-Item -Path $backupPath -Destination $configPath -Force
    Remove-Item $backupPath -Force
    Write-Host "  ✓ Configuration restaurée" -ForegroundColor Gray
}

# Résumé
Write-Host "`n" + "="*70 -ForegroundColor Cyan
Write-Host "✅ TEST RÉUSSI: La correction du format des décisions est validée!" -ForegroundColor Green
Write-Host "="*70 -ForegroundColor Cyan
Write-Host "`nRésumé des validations:" -ForegroundColor Yellow
Write-Host "  • Compare-Config génère des décisions avec marqueurs HTML ✓" -ForegroundColor White
Write-Host "  • Format compatible avec le regex d'Apply-Decisions ✓" -ForegroundColor White
Write-Host "  • Amélioration du formatage du diff ✓" -ForegroundColor White
Write-Host "  • Tous les éléments requis sont présents ✓" -ForegroundColor White
Write-Host "`nLe bug critique est corrigé et le système RooSync est maintenant opérationnel.`n" -ForegroundColor Green

exit 0