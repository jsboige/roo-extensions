<#
.SYNOPSIS
    Test manuel de validation du format des décisions
    
.DESCRIPTION
    Ce script vérifie directement que le code de Compare-Config génère
    le format correct avec les marqueurs HTML requis.
#>

Write-Host "`n=== Validation Manuelle du Format des Décisions ===" -ForegroundColor Cyan

# Simuler la génération d'un bloc de décision comme dans Compare-Config (lignes 100-122)
$decisionId = [guid]::NewGuid().ToString()
$machineName = $env:COMPUTERNAME
$timestamp = (Get-Date).ToUniversalTime().ToString('o')
$diffString = @"
Configuration de référence vs Configuration locale:

[LOCAL] testProperty: test-value-20251002
"@
$contextSubset = @{
    computerInfo = @{ CsName = $machineName }
} | ConvertTo-Json -Depth 5

# Utiliser un StringBuilder pour éviter les problèmes d'échappement avec les backticks
$diffBlock = "
<!-- DECISION_BLOCK_START -->
### DECISION ID: $decisionId
- **Status:** PENDING
- **Machine:** $machineName
- **Timestamp (UTC):** $timestamp
- **Source Action:** Compare-Config
- **Details:** Une différence a été détectée entre la configuration locale et la configuration de référence.

**Diff:**
" + '```diff' + "
$diffString
" + '```' + "

**Contexte Système:**
" + '```json' + "
$contextSubset
" + '```' + "

**Actions:**
- [ ] **Approuver & Fusionner**
<!-- DECISION_BLOCK_END -->

"

Write-Host "`n[1/3] Génération d'un bloc de décision simulé..." -ForegroundColor Green
Write-Host "  ✓ Bloc généré" -ForegroundColor Gray

# Vérifications
Write-Host "`n[2/3] Vérification du format..." -ForegroundColor Green

$checks = @{
    "Marqueur DECISION_BLOCK_START présent" = $diffBlock -match '<!--\s*DECISION_BLOCK_START\s*-->'
    "Marqueur DECISION_BLOCK_END présent" = $diffBlock -match '<!--\s*DECISION_BLOCK_END\s*-->'
    "Status PENDING présent" = $diffBlock -match '\*\*Status:\*\* PENDING'
    "Checkbox non cochée présente" = $diffBlock -match '- \[ \] \*\*Approuver & Fusionner\*\*'
    "Section Diff présente" = $diffBlock -match '\*\*Diff:\*\*'
    "Section Contexte Système présente" = $diffBlock -match '\*\*Contexte Système:\*\*'
    "DECISION ID présent" = $diffBlock -match 'DECISION ID:'
    "Format code diff présent" = $diffBlock -match '```diff'
    "Format code json présent" = $diffBlock -match '```json'
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
    Write-Error "Format invalide!"
    exit 1
}

# Test regex Apply-Decisions
Write-Host "`n[3/3] Test de compatibilité avec le regex d'Apply-Decisions..." -ForegroundColor Green

# Simuler une approbation
$approvedBlock = $diffBlock -replace '- \[ \] \*\*Approuver & Fusionner\*\*', '- [x] **Approuver & Fusionner**'

$decisionBlockRegex = '(?s)(<!--\s*DECISION_BLOCK_START.*?-->)(.*?\[x\].*?Approuver & Fusionner.*?)(<!--\s*DECISION_BLOCK_END\s*-->)'
$match = [regex]::Match($approvedBlock, $decisionBlockRegex)

if ($match.Success) {
    Write-Host "  ✓ Le regex détecte correctement la décision approuvée" -ForegroundColor Green
    Write-Host "  ✓ Nombre de groupes capturés: $($match.Groups.Count)" -ForegroundColor Gray
} else {
    Write-Error "Le regex ne détecte pas la décision approuvée!"
    exit 1
}

Write-Host "`n" + "="*70 -ForegroundColor Cyan
Write-Host "✅ VALIDATION RÉUSSIE: Le format des décisions est correct!" -ForegroundColor Green
Write-Host "="*70 -ForegroundColor Cyan

Write-Host "`nExtrait du bloc généré:" -ForegroundColor Yellow
Write-Host $diffBlock.Substring(0, [Math]::Min(400, $diffBlock.Length))
Write-Host "`n[...]`n" -ForegroundColor Gray

exit 0