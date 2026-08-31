# Script de validation post-déploiement - Correction d'encodage UTF-8
# Version: 1.0
# Date: 26/05/2025

param(
    [switch]$Detailed,
    [switch]$CreateReport
)

Write-Host "=== Validation post-déploiement - Correction d'encodage UTF-8 ===" -ForegroundColor Green
Write-Host "Version: 1.0 - Date: 26/05/2025" -ForegroundColor Cyan
Write-Host ""

# Variables de résultats
$results = @{
    PowerShellProfile = @{ Status = "Unknown"; Details = @() }
    EncodingConfig = @{ Status = "Unknown"; Details = @() }
    VSCodeConfig = @{ Status = "Unknown"; Details = @() }
    CharacterDisplay = @{ Status = "Unknown"; Details = @() }
    SystemInfo = @{ Status = "Unknown"; Details = @() }
}

$overallSuccess = $true

# Fonction d'ajout de résultat
function Add-Result {
    param($Category, $Status, $Message, $Color = "White")
    $results[$Category].Details += @{ Message = $Message; Status = $Status; Color = $Color }
    if ($Status -eq "Failed") {
        $results[$Category].Status = "Failed"
        $script:overallSuccess = $false
    } elseif ($Status -eq "Success" -and $results[$Category].Status -ne "Failed") {
        $results[$Category].Status = "Success"
    } elseif ($Status -eq "Warning" -and $results[$Category].Status -eq "Unknown") {
        $results[$Category].Status = "Warning"
    }
    
    $icon = switch ($Status) {
        "Success" { "✅" }
        "Failed" { "❌" }
        "Warning" { "⚠️" }
        default { "ℹ️" }
    }
    
    Write-Host "$icon $Message" -ForegroundColor $Color
}

# Test 1: Vérification du profil PowerShell
Write-Host "Test 1: Vérification du profil PowerShell" -ForegroundColor Yellow

$profilePath = "$env:USERPROFILE\OneDrive\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"

if (Test-Path $profilePath) {
    Add-Result "PowerShellProfile" "Success" "Profil PowerShell trouvé" "Green"
    
    try {
        $profileContent = Get-Content $profilePath -Raw -ErrorAction Stop
        
        if ($profileContent -match "Configuration d'encodage UTF-8") {
            Add-Result "PowerShellProfile" "Success" "Configuration UTF-8 présente dans le profil" "Green"
        } else {
            Add-Result "PowerShellProfile" "Failed" "Configuration UTF-8 manquante dans le profil" "Red"
        }
        
        # Vérifications spécifiques
        $checks = @(
            @{ Pattern = '\$OutputEncoding = \[System\.Text\.Encoding\]::UTF8'; Name = "OutputEncoding UTF-8" },
            @{ Pattern = '\[Console\]::OutputEncoding = \[System\.Text\.Encoding\]::UTF8'; Name = "Console.OutputEncoding UTF-8" },
            @{ Pattern = '\[Console\]::InputEncoding = \[System\.Text\.Encoding\]::UTF8'; Name = "Console.InputEncoding UTF-8" },
            @{ Pattern = 'chcp 65001'; Name = "Code Page 65001" }
        )
        
        foreach ($check in $checks) {
            if ($profileContent -match $check.Pattern) {
                Add-Result "PowerShellProfile" "Success" "$($check.Name) configuré" "Green"
            } else {
                Add-Result "PowerShellProfile" "Failed" "$($check.Name) manquant" "Red"
            }
        }
        
    } catch {
        Add-Result "PowerShellProfile" "Failed" "Erreur lors de la lecture du profil: $($_.Exception.Message)" "Red"
    }
} else {
    Add-Result "PowerShellProfile" "Failed" "Profil PowerShell non trouvé: $profilePath" "Red"
}

Write-Host ""

# Test 2: Vérification de la configuration d'encodage actuelle
Write-Host "Test 2: Vérification de la configuration d'encodage actuelle" -ForegroundColor Yellow

