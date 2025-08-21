# ======================================================
# Script d'installation unifié pour la démo Roo
# ======================================================
#
# Description: Ce script automatise l'installation et la configuration
# de la démo d'initiation à Roo, incluant la vérification des prérequis,
# la configuration des clés API et la préparation de l'environnement.
#
# Auteur: Roo Assistant
# Date: 21/05/2025
# Version: 1.0
# ======================================================

param (
    [switch]$SkipPrerequisites = $false,
    [switch]$SkipExtensionInstall = $false,
    [switch]$SkipWorkspacePreparation = $false,
    [string]$ApiKeyOpenAI = "",
    [string]$ApiKeyAnthropic = "",
    [string]$ApiKeyRoo = "",
    [string]$CustomDemoPath = "",
    [switch]$Verbose = $false,
    [switch]$Help = $false
)

# Fonction pour afficher l'aide
function Show-Help {
    Write-Host "Script d'installation unifié pour la démo Roo" -ForegroundColor Cyan
    Write-Host "Usage: .\install-demo.ps1 [options]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -SkipPrerequisites         : Ignorer la vérification des prérequis"
    Write-Host "  -SkipExtensionInstall      : Ignorer l'installation de l'extension Roo"
    Write-Host "  -SkipWorkspacePreparation  : Ignorer la préparation des espaces de travail"
    Write-Host "  -ApiKeyOpenAI <clé>        : Spécifier la clé API OpenAI"
    Write-Host "  -ApiKeyAnthropic <clé>     : Spécifier la clé API Anthropic"
    Write-Host "  -ApiKeyRoo <clé>           : Spécifier la clé API Roo"
    Write-Host "  -CustomDemoPath <chemin>   : Spécifier un chemin personnalisé pour la démo"
    Write-Host "  -Verbose                   : Afficher des informations détaillées"
    Write-Host "  -Help                      : Afficher cette aide"
    Write-Host ""
    Write-Host "Exemple:"
    Write-Host "  .\install-demo.ps1 -ApiKeyOpenAI 'sk-...' -Verbose"
    exit 0
}

# Afficher l'aide si demandé
if ($Help) {
    Show-Help
}

# Fonction pour afficher les messages avec formatage
function Write-ColorOutput {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [string]$ForegroundColor = "White"
    )
    
    Write-Host $Message -ForegroundColor $ForegroundColor
}

# Fonction pour afficher les messages verbeux
function Write-VerboseOutput {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    
    if ($Verbose) {
        Write-Host $Message -ForegroundColor Gray
    }
}

# Fonction pour vérifier si une commande existe
function Test-CommandExists {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Command
    )
    
    $exists = $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
    return $exists
}

# Fonction pour vérifier la version d'une commande
function Get-CommandVersion {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Command,
        
        [Parameter(Mandatory=$true)]
        [string]$VersionParam
    )
    
    try {
        $version = Invoke-Expression "$Command $VersionParam"
        return $version
    }
    catch {
        return $null
    }
}

# Fonction pour vérifier si VS Code est installé
function Test-VSCodeInstalled {
    $vsCodePath = $null
    
    # Vérifier dans le chemin système
    $vsCodePath = Get-Command "code" -ErrorAction SilentlyContinue
    
    # Vérifier les emplacements d'installation courants si non trouvé dans le chemin
    if (-not $vsCodePath) {
        $possiblePaths = @(
            "${env:ProgramFiles}\Microsoft VS Code\bin\code.cmd",
            "${env:ProgramFiles(x86)}\Microsoft VS Code\bin\code.cmd",
            "${env:LOCALAPPDATA}\Programs\Microsoft VS Code\bin\code.cmd"
        )
        
        foreach ($path in $possiblePaths) {
            if (Test-Path $path) {
                $vsCodePath = $path
                break
            }
        }
    }
    
    return $null -ne $vsCodePath
}

