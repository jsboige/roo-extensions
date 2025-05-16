# Script pour appliquer les configurations de test d'escalade
# Ce script met à jour les profils des modes simples et complexes pour tester l'escalade fonctionnelle

param (
    [Parameter(Mandatory=$true)]
    [string]$ConfigName
)

# Chemins des fichiers
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path -Path $scriptPath -ChildPath "escalation-test-config.json"
$settingsPath = Join-Path -Path $scriptPath -ChildPath "settings/settings.json"
$modesPath = Join-Path -Path $scriptPath -ChildPath "settings/modes.json"

# Vérification de l'existence des fichiers
if (-not (Test-Path $configPath)) {
    Write-Error "Le fichier de configuration n'existe pas: $configPath"
    exit 1
}

if (-not (Test-Path $settingsPath)) {
    Write-Error "Le fichier settings.json n'existe pas: $settingsPath"
    exit 1
}

if (-not (Test-Path $modesPath)) {
    Write-Error "Le fichier modes.json n'existe pas: $modesPath"
    exit 1
}

# Chargement des fichiers
$config = Get-Content -Path $configPath -Raw | ConvertFrom-Json
$settings = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
$modes = Get-Content -Path $modesPath -Raw | ConvertFrom-Json

# Afficher les configurations disponibles
Write-Host "Configurations disponibles:" -ForegroundColor Yellow
foreach ($conf in $config.configurations) {
    Write-Host "- '$($conf.name)'" -ForegroundColor Cyan
    # Afficher les octets du nom pour diagnostic
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($conf.name)
    $bytesHex = ($bytes | ForEach-Object { $_.ToString("X2") }) -join " "
    Write-Host "  Bytes: $bytesHex" -ForegroundColor Gray
}

Write-Host "Nom recherché: '$ConfigName'" -ForegroundColor Yellow
$bytesInput = [System.Text.Encoding]::UTF8.GetBytes($ConfigName)
$bytesInputHex = ($bytesInput | ForEach-Object { $_.ToString("X2") }) -join " "
Write-Host "Bytes recherchés: $bytesInputHex" -ForegroundColor Gray

# Recherche de la configuration spécifiée en ignorant la casse et les accents
$selectedConfig = $null
foreach ($conf in $config.configurations) {
    if ($conf.name -eq $ConfigName) {
        $selectedConfig = $conf
        Write-Host "Configuration trouvée par correspondance exacte" -ForegroundColor Green
        break
    }
    
    # Essayer de trouver par correspondance partielle
    if ($conf.name -like "*$($ConfigName.Substring(0, $ConfigName.Length - 2))*") {
        $selectedConfig = $conf
        Write-Host "Configuration trouvée par correspondance partielle" -ForegroundColor Yellow
        break
    }
}

if ($null -eq $selectedConfig) {
    Write-Error "Configuration non trouvée: $ConfigName"
    exit 1
}

Write-Host "Application de la configuration: $ConfigName" -ForegroundColor Green
Write-Host "Description: $($selectedConfig.description)" -ForegroundColor Cyan

# Sauvegarde des fichiers originaux
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$settingsBackupPath = "$settingsPath.backup-$timestamp"
$modesBackupPath = "$modesPath.backup-$timestamp"

Copy-Item -Path $settingsPath -Destination $settingsBackupPath
Copy-Item -Path $modesPath -Destination $modesBackupPath

Write-Host "Fichiers de sauvegarde créés:" -ForegroundColor Yellow
Write-Host "- $settingsBackupPath" -ForegroundColor Yellow
Write-Host "- $modesBackupPath" -ForegroundColor Yellow

# Mise à jour des modes
foreach ($mode in $modes.modes) {
    $modeSlug = $mode.slug
    
    if ($selectedConfig.modes.PSObject.Properties.Name -contains $modeSlug) {
        $modelId = $selectedConfig.modes.$modeSlug
        
        # Recherche du profil API correspondant au modèle
        $apiProfile = $null
        
        # Recherche dans les profils existants
        foreach ($profile in $settings.apiConfigs.PSObject.Properties) {
            if ($profile.Value.openRouterModelId -eq $modelId) {
                $apiProfile = $profile.Name
                break
            }
        }
        
        if ($apiProfile) {
            Write-Host "Mode $modeSlug - Utilisation du profil existant $apiProfile pour le modèle $modelId" -ForegroundColor Green
            $mode.defaultModel = $apiProfile
        } else {
            Write-Host "Mode $modeSlug - Utilisation directe du modèle $modelId (pas de profil trouvé)" -ForegroundColor Yellow
            $mode.defaultModel = $modelId
        }
    }
}

# Sauvegarde des fichiers mis à jour
$modes | ConvertTo-Json -Depth 10 | Set-Content -Path $modesPath

Write-Host "`nConfiguration appliquée avec succès!" -ForegroundColor Green
Write-Host "Redémarrez VSCode pour que les changements prennent effet." -ForegroundColor Magenta