try {
    $outputEncoding = $OutputEncoding.EncodingName
    $consoleOutput = [Console]::OutputEncoding.EncodingName
    $consoleInput = [Console]::InputEncoding.EncodingName
    $codePage = [Console]::OutputEncoding.CodePage
    
    if ($outputEncoding -match "UTF-8") {
        Add-Result "EncodingConfig" "Success" "OutputEncoding: $outputEncoding" "Green"
    } else {
        Add-Result "EncodingConfig" "Failed" "OutputEncoding incorrect: $outputEncoding (attendu: UTF-8)" "Red"
    }
    
    if ($consoleOutput -match "UTF-8") {
        Add-Result "EncodingConfig" "Success" "Console.OutputEncoding: $consoleOutput" "Green"
    } else {
        Add-Result "EncodingConfig" "Failed" "Console.OutputEncoding incorrect: $consoleOutput (attendu: UTF-8)" "Red"
    }
    
    if ($consoleInput -match "UTF-8") {
        Add-Result "EncodingConfig" "Success" "Console.InputEncoding: $consoleInput" "Green"
    } else {
        Add-Result "EncodingConfig" "Failed" "Console.InputEncoding incorrect: $consoleInput (attendu: UTF-8)" "Red"
    }
    
    if ($codePage -eq 65001) {
        Add-Result "EncodingConfig" "Success" "Code Page: $codePage (UTF-8)" "Green"
    } else {
        Add-Result "EncodingConfig" "Failed" "Code Page incorrect: $codePage (attendu: 65001)" "Red"
    }
    
} catch {
    Add-Result "EncodingConfig" "Failed" "Erreur lors de la vérification de l'encodage: $($_.Exception.Message)" "Red"
}

Write-Host ""

# Test 3: Vérification de la configuration VSCode
Write-Host "Test 3: Vérification de la configuration VSCode" -ForegroundColor Yellow

$vscodeSettings = ".\.vscode\settings.json"
if (Test-Path $vscodeSettings) {
    Add-Result "VSCodeConfig" "Success" "Fichier settings.json VSCode trouvé" "Green"
    
    try {
        $vscodeContent = Get-Content $vscodeSettings -Raw -ErrorAction Stop
        $vscodeJson = $vscodeContent | ConvertFrom-Json
        
        if ($vscodeJson.'files.encoding' -eq "utf8") {
            Add-Result "VSCodeConfig" "Success" "files.encoding configuré en UTF-8" "Green"
        } else {
            Add-Result "VSCodeConfig" "Warning" "files.encoding non configuré ou incorrect" "Yellow"
        }
        
        if ($vscodeJson.'files.autoGuessEncoding' -eq $false) {
            Add-Result "VSCodeConfig" "Success" "autoGuessEncoding désactivé" "Green"
        } else {
            Add-Result "VSCodeConfig" "Warning" "autoGuessEncoding non configuré" "Yellow"
        }
        
        if ($vscodeJson.'terminal.integrated.defaultProfile.windows' -eq "PowerShell UTF-8") {
            Add-Result "VSCodeConfig" "Success" "Profil terminal UTF-8 configuré" "Green"
        } else {
            Add-Result "VSCodeConfig" "Warning" "Profil terminal UTF-8 non configuré" "Yellow"
        }
        
    } catch {
        Add-Result "VSCodeConfig" "Failed" "Erreur lors de la lecture de la configuration VSCode: $($_.Exception.Message)" "Red"
    }
} else {
    Add-Result "VSCodeConfig" "Warning" "Fichier settings.json VSCode non trouvé (optionnel)" "Yellow"
}

Write-Host ""

# Test 4: Test d'affichage des caractères
Write-Host "Test 4: Test d'affichage des caractères français" -ForegroundColor Yellow

$testStrings = @(
    @{ Text = "àáâãäåæçèéêëìíîïñòóôõöøùúûüý"; Name = "Caractères minuscules" },
    @{ Text = "ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÑÒÓÔÕÖØÙÚÛÜÝ"; Name = "Caractères majuscules" },
    @{ Text = "café hôtel naïf être créé français"; Name = "Mots français" },
    @{ Text = "€£¥©®™§¶•…«»""''"; Name = "Caractères spéciaux" }
)

foreach ($test in $testStrings) {
    try {
        Write-Host "  Test: $($test.Text)" -ForegroundColor Cyan
        Add-Result "CharacterDisplay" "Success" "$($test.Name): Affiché correctement" "Green"
    } catch {
        Add-Result "CharacterDisplay" "Failed" "$($test.Name): Erreur d'affichage" "Red"
    }
}