# Fonction pour vérifier si une extension VS Code est installée
function Test-VSCodeExtensionInstalled {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ExtensionId
    )
    
    try {
        $extensions = Invoke-Expression "code --list-extensions" -ErrorAction SilentlyContinue
        return $extensions -contains $ExtensionId
    }
    catch {
        return $false
    }
}

# Fonction pour installer une extension VS Code
function Install-VSCodeExtension {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ExtensionId
    )
    
    try {
        Write-ColorOutput "Installation de l'extension $ExtensionId..." "Yellow"
        $result = Invoke-Expression "code --install-extension $ExtensionId --force"
        Write-VerboseOutput $result
        return $true
    }
    catch {
        Write-ColorOutput "Erreur lors de l'installation de l'extension $ExtensionId: $_" "Red"
        return $false
    }
}

# Fonction pour créer ou mettre à jour le fichier .env
function Update-EnvFile {
    param (
        [Parameter(Mandatory=$true)]
        [string]$EnvFilePath,
        
        [Parameter(Mandatory=$false)]
        [string]$OpenAIKey = "",
        
        [Parameter(Mandatory=$false)]
        [string]$AnthropicKey = "",
        
        [Parameter(Mandatory=$false)]
        [string]$RooKey = ""
    )
    
    # Vérifier si le fichier .env existe déjà
    $envExists = Test-Path $EnvFilePath
    
    # Créer ou charger le contenu existant
    $envContent = @()
    if ($envExists) {
        $envContent = Get-Content $EnvFilePath
    }
    
    # Fonction pour mettre à jour une variable dans le contenu
    function Update-EnvVariable {
        param (
            [string[]]$Content,
            [string]$VarName,
            [string]$VarValue
        )
        
        if ([string]::IsNullOrWhiteSpace($VarValue)) {
            return $Content
        }
        
        $varPattern = "^$VarName=.*"
        $varLine = "$VarName=$VarValue"
        
        $varExists = $Content | Where-Object { $_ -match $varPattern }
        
        if ($varExists) {
            return $Content | ForEach-Object { $_ -replace $varPattern, $varLine }
        }
        else {
            return $Content + $varLine
        }
    }
    
    # Mettre à jour les variables
    if (-not [string]::IsNullOrWhiteSpace($OpenAIKey)) {
        $envContent = Update-EnvVariable -Content $envContent -VarName "DEMO_ROO_OPENAI_API_KEY" -VarValue $OpenAIKey
    }
    
    if (-not [string]::IsNullOrWhiteSpace($AnthropicKey)) {
        $envContent = Update-EnvVariable -Content $envContent -VarName "DEMO_ROO_ANTHROPIC_API_KEY" -VarValue $AnthropicKey
    }
    
    if (-not [string]::IsNullOrWhiteSpace($RooKey)) {
        $envContent = Update-EnvVariable -Content $envContent -VarName "DEMO_ROO_API_KEY" -VarValue $RooKey
    }
    
    # Écrire le contenu mis à jour
    $envContent | Set-Content $EnvFilePath -Force
    
    return $true
}

# Affichage du titre
Write-ColorOutput "=========================================" "Cyan"
Write-ColorOutput "  INSTALLATION DE LA DÉMO ROO" "Cyan"
Write-ColorOutput "=========================================" "Cyan"
Write-Host ""

# Déterminer le chemin du script pour trouver le répertoire racine du projet
$scriptPath = $PSScriptRoot
if (-not $scriptPath) {
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
}

# Remonter de deux niveaux pour atteindre la racine du projet
$rootPath = Join-Path -Path $scriptPath -ChildPath "..\.."
$rootPath = [System.IO.Path]::GetFullPath($rootPath)

# Définir le chemin vers le répertoire demo-roo-code
if ([string]::IsNullOrWhiteSpace($CustomDemoPath)) {
    $demoRootPath = Join-Path -Path $rootPath -ChildPath "demo-roo-code"
} else {
    $demoRootPath = $CustomDemoPath
    if (-not (Test-Path $demoRootPath)) {
        Write-ColorOutput "Le chemin personnalisé spécifié n'existe pas: $demoRootPath" "Red"
        exit 1
    }
}

