<#
.SYNOPSIS
    Installe et configure les MCPs (Model Context Protocol) internes et externes.
.DESCRIPTION
    Ce script robuste suit les principes du SDDD (Semantic Doc Driven Design) pour automatiser l'installation de l'environnement MCP.
    Il gère les prérequis, met à jour les submodules, découvre et installe les MCPs, puis met à jour la configuration centrale.
.PARAMETER McpName
    Spécifie le nom d'un ou plusieurs MCPs à installer. Si non fourni, le script tentera d'installer tous les MCPs découverts.
.PARAMETER Force
    Force la réinstallation d'un MCP même s'il semble déjà installé (par exemple, si le répertoire node_modules existe déjà).
.EXAMPLE
    PS > .\install-mcps.ps1
    Tente d'installer tous les MCPs.
.EXAMPLE
    PS > .\install-mcps.ps1 -McpName "quickfiles-server", "win-cli"
    Installe uniquement les MCPs 'quickfiles-server' et 'win-cli'.
.EXAMPLE
    PS > .\install-mcps.ps1 -McpName "quickfiles-server" -Force
    Force la réinstallation du MCP 'quickfiles-server'.
#>

param (
    [Parameter(Mandatory = $false)]
    [string[]]$McpName,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Forcer l'encodage UTF-8 pour la sortie
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# =============================================================================
# Helper Functions
# =============================================================================

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

function Test-CommandExists {
    param([string]$command)
    return [bool](Get-Command $command -ErrorAction SilentlyContinue)
}

function Find-ViablePythonExecutable {
    $candidates = Get-Command python3, python, py -All -ErrorAction SilentlyContinue
    foreach ($candidate in $candidates) {
        $path = $candidate.Source
        if ($path -like "*\WindowsApps\*") {
            Write-ColorOutput "Ignorant l'alias du Windows Store: $path" "Gray"
            continue
        }

        try {
            Write-ColorOutput "Test de l'exécutable : $path" "Gray"
            $process = Start-Process -FilePath $path -ArgumentList "--version" -Wait -NoNewWindow -PassThru -RedirectStandardOutput ".\stdout.txt" -RedirectStandardError ".\stderr.txt"
            if ($process.ExitCode -eq 0) {
                Write-ColorOutput "Exécutable viable trouvé : $path" "Green"
                Remove-Item -Path ".\stdout.txt", ".\stderr.txt" -ErrorAction SilentlyContinue
                return $path
            }
        } catch {
            Write-ColorOutput "Échec du test pour $path : $($_.Exception.Message)" "Gray"
        } finally {
            Remove-Item -Path ".\stdout.txt", ".\stderr.txt" -ErrorAction SilentlyContinue
        }
    }
    return $null
}

# =============================================================================
# Initialisation
# =============================================================================

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Resolve-Path (Join-Path -Path $scriptDir -ChildPath "..\..")

Write-ColorOutput "=========================================================" "Cyan"
Write-ColorOutput "   Installation et Déploiement des MCPs" "Cyan"
Write-ColorOutput "=========================================================" "Cyan"
Write-ColorOutput "Répertoire racine du projet : $rootDir"

# 1. Vérification des prérequis
Write-ColorOutput "`n[Phase 1/4] Vérification des prérequis..." "Yellow"
$prereqsOk = $true
if (-not (Test-CommandExists "git")) {
    Write-ColorOutput "ERREUR: Git n'est pas installé ou accessible dans le PATH." "Red"
    $prereqsOk = $false
}
if (-not (Test-CommandExists "node")) {
    Write-ColorOutput "ERREUR: Node.js n'est pas installé ou accessible dans le PATH." "Red"
    $prereqsOk = $false
}

if (-not $prereqsOk) {
    Write-ColorOutput "`nVeuillez installer les logiciels manquants et réessayer." "Red"
    exit 1
}
Write-ColorOutput "Prérequis validés." "Green"

# 2. Mise à jour des submodules Git
Write-ColorOutput "`n[Phase 2/4] Initialisation et mise à jour des submodules Git..." "Yellow"
try {
    Push-Location -Path $rootDir
    git submodule update --init --recursive -ErrorAction SilentlyContinue | Out-Null
    Pop-Location
    Write-ColorOutput "Submodules mis à jour avec succès." "Green"
} catch {
    Write-ColorOutput "ERREUR: Impossible de mettre à jour les submodules Git." "Red"
    Write-ColorOutput $_.Exception.Message "Red"
    Pop-Location
    exit 1
}

# =============================================================================
# Découverte et Installation
# =============================================================================

Write-ColorOutput "`n[Phase 3/4] Découverte et installation des MCPs..." "Yellow"

$internalMcpsPath = Join-Path -Path $rootDir -ChildPath "mcps/internal/servers"
$externalMcpsPath = Join-Path -Path $rootDir -ChildPath "mcps/external"
$installedMcps = @{}

$allMcps = @()
if (Test-Path $internalMcpsPath) {
    $allMcps += Get-ChildItem -Path $internalMcpsPath -Directory | Select-Object @{N='Name';E={$_.Name}},@{N='Type';E={"Internal"}},@{N='Path';E={$_.FullName}}
}
if (Test-Path $externalMcpsPath) {
    $allMcps += Get-ChildItem -Path $externalMcpsPath -Directory | Select-Object @{N='Name';E={$_.Name}},@{N='Type';E={"External"}},@{N='Path';E={$_.FullName}}
}

if ($McpName) {
    Write-ColorOutput "Filtrage des MCPs à installer : $($McpName -join ', ')"
    $allMcps = $allMcps | Where-Object { $_.Name -in $McpName }
}

if ($allMcps.Count -eq 0) {
    Write-ColorOutput "Aucun MCP trouvé ou spécifié. Fin du script." "Yellow"
    exit 0
}

foreach ($mcp in $allMcps) {
    Write-ColorOutput "`n--- Traitement de $($mcp.Name) ($($mcp.Type)) ---" "Cyan"

    if ($mcp.Type -eq "Internal") {
        $packageJsonPath = Join-Path -Path $mcp.Path -ChildPath "package.json"
        if (-not (Test-Path $packageJsonPath)) {
            Write-ColorOutput "package.json non trouvé. MCP ignoré." "Yellow"
            continue
        }

        $nodeModulesPath = Join-Path -Path $mcp.Path -ChildPath "node_modules"
        if ((Test-Path $nodeModulesPath) -and (-not $Force)) {
            Write-ColorOutput "Dépendances déjà installées (node_modules existe). Utilisez -Force pour réinstaller." "Green"
            $installedMcps[$mcp.Name] = $mcp.Path
            continue
        }

        try {
            Write-ColorOutput "Installation des dépendances avec 'npm install'..."
            Push-Location -Path $mcp.Path
            npm install --include=dev --silent
            
            # Vérifier si un script "build" existe et l'exécuter
            $pkg = Get-Content -Path $packageJsonPath | ConvertFrom-Json
            if ($pkg.scripts.build) {
                Write-ColorOutput "Exécution du script 'npm run build'..."
                npm run build --silent
            }
            
            # Tâche Spécifique: Créer le .env pour github-projects-mcp
            if ($mcp.Name -eq "github-projects-mcp") {
                Write-ColorOutput "Configuration de l'environnement pour github-projects-mcp..."
                # ATTENTION: Remplacez "VOTRE_TOKEN_GITHUB" par un jeton d'accès personnel (PAT) valide.
                $token = "VOTRE_TOKEN_GITHUB"
                $envContent = "GITHUB_ACCOUNTS_JSON='[{`"user`":`"jsboige`",`"token`":`"$($token)`"}]'"
                $envFilePath = Join-Path -Path $mcp.Path -ChildPath ".env"
                [System.IO.File]::WriteAllText($envFilePath, $envContent, [System.Text.UTF8Encoding]::new($false))
                Write-ColorOutput ".env créé avec succès." "Green"
            }

            Pop-Location
            Write-ColorOutput "Installation de $($mcp.Name) terminée avec succès." "Green"
            $installedMcps[$mcp.Name] = $mcp.Path
        } catch {
            Write-ColorOutput "ERREUR lors de l'installation de $($mcp.Name)." "Red"
            Write-ColorOutput $_.Exception.Message "Red"
            Pop-Location
        }
    }
    elseif ($mcp.Type -eq "External") {
        $installScriptPath = Join-Path -Path $mcp.Path -ChildPath "install.ps1"
        if (Test-Path $installScriptPath) {
            try {
                Write-ColorOutput "Exécution du script d'installation: $installScriptPath"
                Push-Location -Path $mcp.Path
                & $installScriptPath
                Pop-Location
                Write-ColorOutput "Script d'installation pour $($mcp.Name) exécuté." "Green"
            } catch {
                Write-ColorOutput "ERREUR lors de l'exécution de l'installateur pour $($mcp.Name)." "Red"
                Write-ColorOutput $_.Exception.Message "Red"
                Pop-Location
            }
        } else {
            Write-ColorOutput "Aucun 'install.ps1' trouvé. Veuillez consulter le README.md pour une installation manuelle." "Yellow"
        }
    }
}

# =============================================================================
# Configuration
# =============================================================================
# Phase 3.5: Préchauffage du cache pour les paquets npx sensibles
Write-ColorOutput "`n[Phase 3.5/4] Préchauffage des caches npx..." "Yellow"
try {
    Write-ColorOutput "Préchauffage du cache pour @playwright/mcp..."
    # Exécuter une commande légère force npx à télécharger et installer le paquet proprement.
    npx -y @playwright/mcp --version | Out-Null
    Write-ColorOutput "Cache pour @playwright/mcp préchauffé avec succès." "Green"
} catch {
    Write-ColorOutput "AVERTISSEMENT: Une erreur est survenue lors du préchauffage du cache de Playwright. Le démarrage pourrait échouer." "Yellow"
    Write-ColorOutput $_.Exception.Message "Yellow"
}

Write-ColorOutput "`n[Phase 4/4] Mise à jour de la configuration des serveurs..." "Yellow"

if ($installedMcps.Count -eq 0) {
    Write-ColorOutput "Aucun MCP interne n'a été installé avec succès. La configuration n'a pas été modifiée." "Yellow"
} else {
    $serversJsonPath = Join-Path -Path $env:APPDATA -ChildPath "Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json"
    if (-not (Test-Path $serversJsonPath)) {
        Write-ColorOutput "ERREUR : Le fichier de configuration '$serversJsonPath' est introuvable." "Red"
        exit 1
    }

    try {
        # Sauvegarde
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupFile = "$serversJsonPath.backup_$timestamp"
        Copy-Item -Path $serversJsonPath -Destination $backupFile -Force
        Write-ColorOutput "Sauvegarde de la configuration créée : $backupFile" "Green"

        # On part d'une feuille blanche pour la configuration
        $finalConfig = @{
            mcpServers = @{}
        }
        
        # On ne garde pas les anciennes propriétés pour garantir un fichier propre.
        
        Write-ColorOutput "Construction de la configuration pour les MCPs internes installés..."
        foreach ($name in $installedMcps.Keys) {
            $path = $installedMcps[$name]
            $packageJsonPath = Join-Path -Path $path -ChildPath "package.json"
            if (-not (Test-Path $packageJsonPath)) { continue }
            $pkg = Get-Content -Path $packageJsonPath | ConvertFrom-Json
            
            $mainFile = if ($pkg.main) { $pkg.main } else { "index.js" }
            
            try {
                $mainFilePath = (Resolve-Path (Join-Path -Path $path -ChildPath $mainFile)).Path.Replace("\", "/")
            }
            catch {
                Write-ColorOutput "Erreur: Le fichier principal '$mainFile' est introuvable pour le MCP '$name'. Ce MCP ne sera pas ajouté à la configuration." "Red"
                continue
            }
            
            $serverKey = $name.Replace("-server", "")
            if ($name -eq "github-projects-mcp") {
                $serverKey = "github-projects-mcp"
            }
            
            # La plupart des serveurs Node.js fonctionnent mieux avec 'node' directement.
            $command = "node"
            $args = @($mainFilePath)
            
            Write-ColorOutput "Ajout de l'entrée pour '$serverKey'..."

            $newEntry = @{
                command = $command
                args = $args
                transportType = "stdio"
                disabled = $false
                autoStart = $true
                description = if($pkg.description) { $pkg.description } else { "Serveur MCP pour $name" }
                autoApprove = @()
                alwaysAllow = @()
            }

            if ($name -in @("roo-state-manager", "github-projects-mcp")) {
                $newEntry["options"] = @{
                    cwd = $path.Replace("\", "/")
                }
            }

            # La section 'env' est complètement retirée pour ce MCP lors de la génération
            $finalConfig.mcpServers[$serverKey] = $newEntry
        }

        # Ajouter la configuration pour les MCPs externes courants
        Write-ColorOutput "Ajout de la configuration pour les MCPs externes..."
        
        $finalConfig.mcpServers['searxng'] = @{
            command = "cmd"
            args = @("/c", "npx", "-y", "mcp-searxng")
            transportType = "stdio"
            disabled = $false
            autoStart = $true
            description = "MCP pour la recherche web avec SearXNG"
            env = @{ "SEARXNG_URL" = "https://search.myia.io/" }
            autoApprove = @()
            alwaysAllow = @("web_url_read", "searxng_web_search")
        }

        $finalConfig.mcpServers['playwright'] = @{
            command = "cmd"
            args = @("/c", "npx", "-y", "@playwright/mcp", "--browser", "firefox")
            transportType = "stdio"
            disabled = $false
            autoStart = $true
            description = "MCP pour l'automatisation web avec Playwright"
            autoApprove = @()
            alwaysAllow = @("browser_navigate", "browser_click", "browser_take_screenshot", "browser_close", "browser_snapshot", "browser_install")
        }

        # Logique de détection robuste de Python
        $pythonPath = Find-ViablePythonExecutable
        
        if ($pythonPath) {
            Write-ColorOutput "Python trouvé : $pythonPath" "Green"
            $finalConfig.mcpServers['markitdown'] = @{
                command = $pythonPath
                args = @("-m", "markitdown_mcp")
                transportType = "stdio"
                disabled = $false
                autoStart = $true
                description = "MCP pour manipuler des fichiers Markdown."
                autoApprove = @()
                alwaysAllow = @("convert_to_markdown")
            }
        } else {
            Write-ColorOutput "AVERTISSEMENT: Aucun exécutable Python (python3, python, py) n'a été trouvé. Le MCP 'markitdown' sera désactivé." "Yellow"
            # Optionnel: On peut ajouter une entrée désactivée pour informer l'utilisateur
            $finalConfig.mcpServers['markitdown'] = @{
                command = "echo"
                args = @("Python not found, markitdown is disabled.")
                transportType = "stdio"
                disabled = $true
                autoStart = $false
                description = "MCP pour manipuler des fichiers Markdown (DÉSACTIVÉ - PYTHON INTROUVABLE)."
            }
        }

        $jsonOutput = $finalConfig | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($serversJsonPath, $jsonOutput, [System.Text.UTF8Encoding]::new($false))
        Write-ColorOutput "Le fichier 'mcp_settings.json' a été mis à jour avec succès." "Green"

    } catch {
        Write-ColorOutput "ERREUR lors de la mise à jour de '$serversJsonPath'." "Red"
        Write-ColorOutput $_.Exception.Message "Red"
    }
}


# =============================================================================
# Résumé
# =============================================================================

Write-ColorOutput "`n=========================================================" "Cyan"
Write-ColorOutput "   Déploiement terminé !" "Green"
Write-ColorOutput "=========================================================" "Cyan"
Write-ColorOutput "N'oubliez pas de redémarrer Visual Studio Code pour que les changements prennent effet." "White"
