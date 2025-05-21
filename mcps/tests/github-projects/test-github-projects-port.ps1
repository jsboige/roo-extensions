# Script PowerShell pour tester le MCP GitHub Projects sur le port 3002
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

# Vérifier la configuration
Write-Log "Vérification de la configuration..." -Level "INFO"

$settingsPath = "C:\Users\MYIA\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json"
$configOk = $false

if (Test-Path $settingsPath) {
    try {
        $settings = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
        
        if ($settings.mcpServers.'github-projects') {
            $configOk = $true
            Write-Log "Configuration trouvée pour le MCP GitHub Projects." -Level "SUCCESS"
            
            $port = $settings.mcpServers.'github-projects'.env.MCP_PORT
            if ($port) {
                Write-Log "Port configuré: $port" -Level "INFO"
            } else {
                Write-Log "Port non configuré dans mcp_settings.json, utilisation du port par défaut (3002)." -Level "WARNING"
                $port = "3002"
            }
        } else {
            Write-Log "Configuration du MCP GitHub Projects non trouvée dans mcp_settings.json." -Level "ERROR"
        }
    } catch {
        Write-Log "Erreur lors de la lecture du fichier de configuration: $_" -Level "ERROR"
    }
} else {
    Write-Log "Fichier de configuration non trouvé: $settingsPath" -Level "ERROR"
}

# Tester la connexion au serveur
Write-Log "Test de connexion au serveur MCP GitHub Projects sur le port $port..." -Level "INFO"

try {
    $testConnection = Test-NetConnection -ComputerName localhost -Port $port -InformationLevel Quiet
    
    if ($testConnection) {
        Write-Log "Connexion réussie au serveur MCP GitHub Projects sur le port $port." -Level "SUCCESS"
    } else {
        Write-Log "Impossible de se connecter au serveur MCP GitHub Projects sur le port $port." -Level "ERROR"
    }
} catch {
    Write-Log "Erreur lors du test de connexion: $_" -Level "ERROR"
}

# Résumé
Write-Log "Résumé des tests:" -Level "INFO"
Write-Log "- Fichier de configuration: $settingsPath" -Level "INFO"
Write-Log "- Configuration valide: $configOk" -Level "INFO"
Write-Log "- Port configuré: $port" -Level "INFO"