Write-ColorOutput "Chemin racine du projet: $rootPath" "Yellow"
Write-ColorOutput "Chemin de la démo: $demoRootPath" "Yellow"
Write-Host ""

# Vérification des prérequis
if (-not $SkipPrerequisites) {
    Write-ColorOutput "Vérification des prérequis..." "Yellow"
    
    # Vérifier VS Code
    $vsCodeInstalled = Test-VSCodeInstalled
    if ($vsCodeInstalled) {
        Write-ColorOutput "✓ Visual Studio Code est installé" "Green"
    } else {
        Write-ColorOutput "✗ Visual Studio Code n'est pas installé ou n'est pas dans le PATH" "Red"
        Write-ColorOutput "  Veuillez installer VS Code depuis https://code.visualstudio.com/" "Red"
        Write-ColorOutput "  Ou utilisez -SkipPrerequisites pour ignorer cette vérification" "Red"
        exit 1
    }
    
    # Vérifier Python
    $pythonInstalled = Test-CommandExists "python" -or Test-CommandExists "python3"
    if ($pythonInstalled) {
        $pythonCommand = if (Test-CommandExists "python") { "python" } else { "python3" }
        $pythonVersion = Get-CommandVersion -Command $pythonCommand -VersionParam "--version"
        Write-ColorOutput "✓ Python est installé: $pythonVersion" "Green"
    } else {
        Write-ColorOutput "✗ Python n'est pas installé ou n'est pas dans le PATH" "Red"
        Write-ColorOutput "  Veuillez installer Python depuis https://www.python.org/downloads/" "Red"
        Write-ColorOutput "  Ou utilisez -SkipPrerequisites pour ignorer cette vérification" "Red"
        exit 1
    }
    
    # Vérifier Node.js
    $nodeInstalled = Test-CommandExists "node"
    if ($nodeInstalled) {
        $nodeVersion = Get-CommandVersion -Command "node" -VersionParam "--version"
        Write-ColorOutput "✓ Node.js est installé: $nodeVersion" "Green"
    } else {
        Write-ColorOutput "✗ Node.js n'est pas installé ou n'est pas dans le PATH" "Red"
        Write-ColorOutput "  Veuillez installer Node.js depuis https://nodejs.org/" "Red"
        Write-ColorOutput "  Ou utilisez -SkipPrerequisites pour ignorer cette vérification" "Red"
        exit 1
    }
    
    # Vérifier npm
    $npmInstalled = Test-CommandExists "npm"
    if ($npmInstalled) {
        $npmVersion = Get-CommandVersion -Command "npm" -VersionParam "--version"
        Write-ColorOutput "✓ npm est installé: $npmVersion" "Green"
    } else {
        Write-ColorOutput "✗ npm n'est pas installé ou n'est pas dans le PATH" "Red"
        Write-ColorOutput "  npm est généralement installé avec Node.js" "Red"
        Write-ColorOutput "  Ou utilisez -SkipPrerequisites pour ignorer cette vérification" "Red"
        exit 1
    }
    
    Write-Host ""
}

# Installation de l'extension Roo
if (-not $SkipExtensionInstall) {
    Write-ColorOutput "Vérification de l'extension Roo..." "Yellow"
    
    $rooExtensionId = "roo.roo"  # ID de l'extension Roo
    $rooExtensionInstalled = Test-VSCodeExtensionInstalled -ExtensionId $rooExtensionId
    
    if ($rooExtensionInstalled) {
        Write-ColorOutput "✓ L'extension Roo est déjà installée" "Green"
    } else {
        Write-ColorOutput "L'extension Roo n'est pas installée. Installation en cours..." "Yellow"
        $installed = Install-VSCodeExtension -ExtensionId $rooExtensionId
        
        if ($installed) {
            Write-ColorOutput "✓ L'extension Roo a été installée avec succès" "Green"
        } else {
            Write-ColorOutput "✗ Échec de l'installation de l'extension Roo" "Red"
            Write-ColorOutput "  Veuillez l'installer manuellement depuis VS Code Marketplace" "Red"
            Write-ColorOutput "  Ou utilisez -SkipExtensionInstall pour ignorer cette étape" "Red"
        }
    }
    
    Write-Host ""
}

