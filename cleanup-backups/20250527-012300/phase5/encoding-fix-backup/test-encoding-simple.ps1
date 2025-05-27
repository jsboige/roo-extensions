# Script de test d'encodage PowerShell (version simplifiée)
# Auteur: Roo (Assistant IA)
# Date: 26/05/2025

Write-Host "=== Test de configuration d'encodage PowerShell ===" -ForegroundColor Cyan
Write-Host "Date du test: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray

# Test 1: Vérification de OutputEncoding
Write-Host "`n1. Test OutputEncoding" -ForegroundColor Yellow
Write-Host "   Valeur actuelle: $($OutputEncoding.EncodingName)" -ForegroundColor White
if ($OutputEncoding.EncodingName -like "*UTF-8*") {
    Write-Host "   ✓ OutputEncoding configuré en UTF-8" -ForegroundColor Green
    $test1 = $true
} else {
    Write-Host "   ✗ OutputEncoding n'est pas en UTF-8" -ForegroundColor Red
    $test1 = $false
}

# Test 2: Vérification de Console.OutputEncoding
Write-Host "`n2. Test Console.OutputEncoding" -ForegroundColor Yellow
Write-Host "   Valeur actuelle: $([Console]::OutputEncoding.EncodingName)" -ForegroundColor White
if ([Console]::OutputEncoding.EncodingName -like "*UTF-8*") {
    Write-Host "   ✓ Console.OutputEncoding configuré en UTF-8" -ForegroundColor Green
    $test2 = $true
} else {
    Write-Host "   ✗ Console.OutputEncoding n'est pas en UTF-8" -ForegroundColor Red
    $test2 = $false
}

# Test 3: Vérification de Console.InputEncoding
Write-Host "`n3. Test Console.InputEncoding" -ForegroundColor Yellow
Write-Host "   Valeur actuelle: $([Console]::InputEncoding.EncodingName)" -ForegroundColor White
if ([Console]::InputEncoding.EncodingName -like "*UTF-8*") {
    Write-Host "   ✓ Console.InputEncoding configuré en UTF-8" -ForegroundColor Green
    $test3 = $true
} else {
    Write-Host "   ✗ Console.InputEncoding n'est pas en UTF-8" -ForegroundColor Red
    $test3 = $false
}

# Test 4: Vérification de la code page
Write-Host "`n4. Test Code Page" -ForegroundColor Yellow
$codePage = (chcp) -replace ".*: ", ""
Write-Host "   Code page actuelle: $codePage" -ForegroundColor White
if ($codePage -eq "65001") {
    Write-Host "   ✓ Code page configurée en 65001 (UTF-8)" -ForegroundColor Green
    $test4 = $true
} else {
    Write-Host "   ✗ Code page n'est pas 65001 (UTF-8)" -ForegroundColor Red
    $test4 = $false
}

# Test 5: Affichage de caractères français
Write-Host "`n5. Test d'affichage des caractères français" -ForegroundColor Yellow
$testChars = "àáâãäåæçèéêëìíîïñòóôõöøùúûüý"
Write-Host "   Caractères de test: $testChars" -ForegroundColor White
Write-Host "   Si vous voyez correctement tous les caractères accentués ci-dessus, le test est réussi." -ForegroundColor Gray

# Test 6: Test avec des mots français complets
Write-Host "`n6. Test avec des mots français" -ForegroundColor Yellow
$frenchWords = @("français", "créé", "répertoire", "tâche", "problème", "sélectionné")
foreach ($word in $frenchWords) {
    Write-Host "   • $word" -ForegroundColor White
}

# Résumé des tests
Write-Host "`n=== Résumé des tests ===" -ForegroundColor Cyan
$allTests = @($test1, $test2, $test3, $test4)
$passedTests = ($allTests | Where-Object { $_ }).Count
$totalTests = $allTests.Count

Write-Host "Tests automatiques réussis: $passedTests/$totalTests" -ForegroundColor $(if ($passedTests -eq $totalTests) { "Green" } else { "Yellow" })

if ($passedTests -eq $totalTests) {
    Write-Host "✓ Tous les tests automatiques sont réussis !" -ForegroundColor Green
    Write-Host "✓ Vérifiez visuellement que les caractères français s'affichent correctement." -ForegroundColor Green
} else {
    Write-Host "⚠ Certains tests ont échoué. La configuration peut nécessiter des ajustements." -ForegroundColor Yellow
}

# Informations supplémentaires
Write-Host "`n=== Informations système ===" -ForegroundColor Cyan
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
Write-Host "Culture: $((Get-Culture).Name)" -ForegroundColor Gray
Write-Host "UI Culture: $((Get-UICulture).Name)" -ForegroundColor Gray

Write-Host "`n=== Test terminé ===" -ForegroundColor Cyan
