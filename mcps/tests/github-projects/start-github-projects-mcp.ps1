# Script PowerShell pour démarrer le serveur MCP GitHub Projects
$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

# Fonction pour afficher les messages de log
function Write-Log {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $colorMap = @{
        "INFO" = "White"
        "WARNING" = "Yellow"
        "ERROR" = "Red"
        "SUCCESS" = "Green"
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $colorMap[$Level]
}

# Vérifier si le port 3002 est déjà utilisé
Write-Log "Vérification si le port 3002 est déjà utilisé..." -Level "INFO"
$portInUse = $false

try {
    $connections = Get-NetTCPConnection -LocalPort 3002 -ErrorAction SilentlyContinue
    if ($connections) {
        $portInUse = $true
        Write-Log "Le port 3002 est déjà utilisé par le processus $($connections[0].OwningProcess)" -Level "WARNING"
        
        # Obtenir le nom du processus
        $process = Get-Process -Id $connections[0].OwningProcess -ErrorAction SilentlyContinue
        if ($process) {
            Write-Log "Processus utilisant le port 3002: $($process.ProcessName)" -Level "INFO"
        }
        
        # Demander à l'utilisateur s'il souhaite arrêter le processus
        $confirmation = Read-Host "Voulez-vous arrêter ce processus pour libérer le port 3002? (O/N)"
        if ($confirmation -eq "O" -or $confirmation -eq "o") {
            Write-Log "Arrêt du processus $($process.ProcessName) (PID: $($connections[0].OwningProcess))..." -Level "INFO"
            Stop-Process -Id $connections[0].OwningProcess -Force
            Start-Sleep -Seconds 2
            Write-Log "Processus arrêté." -Level "SUCCESS"
            $portInUse = $false
        }
    } else {
        Write-Log "Le port 3002 est disponible." -Level "SUCCESS"
    }
} catch {
    Write-Log "Erreur lors de la vérification du port: $_" -Level "ERROR"
}

if ($portInUse) {
    Write-Log "Le port 3002 est toujours utilisé. Impossible de démarrer le serveur MCP GitHub Projects." -Level "ERROR"
    exit 1
}

# Vérifier l'existence du répertoire du serveur
$serverPath = "D:\roo-extensions\mcps\mcp-servers\servers\github-projects-mcp"
if (-not (Test-Path $serverPath)) {
    Write-Log "Le répertoire du serveur MCP GitHub Projects n'existe pas: $serverPath" -Level "ERROR"
    exit 1
}

# Vérifier l'existence du fichier .env
$envPath = Join-Path $serverPath ".env"
if (-not (Test-Path $envPath)) {
    Write-Log "Le fichier .env n'existe pas. Création du fichier..." -Level "INFO"
    
    @"
# Configuration du serveur MCP GitHub Projects
MCP_PORT=3002
MCP_HOST=localhost
GITHUB_TOKEN=PLACEHOLDER_GITHUB_TOKEN
"@ | Out-File -FilePath $envPath -Encoding utf8
    
    Write-Log "Fichier .env créé avec succès." -Level "SUCCESS"
} else {
    Write-Log "Fichier .env trouvé." -Level "SUCCESS"
    
    # Vérifier si le port est correctement configuré dans le fichier .env
    $envContent = Get-Content -Path $envPath -Raw
    if (-not ($envContent -match "MCP_PORT=3002")) {
        Write-Log "Le port n'est pas correctement configuré dans le fichier .env. Mise à jour..." -Level "INFO"
        $envContent = $envContent -replace "MCP_PORT=\d+", "MCP_PORT=3002"
        if (-not ($envContent -match "MCP_PORT=")) {
            $envContent += "`nMCP_PORT=3002"
        }
        $envContent | Out-File -FilePath $envPath -Encoding utf8
        Write-Log "Fichier .env mis à jour avec succès." -Level "SUCCESS"
    }
}

# Vérifier si le serveur est compilé
$distPath = Join-Path $serverPath "dist"
if (-not (Test-Path $distPath)) {
    Write-Log "Le serveur n'est pas compilé. Compilation..." -Level "INFO"
    
    # Se déplacer dans le répertoire du serveur
    Push-Location $serverPath
    
    # Installer les dépendances si nécessaire
    if (-not (Test-Path (Join-Path $serverPath "node_modules"))) {
        Write-Log "Installation des dépendances..." -Level "INFO"
        npm install
    }
    
    # Compiler le serveur
    Write-Log "Compilation du serveur..." -Level "INFO"
    npm run build
    
    # Revenir au répertoire précédent
    Pop-Location
    
    if (-not (Test-Path $distPath)) {
        Write-Log "Échec de la compilation du serveur." -Level "ERROR"
        exit 1
    }
    
    Write-Log "Serveur compilé avec succès." -Level "SUCCESS"
} else {
    Write-Log "Le serveur est déjà compilé." -Level "SUCCESS"
}

# Démarrer le serveur
Write-Log "Démarrage du serveur MCP GitHub Projects..." -Level "INFO"

# Se déplacer dans le répertoire du serveur
Push-Location $serverPath

# Définir les variables d'environnement
$env:MCP_PORT = "3002"
$env:MCP_HOST = "localhost"
$env:GITHUB_TOKEN = "PLACEHOLDER_GITHUB_TOKEN"
$env:DEBUG = "mcp:*"

# Démarrer le serveur
Write-Log "Exécution du serveur..." -Level "INFO"
Write-Log "Le serveur est maintenant en cours d'exécution sur http://localhost:3002" -Level "SUCCESS"
Write-Log "Appuyez sur Ctrl+C pour arrêter le serveur." -Level "INFO"

# Exécuter le serveur
node dist\index.js

# Revenir au répertoire précédent
Pop-Location