# Configuration du fichier .env
Write-ColorOutput "Configuration du fichier .env..." "Yellow"

$envFilePath = Join-Path -Path $demoRootPath -ChildPath ".env"
$envExamplePath = Join-Path -Path $demoRootPath -ChildPath ".env.example"

if (-not (Test-Path $envExamplePath)) {
    Write-ColorOutput "✗ Le fichier .env.example n'existe pas: $envExamplePath" "Red"
} else {
    # Créer le fichier .env s'il n'existe pas
    if (-not (Test-Path $envFilePath)) {
        Copy-Item -Path $envExamplePath -Destination $envFilePath
        Write-ColorOutput "✓ Fichier .env créé à partir de .env.example" "Green"
    } else {
        Write-ColorOutput "✓ Le fichier .env existe déjà" "Green"
    }
    
    # Mettre à jour les clés API si fournies
    $updated = Update-EnvFile -EnvFilePath $envFilePath -OpenAIKey $ApiKeyOpenAI -AnthropicKey $ApiKeyAnthropic -RooKey $ApiKeyRoo
    
    if ($updated) {
        Write-ColorOutput "✓ Fichier .env mis à jour avec les clés API fournies" "Green"
    }
}

Write-Host ""

# Préparation des espaces de travail
if (-not $SkipWorkspacePreparation) {
    Write-ColorOutput "Préparation des espaces de travail..." "Yellow"
    
    $prepareScriptPath = Join-Path -Path $scriptPath -ChildPath "prepare-workspaces.ps1"
    
    if (-not (Test-Path $prepareScriptPath)) {
        Write-ColorOutput "✗ Le script de préparation n'existe pas: $prepareScriptPath" "Red"
    } else {
        try {
            Write-VerboseOutput "Exécution du script: $prepareScriptPath"
            & $prepareScriptPath
            Write-ColorOutput "✓ Les espaces de travail ont été préparés avec succès" "Green"
        } catch {
            Write-ColorOutput "✗ Erreur lors de la préparation des espaces de travail: $_" "Red"
        }
    }
    
    Write-Host ""
}

# Affichage du résumé
Write-ColorOutput "=========================================" "Cyan"
Write-ColorOutput "  INSTALLATION TERMINÉE" "Cyan"
Write-ColorOutput "=========================================" "Cyan"
Write-ColorOutput "La démo Roo a été installée et configurée avec succès!" "Green"
Write-ColorOutput "Pour commencer à utiliser la démo:" "Yellow"
Write-ColorOutput "1. Ouvrez VS Code dans le répertoire d'une démo spécifique" "Yellow"
Write-ColorOutput "   Exemple: code $demoRootPath\01-decouverte\demo-1-conversation\workspace" "Yellow"
Write-ColorOutput "2. Suivez les instructions du fichier README.md dans le workspace" "Yellow"
Write-ColorOutput "3. Utilisez le panneau Roo en cliquant sur l'icône Roo dans la barre latérale" "Yellow"
Write-Host ""
Write-ColorOutput "Pour plus d'informations, consultez:" "Yellow"
Write-ColorOutput "- Le guide d'introduction à la démo: $rootPath\docs\guides\demo-guide.md" "Yellow"
Write-ColorOutput "- Le guide d'installation complet: $rootPath\docs\guides\installation-complete.md" "Yellow"
Write-ColorOutput "- Le guide de maintenance: $rootPath\docs\guides\demo-maintenance.md" "Yellow"
Write-Host ""
Write-ColorOutput "Version actuelle de la démo: $(Get-Content -Path "$demoRootPath\VERSION.md" -TotalCount 1 -ErrorAction SilentlyContinue)" "Cyan"
Write-ColorOutput "=========================================" "Cyan"