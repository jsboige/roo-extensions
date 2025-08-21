<#
.SYNOPSIS
    Script de surveillance des serveurs MCP.

.DESCRIPTION
    Ce script execute le moniteur JavaScript des serveurs MCP et peut redemarrer
    les serveurs defaillants si necessaire. Il est concu pour etre execute manuellement
    ou comme tache planifiee Windows.

.PARAMETER RestartServers
    Si specifie, tente de redemarrer les serveurs defaillants.

.PARAMETER LogOnly
    Si specifie, n'affiche pas les messages dans la console, uniquement dans les fichiers de log.

.PARAMETER EmailAlert
    Si specifie, envoie une alerte par email en cas de probleme (necessite une configuration supplementaire).

.EXAMPLE
    .\monitor-mcp-servers.ps1
    Execute la surveillance sans redemarrer les serveurs defaillants.

.EXAMPLE
    .\monitor-mcp-servers.ps1 -RestartServers
    Execute la surveillance et tente de redemarrer les serveurs defaillants.

.NOTES
    Auteur: Roo Extensions Team
    Date: Mai 2025
#>

param (
    [switch]$RestartServers,
    [switch]$LogOnly,
    [switch]$EmailAlert
)

# Definition des chemins
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$JSMonitorPath = Join-Path -Path $ScriptPath -ChildPath "monitor-mcp-servers.js"
$LogDir = Join-Path -Path $ScriptPath -ChildPath "logs"
$AlertDir = Join-Path -Path $ScriptPath -ChildPath "alerts"
$LogFile = Join-Path -Path $LogDir -ChildPath "mcp-monitor-ps-$(Get-Date -Format 'yyyy-MM-dd').log"

