# Script de déploiement pour l'architecture d'orchestration à 5 niveaux
# Ce script déploie les configurations des modes pour les 5 niveaux de complexité

# Définition des chemins
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootPath = Split-Path -Parent $scriptPath
$configsPath = Join-Path -Path $rootPath -ChildPath "configs"
$rooConfigPath = "$env:APPDATA\Code\User\globalStorage\anthropic.claude\roo"

# Création du répertoire de destination s'il n'existe pas
if (-not (Test-Path -Path $rooConfigPath)) {
    Write-Host "Création du répertoire de configuration Roo..."
    New-Item -Path $rooConfigPath -ItemType Directory -Force | Out-Null
}

# Fonction pour déployer un fichier de configuration
function Deploy-ConfigFile {
    param (
        [string]$sourcePath,
        [string]$destinationPath,
        [string]$configName
    )

    if (Test-Path -Path $sourcePath) {
        try {
            Copy-Item -Path $sourcePath -Destination $destinationPath -Force
            Write-Host "✅ Configuration $configName déployée avec succès" -ForegroundColor Green
        }
        catch {
            Write-Host "❌ Erreur lors du déploiement de la configuration $configName : $_" -ForegroundColor Red
        }
    }
    else {
        Write-Host "⚠️ Le fichier de configuration $configName n'existe pas" -ForegroundColor Yellow
    }
}

# Fonction pour fusionner les configurations avec les configurations existantes
function Merge-Configurations {
    param (
        [string]$sourceConfigPath,
        [string]$existingConfigPath,
        [string]$configName
    )

    if (Test-Path -Path $sourceConfigPath -and (Test-Path -Path $existingConfigPath)) {
        try {
            $sourceConfig = Get-Content -Path $sourceConfigPath -Raw | ConvertFrom-Json
            $existingConfig = Get-Content -Path $existingConfigPath -Raw | ConvertFrom-Json

            # Logique de fusion spécifique à chaque type de configuration
            # Pour les modes, nous ajoutons les nouveaux modes à la liste existante
            if ($configName -eq "modes") {
                foreach ($mode in $sourceConfig.customModes) {
                    $existingMode = $existingConfig.customModes | Where-Object { $_.slug -eq $mode.slug }
                    if ($null -eq $existingMode) {
                        $existingConfig.customModes += $mode
                    }
                    else {
                        # Remplacer le mode existant par le nouveau
                        $index = [array]::IndexOf($existingConfig.customModes, $existingMode)
                        $existingConfig.customModes[$index] = $mode
                    }
                }
            }

            # Sauvegarder la configuration fusionnée
            $existingConfig | ConvertTo-Json -Depth 100 | Set-Content -Path $existingConfigPath
            Write-Host "✅ Configuration $configName fusionnée avec succès" -ForegroundColor Green
        }
        catch {
            Write-Host "❌ Erreur lors de la fusion de la configuration $configName : $_" -ForegroundColor Red
        }
    }
    else {
        Write-Host "⚠️ Impossible de fusionner les configurations, un des fichiers n'existe pas" -ForegroundColor Yellow
    }
}

# Vérification de l'existence des fichiers de configuration
Write-Host "Vérification des fichiers de configuration..." -ForegroundColor Cyan

$configFiles = @(
    @{Name = "micro-modes.json"; Path = Join-Path -Path $configsPath -ChildPath "micro-modes.json"},
    @{Name = "mini-modes.json"; Path = Join-Path -Path $configsPath -ChildPath "mini-modes.json"},
    @{Name = "medium-modes.json"; Path = Join-Path -Path $configsPath -ChildPath "medium-modes.json"},
    @{Name = "large-modes.json"; Path = Join-Path -Path $configsPath -ChildPath "large-modes.json"},
    @{Name = "oracle-modes.json"; Path = Join-Path -Path $configsPath -ChildPath "oracle-modes.json"}
)

$allFilesExist = $true
foreach ($file in $configFiles) {
    if (-not (Test-Path -Path $file.Path)) {
        Write-Host "❌ Le fichier $($file.Name) n'existe pas" -ForegroundColor Red
        $allFilesExist = $false
    }
    else {
        Write-Host "✅ Le fichier $($file.Name) existe" -ForegroundColor Green
    }
}

if (-not $allFilesExist) {
    Write-Host "⚠️ Certains fichiers de configuration sont manquants. Veuillez les créer avant de continuer." -ForegroundColor Yellow
    exit 1
}

# Validation des fichiers JSON
Write-Host "Validation des fichiers JSON..." -ForegroundColor Cyan

$allFilesValid = $true
foreach ($file in $configFiles) {
    try {
        $null = Get-Content -Path $file.Path -Raw | ConvertFrom-Json
        Write-Host "✅ Le fichier $($file.Name) est un JSON valide" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Le fichier $($file.Name) n'est pas un JSON valide : $_" -ForegroundColor Red
        $allFilesValid = $false
    }
}

if (-not $allFilesValid) {
    Write-Host "⚠️ Certains fichiers JSON sont invalides. Veuillez les corriger avant de continuer." -ForegroundColor Yellow
    exit 1
}

# Création du fichier de configuration fusionné
Write-Host "Création du fichier de configuration fusionné..." -ForegroundColor Cyan

$mergedModes = @{
    "customModes" = @()
}

foreach ($file in $configFiles) {
    try {
        $config = Get-Content -Path $file.Path -Raw | ConvertFrom-Json
        if ($config.customModes) {
            foreach ($mode in $config.customModes) {
                $mergedModes.customModes += $mode
            }
        }
    }
    catch {
        Write-Host "❌ Erreur lors de la fusion du fichier $($file.Name) : $_" -ForegroundColor Red
    }
}

$mergedModesPath = Join-Path -Path $configsPath -ChildPath "merged-modes.json"
$mergedModes | ConvertTo-Json -Depth 100 | Set-Content -Path $mergedModesPath
Write-Host "✅ Fichier de configuration fusionné créé : $mergedModesPath" -ForegroundColor Green

# Déploiement des configurations
Write-Host "Déploiement des configurations..." -ForegroundColor Cyan

$rooModesPath = Join-Path -Path $rooConfigPath -ChildPath "modes.json"

# Déployer directement en remplaçant le fichier existant
Deploy-ConfigFile -sourcePath $mergedModesPath -destinationPath $rooModesPath -configName "modes"

# Création d'un fichier de sauvegarde
$backupPath = Join-Path -Path $rootPath -ChildPath "backup"
if (-not (Test-Path -Path $backupPath)) {
    New-Item -Path $backupPath -ItemType Directory -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupFile = Join-Path -Path $backupPath -ChildPath "modes_backup_$timestamp.json"

if (Test-Path -Path $rooModesPath) {
    Copy-Item -Path $rooModesPath -Destination $backupFile
    Write-Host "✅ Sauvegarde créée : $backupFile" -ForegroundColor Green
}

Write-Host "Déploiement terminé avec succès !" -ForegroundColor Green
Write-Host "Pour utiliser les nouveaux modes, redémarrez VS Code." -ForegroundColor Cyan

# Nettoyage des fichiers intermédiaires
Write-Host "Nettoyage des fichiers intermédiaires..." -ForegroundColor Cyan
Remove-Item -Path $mergedModesPath -Force
Write-Host "✅ Fichiers intermédiaires nettoyés" -ForegroundColor Green