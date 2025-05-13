# Script de test pour vérifier l'utilisation correcte des commandes PowerShell
# Ce script démontre l'utilisation de la syntaxe PowerShell appropriée
# et évite les erreurs courantes comme l'utilisation de "&&"

# Fonction pour afficher un message formaté
function Write-TestMessage {
    param (
        [string]$Message,
        [string]$Type = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Type] $Message"
}

# Création de la structure de répertoires pour les tests
$testRootDir = ".\tests/mcp-structure"
$subDirs = @("data", "logs", "config", "output")

Write-TestMessage "Création de la structure de répertoires de test..."

# Vérification si le répertoire existe déjà et suppression si nécessaire
if (Test-Path -Path $testRootDir) {
    Write-TestMessage "Le répertoire de test existe déjà, suppression en cours..." -Type "WARNING"
    Remove-Item -Path $testRootDir -Recurse -Force
}

# Création du répertoire racine
New-Item -Path $testRootDir -ItemType Directory | Out-Null

# Création des sous-répertoires en utilisant une boucle
foreach ($dir in $subDirs) {
    $path = Join-Path -Path $testRootDir -ChildPath $dir
    New-Item -Path $path -ItemType Directory | Out-Null
    Write-TestMessage "Répertoire créé: $path"
}

# Génération de fichiers de test avec du contenu
Write-TestMessage "Génération des fichiers de test..."

# Exemple 1: Création d'un fichier de configuration JSON
$configContent = @{
    appName = "TestMCPApp"
    version = "1.0.0"
    settings = @{
        logLevel = "INFO"
        maxRetries = 3
        timeout = 30
    }
    features = @("quickfiles", "jinavigator")
} | ConvertTo-Json -Depth 3

$configPath = Join-Path -Path $testRootDir -ChildPath "config\settings.json"
Set-Content -Path $configPath -Value $configContent
Write-TestMessage "Fichier de configuration créé: $configPath"

# Exemple 2: Création de plusieurs fichiers texte avec une boucle et des conditions
1..5 | ForEach-Object {
    $fileName = "test-file-$_.txt"
    $filePath = Join-Path -Path $testRootDir -ChildPath "data\$fileName"
    
    # Contenu différent selon le numéro de fichier
    $content = if ($_ % 2 -eq 0) {
        "# Fichier de test pair ($fileName)`n`nCe fichier est utilisé pour tester le MCP quickfiles.`nIl contient des données de test pour le fichier numéro $_."
    } else {
        "# Fichier de test impair ($fileName)`n`nCe fichier est utilisé pour tester le MCP quickfiles.`nIl contient des données différentes car son numéro est impair ($_)."
    }
    
    Set-Content -Path $filePath -Value $content
    Write-TestMessage "Fichier de données créé: $filePath"
}

# Exemple 3: Création d'un fichier de log avec la date et l'heure
$logPath = Join-Path -Path $testRootDir -ChildPath "logs\setup.log"
$logContent = @"
[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] [INFO] Initialisation de l'environnement de test
[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] [INFO] Création des répertoires de test
[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] [INFO] Génération des fichiers de test
[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] [INFO] Configuration terminée
"@

Set-Content -Path $logPath -Value $logContent
Write-TestMessage "Fichier de log créé: $logPath"

# Exemple 4: Utilisation de pipelines pour traiter et générer un rapport
$reportPath = Join-Path -Path $testRootDir -ChildPath "output\report.md"

# Collecte d'informations sur les fichiers créés
$fileStats = Get-ChildItem -Path $testRootDir -Recurse -File | 
    Select-Object Name, Length, LastWriteTime, @{Name="Directory"; Expression={$_.DirectoryName}} |
    Sort-Object Directory, Name

# Génération d'un rapport Markdown
$reportContent = @"
# Rapport de test MCP PowerShell

## Structure de répertoires créée

$(Get-ChildItem -Path $testRootDir -Directory -Recurse | ForEach-Object { "- $_" } | Out-String)

## Fichiers générés

| Nom | Taille (octets) | Date de modification | Répertoire |
|-----|----------------|----------------------|------------|
$(
    $fileStats | ForEach-Object {
        "| $($_.Name) | $($_.Length) | $($_.LastWriteTime) | $($_.Directory) |"
    } | Out-String
)

## Résumé

- Nombre total de répertoires: $(Get-ChildItem -Path $testRootDir -Directory -Recurse | Measure-Object | Select-Object -ExpandProperty Count)
- Nombre total de fichiers: $(Get-ChildItem -Path $testRootDir -File -Recurse | Measure-Object | Select-Object -ExpandProperty Count)
- Taille totale: $((Get-ChildItem -Path $testRootDir -File -Recurse | Measure-Object -Property Length -Sum).Sum) octets

Rapport généré le $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@

Set-Content -Path $reportPath -Value $reportContent
Write-TestMessage "Rapport généré: $reportPath"

# Affichage du résumé final
Write-TestMessage "Structure de test créée avec succès!" -Type "SUCCESS"
Write-TestMessage "Répertoire racine: $((Get-Item $testRootDir).FullName)" -Type "SUCCESS"
Write-TestMessage "Nombre total de fichiers créés: $((Get-ChildItem -Path $testRootDir -File -Recurse | Measure-Object).Count)" -Type "SUCCESS"

# Fin du script