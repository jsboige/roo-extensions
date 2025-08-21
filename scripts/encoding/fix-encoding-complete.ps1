# Script pour corriger complètement l'encodage du fichier standard-modes.json
# Ce script corrige les caractères mal encodés et les emojis

# Chemin du fichier source
$sourceFilePath = "$PSScriptRoot\..\roo-modes\configs\standard-modes.json"

# Vérifier si le fichier existe
if (-not (Test-Path -Path $sourceFilePath)) {
    Write-Host "Erreur: Le fichier $sourceFilePath n'existe pas." -ForegroundColor Red
    exit 1
}

# Créer une copie de sauvegarde
$backupPath = "$sourceFilePath.backup-complete"
Copy-Item -Path $sourceFilePath -Destination $backupPath -Force
Write-Host "Copie de sauvegarde créée: $backupPath" -ForegroundColor Green

try {
    # Lire le contenu du fichier JSON
    Write-Host "Lecture du fichier JSON..." -ForegroundColor Cyan
    $jsonContent = Get-Content -Path $sourceFilePath -Raw -Encoding UTF8

    # Corriger les caractères mal encodés
    Write-Host "Correction des caractères mal encodés..." -ForegroundColor Cyan
    
    # Correction pour les caractères accentués
    $correctedContent = $jsonContent
    
    # Correction pour "é" (Ã©)
    $correctedContent = $correctedContent -replace "Ã©", "é"
    
    # Correction pour "è" (Ã¨)
    $correctedContent = $correctedContent -replace "Ã¨", "è"
    
    # Correction pour "ê" (Ãª)
    $correctedContent = $correctedContent -replace "Ãª", "ê"
    
    # Correction pour "à" (Ã )
    $correctedContent = $correctedContent -replace "Ã ", "à"
    
    # Correction pour "ç" (Ã§)
    $correctedContent = $correctedContent -replace "Ã§", "ç"
    
    # Correction pour "ô" (Ã´)
    $correctedContent = $correctedContent -replace "Ã´", "ô"
    
    # Correction pour "î" (Ã®)
    $correctedContent = $correctedContent -replace "Ã®", "î"
    
    # Correction pour "û" (Ã»)
    $correctedContent = $correctedContent -replace "Ã»", "û"
    
    # Correction pour "ù" (Ã¹)
    $correctedContent = $correctedContent -replace "Ã¹", "ù"
    
    # Correction pour "ï" (Ã¯)
    $correctedContent = $correctedContent -replace "Ã¯", "ï"
    
    # Correction pour "ü" (Ã¼)
    $correctedContent = $correctedContent -replace "Ã¼", "ü"
    
    # Correction pour "ë" (Ã«)
    $correctedContent = $correctedContent -replace "Ã«", "ë"
    
    # Correction pour "É" (Ã‰)
    $correctedContent = $correctedContent -replace "Ã‰", "É"
    
    # Correction pour "È" (Ã)
    $correctedContent = $correctedContent -replace "Ã", "È"
    
    # Correction pour "Ê" (ÃŠ)
    $correctedContent = $correctedContent -replace "ÃŠ", "Ê"
    
    # Correction pour "À" (Ã€)
    $correctedContent = $correctedContent -replace "Ã€", "À"
    
    # Correction pour "Ç" (Ã‡)
    $correctedContent = $correctedContent -replace "Ã‡", "Ç"

    # Correction pour les caractères avec triple encodage
    $correctedContent = $correctedContent -replace "ÃˆÂ ", "à"
    $correctedContent = $correctedContent -replace "ÃˆÂ¢", "â"

    # Correction pour les emojis
    # Manager emoji (👨‍💼)
    $correctedContent = $correctedContent -replace "Ã°Å¸â€˜Â¨Ã¢â‚¬ÂÃ°Å¸â€™Â¼", [char]0x1F468 + [char]0x200D + [char]0x1F4BC
    
    # Code emoji (💻)
    $correctedContent = $correctedContent -replace "Ã°Å¸â€™Â»", [char]0x1F4BB
    
    # Debug emoji (🪲)
    $correctedContent = $correctedContent -replace "Ã°Å¸ÂªÂ²", [char]0x1FAB2
    
    # Architect emoji (🏗️)
    $correctedContent = $correctedContent -replace "Ã°Å¸Ââ€"Ã¯Â¸Â", [char]0x1F3D7 + [char]0xFE0F
    
    # Ask emoji (❓)
    $correctedContent = $correctedContent -replace "Ã¢Ââ€œ", [char]0x2753
    
    # Orchestrator emoji (🪃)
    $correctedContent = $correctedContent -replace "Ã°Å¸ÂªÆ'", [char]0x1FA83

    # Vérifier que le JSON est valide
    try {
        $null = $correctedContent | ConvertFrom-Json
        Write-Host "Le JSON corrigé est valide." -ForegroundColor Green
    }
    catch {
        Write-Host "Avertissement: Le JSON corrigé n'est pas valide. Vérifiez le résultat manuellement." -ForegroundColor Yellow
        Write-Host $_.Exception.Message -ForegroundColor Yellow
    }

    # Écrire le contenu corrigé en UTF-8 sans BOM
    Write-Host "Écriture du fichier corrigé en UTF-8 sans BOM..." -ForegroundColor Cyan
    [System.IO.File]::WriteAllText($sourceFilePath, $correctedContent, [System.Text.UTF8Encoding]::new($false))

    Write-Host "Correction d'encodage réussie!" -ForegroundColor Green

    # Vérifier l'encodage après correction
    $bytes = [System.IO.File]::ReadAllBytes($sourceFilePath)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        Write-Host "Le fichier est maintenant encodé en UTF-8 avec BOM" -ForegroundColor Yellow
    } else {
        Write-Host "Le fichier est maintenant encodé en UTF-8 sans BOM" -ForegroundColor Green
    }
} catch {
    Write-Host "Erreur lors de la correction de l'encodage:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

Write-Host "`nPour déployer les modes corrigés:" -ForegroundColor Cyan
Write-Host "1. Exécutez le script deploy-modes-simple-complex.ps1" -ForegroundColor White
Write-Host "2. Redémarrez Visual Studio Code" -ForegroundColor White
Write-Host "3. Ouvrez la palette de commandes (Ctrl+Shift+P)" -ForegroundColor White
Write-Host "4. Tapez 'Roo: Switch Mode' et sélectionnez un des modes" -ForegroundColor White