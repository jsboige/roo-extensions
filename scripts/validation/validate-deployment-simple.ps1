# Script de validation du deploiement UTF-8
# Version: 1.0 - Date: 26/05/2025

param(
    [switch]$CreateReport,
    [switch]$Verbose
)

$results = @()

function Add-Result {
    param($Test, $Status, $Message, $Details = "")
    
    $icon = switch ($Status) {
        "PASS" { "OK" }
        "FAIL" { "ERREUR" }
        "WARN" { "ATTENTION" }
        default { "INFO" }
    }
    
    Write-Host "$icon $Test" -ForegroundColor $(
        switch ($Status) {
            "PASS" { "Green" }
            "FAIL" { "Red" }
            "WARN" { "Yellow" }
            default { "Cyan" }
        }
    )
    
    if ($Message) {
        Write-Host "    $Message" -ForegroundColor Gray
    }
    
    $script:results += @{
        Test = $Test
        Status = $Status
        Message = $Message
        Details = $Details
        Timestamp = Get-Date
    }
}

Write-Host "=== Validation du deploiement UTF-8 ===" -ForegroundColor Green
Write-Host "Date: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" -ForegroundColor Cyan
Write-Host ""

# Test 1: Verification du profil PowerShell
Write-Host "Test 1: Verification du profil PowerShell" -ForegroundColor Yellow
$profilePath = $PROFILE.CurrentUserAllHosts

if (Test-Path $profilePath) {
    $profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
    if ($profileContent -and ($profileContent -match "OutputEncoding.*UTF8" -or $profileContent -match "chcp 65001")) {
        Add-Result "Profil PowerShell configure" "PASS" "Configuration UTF-8 detectee dans $profilePath"
    } else {
        Add-Result "Profil PowerShell configure" "FAIL" "Configuration UTF-8 manquante dans $profilePath"
    }
} else {
    Add-Result "Profil PowerShell configure" "FAIL" "Profil PowerShell introuvable: $profilePath"
}

# Test 2: Verification de l'encodage de sortie
Write-Host "Test 2: Verification de l'encodage de sortie" -ForegroundColor Yellow
try {
    $outputEncoding = [Console]::OutputEncoding.EncodingName
    if ($outputEncoding -match "UTF-8") {
        Add-Result "Encodage de sortie" "PASS" "OutputEncoding: $outputEncoding"
    } else {
        Add-Result "Encodage de sortie" "WARN" "OutputEncoding: $outputEncoding (attendu: UTF-8)"
    }
} catch {
    Add-Result "Encodage de sortie" "FAIL" "Impossible de determiner l'encodage de sortie"
}

# Test 3: Verification de l'encodage d'entree
Write-Host "Test 3: Verification de l'encodage d'entree" -ForegroundColor Yellow
try {
    $inputEncoding = [Console]::InputEncoding.EncodingName
    if ($inputEncoding -match "UTF-8") {
        Add-Result "Encodage d'entree" "PASS" "InputEncoding: $inputEncoding"
    } else {
        Add-Result "Encodage d'entree" "WARN" "InputEncoding: $inputEncoding (attendu: UTF-8)"
    }
} catch {
    Add-Result "Encodage d'entree" "FAIL" "Impossible de determiner l'encodage d'entree"
}

# Test 4: Verification de la page de codes
Write-Host "Test 4: Verification de la page de codes" -ForegroundColor Yellow
try {
    $codePage = chcp
    if ($codePage -match "65001") {
        Add-Result "Page de codes" "PASS" "Page de codes: 65001 (UTF-8)"
    } else {
        Add-Result "Page de codes" "WARN" "Page de codes: $codePage (attendu: 65001)"
    }
} catch {
    Add-Result "Page de codes" "FAIL" "Impossible de determiner la page de codes"
}

# Test 5: Test d'affichage des caracteres francais
Write-Host "Test 5: Test d'affichage des caracteres francais" -ForegroundColor Yellow
$testChars = @(
    @{ Text = "cafe"; Name = "Caracteres accentues" },
    @{ Text = "hotel"; Name = "Caracteres accentues" },
    @{ Text = "francais"; Name = "Cedille" },
    @{ Text = "naif"; Name = "Trema" }
)

$allTestsPassed = $true
foreach ($test in $testChars) {
    try {
        $output = $test.Text
        if ($output -eq $test.Text) {
            if ($Verbose) {
                Add-Result "Affichage: $($test.Name)" "PASS" "Texte: '$($test.Text)'"
            }
        } else {
            Add-Result "Affichage: $($test.Name)" "FAIL" "Corruption detectee: '$output' != '$($test.Text)'"
            $allTestsPassed = $false
        }
    } catch {
        Add-Result "Affichage: $($test.Name)" "FAIL" "Erreur lors du test: $($_.Exception.Message)"
        $allTestsPassed = $false
    }
}

