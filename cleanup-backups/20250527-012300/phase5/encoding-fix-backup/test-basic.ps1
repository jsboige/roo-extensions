# Test basique d'encodage PowerShell
# Auteur: Roo (Assistant IA)
# Date: 26/05/2025

Write-Host "=== Test de configuration d'encodage PowerShell ===" -ForegroundColor Cyan
Write-Host "Date du test: $(Get-Date)" -ForegroundColor Gray

# Test 1: OutputEncoding
Write-Host "`n1. Test OutputEncoding" -ForegroundColor Yellow
Write-Host "   Valeur: $($OutputEncoding.EncodingName)" -ForegroundColor White
$test1 = $OutputEncoding.EncodingName -like "*UTF-8*"
if ($test1) {
    Write-Host "   OK - OutputEncoding en UTF-8" -ForegroundColor Green
} else {
    Write-Host "   ERREUR - OutputEncoding pas en UTF-8" -ForegroundColor Red
}

# Test 2: Console.OutputEncoding
Write-Host "`n2. Test Console.OutputEncoding" -ForegroundColor Yellow
Write-Host "   Valeur: $([Console]::OutputEncoding.EncodingName)" -ForegroundColor White
$test2 = [Console]::OutputEncoding.EncodingName -like "*UTF-8*"
if ($test2) {
    Write-Host "   OK - Console.OutputEncoding en UTF-8" -ForegroundColor Green
} else {
    Write-Host "   ERREUR - Console.OutputEncoding pas en UTF-8" -ForegroundColor Red
}

# Test 3: Console.InputEncoding
Write-Host "`n3. Test Console.InputEncoding" -ForegroundColor Yellow
Write-Host "   Valeur: $([Console]::InputEncoding.EncodingName)" -ForegroundColor White
$test3 = [Console]::InputEncoding.EncodingName -like "*UTF-8*"
if ($test3) {
    Write-Host "   OK - Console.InputEncoding en UTF-8" -ForegroundColor Green
} else {
    Write-Host "   ERREUR - Console.InputEncoding pas en UTF-8" -ForegroundColor Red
}

# Test 4: Code page
Write-Host "`n4. Test Code Page" -ForegroundColor Yellow
$codePage = (chcp) -replace ".*: ", ""
Write-Host "   Code page: $codePage" -ForegroundColor White
$test4 = $codePage -eq "65001"
if ($test4) {
    Write-Host "   OK - Code page 65001 (UTF-8)" -ForegroundColor Green
} else {
    Write-Host "   ERREUR - Code page pas 65001" -ForegroundColor Red
}

# Test 5: Caracteres francais
Write-Host "`n5. Test caracteres francais" -ForegroundColor Yellow
$testChars = "àáâãäåæçèéêëìíîïñòóôõöøùúûüý"
Write-Host "   Test: $testChars" -ForegroundColor White
Write-Host "   Mots: français créé répertoire tâche problème" -ForegroundColor White

# Resume
Write-Host "`n=== Resume ===" -ForegroundColor Cyan
$allTests = @($test1, $test2, $test3, $test4)
$passedTests = ($allTests | Where-Object { $_ }).Count
$totalTests = $allTests.Count

Write-Host "Tests reussis: $passedTests/$totalTests" -ForegroundColor $(if ($passedTests -eq $totalTests) { "Green" } else { "Yellow" })

if ($passedTests -eq $totalTests) {
    Write-Host "SUCCES - Tous les tests sont OK" -ForegroundColor Green
} else {
    Write-Host "ATTENTION - Certains tests ont echoue" -ForegroundColor Yellow
}

# Infos systeme
Write-Host "`n=== Informations ===" -ForegroundColor Cyan
Write-Host "PowerShell: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
Write-Host "Culture: $((Get-Culture).Name)" -ForegroundColor Gray

Write-Host "`nTest termine" -ForegroundColor Cyan
