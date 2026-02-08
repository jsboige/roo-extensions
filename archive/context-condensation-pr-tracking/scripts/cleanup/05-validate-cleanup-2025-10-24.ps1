# Script SDDD 12.5: Validation post-nettoyage
# Date: 2025-10-24T10:16:00Z
# Objectif: Valider que le nettoyage a ete effectue correctement

Write-Host "SDDD 12.5 - Validation post-nettoyage" -ForegroundColor Cyan

# Fichiers critiques qui doivent etre presents apres nettoyage
$criticalFiles = @(
    "webview-ui/src/components/settings/__tests__/CondensationProviderSettings.spec.tsx",
    "webview-ui/vitest.config.ts",
    "webview-ui/vitest.setup.ts",
    "webview-ui/package.json",
    "webview-ui/tsconfig.json"
)

# Fichiers qui ne doivent plus etre presents apres nettoyage
$forbiddenFiles = @(
    "webview-ui/debug-test-output.txt",
    "webview-ui/debug-test.spec.tsx",
    "webview-ui/src/debug-test.spec.tsx",
    "webview-ui/src/basic-react-test.spec.tsx",
    "webview-ui/vitest.config.fixed.ts",
    "webview-ui/vitest.setup.fixed.ts"
)

Write-Host "Verification des fichiers critiques preserves:" -ForegroundColor Yellow
$criticalPresent = 0
$criticalMissing = 0

foreach ($file in $criticalFiles) {
    if (Test-Path $file) {
        Write-Host "  OK $file" -ForegroundColor Green
        $criticalPresent++
    } else {
        Write-Host "  MANQUANT $file" -ForegroundColor Red
        $criticalMissing++
    }
}

Write-Host "`nVerification des fichiers temporaires supprimes:" -ForegroundColor Yellow
$forbiddenPresent = 0
$forbiddenAbsent = 0

foreach ($file in $forbiddenFiles) {
    if (Test-Path $file) {
        Write-Host "  ENCORE PRESENT $file" -ForegroundColor Red
        $forbiddenPresent++
    } else {
        Write-Host "  CORRECTEMENT SUPPRIME $file" -ForegroundColor Green
        $forbiddenAbsent++
    }
}

# Verification avec git status
Write-Host "`nFichiers modifies/non suivis:" -ForegroundColor Yellow
$gitStatus = git status --porcelain 2>$null
if ($gitStatus) {
    Write-Host $gitStatus
} else {
    Write-Host "Aucun fichier modifie"
}

Write-Host "`nResume de la validation SDDD 12.5:" -ForegroundColor Cyan
Write-Host "  Fichiers critiques presents: $criticalPresent/$($criticalFiles.Count)" -ForegroundColor Green
Write-Host "  Fichiers temporaires supprimes: $forbiddenAbsent/$($forbiddenFiles.Count)" -ForegroundColor Green

if ($criticalMissing -eq 0 -and $forbiddenPresent -eq 0) {
    Write-Host "Validation SDDD 12.5 reussie - Nettoyage correct" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Validation SDDD 12.5 echouee - Problemes detectes" -ForegroundColor Red
    if ($criticalMissing -gt 0) {
        Write-Host "  Fichiers critiques manquants: $criticalMissing" -ForegroundColor Red
    }
    if ($forbiddenPresent -gt 0) {
        Write-Host "  Fichiers temporaires encore presents: $forbiddenPresent" -ForegroundColor Red
    }
    exit 1
}