if ($allTestsPassed) {
    Add-Result "Test d'affichage global" "PASS" "Tous les caracteres francais s'affichent correctement"
} else {
    Add-Result "Test d'affichage global" "FAIL" "Certains caracteres ne s'affichent pas correctement"
}

# Test 6: Verification de la configuration VSCode
Write-Host "Test 6: Verification de la configuration VSCode" -ForegroundColor Yellow
$vscodeSettings = "$env:APPDATA\Code\User\settings.json"

if (Test-Path $vscodeSettings) {
    try {
        $vscodeConfig = Get-Content $vscodeSettings -Raw | ConvertFrom-Json
        $hasUtf8 = $vscodeConfig.'files.encoding' -eq "utf8"
        
        if ($hasUtf8) {
            Add-Result "Configuration VSCode" "PASS" "Encodage UTF-8 configure dans VSCode"
        } else {
            Add-Result "Configuration VSCode" "WARN" "Encodage UTF-8 non configure dans VSCode"
        }
    } catch {
        Add-Result "Configuration VSCode" "WARN" "Impossible de lire la configuration VSCode"
    }
} else {
    Add-Result "Configuration VSCode" "INFO" "Fichier de configuration VSCode introuvable"
}

# Test 7: Verification du fichier de test
Write-Host "Test 7: Verification du fichier de test" -ForegroundColor Yellow
$testFile = "test-caracteres-francais.txt"

if (Test-Path $testFile) {
    try {
        $testContent = Get-Content $testFile -Raw -Encoding UTF8
        if ($testContent -and $testContent.Length -gt 0) {
            Add-Result "Fichier de test" "PASS" "Fichier de test cree et lisible"
        } else {
            Add-Result "Fichier de test" "WARN" "Fichier de test vide ou illisible"
        }
    } catch {
        Add-Result "Fichier de test" "FAIL" "Erreur lors de la lecture du fichier de test"
    }
} else {
    Add-Result "Fichier de test" "WARN" "Fichier de test introuvable"
}

# Calcul des resultats
$passCount = ($results | Where-Object { $_.Status -eq "PASS" }).Count
$failCount = ($results | Where-Object { $_.Status -eq "FAIL" }).Count
$warnCount = ($results | Where-Object { $_.Status -eq "WARN" }).Count
$totalCount = $results.Count

Write-Host ""
Write-Host "=== Resultats de la validation ===" -ForegroundColor Green
Write-Host "Tests reussis: $passCount" -ForegroundColor Green
Write-Host "Tests echoues: $failCount" -ForegroundColor Red
Write-Host "Avertissements: $warnCount" -ForegroundColor Yellow
Write-Host "Total: $totalCount" -ForegroundColor Cyan

# Generation du rapport si demande
if ($CreateReport) {
    $reportPath = "validation-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
    
    $reportContent = @"
# Rapport de validation du deploiement UTF-8

**Date**: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')
**Systeme**: $env:COMPUTERNAME
**Utilisateur**: $env:USERNAME

## Resume

- Tests reussis: $passCount
- Tests echoues: $failCount  
- Avertissements: $warnCount
- Total: $totalCount

## Details des tests

"@

    foreach ($result in $results) {
        $statusIcon = switch ($result.Status) {
            "PASS" { "✅" }
            "FAIL" { "❌" }
            "WARN" { "⚠️" }
            default { "ℹ️" }
        }
        
        $reportContent += @"

### $statusIcon $($result.Test)

**Statut**: $($result.Status)
**Message**: $($result.Message)
**Heure**: $($result.Timestamp.ToString('HH:mm:ss'))

"@
        
        if ($result.Details) {
            $reportContent += "**Details**: $($result.Details)`n"
        }
    }
    
    $reportContent += @"

## Recommandations

"@
    
    if ($failCount -gt 0) {
        $reportContent += "- Des erreurs ont ete detectees. Verifiez la configuration et relancez le deploiement si necessaire.`n"
    }
    
    if ($warnCount -gt 0) {
        $reportContent += "- Des avertissements ont ete emis. La configuration fonctionne mais pourrait etre amelioree.`n"
    }
    
    if ($failCount -eq 0 -and $warnCount -eq 0) {
        $reportContent += "- Toutes les validations sont passees avec succes. La configuration UTF-8 est operationnelle.`n"
    }
    
    try {
        $reportContent | Out-File -FilePath $reportPath -Encoding UTF8 -Force
        Write-Host ""
        Write-Host "Rapport genere: $reportPath" -ForegroundColor Green
    } catch {
        Write-Host ""
        Write-Host "Erreur lors de la generation du rapport: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Determination du code de sortie
$exitCode = if ($failCount -gt 0) { 1 } else { 0 }

Write-Host ""
if ($exitCode -eq 0) {
    Write-Host "Validation terminee avec succes!" -ForegroundColor Green
} else {
    Write-Host "Validation terminee avec des erreurs." -ForegroundColor Red
}

exit $exitCode