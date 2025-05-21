# Script pour télécharger et utiliser Node.js portable
$nodeVersion = "20.12.2" # Version LTS récente
$nodeDirName = "node-v$nodeVersion-win-x64"
$nodeZipName = "$nodeDirName.zip"
$nodeUrl = "https://nodejs.org/dist/v$nodeVersion/$nodeZipName"
$nodeDir = Join-Path $PSScriptRoot "node-portable"
$nodeZipPath = Join-Path $nodeDir $nodeZipName
$nodeExePath = Join-Path $nodeDir "$nodeDirName\node.exe"

# Créer le répertoire pour Node.js portable s'il n'existe pas
if (-not (Test-Path $nodeDir)) {
    Write-Host "Création du répertoire pour Node.js portable..."
    New-Item -ItemType Directory -Path $nodeDir -Force | Out-Null
}

# Télécharger Node.js s'il n'existe pas déjà
if (-not (Test-Path $nodeExePath)) {
    Write-Host "Téléchargement de Node.js v$nodeVersion..."
    
    # Créer un client WebClient pour télécharger le fichier
    $webClient = New-Object System.Net.WebClient
    
    try {
        # Télécharger le fichier ZIP de Node.js
        $webClient.DownloadFile($nodeUrl, $nodeZipPath)
        
        Write-Host "Extraction de Node.js..."
        # Extraire le fichier ZIP
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($nodeZipPath, $nodeDir)
        
        # Supprimer le fichier ZIP après extraction
        Remove-Item $nodeZipPath -Force
        
        Write-Host "Node.js v$nodeVersion a été téléchargé et extrait avec succès."
    }
    catch {
        Write-Host "Erreur lors du téléchargement ou de l'extraction de Node.js: $_"
        exit 1
    }
    finally {
        $webClient.Dispose()
    }
}

# Exécuter Node.js avec les arguments fournis
Write-Host "Exécution de Node.js..."
$scriptPath = $args[0]
$scriptArgs = $args[1..($args.Length-1)]

# Afficher la commande qui sera exécutée
Write-Host "Commande: $nodeExePath $scriptPath $scriptArgs"

# Exécuter Node.js avec les arguments
& $nodeExePath $scriptPath $scriptArgs