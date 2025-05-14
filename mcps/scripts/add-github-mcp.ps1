# Script pour ajouter la configuration du MCP GitHub au fichier servers.json global de Roo

# Fonction pour afficher des messages colorés
function Write-ColorOutput {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$ForegroundColor = "White"
    )
    
    $originalColor = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    Write-Output $Message
    $host.UI.RawUI.ForegroundColor = $originalColor
}

# Bannière
Write-ColorOutput "`n=========================================================" "Cyan"
Write-ColorOutput "   Configuration du MCP GitHub dans Roo" "Cyan"
Write-ColorOutput "=========================================================" "Cyan"

# Déterminer le chemin du fichier de configuration des serveurs
$rooSettingsDir = Join-Path -Path $env:APPDATA -ChildPath "Code\User\globalStorage\rooveterinaryinc.roo-cline\settings"
$serversConfigFile = Join-Path -Path $rooSettingsDir -ChildPath "servers.json"

# Vérifier si le fichier de configuration des serveurs existe
if (Test-Path -Path $serversConfigFile) {
    Write-ColorOutput "Le fichier de configuration des serveurs existe." "Green"
    
    # Lire le contenu du fichier
    try {
        $serversConfig = Get-Content -Path $serversConfigFile -Raw | ConvertFrom-Json
        $githubConfigured = $false
        
        # Vérifier si le serveur GitHub est déjà configuré
        foreach ($server in $serversConfig.servers) {
            if ($server.name -eq "github") {
                $githubConfigured = $true
                break
            }
        }
        
        if ($githubConfigured) {
            Write-ColorOutput "Le serveur MCP GitHub est déjà configuré." "Green"
        }
        else {
            Write-ColorOutput "Le serveur MCP GitHub n'est pas configuré. Ajout en cours..." "Yellow"
            
            # Demander le token GitHub à l'utilisateur
            $githubToken = Read-Host "Veuillez entrer votre token GitHub personnel" -AsSecureString
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($githubToken)
            $githubTokenPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
            
            # Créer la configuration du serveur GitHub
            $githubServer = @{
                name = "github"
                type = "stdio"
                command = "docker"
                args = @(
                    "run",
                    "-i",
                    "--rm",
                    "-e",
                    "GITHUB_PERSONAL_ACCESS_TOKEN",
                    "ghcr.io/github/github-mcp-server"
                )
                env = @{
                    GITHUB_PERSONAL_ACCESS_TOKEN = $githubTokenPlain
                }
                enabled = $true
                autoStart = $true
                description = "Serveur MCP pour interagir avec les API GitHub"
            }
            
            # Ajouter la configuration du serveur GitHub au fichier
            $serversConfig.servers += $githubServer
            
            # Écrire le fichier mis à jour
            $serversConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $serversConfigFile
            
            Write-ColorOutput "Le serveur MCP GitHub a été ajouté avec succès." "Green"
        }
    }
    catch {
        Write-ColorOutput "Erreur lors de la lecture ou de la mise à jour du fichier de configuration des serveurs:" "Red"
        Write-ColorOutput $_.Exception.Message "Red"
    }
}
else {
    Write-ColorOutput "Le fichier de configuration des serveurs n'existe pas." "Red"
    Write-ColorOutput "Veuillez exécuter le script install-mcp-and-modes.ps1 pour créer le fichier de configuration." "Red"
}

# Résumé
Write-ColorOutput "`n=========================================================" "Cyan"
Write-ColorOutput "   Configuration terminée!" "Green"
Write-ColorOutput "=========================================================" "Cyan"
Write-ColorOutput "`nPour activer le MCP GitHub:" "White"
Write-ColorOutput "1. Redémarrez Visual Studio Code" "White"
Write-ColorOutput "2. Le MCP GitHub devrait démarrer automatiquement" "White"
Write-ColorOutput "`n" "White"