# Creer les repertoires de logs et d'alertes s'ils n'existent pas
if (-not (Test-Path -Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}

if (-not (Test-Path -Path $AlertDir)) {
    New-Item -Path $AlertDir -ItemType Directory -Force | Out-Null
}

# Fonction pour ecrire dans le log
function Write-Log {
    param (
        [string]$Message,
        [switch]$IsAlert
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] $Message"
    
    # Ecrire dans le fichier de log
    Add-Content -Path $LogFile -Value $LogEntry
    
    # Afficher dans la console si LogOnly n'est pas specifie
    if (-not $LogOnly) {
        if ($IsAlert) {
            Write-Host $LogEntry -ForegroundColor Red
        } else {
            Write-Host $LogEntry
        }
    }
    
    # Si c'est une alerte, ecrire egalement dans le fichier d'alertes
    if ($IsAlert) {
        $AlertFile = Join-Path -Path $AlertDir -ChildPath "mcp-alerts-ps-$(Get-Date -Format 'yyyy-MM-dd').log"
        Add-Content -Path $AlertFile -Value $LogEntry
    }
}

# Fonction pour envoyer une alerte par email
function Send-EmailAlert {
    param (
        [string]$Subject,
        [string]$Body
    )
    
    # Cette fonction est un placeholder - elle doit etre configuree avec les parametres SMTP appropries
    if ($EmailAlert) {
        Write-Log "Envoi d'une alerte par email: $Subject" -IsAlert
        
        # Exemple de configuration SMTP - à personnaliser
        <#
        $SmtpServer = "smtp.example.com"
        $SmtpPort = 587
        $Username = "alertes@example.com"
        $Password = ConvertTo-SecureString "VotreMotDePasse" -AsPlainText -Force
        $Credential = New-Object System.Management.Automation.PSCredential ($Username, $Password)
        $From = "alertes@example.com"
        $To = "admin@example.com"
        
        Send-MailMessage -From $From -To $To -Subject $Subject -Body $Body -SmtpServer $SmtpServer `
            -Port $SmtpPort -UseSsl -Credential $Credential
        #>
        
        # Pour l'instant, on se contente de logger l'alerte
        Write-Log "ALERTE EMAIL: $Subject - $Body" -IsAlert
    }
}

# Fonction pour redemarrer un serveur MCP
function Restart-McpServer {
    param (
        [string]$ServerName,
        [string]$StartScript
    )
    
    Write-Log "Tentative de redemarrage du serveur $ServerName..." -IsAlert
    
    if ([string]::IsNullOrEmpty($StartScript) -or -not (Test-Path -Path $StartScript)) {
        Write-Log "Impossible de redemarrer ${ServerName}: Script de demarrage non trouve ou non specifie." -IsAlert
        return $false
    }
    
    try {
        # Tuer les processus existants (a adapter selon le serveur)
        # Cette partie est simplifiee et devrait etre adaptee pour chaque serveur
        if ($ServerName -like "*Jupyter*") {
            Get-Process -Name "node" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*jupyter-mcp-server*" } | Stop-Process -Force
        } elseif ($ServerName -like "*JinaNavigator*") {
            Get-Process -Name "node" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*jinavigator-server*" } | Stop-Process -Force
        } elseif ($ServerName -like "*QuickFiles*") {
            Get-Process -Name "node" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*quickfiles-server*" } | Stop-Process -Force
        } elseif ($ServerName -like "*SearxNG*") {
            Get-Process -Name "node" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*searxng-server*" } | Stop-Process -Force
        } elseif ($ServerName -like "*Win-CLI*") {
            Get-Process -Name "node" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*server-win-cli*" } | Stop-Process -Force
        }
        
        # Attendre que les processus se terminent
        Start-Sleep -Seconds 2
        
        # Demarrer le serveur
        Write-Log "Demarrage de $ServerName avec le script: $StartScript"
        Start-Process -FilePath $StartScript -WindowStyle Hidden
        
        # Attendre que le serveur demarre
        Start-Sleep -Seconds 10
        
        Write-Log "Le serveur $ServerName a ete redemarre avec succes."
        return $true
    }
    catch {
        Write-Log "Erreur lors du redemarrage de ${ServerName}: $_" -IsAlert
        return $false
    }
}

# Fonction principale
function Start-McpMonitoring {
    Write-Log "Demarrage de la surveillance des serveurs MCP..."
    
    try {
        # Verifier si Node.js est installe
        $NodeVersion = node --version
        Write-Log "Node.js version: $NodeVersion"
        
        # Verifier si le script JavaScript existe
        if (-not (Test-Path -Path $JSMonitorPath)) {
            Write-Log "Le script de surveillance JavaScript n'existe pas: $JSMonitorPath" -IsAlert
            return
        }
        
        # Executer le script JavaScript et capturer la sortie
        Write-Log "Execution du script de surveillance JavaScript..."
        $Output = node $JSMonitorPath
        
        # Analyser la sortie pour detecter les problemes
        $ProblemDetected = $false
        $ProblemServers = @()
        
        foreach ($Line in $Output) {
            # Ecrire la sortie dans le log
            Write-Log $Line
            
            # Detecter les problemes
            if ($Line -like "*ALERTE*" -or $Line -like "*Probleme*" -or $Line -like "*n'est pas en cours d'execution*" -or $Line -like "*ne repond pas*") {
                $ProblemDetected = $true
                
                # Extraire le nom du serveur s'il est mentionne
                if ($Line -like "*serveur*") {
                    $ServerName = $Line -replace ".*serveur\s+([^:]+).*", '$1'
                    if ($ServerName -and $ServerName -ne $Line) {
                        $ProblemServers += $ServerName
                    }
                }
            }
        }
        
        # Si des problemes sont detectes et que RestartServers est specifie
        if ($ProblemDetected -and $RestartServers) {
            Write-Log "Des problemes ont ete detectes. Tentative de redemarrage des serveurs defaillants..." -IsAlert
            
            # Charger les informations des serveurs depuis le script JavaScript
            $ServerInfo = Get-Content -Path $JSMonitorPath | Select-String -Pattern "name: '([^']+)'.*startScript: (.*)" -AllMatches
            
            foreach ($Server in $ProblemServers) {
                $ServerConfig = $ServerInfo | Where-Object { $_.Matches.Groups[1].Value -eq $Server }
                
                if ($ServerConfig) {
                    $StartScript = $ServerConfig.Matches.Groups[2].Value.Trim()
                    # Nettoyer la valeur du script (enlever les guillemets, etc.)
                    $StartScript = $StartScript -replace "path\.join\(__dirname, '(.+)'\)", '$1'
                    $StartScript = $StartScript -replace "'|,|\s*$", ""
                    
                    if ($StartScript -ne "null") {
                        $FullStartScript = Join-Path -Path (Split-Path -Parent $ScriptPath) -ChildPath $StartScript
                        Restart-McpServer -ServerName $Server -StartScript $FullStartScript
                    } else {
                        Write-Log "Impossible de redemarrer ${Server}: Aucun script de demarrage specifie." -IsAlert
                    }
                }
            }
            
            # Executer a nouveau la surveillance pour verifier si les redemarrages ont resolu les problemes
            Write-Log "Verification de l'etat des serveurs apres redemarrage..."
            Start-Sleep -Seconds 15
            $Output = node $JSMonitorPath
            
            # Verifier si des problemes persistent
            $ProblemsRemain = $false
            foreach ($Line in $Output) {
                Write-Log $Line
                if ($Line -like "*ALERTE*" -or $Line -like "*Probleme*" -or $Line -like "*n'est pas en cours d'execution*" -or $Line -like "*ne repond pas*") {
                    $ProblemsRemain = $true
                }
            }
            
            if ($ProblemsRemain) {
                $AlertMessage = "Des problemes persistent avec les serveurs MCP apres tentative de redemarrage."
                Write-Log $AlertMessage -IsAlert
                Send-EmailAlert -Subject "ALERTE: Problemes persistants avec les serveurs MCP" -Body $AlertMessage
            } else {
                Write-Log "Tous les serveurs MCP fonctionnent correctement apres redemarrage."
            }
        }
        elseif ($ProblemDetected) {
            $AlertMessage = "Des problemes ont ete detectes avec les serveurs MCP. Utilisez l'option -RestartServers pour tenter un redemarrage automatique."
            Write-Log $AlertMessage -IsAlert
            Send-EmailAlert -Subject "ALERTE: Problemes detectes avec les serveurs MCP" -Body $AlertMessage
        }
        else {
            Write-Log "Tous les serveurs MCP fonctionnent correctement."
        }
    }
    catch {
        Write-Log "Erreur lors de l'execution de la surveillance: $_" -IsAlert
        Send-EmailAlert -Subject "ERREUR: Echec de la surveillance des serveurs MCP" -Body $_.ToString()
    }
    
    Write-Log "Fin de la surveillance des serveurs MCP."
}

# Executer la fonction principale
Start-McpMonitoring