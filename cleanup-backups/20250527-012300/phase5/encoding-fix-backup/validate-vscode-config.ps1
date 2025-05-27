# Script de validation de la configuration VSCode UTF-8
# Exécute depuis le répertoire du projet

Write-Host "=== Validation de la configuration VSCode UTF-8 ===" -ForegroundColor Green
Write-Host ""

# Changer vers le répertoire du script
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir
Write-Host "Répertoire de travail : $(Get-Location)" -ForegroundColor Cyan
Write-Host ""

# Test 1: Vérification de l'encodage actuel
Write-Host "Test 1: Vérification de l'encodage du terminal" -ForegroundColor Yellow
Write-Host "Page de code actuelle : $([Console]::OutputEncoding.CodePage)"
Write-Host "Encodage de sortie : $([Console]::OutputEncoding.EncodingName)"

# Forcer UTF-8 pour ce script
chcp 65001 | Out-Null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "Après configuration UTF-8 :"
Write-Host "Page de code : $([Console]::OutputEncoding.CodePage)"
Write-Host "Encodage : $([Console]::OutputEncoding.EncodingName)"
Write-Host ""

# Test 2: Caractères français
Write-Host "Test 2: Affichage des caractères français" -ForegroundColor Yellow
Write-Host "àáâãäåæçèéêëìíîïñòóôõöøùúûüý"
Write-Host "ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÑÒÓÔÕÖØÙÚÛÜÝ"
Write-Host "Mots avec accents : café, hôtel, naïf, coïncidence, être, créé"
Write-Host ""

# Test 3: Caractères spéciaux
Write-Host "Test 3: Caractères spéciaux et symboles" -ForegroundColor Yellow
Write-Host "€ £ ¥ © ® ™ § ¶ • … « » " " ' '"
Write-Host "Symboles : ± × ÷ ≠ ≤ ≥ ∞ √ ∑ ∏"
Write-Host ""

# Test 4: Vérification des fichiers de configuration
Write-Host "Test 4: Vérification des fichiers de configuration" -ForegroundColor Yellow

# Vérifier settings.json workspace
$workspaceSettings = ".\.vscode\settings.json"
if (Test-Path $workspaceSettings) {
    Write-Host "✅ Fichier workspace settings.json trouvé" -ForegroundColor Green
    $content = Get-Content $workspaceSettings -Raw
    if ($content -match '"files\.encoding":\s*"utf8"') {
        Write-Host "✅ Configuration files.encoding: utf8 présente" -ForegroundColor Green
    } else {
        Write-Host "❌ Configuration files.encoding manquante" -ForegroundColor Red
    }
    if ($content -match '"chcp 65001"') {
        Write-Host "✅ Configuration terminal UTF-8 présente" -ForegroundColor Green
    } else {
        Write-Host "❌ Configuration terminal UTF-8 manquante" -ForegroundColor Red
    }
} else {
    Write-Host "❌ Fichier workspace settings.json non trouvé" -ForegroundColor Red
}

# Vérifier settings.json utilisateur
$userSettings = "$env:APPDATA\Code\User\settings.json"
if (Test-Path $userSettings) {
    Write-Host "✅ Fichier utilisateur settings.json trouvé" -ForegroundColor Green
    $userContent = Get-Content $userSettings -Raw
    if ($userContent -match '"files\.encoding":\s*"utf8"') {
        Write-Host "✅ Configuration utilisateur UTF-8 présente" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Configuration utilisateur UTF-8 recommandée" -ForegroundColor Yellow
    }
} else {
    Write-Host "❌ Fichier utilisateur settings.json non trouvé" -ForegroundColor Red
}
Write-Host ""

# Test 5: Création d'un fichier de test
Write-Host "Test 5: Création d'un fichier de test UTF-8" -ForegroundColor Yellow
$testContent = @"
# Fichier de test UTF-8 - $(Get-Date)
Caractères français : àéèùç ÀÉÈÙÇ
Caractères spéciaux : €£¥©®™
Emojis : 🚀💻📁✅
Phrase : "L'été dernier, j'ai visité un château près de Montréal."
"@

$testFile = "validation-utf8-test.txt"
try {
    $testContent | Out-File -FilePath $testFile -Encoding UTF8 -Force
    Write-Host "✅ Fichier '$testFile' créé avec succès" -ForegroundColor Green
    
    # Lire et afficher le contenu
    $readContent = Get-Content $testFile -Encoding UTF8
    Write-Host "Contenu lu du fichier :"
    $readContent | ForEach-Object { Write-Host "  $_" }
} catch {
    Write-Host "❌ Erreur lors de la création du fichier : $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 6: Informations système
Write-Host "Test 6: Informations système" -ForegroundColor Yellow
Write-Host "Version PowerShell : $($PSVersionTable.PSVersion)"
Write-Host "Culture système : $([System.Globalization.CultureInfo]::CurrentCulture.Name)"
Write-Host "Culture UI : $([System.Globalization.CultureInfo]::CurrentUICulture.Name)"
Write-Host "Répertoire de travail : $(Get-Location)"
Write-Host ""

# Test 7: Instructions pour VSCode
Write-Host "Test 7: Instructions pour tester dans VSCode" -ForegroundColor Yellow
Write-Host "1. Ouvrez ce dossier dans VSCode : code ." -ForegroundColor Cyan
Write-Host "2. Ouvrez un terminal intégré (Ctrl+`)" -ForegroundColor Cyan
Write-Host "3. Vérifiez que PowerShell démarre avec UTF-8" -ForegroundColor Cyan
Write-Host "4. Tapez : echo 'café hôtel naïf'" -ForegroundColor Cyan
Write-Host "5. Ouvrez le fichier test-caracteres-francais.txt" -ForegroundColor Cyan
Write-Host "6. Vérifiez que tous les caractères s'affichent correctement" -ForegroundColor Cyan
Write-Host ""

Write-Host "=== Fin de la validation ===" -ForegroundColor Green
Write-Host "Si tous les tests sont verts et les caractères s'affichent bien," -ForegroundColor Cyan
Write-Host "la configuration UTF-8 est correcte !" -ForegroundColor Cyan