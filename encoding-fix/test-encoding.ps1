# Script de test pour valider l'encodage UTF-8 dans VSCode
# Ce script teste l'affichage des caractères français et UTF-8

Write-Host "=== Test d'encodage UTF-8 pour VSCode ===" -ForegroundColor Green
Write-Host ""

# Test 1: Caractères français de base
Write-Host "Test 1: Caractères français de base" -ForegroundColor Yellow
Write-Host "àáâãäåæçèéêëìíîïñòóôõöøùúûüý"
Write-Host "ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÑÒÓÔÕÖØÙÚÛÜÝ"
Write-Host "Voici quelques mots avec accents : café, hôtel, naïf, coïncidence"
Write-Host ""

# Test 2: Caractères spéciaux
Write-Host "Test 2: Caractères spéciaux et symboles" -ForegroundColor Yellow
Write-Host "€ £ ¥ © ® ™ § ¶ • … « » " " ' '"
Write-Host "Symboles mathématiques : ± × ÷ ≠ ≤ ≥ ∞ √ ∑ ∏"
Write-Host ""

# Test 3: Emojis et caractères Unicode
Write-Host "Test 3: Emojis et caractères Unicode" -ForegroundColor Yellow
Write-Host "🚀 🎯 ✅ ❌ 💻 📁 🔧 ⚙️"
Write-Host "Flèches : → ← ↑ ↓ ↔ ⇒ ⇐ ⇑ ⇓"
Write-Host ""

# Test 4: Vérification de l'encodage du terminal
Write-Host "Test 4: Vérification de l'encodage du terminal" -ForegroundColor Yellow
Write-Host "Page de code actuelle : $([Console]::OutputEncoding.CodePage)"
Write-Host "Encodage de sortie : $([Console]::OutputEncoding.EncodingName)"
Write-Host ""

# Test 5: Création d'un fichier de test avec caractères UTF-8
Write-Host "Test 5: Création d'un fichier de test UTF-8" -ForegroundColor Yellow
$testContent = @"
# Fichier de test UTF-8
Ce fichier contient des caractères français : àéèùç
Caractères spéciaux : €£¥©®™
Emojis : 🚀💻📁
Date de création : $(Get-Date)
"@

$testFile = "test-utf8.txt"
$testContent | Out-File -FilePath $testFile -Encoding UTF8
Write-Host "Fichier '$testFile' créé avec encodage UTF-8"

# Vérification du contenu
Write-Host "Contenu du fichier :"
Get-Content $testFile
Write-Host ""

# Test 6: Informations système
Write-Host "Test 6: Informations système" -ForegroundColor Yellow
Write-Host "Version PowerShell : $($PSVersionTable.PSVersion)"
Write-Host "Culture système : $([System.Globalization.CultureInfo]::CurrentCulture.Name)"
Write-Host "Culture UI : $([System.Globalization.CultureInfo]::CurrentUICulture.Name)"
Write-Host ""

Write-Host "=== Fin des tests ===" -ForegroundColor Green
Write-Host "Si tous les caractères s'affichent correctement, l'encodage UTF-8 fonctionne !" -ForegroundColor Cyan
