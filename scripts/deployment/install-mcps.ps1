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

# Recommandations PowerShell (Tâche 2.24):
# - Set-StrictMode pour détecter les erreurs de typage
# - Utilisation de [hashtable] explicite au lieu de PSObject
# - Ajout de timeouts pour éviter les blocages
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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
 
function Parse-EnvFile {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
  
    # Utilisation de [hashtable] explicite
    [hashtable]$envVars = @{}
    if (Test-Path $FilePath) {
        Get-Content $FilePath | ForEach-Object {
            $line = $_.Trim()
            if ($line -and $line -notlike '#*') {
                $parts = $line -split '=', 2
                if ($parts.Length -eq 2) {
                    $key = $parts[0].Trim()
                    $value = $parts[1].Trim()
                    # Supprimer les guillemets optionnels
                    if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
                        $value = $value.Substring(1, $value.Length - 2)
                    }
                    $envVars[$key] = $value
                }
            }
        }
    }
    return $envVars
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
            # CORRECTION SDDD v1.3: Ajout de timeout sur npm install (5 minutes)
            $installJob = Start-Job -ScriptBlock { npm install --include=dev --silent }
            $installJob | Wait-Job -Timeout 300 | Out-Null
            if ($installJob.State -ne 'Completed') {
                Write-ColorOutput "Erreur: Timeout lors de l'installation des dépendances pour $($mcp.Name) (5min)." -ForegroundColor Red
                Remove-Job -Job $installJob -Force -ErrorAction SilentlyContinue
                Pop-Location
                continue
            }
            $installOutput = Receive-Job -Job $installJob
            Remove-Job -Job $installJob -Force -ErrorAction SilentlyContinue
            if ($LASTEXITCODE -ne 0) {
                Write-ColorOutput "Erreur lors de l'installation des dépendances pour $($mcp.Name)." -ForegroundColor Red
                Pop-Location
                continue
            }
            
            # Vérifier si un script "build" existe et l'exécuter
            $pkg = Get-Content -Path $packageJsonPath | ConvertFrom-Json
            if ($pkg.scripts.build) {
                Write-ColorOutput "Exécution du script 'npm run build'..."
                # CORRECTION SDDD v1.3: Ajout de timeout sur npm run build (5 minutes)
                $buildJob = Start-Job -ScriptBlock { npm run build --silent }
                $buildJob | Wait-Job -Timeout 300 | Out-Null
                if ($buildJob.State -ne 'Completed') {
                    Write-ColorOutput "Erreur: Timeout lors de la compilation de $($mcp.Name) (5min)." -ForegroundColor Red
                    Remove-Job -Job $buildJob -Force -ErrorAction SilentlyContinue
                    Pop-Location
                    continue
                }
                $buildOutput = Receive-Job -Job $buildJob
                Remove-Job -Job $buildJob -Force -ErrorAction SilentlyContinue
                if ($LASTEXITCODE -ne 0) {
                    Write-ColorOutput "Erreur lors de la compilation de $($mcp.Name)." -ForegroundColor Red
                    Pop-Location
                    continue
                }
            }
            
            # Tâche Spécifique: Créer le .env pour github-projects-mcp
            if ($mcp.Name -eq "github-projects-mcp") {
                Write-ColorOutput "Configuration de l'environnement pour github-projects-mcp..."
                # ATTENTION: Remplacez "VOTRE_TOKEN_GITHUB" par un jeton d'accès personnel (PAT) valide.
                $token = "VOTRE_TOKEN_GITHUB"
                # Utilisation de [hashtable] explicite
                [hashtable[]]$accounts = @(
                    @{ user = "jsboige"; token = $token }
                )
                $jsonContent = $accounts | ConvertTo-Json -Compress
                $envContent = "GITHUB_ACCOUNTS_JSON='$($jsonContent)'"
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
        }
        
        $requirementsPath = Join-Path -Path $mcp.Path -ChildPath "requirements.txt"
        if (Test-Path $requirementsPath) {
            Write-ColorOutput "Fichier 'requirements.txt' trouvé. Tentative d'installation des dépendances Python."
            $pythonPath = Find-ViablePythonExecutable
            if ($pythonPath) {
                try {
                    Write-ColorOutput "Installation des dépendances avec pip pour $($mcp.Name)..."
                    Push-Location -Path $mcp.Path
                    & $pythonPath -m pip install -r $requirementsPath
                    Pop-Location
                    Write-ColorOutput "Dépendances Python pour $($mcp.Name) installées." "Green"
                } catch {
                    Write-ColorOutput "ERREUR lors de l'installation des dépendances Python pour $($mcp.Name)." "Red"
                    Write-ColorOutput $_.Exception.Message "Red"
                    Pop-Location
                }
            } else {
                Write-ColorOutput "AVERTISSEMENT: 'requirements.txt' trouvé mais aucun exécutable Python viable n'a été détecté. Installation manuelle requise." "Yellow"
            }
        }

        if (-not (Test-Path $installScriptPath) -and -not (Test-Path $requirementsPath)) {
            Write-ColorOutput "Aucun 'install.ps1' ou 'requirements.txt' trouvé. Veuillez consulter le README.md pour une installation manuelle." "Yellow"
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
    # CORRECTION SDDD v1.3: Ajout de timeout sur npx (2 minutes)
    $npxJob = Start-Job -ScriptBlock { npx -y @playwright/mcp --version }
    $npxJob | Wait-Job -Timeout 120 | Out-Null
    if ($npxJob.State -eq 'Completed') {
        $npxOutput = Receive-Job -Job $npxJob
        Write-ColorOutput "Cache pour @playwright/mcp préchauffé avec succès." "Green"
    } else {
        Write-ColorOutput "AVERTISSEMENT: Timeout lors du préchauffage du cache de Playwright (2min)." "Yellow"
    }
    Remove-Job -Job $npxJob -Force -ErrorAction SilentlyContinue
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
        # Utilisation de [hashtable] explicite
        [hashtable]$finalConfig = @{
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
            
            Write-ColorOutput "Ajout de l'entrée pour '$serverKey'..."

            # Logique spécifique pour roo-state-manager
            if ($serverKey -eq "roo-state-manager") {
                Write-ColorOutput "Application de la configuration spéciale pour 'roo-state-manager'..."
                $mcpCwd = $path.Replace("\", "/")
                $wrapperPath = ($mcpCwd + "/mcp-wrapper.cjs")
                $buildIndexPath = ($mcpCwd + "/build/index.js")

                # Utilisation de [hashtable] explicite
                [hashtable]$newEntry = @{
                    command       = "node"
                    args          = @($wrapperPath)
                    cwd           = $mcpCwd
                    transportType = "stdio"
                    disabled      = $false
                    autoStart     = $true
                    description   = "MCP Roo State Manager - Gestionnaire d'etat et de conversations. [RESTART]"
                    env           = @{}
                    alwaysAllow   = @(
                       "manage_mcp_settings",
                       "roosync_get_status", "roosync_list_diffs", "roosync_compare_config", "roosync_refresh_dashboard",
                       "roosync_config", "roosync_inventory", "roosync_baseline", "roosync_machines", "roosync_init",
                       "roosync_send", "roosync_read", "roosync_manage",
                       "roosync_decision", "roosync_decision_info",
                       "roosync_heartbeat_status",
                       "analyze_roosync_problems", "diagnose_env",
                       "roosync_summarize"
                    )
                    options       = @{ cwd = ($mcpCwd + "/") }
                    watchPaths    = @($buildIndexPath)
                    enabled       = $true
                    timeout       = 300
                }
            } else {
                # Logique générale pour les autres MCPs
                # Utilisation de [hashtable] explicite
                [hashtable]$newEntry = @{
                    command       = "node"
                    args          = @($mainFilePath)
                    transportType = "stdio"
                    disabled      = $false
                    autoStart     = $true
                    description   = if ($pkg.description) { $pkg.description } else { "Serveur MCP pour $name" }
                    autoApprove   = @()
                    alwaysAllow   = @()
                }
                if ($name -eq "github-projects-mcp") {
                   $newEntry["cwd"] = $path.Replace("\", "/")
                }
            }

            $finalConfig.mcpServers[$serverKey] = $newEntry
        }

        # Ajouter la configuration pour les MCPs externes courants
        Write-ColorOutput "Ajout de la configuration pour les MCPs externes..."
        
        # Utilisation de [hashtable] explicite
        [hashtable]$searxngConfig = @{
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
        $finalConfig.mcpServers['searxng'] = $searxngConfig

        # Utilisation de [hashtable] explicite
        [hashtable]$playwrightConfig = @{
            command = "cmd"
            args = @("/c", "npx", "-y", "@playwright/mcp", "--browser", "firefox")
            transportType = "stdio"
            disabled = $false
            autoStart = $true
            description = "MCP pour l'automatisation web avec Playwright"
            autoApprove = @()
            alwaysAllow = @("browser_navigate", "browser_click", "browser_take_screenshot", "browser_close", "browser_snapshot", "browser_install")
        }
        $finalConfig.mcpServers['playwright'] = $playwrightConfig

        # win-cli : fork local avec config debridee
        $winCliDistPath = ($rootDir.Path.Replace("\", "/") + "/mcps/external/win-cli/server/dist/index.js")
        $winCliConfigPath = ($rootDir.Path.Replace("\", "/") + "/mcps/external/win-cli/unrestricted-config.json")
        $winCliCwd = ($rootDir.Path.Replace("\", "/") + "/mcps/external/win-cli/server")

        if (Test-Path (Join-Path -Path $rootDir -ChildPath "mcps/external/win-cli/server/dist/index.js")) {
            Write-ColorOutput "Ajout de win-cli (fork local avec config debridee)..."
            [hashtable]$winCliConfig = @{
                command       = "node"
                args          = @($winCliDistPath, "--config", $winCliConfigPath)
                cwd           = $winCliCwd
                transportType = "stdio"
                disabled      = $false
                autoStart     = $true
                description   = "MCP for executing CLI commands on Windows (local fork, unrestricted)"
                autoApprove   = @()
                alwaysAllow   = @("execute_command", "get_command_history", "get_current_directory")
                options       = @{ cwd = ($winCliCwd + "/") }
            }
            $finalConfig.mcpServers['win-cli'] = $winCliConfig
        } else {
            Write-ColorOutput "AVERTISSEMENT: win-cli fork non build (dist/index.js absent). Lancer 'npm run build' dans mcps/external/win-cli/server/." "Yellow"
        }

        # Logique de détection robuste de Python
        $pythonPath = Find-ViablePythonExecutable
        
        if ($pythonPath) {
            Write-ColorOutput "Python trouve : $pythonPath" "Green"
            $pythonPathForward = $pythonPath.Replace("\", "/")
            [hashtable]$markitdownConfig = @{
                command       = "cmd"
                args          = @("/c", $pythonPathForward, "-m", "markitdown_mcp")
                transportType = "stdio"
                disabled      = $false
                autoStart     = $true
                description   = "Un MCP pour manipuler des fichiers Markdown."
                env           = @{}
                autoApprove   = @()
                alwaysAllow   = @("convert_to_markdown")
            }
            $finalConfig.mcpServers['markitdown'] = $markitdownConfig
        } else {
            Write-ColorOutput "AVERTISSEMENT: Python introuvable. Le MCP 'markitdown' sera desactive." "Yellow"
            [hashtable]$markitdownDisabledConfig = @{
                command       = "cmd"
                args          = @("/c", "echo", "Python not found, markitdown is disabled.")
                transportType = "stdio"
                disabled      = $true
                autoStart     = $true
                description   = "Un MCP pour manipuler des fichiers Markdown."
                env           = @{}
                autoApprove   = @()
                alwaysAllow   = @("convert_to_markdown")
            }
            $finalConfig.mcpServers['markitdown'] = $markitdownDisabledConfig
        }

        # jupyter : desactive par defaut (necessite conda + environnement mcp-jupyter)
        $jupyterCwd = ($rootDir.Path.Replace("\", "/") + "/mcps/internal/servers/jupyter-papermill-mcp-server")
        [hashtable]$jupyterConfig = @{
            command       = "conda"
            args          = @("run", "-n", "mcp-jupyter", "--no-capture-output", "python", "-m", "papermill_mcp.main")
            transportType = "stdio"
            disabled      = $true
            autoStart     = $true
            description   = "Serveur MCP Python/Papermill pour operations Jupyter Notebook (environnement Conda isole mcp-jupyter)"
            alwaysAllow   = @(
                "read_notebook", "write_notebook", "create_notebook", "add_cell", "remove_cell", "update_cell",
                "inspect_notebook", "manage_kernel", "execute_on_kernel", "execute_notebook",
                "list_notebook_files", "get_notebook_info", "get_kernel_status", "cleanup_all_kernels",
                "start_jupyter_server", "stop_jupyter_server", "manage_async_job", "list_kernels",
                "system_info", "start_notebook_async", "execute_notebook_sync", "read_cells"
            )
            options       = @{ cwd = $jupyterCwd }
        }
        $finalConfig.mcpServers['jupyter'] = $jupyterConfig

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
