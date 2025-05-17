# Script pour corriger l'encodage du fichier custom_modes.json
# Ce script lit le fichier JSON, le convertit en objet PowerShell, puis le réécrit en UTF-8 sans BOM

# Chemin du fichier global
$globalFilePath = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json"

# Vérifier si le fichier existe
if (-not (Test-Path -Path $globalFilePath)) {
    Write-Host "Erreur: Le fichier $globalFilePath n'existe pas." -ForegroundColor Red
    exit 1
}

# Afficher l'encodage actuel
$bytes = [System.IO.File]::ReadAllBytes($globalFilePath)
if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    Write-Host "Le fichier est actuellement encodé en UTF-8 avec BOM" -ForegroundColor Yellow
} else {
    Write-Host "Le fichier est actuellement encodé en UTF-8 sans BOM ou un autre encodage" -ForegroundColor Yellow
}

try {
    # Lire le contenu du fichier JSON
    Write-Host "Lecture du fichier JSON..." -ForegroundColor Cyan
    $jsonContent = Get-Content -Path $globalFilePath -Raw -ErrorAction Stop
    
    # Convertir le JSON en objet PowerShell
    Write-Host "Conversion du JSON en objet PowerShell..." -ForegroundColor Cyan
    $jsonObject = ConvertFrom-Json $jsonContent -ErrorAction Stop
    
    # Convertir l'objet PowerShell en JSON avec encodage UTF-8
    Write-Host "Reconversion en JSON..." -ForegroundColor Cyan
    $jsonString = ConvertTo-Json $jsonObject -Depth 100
    
    # Créer une copie de sauvegarde
    $backupPath = "$globalFilePath.backup"
    Copy-Item -Path $globalFilePath -Destination $backupPath -Force
    Write-Host "Copie de sauvegarde créée: $backupPath" -ForegroundColor Green
    
    # Écrire le contenu en UTF-8 sans BOM
    Write-Host "Écriture du fichier en UTF-8 sans BOM..." -ForegroundColor Cyan
    [System.IO.File]::WriteAllText($globalFilePath, $jsonString, [System.Text.UTF8Encoding]::new($false))
    
    Write-Host "Correction d'encodage réussie!" -ForegroundColor Green
    
    # Vérifier l'encodage après correction
    $bytes = [System.IO.File]::ReadAllBytes($globalFilePath)
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

Write-Host "`nPour activer les modes:" -ForegroundColor Cyan
Write-Host "1. Redémarrez Visual Studio Code" -ForegroundColor White
Write-Host "2. Ouvrez la palette de commandes (Ctrl+Shift+P)" -ForegroundColor White
Write-Host "3. Tapez 'Roo: Switch Mode' et sélectionnez un des modes" -ForegroundColor White