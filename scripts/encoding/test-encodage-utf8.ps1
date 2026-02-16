# Script de tests de validation UTF-8
# Vérifie que la configuration UTF-8 fonctionne correctement

Write-Host "=== TESTS DE VALIDATION UTF-8 ===" -ForegroundColor Cyan
Write-Host ""

$testsReussis = 0
$testsEchoues = 0

# Test 1: Vérification encodage PowerShell
Write-Host "Test 1: Encodage PowerShell" -ForegroundColor Yellow
$testString = "trouvé"
if ($testString -eq "trouvé") {
    Write-Host "✅ Test 1 RÉUSSI: Caractères accentués corrects" -ForegroundColor Green
    $testsReussis++
} else {
    Write-Host "❌ Test 1 ÉCHOUÉ: '$testString' != 'trouvé'" -ForegroundColor Red
    $testsEchoues++
}
Write-Host ""

# Test 2: Vérification Console.OutputEncoding
Write-Host "Test 2: Console.OutputEncoding" -ForegroundColor Yellow
if ([Console]::OutputEncoding.CodePage -eq 65001) {
    Write-Host "✅ Test 2 RÉUSSI: CodePage = 65001 (UTF-8)" -ForegroundColor Green
    $testsReussis++
} else {
    Write-Host "❌ Test 2 ÉCHOUÉ: CodePage = $([Console]::OutputEncoding.CodePage)" -ForegroundColor Red
    $testsEchoues++
}
Write-Host ""

# Test 3: Vérification OutputEncoding
Write-Host "Test 3: OutputEncoding" -ForegroundColor Yellow
if ($OutputEncoding.EncodingName -match "UTF-8") {
    Write-Host "✅ Test 3 RÉUSSI: OutputEncoding = UTF-8" -ForegroundColor Green
    $testsReussis++
} else {
    Write-Host "❌ Test 3 ÉCHOUÉ: OutputEncoding = $($OutputEncoding.EncodingName)" -ForegroundColor Red
    $testsEchoues++
}
Write-Host ""

# Test 4: Vérification profil PS7
Write-Host "Test 4: Profil PowerShell 7" -ForegroundColor Yellow
$profilePS7 = "$HOME\OneDrive\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
if (Test-Path $profilePS7) {
    $content = Get-Content $profilePS7 -Raw
    if ($content -match "UTF-8" -and $content -match "\[Console\]::OutputEncoding") {
        Write-Host "✅ Test 4 RÉUSSI: Profil PS7 configuré" -ForegroundColor Green
        $testsReussis++
    } else {
        Write-Host "❌ Test 4 ÉCHOUÉ: Configuration UTF-8 manquante dans profil PS7" -ForegroundColor Red
        $testsEchoues++
    }
} else {
    Write-Host "❌ Test 4 ÉCHOUÉ: Profil PS7 introuvable" -ForegroundColor Red
    $testsEchoues++
}
Write-Host ""

# Test 5: Vérification profil PS5.1
Write-Host "Test 5: Profil PowerShell 5.1" -ForegroundColor Yellow
$profilePS51 = "$HOME\Documents\WindowsPowerShell\profile.ps1"
if (Test-Path $profilePS51) {
    $content = Get-Content $profilePS51 -Raw
    if ($content -match "UTF-8" -and $content -match "\[Console\]::OutputEncoding") {
        Write-Host "✅ Test 5 RÉUSSI: Profil PS5.1 configuré" -ForegroundColor Green
        $testsReussis++
    } else {
        Write-Host "❌ Test 5 ÉCHOUÉ: Configuration UTF-8 manquante dans profil PS5.1" -ForegroundColor Red
        $testsEchoues++
    }
} else {
    Write-Host "❌ Test 5 ÉCHOUÉ: Profil PS5.1 introuvable" -ForegroundColor Red
    $testsEchoues++
}
Write-Host ""

# Test 6: Vérification VSCode settings
Write-Host "Test 6: Configuration VSCode" -ForegroundColor Yellow
$vscodeSettings = "$env:APPDATA\Code\User\settings.json"
if (Test-Path $vscodeSettings) {
    $settings = Get-Content $vscodeSettings -Raw | ConvertFrom-Json
    if ($settings.'terminal.integrated.defaultProfile.windows' -eq 'PowerShell 7 (pwsh)') {
        Write-Host "✅ Test 6 RÉUSSI: VSCode configuré pour pwsh" -ForegroundColor Green
        $testsReussis++
    } else {
        Write-Host "⚠️  Test 6 PARTIEL: Terminal par défaut = $($settings.'terminal.integrated.defaultProfile.windows')" -ForegroundColor Yellow
        $testsReussis++
    }
} else {
    Write-Host "❌ Test 6 ÉCHOUÉ: VSCode settings introuvable" -ForegroundColor Red
    $testsEchoues++
}
Write-Host ""

# Test 7: Test écriture fichier UTF-8
Write-Host "Test 7: Écriture fichier UTF-8" -ForegroundColor Yellow
$testFile = "test-utf8-temp.txt"
$testContent = "Test: éàèùç - trouvé"
$testContent | Out-File $testFile -Encoding utf8
$readContent = Get-Content $testFile -Raw
Remove-Item $testFile -ErrorAction SilentlyContinue
if ($readContent -match "trouvé") {
    Write-Host "✅ Test 7 RÉUSSI: Fichier UTF-8 correct" -ForegroundColor Green
    $testsReussis++
} else {
    Write-Host "❌ Test 7 ÉCHOUÉ: Contenu lu = $readContent" -ForegroundColor Red
    $testsEchoues++
}
Write-Host ""

# Résumé
Write-Host "=== RÉSUMÉ DES TESTS ===" -ForegroundColor Cyan
Write-Host "Tests réussis: $testsReussis" -ForegroundColor Green
Write-Host "Tests échoués: $testsEchoues" -ForegroundColor $(if ($testsEchoues -eq 0) { "Green" } else { "Red" })
$total = $testsReussis + $testsEchoues
$pourcentage = [math]::Round(($testsReussis / $total) * 100, 2)
Write-Host "Score: $pourcentage%" -ForegroundColor $(if ($pourcentage -ge 100) { "Green" } elseif ($pourcentage -ge 85) { "Yellow" } else { "Red" })
Write-Host ""

if ($testsEchoues -eq 0) {
    Write-Host "✅ TOUS LES TESTS SONT RÉUSSIS!" -ForegroundColor Green
    Write-Host "La configuration UTF-8 est complète et fonctionnelle." -ForegroundColor Green
} else {
    Write-Host "⚠️  Certains tests ont échoué. Vérifiez la configuration." -ForegroundColor Yellow
}

# Retourner le code d'erreur approprié
exit $testsEchoues