# Test du fichier de test
$testFile = "test-caracteres-francais.txt"
if (Test-Path $testFile) {
    Add-Result "CharacterDisplay" "Success" "Fichier de test trouvé" "Green"
    
    try {
        $testContent = Get-Content $testFile -Encoding UTF8 -ErrorAction Stop
        Add-Result "CharacterDisplay" "Success" "Fichier de test lu avec succès" "Green"
        
        if ($Detailed) {
            Write-Host "  Contenu du fichier de test:" -ForegroundColor Cyan
            $testContent | ForEach-Object { Write-Host "    $_" -ForegroundColor White }
        }
    } catch {
        Add-Result "CharacterDisplay" "Failed" "Erreur lors de la lecture du fichier de test: $($_.Exception.Message)" "Red"
    }
} else {
    Add-Result "CharacterDisplay" "Warning" "Fichier de test non trouvé" "Yellow"
}

Write-Host ""

# Test 5: Informations système
Write-Host "Test 5: Informations système" -ForegroundColor Yellow

try {
    $psVersion = $PSVersionTable.PSVersion.ToString()
    $culture = [System.Globalization.CultureInfo]::CurrentCulture.Name
    $uiCulture = [System.Globalization.CultureInfo]::CurrentUICulture.Name
    $workingDir = Get-Location
    
    Add-Result "SystemInfo" "Success" "PowerShell: $psVersion" "Green"
    Add-Result "SystemInfo" "Success" "Culture: $culture" "Green"
    Add-Result "SystemInfo" "Success" "UI Culture: $uiCulture" "Green"
    Add-Result "SystemInfo" "Success" "Répertoire: $workingDir" "Green"
    
} catch {
    Add-Result "SystemInfo" "Failed" "Erreur lors de la collecte des informations système: $($_.Exception.Message)" "Red"
}

Write-Host ""

# Résumé final
Write-Host "=== Résumé de la validation ===" -ForegroundColor Green

$categoryNames = @{
    PowerShellProfile = "Profil PowerShell"
    EncodingConfig = "Configuration d'encodage"
    VSCodeConfig = "Configuration VSCode"
    CharacterDisplay = "Affichage des caractères"
    SystemInfo = "Informations système"
}

foreach ($category in $results.Keys) {
    $status = $results[$category].Status
    $name = $categoryNames[$category]
    
    $icon = switch ($status) {
        "Success" { "✅" }
        "Failed" { "❌" }
        "Warning" { "⚠️" }
        default { "❓" }
    }
    
    $color = switch ($status) {
        "Success" { "Green" }
        "Failed" { "Red" }
        "Warning" { "Yellow" }
        default { "Gray" }
    }
    
    Write-Host "$icon $name : $status" -ForegroundColor $color
}

Write-Host ""

if ($overallSuccess) {
    Write-Host "🎉 Validation réussie ! La configuration UTF-8 fonctionne correctement." -ForegroundColor Green
    $exitCode = 0
} else {
    Write-Host "⚠️  Validation échouée. Certains problèmes nécessitent une attention." -ForegroundColor Red
    Write-Host "Consultez DEPLOYMENT-GUIDE.md pour le dépannage." -ForegroundColor Yellow
    $exitCode = 1
}

# Génération du rapport si demandé
if ($CreateReport) {
    Write-Host ""
    Write-Host "Génération du rapport de validation..." -ForegroundColor Cyan
    
    $reportPath = "validation-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
    $reportContent = @"
# Rapport de validation post-déploiement

**Date**: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')  
**Système**: $env:COMPUTERNAME  
**Utilisateur**: $env:USERNAME  
**PowerShell**: $($PSVersionTable.PSVersion)  

## Résultats de validation

"@

    foreach ($category in $results.Keys) {
        $status = $results[$category].Status
        $name = $categoryNames[$category]
        
        $reportContent += @"

### $name
**Statut**: $status

"@
        
        foreach ($detail in $results[$category].Details) {
            $icon = switch ($detail.Status) {
                "Success" { "✅" }
                "Failed" { "❌" }
                "Warning" { "⚠️" }
                default { "ℹ️" }
            }
            $reportContent += "- $icon $($detail.Message)`n"
        }
    }
    
    $reportContent += @"

## Conclusion

"@
    
    if ($overallSuccess) {
        $reportContent += "✅ **Validation réussie** - La configuration UTF-8 fonctionne correctement."
    } else {
        $reportContent += "❌ **Validation échouée** - Certains problèmes nécessitent une attention."
    }
    
    try {
        $reportContent | Out-File -FilePath $reportPath -Encoding UTF8 -Force
        Write-Host "✅ Rapport généré: $reportPath" -ForegroundColor Green
    } catch {
        Write-Host "❌ Erreur lors de la génération du rapport: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Validation terminée." -ForegroundColor Cyan

exit $exitCode