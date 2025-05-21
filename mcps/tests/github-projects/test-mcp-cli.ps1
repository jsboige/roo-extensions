# Script PowerShell pour tester le MCP CLI avec le serveur GitHub Projects
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

# Rechercher le MCP CLI
Write-Log "Recherche du MCP CLI..." -Level "INFO"

$mcpCliPath = $null
$possiblePaths = @(
    "C:\Users\MYIA\AppData\Local\Programs\Roo\resources\app\out\mcp-cli\mcp-cli.exe",
    "C:\Program Files\Roo\resources\app\out\mcp-cli\mcp-cli.exe",
    "C:\Program Files (x86)\Roo\resources\app\out\mcp-cli\mcp-cli.exe"
)

foreach ($path in $possiblePaths) {
    if (Test-Path $path) {
        $mcpCliPath = $path
        Write-Log "MCP CLI trouvé: $mcpCliPath" -Level "SUCCESS"
        break
    }
}

if (-not $mcpCliPath) {
    Write-Log "MCP CLI non trouvé. Recherche dans le PATH..." -Level "WARNING"
    
    try {
        $mcpCliCommand = Get-Command "mcp-cli" -ErrorAction SilentlyContinue
        if ($mcpCliCommand) {
            $mcpCliPath = $mcpCliCommand.Source
            Write-Log "MCP CLI trouvé dans le PATH: $mcpCliPath" -Level "SUCCESS"
        } else {
            Write-Log "MCP CLI non trouvé dans le PATH." -Level "ERROR"
        }
    } catch {
        Write-Log "Erreur lors de la recherche du MCP CLI: $_" -Level "ERROR"
    }
}

if (-not $mcpCliPath) {
    Write-Log "MCP CLI non trouvé. Installation de la version npm..." -Level "INFO"
    
    try {
        npm install -g @modelcontextprotocol/cli
        $mcpCliCommand = Get-Command "mcp" -ErrorAction SilentlyContinue
        if ($mcpCliCommand) {
            $mcpCliPath = $mcpCliCommand.Source
            Write-Log "MCP CLI installé avec succès: $mcpCliPath" -Level "SUCCESS"
        } else {
            Write-Log "Échec de l'installation du MCP CLI." -Level "ERROR"
            exit 1
        }
    } catch {
        Write-Log "Erreur lors de l'installation du MCP CLI: $_" -Level "ERROR"
        exit 1
    }
}

# Vérifier si le serveur est en cours d'exécution
Write-Log "Vérification si le serveur MCP GitHub Projects est en cours d'exécution..." -Level "INFO"

try {
    $connections = Get-NetTCPConnection -LocalPort 3002 -ErrorAction SilentlyContinue
    if ($connections) {
        Write-Log "Le serveur MCP GitHub Projects est en cours d'exécution sur le port 3002." -Level "SUCCESS"
    } else {
        Write-Log "Le serveur MCP GitHub Projects n'est pas en cours d'exécution sur le port 3002." -Level "WARNING"
        
        # Demander à l'utilisateur s'il souhaite démarrer le serveur
        $confirmation = Read-Host "Voulez-vous démarrer le serveur MCP GitHub Projects? (O/N)"
        if ($confirmation -eq "O" -or $confirmation -eq "o") {
            Write-Log "Démarrage du serveur MCP GitHub Projects..." -Level "INFO"
            
            # Démarrer le serveur dans une nouvelle fenêtre PowerShell
            Start-Process powershell -ArgumentList "-NoExit", "-File", "D:\roo-extensions\mcps\tests\github-projects\start-github-projects-mcp.ps1"
            
            # Attendre que le serveur démarre
            Write-Log "Attente du démarrage du serveur..." -Level "INFO"
            Start-Sleep -Seconds 5
        } else {
            Write-Log "Le serveur MCP GitHub Projects n'est pas en cours d'exécution. Impossible de continuer." -Level "ERROR"
            exit 1
        }
    }
} catch {
    Write-Log "Erreur lors de la vérification du serveur: $_" -Level "ERROR"
}

# Tester le MCP CLI
Write-Log "Test du MCP CLI avec le serveur GitHub Projects..." -Level "INFO"

# Fonction pour exécuter une commande MCP CLI
function Invoke-McpCli {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Command,
        
        [Parameter(Mandatory=$false)]
        [string]$Arguments = ""
    )
    
    Write-Log "Exécution de la commande MCP CLI: $Command $Arguments" -Level "INFO"
    
    try {
        if ($mcpCliPath -match "mcp-cli.exe$") {
            $result = & $mcpCliPath $Command $Arguments
        } else {
            $result = & mcp $Command $Arguments
        }
        
        return $result
    } catch {
        Write-Log "Erreur lors de l'exécution de la commande MCP CLI: $_" -Level "ERROR"
        return $null
    }
}

# Tester la commande list-servers
Write-Log "Test de la commande list-servers..." -Level "INFO"
$servers = Invoke-McpCli "list-servers"
Write-Log "Serveurs disponibles:" -Level "INFO"
$servers | ForEach-Object { Write-Log "- $_" -Level "INFO" }

# Tester la commande list-tools pour le serveur github-projects
Write-Log "Test de la commande list-tools pour le serveur github-projects..." -Level "INFO"
$tools = Invoke-McpCli "list-tools" "--server github-projects"
Write-Log "Outils disponibles pour le serveur github-projects:" -Level "INFO"
$tools | ForEach-Object { Write-Log "- $_" -Level "INFO" }

# Tester la commande list-projects
Write-Log "Test de la commande list-projects..." -Level "INFO"
$owner = "votre-nom-utilisateur-github" # Remplacez par votre nom d'utilisateur GitHub
$result = Invoke-McpCli "use-tool" "--server github-projects --tool list_projects --input `"{ \`"owner\`": \`"$owner\`" }`""
Write-Log "Résultat de la commande list-projects:" -Level "INFO"
$result | ForEach-Object { Write-Log $_ -Level "INFO" }

# Résumé
Write-Log "Résumé des tests:" -Level "INFO"
Write-Log "- MCP CLI: $mcpCliPath" -Level "INFO"
Write-Log "- Serveur MCP GitHub Projects: Port 3002" -Level "INFO"