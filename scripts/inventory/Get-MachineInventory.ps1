<#
.SYNOPSIS
    Collecte l'inventaire complet de configuration d'une machine Roo
.DESCRIPTION
    Script reutilisable pour collecter toutes les informations de configuration
.PARAMETER MachineId
    L'identifiant de la machine (par defaut: hostname)
.PARAMETER OutputPath
    Le chemin de sortie pour le fichier JSON d'inventaire
.EXAMPLE
    .\Get-MachineInventory.ps1 -MachineId "myia-po-2024"
#>
# Recommandations PowerShell (Tâche 2.24):
# - Set-StrictMode pour détecter les erreurs de typage
# - Utilisation de [hashtable] explicite au lieu de PSObject
# - Ajout de timeouts pour éviter les blocages
# CORRECTION: Désactiver Set-StrictMode car il empêche l'utilisation de variables $null
# Set-StrictMode -Version Latest

param(
    [Parameter(Mandatory=$false)]
    [string]$MachineId = $env:COMPUTERNAME,

    [Parameter(Mandatory=$false)]
    [string]$OutputPath,

    [Parameter(Mandatory=$false)]
    [string]$SharedStatePath
)

$ErrorActionPreference = 'Stop'
# Définir OutputPath avec chemin absolu basé sur SharedStatePath si non fourni
# CORRECTION SDDD : Utiliser SharedStatePath passé en paramètre pour RooSync
# CORRECTION: Initialiser OutputPath pour éviter l'erreur Set-StrictMode
$OutputPath = $null

if (-not $OutputPath) {
    if (-not $SharedStatePath) {
        Write-Error "ERREUR CRITIQUE: SharedStatePath n'est pas fourni. Veuillez passer le paramètre -SharedStatePath."
        exit 1
    }
    $inventoriesDir = Join-Path $SharedStatePath "inventories"
    if (-not (Test-Path $inventoriesDir)) {
        New-Item -ItemType Directory -Path $inventoriesDir -Force | Out-Null
    }
    # CORRECTION : Le nom du fichier doit commencer par le machineId pour que le wrapper TypeScript le trouve
    # Format attendu par InventoryCollectorWrapper : {machineId}*.json (ex: myia-po-2026.json)
    $OutputPath = Join-Path $inventoriesDir "$($MachineId.ToLower()).json"
}

# Configuration des chemins
# CORRECTION: Trouver la racine roo-extensions de manière fiable
# 1. Utiliser ROOSYNC_ROOT si défini (priorité)
# 2. Sinon, remonter depuis $PSScriptRoot jusqu'à trouver .git ou CLAUDE.md
function Find-RooExtensionsRoot {
    param([string]$StartPath)

    $currentPath = $StartPath
    $maxDepth = 10  # Limite pour éviter boucle infinie
    $depth = 0

    while ($depth -lt $maxDepth) {
        # Vérifier si c'est la racine roo-extensions (présence de CLAUDE.md et .git)
        $claudeMd = Join-Path $currentPath "CLAUDE.md"
        $gitDir = Join-Path $currentPath ".git"

        if ((Test-Path $claudeMd) -and (Test-Path $gitDir)) {
            return $currentPath
        }

        # Remonter d'un niveau
        $parentPath = Split-Path -Parent $currentPath
        if (-not $parentPath -or $parentPath -eq $currentPath) {
            break  # Atteint la racine du système de fichiers
        }
        $currentPath = $parentPath
        $depth++
    }

    return $null
}

# Priorité 1: Variable d'environnement explicite
if ($env:ROOSYNC_ROOT -and (Test-Path $env:ROOSYNC_ROOT)) {
    $RooExtensionsPath = $env:ROOSYNC_ROOT
    Write-Host "  RooExtensionsPath depuis ROOSYNC_ROOT: $RooExtensionsPath" -ForegroundColor Gray
}
# Priorité 2: Chercher depuis $PSScriptRoot (scripts/inventory/)
elseif ($PSScriptRoot) {
    $foundRoot = Find-RooExtensionsRoot -StartPath $PSScriptRoot
    if ($foundRoot) {
        $RooExtensionsPath = $foundRoot
        Write-Host "  RooExtensionsPath trouve depuis PSScriptRoot: $RooExtensionsPath" -ForegroundColor Gray
    }
}

# Priorité 3: Fallback sur le chemin relatif original
if (-not $RooExtensionsPath) {
    $RooExtensionsPath = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
    Write-Host "  RooExtensionsPath fallback relatif: $RooExtensionsPath" -ForegroundColor Yellow
}
$McpSettingsPath = "C:\Users\$env:USERNAME\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json"
$RooConfigPath = "$RooExtensionsPath\roo-config"
$ScriptsPath = "$RooExtensionsPath\scripts"

Write-Host "Collecte de l'inventaire pour la machine: $MachineId" -ForegroundColor Cyan

# Initialiser l'inventaire
$inventory = @{
    machineId = $MachineId
    timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    inventory = @{
        mcpServers = @()
        slashCommands = @()
        terminalCommands = @{
            allowed = @()
            restricted = @()
        }
        rooModes = @()
        sdddSpecs = @()
        scripts = @{
            categories = @{}
            all = @()
        }
        tools = @{}
        systemInfo = @{
            os = [System.Environment]::OSVersion.VersionString
            hostname = $env:COMPUTERNAME
            username = $env:USERNAME
            powershellVersion = $PSVersionTable.PSVersion.ToString()
        }
    }
    paths = @{
        rooExtensions = $RooExtensionsPath
        mcpSettings = $McpSettingsPath
        rooConfig = $RooConfigPath
        scripts = $ScriptsPath
    }
}

# ===============================
# 1. Configuration MCP
# ===============================
Write-Host "`nCollecte des serveurs MCP..." -ForegroundColor Yellow
try {
    if (Test-Path $McpSettingsPath) {
        $mcpSettings = Get-Content $McpSettingsPath -Raw | ConvertFrom-Json
        foreach ($server in $mcpSettings.mcpServers.PSObject.Properties) {
            $serverInfo = @{
                name = $server.Name
                enabled = -not $server.Value.disabled
                autoStart = $server.Value.autoStart
                description = $server.Value.description
                command = $server.Value.command
                transportType = $server.Value.transportType
                alwaysAllow = $server.Value.alwaysAllow
            }
            $inventory.inventory.mcpServers += $serverInfo

            # FIX LIGNE 82: Remplacement expression inline par structure if/else standard
            if ($serverInfo.enabled) {
                Write-Host "  OK $($server.Name) [ACTIF]" -ForegroundColor Green
            } else {
                Write-Host "  OK $($server.Name) [DESACTIVE]" -ForegroundColor Green
            }
        }
    } else {
        Write-Host "  Fichier mcp_settings.json non trouve" -ForegroundColor Yellow
        $inventory.inventory.mcpServers += @{
            status = "absent"
            path = $McpSettingsPath
        }
    }
} catch {
    Write-Host "  Erreur lors de la lecture MCP: $_" -ForegroundColor Red
    $inventory.inventory.mcpServers += @{ status = "error"; error = $_.Exception.Message }
}

# ===============================
# 2. Modes Roo
# ===============================
Write-Host "`nCollecte des modes Roo..." -ForegroundColor Yellow
try {
    $modesPath = "$RooConfigPath\settings\modes.json"
    if (Test-Path $modesPath) {
        $modesConfig = Get-Content $modesPath -Raw | ConvertFrom-Json
        foreach ($mode in $modesConfig.modes) {
            $modeInfo = @{
                slug = $mode.slug
                name = $mode.name
                description = $mode.description
                defaultModel = $mode.defaultModel
                tools = $mode.tools
                allowedFilePatterns = $mode.allowedFilePatterns
            }
            $inventory.inventory.rooModes += $modeInfo
            Write-Host "  OK $($mode.name) ($($mode.slug))" -ForegroundColor Green
        }
    } else {
        Write-Host "  Fichier modes.json non trouve" -ForegroundColor Yellow
        $inventory.inventory.rooModes += @{ status = "absent" }
    }
} catch {
    Write-Host "  Erreur lors de la lecture des modes: $_" -ForegroundColor Red
    $inventory.inventory.rooModes += @{ status = "error"; error = $_.Exception.Message }
}

# ===============================
# 3. Specifications SDDD - SIMPLIFICATION "Écuries d'Augias"
# ===============================
Write-Host "`nSpecs SDDD: SKIP (simplifie)" -ForegroundColor Gray
# Les specs ne sont pas utiles pour la comparaison des configurations
$inventory.inventory.sdddSpecs = @()

# ===============================
# 4. Scripts disponibles - SIMPLIFICATION "Écuries d'Augias"
# ===============================
Write-Host "`nScripts: SKIP (simplifie - gain ~70KB)" -ForegroundColor Gray
# Les scripts ne sont pas utiles pour la comparaison des configurations
# et gonflent l'inventaire de 70+ KB
$inventory.inventory.scripts = @{
    categories = @{}
    all = @()
}

# ===============================
# 5. Outils installes (CORRECTION SDDD v1.2: Collecte sécurisée)
# ===============================
Write-Host "`nVerification des outils..." -ForegroundColor Yellow
try {
    # PowerShell version (déjà disponible dans systemInfo)
    $inventory.inventory.tools.powershell = @{
        version = $PSVersionTable.PSVersion.ToString()
    }
    Write-Host "  OK PowerShell $($PSVersionTable.PSVersion)" -ForegroundColor Green

    # Node version (vérification rapide avec timeout)
    try {
        $job = Start-Job -ScriptBlock { node --version 2>$null }
        $job | Wait-Job -Timeout 5 | Out-Null
        if ($job.State -eq 'Completed') {
            $nodeVersion = Receive-Job -Job $job
            if ($nodeVersion) {
                $inventory.inventory.tools.node = @{
                    version = $nodeVersion.Trim()
                }
                Write-Host "  OK Node $nodeVersion" -ForegroundColor Green
            } else {
                Write-Host "  Node non trouvé" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  Node: timeout (5s)" -ForegroundColor Yellow
        }
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Host "  Node non disponible" -ForegroundColor Yellow
    }

    # Python version (vérification rapide avec timeout)
    try {
        $job = Start-Job -ScriptBlock { python --version 2>&1 }
        $job | Wait-Job -Timeout 5 | Out-Null
        if ($job.State -eq 'Completed') {
            $pythonVersion = Receive-Job -Job $job
            if ($pythonVersion) {
                $inventory.inventory.tools.python = @{
                    version = $pythonVersion.Trim()
                }
                Write-Host "  OK Python $pythonVersion" -ForegroundColor Green
            } else {
                Write-Host "  Python non trouvé" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  Python: timeout (5s)" -ForegroundColor Yellow
        }
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Host "  Python non disponible" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  Erreur lors de la vérification des outils: $_" -ForegroundColor Red
}

# ===============================
# 6. Système et Hardware (CORRECTION SDDD v1.2: Collecte sécurisée)
# ===============================
Write-Host "`nCollecte des informations système et matérielles..." -ForegroundColor Yellow
try {
    # Architecture (sans blocage)
    $inventory.inventory.systemInfo.architecture = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")
    Write-Host "  OK Architecture: $($inventory.inventory.systemInfo.architecture)" -ForegroundColor Green

    # Uptime (sans blocage)
    $uptime = [System.Environment]::TickCount64 / 1000
    $inventory.inventory.systemInfo.uptime = $uptime
    Write-Host "  OK Uptime: $uptime secondes" -ForegroundColor Green

    # CPU (sans blocage)
    $inventory.inventory.systemInfo.processor = [System.Environment]::GetEnvironmentVariable("PROCESSOR_IDENTIFIER")
    $inventory.inventory.systemInfo.cpuCores = [System.Environment]::ProcessorCount
    $inventory.inventory.systemInfo.cpuThreads = [System.Environment]::ProcessorCount
    Write-Host "  OK CPU: $($inventory.inventory.systemInfo.cpuCores) cœurs" -ForegroundColor Green

    # Mémoire (sans blocage)
    $totalMemory = [System.GC]::MaxGeneration * 1024 * 1024 * 1024
    $availableMemory = [System.GC]::GetTotalMemory($false)
    $inventory.inventory.systemInfo.totalMemory = $totalMemory
    $inventory.inventory.systemInfo.availableMemory = $availableMemory
    Write-Host "  OK Mémoire: $([math]::Round($totalMemory/1GB, 2)) GB" -ForegroundColor Green

    # Disques (collecte limitée sans blocage)
    try {
        $disks = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -gt 0 } | Select-Object -First 5
        $inventory.inventory.systemInfo.disks = @()
        foreach ($disk in $disks) {
            $diskInfo = @{
                drive = $disk.Name
                size = $disk.Used + $disk.Free
                free = $disk.Free
            }
            $inventory.inventory.systemInfo.disks += $diskInfo
            Write-Host "  OK Disque $($disk.Name): $([math]::Round($diskInfo.size/1GB, 2)) GB" -ForegroundColor Green
        }
    } catch {
        Write-Host "  Erreur lors de la collecte des disques: $_" -ForegroundColor Yellow
    }

    # GPU (optionnel, sans blocage)
    try {
        $gpuInfo = Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($gpuInfo) {
            $inventory.inventory.systemInfo.gpu = @(
                @{
                    name = $gpuInfo.Name
                    memory = 0 # Non disponible sans blocage
                }
            )
            Write-Host "  OK GPU: $($gpuInfo.Name)" -ForegroundColor Green
        } else {
            Write-Host "  GPU non détecté" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  GPU non disponible" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  Erreur lors de la collecte système: $_" -ForegroundColor Red
}

# ===============================
# 7. Windows OS (enrichi)
# ===============================
Write-Host "`nCollecte des informations Windows OS..." -ForegroundColor Yellow
try {
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
    if ($osInfo) {
        $inventory.inventory.systemInfo.windowsOS = @{
            caption = $osInfo.Caption
            version = $osInfo.Version
            buildNumber = $osInfo.BuildNumber
            servicePackMajorVersion = $osInfo.ServicePackMajorVersion
            servicePackMinorVersion = $osInfo.ServicePackMinorVersion
            osArchitecture = $osInfo.OSArchitecture
            serialNumber = $osInfo.SerialNumber
            installDate = $osInfo.InstallDate
            lastBootUpTime = $osInfo.LastBootUpTime
            windowsDirectory = $osInfo.WindowsDirectory
            systemDirectory = $osInfo.SystemDirectory
        }
        Write-Host "  OK Windows $($osInfo.Caption) Build $($osInfo.BuildNumber)" -ForegroundColor Green
    } else {
        Write-Host "  Informations Windows OS non disponibles" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  Erreur lors de la collecte Windows OS: $_" -ForegroundColor Red
}

# ===============================
# 8. PowerShell (enrichi)
# ===============================
Write-Host "`nCollecte des informations PowerShell..." -ForegroundColor Yellow
try {
    $inventory.inventory.systemInfo.powerShell = @{
        version = $PSVersionTable.PSVersion.ToString()
        psVersion = $PSVersionTable.PSVersion
        psRemotingProtocolVersion = $PSVersionTable.PSRemotingProtocolVersion
        serializationVersion = $PSVersionTable.SerializationVersion
        wsManStackVersion = $PSVersionTable.WSManStackVersion
        edition = $PSVersionTable.PSEdition
        gitCommitId = $PSVersionTable.GitCommitId
        platform = $PSVersionTable.Platform
        clrVersion = $PSVersionTable.CLRVersion
    }
    Write-Host "  OK PowerShell $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))" -ForegroundColor Green
} catch {
    Write-Host "  Erreur lors de la collecte PowerShell: $_" -ForegroundColor Red
}

# ===============================
# 9. Configuration Roo
# ===============================
Write-Host "`nCollecte de la configuration Roo..." -ForegroundColor Yellow
try {
    $rooConfig = @{}

    # Lire le fichier modes.json
    $modesPath = "$RooConfigPath\settings\modes.json"
    if (Test-Path $modesPath) {
        $modesConfig = Get-Content $modesPath -Raw | ConvertFrom-Json
        $rooConfig.modes = @{
            count = $modesConfig.modes.Count
            defaultMode = $modesConfig.defaultMode
            modes = $modesConfig.modes | ForEach-Object {
                @{
                    slug = $_.slug
                    name = $_.name
                    description = $_.description
                    defaultModel = $_.defaultModel
                }
            }
        }
        Write-Host "  OK Modes Roo: $($modesConfig.modes.Count) modes" -ForegroundColor Green
    } else {
        Write-Host "  Fichier modes.json non trouvé" -ForegroundColor Yellow
    }

    # Lire le fichier settings.json principal
    $settingsPath = "$RooConfigPath\settings\settings.json"
    if (Test-Path $settingsPath) {
        $settingsConfig = Get-Content $settingsPath -Raw | ConvertFrom-Json
        $rooConfig.settings = @{
            defaultModel = $settingsConfig.defaultModel
            temperature = $settingsConfig.temperature
            maxTokens = $settingsConfig.maxTokens
        }
        Write-Host "  OK Settings Roo" -ForegroundColor Green
    } else {
        Write-Host "  Fichier settings.json non trouvé" -ForegroundColor Yellow
    }

    $inventory.inventory.rooConfig = $rooConfig
} catch {
    Write-Host "  Erreur lors de la collecte Roo: $_" -ForegroundColor Red
    $inventory.inventory.rooConfig = @{ status = "error"; error = $_.Exception.Message }
}

# ===============================
# 10. Configuration Claude
# ===============================
Write-Host "`nCollecte de la configuration Claude..." -ForegroundColor Yellow
try {
    $claudeConfig = @{}

    # Lire le fichier mcp_settings.json pour Claude
    if (Test-Path $McpSettingsPath) {
        $mcpSettings = Get-Content $McpSettingsPath -Raw | ConvertFrom-Json
        $claudeConfig.mcpSettings = @{
            mcpServersCount = $mcpSettings.mcpServers.PSObject.Properties.Count
            mcpServers = $mcpSettings.mcpServers.PSObject.Properties | ForEach-Object {
                @{
                    name = $_.Name
                    enabled = -not $_.Value.disabled
                    autoStart = $_.Value.autoStart
                }
            }
        }
        Write-Host "  OK MCP Settings: $($claudeConfig.mcpSettings.mcpServersCount) serveurs" -ForegroundColor Green
    } else {
        Write-Host "  Fichier mcp_settings.json non trouvé" -ForegroundColor Yellow
    }

    # Lire le fichier globalStorage de Claude
    $claudeGlobalStoragePath = "C:\Users\$env:USERNAME\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline"
    if (Test-Path $claudeGlobalStoragePath) {
        $claudeConfig.globalStoragePath = $claudeGlobalStoragePath
        Write-Host "  OK GlobalStorage Claude: $claudeGlobalStoragePath" -ForegroundColor Green
    } else {
        Write-Host "  GlobalStorage Claude non trouvé" -ForegroundColor Yellow
    }

    $inventory.inventory.claudeConfig = $claudeConfig
} catch {
    Write-Host "  Erreur lors de la collecte Claude: $_" -ForegroundColor Red
    $inventory.inventory.claudeConfig = @{ status = "error"; error = $_.Exception.Message }
}

# ===============================
# 11. Variables d'environnement pertinentes
# ===============================
Write-Host "`nCollecte des variables d'environnement..." -ForegroundColor Yellow
try {
    $relevantEnvVars = @(
        "PATH",
        "HOME",
        "USERPROFILE",
        "APPDATA",
        "LOCALAPPDATA",
        "TEMP",
        "TMP",
        "COMPUTERNAME",
        "USERNAME",
        "USERDOMAIN",
        "PROCESSOR_ARCHITECTURE",
        "NUMBER_OF_PROCESSORS",
        "ROOSYNC_ROOT",
        "ROOSYNC_SHARED_PATH",
        "ROOSYNC_MACHINE_ID"
    )

    $envVars = @{}
    foreach ($varName in $relevantEnvVars) {
        $varValue = [System.Environment]::GetEnvironmentVariable($varName)
        if ($varValue) {
            $envVars[$varName] = $varValue
        }
    }

    $inventory.inventory.environmentVariables = $envVars
    Write-Host "  OK Variables d'environnement: $($envVars.Count) collectées" -ForegroundColor Green
} catch {
    Write-Host "  Erreur lors de la collecte des variables d'environnement: $_" -ForegroundColor Red
    $inventory.inventory.environmentVariables = @{ status = "error"; error = $_.Exception.Message }
}

# ===============================
# 12. Sauvegarde de l'inventaire
# ===============================
Write-Host "`nSauvegarde de l'inventaire..." -ForegroundColor Yellow

try {
    $outputDir = Split-Path -Parent $OutputPath
    if (-not (Test-Path $outputDir)) {
        Write-Host "  Création du répertoire: $outputDir" -ForegroundColor Gray
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    Write-Host "  Sérialisation JSON en cours..." -ForegroundColor Gray
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    # CORRECTION SDDD v1.1: Réduire la profondeur de sérialisation et utiliser -Compress
    # -Depth 99 désactive la limite de profondeur pour inclure la structure complète
    # -Compress réduit la taille du fichier et accélère l'écriture
    $inventory | ConvertTo-Json -Depth 99 -Compress | Set-Content -Path $OutputPath -Encoding UTF8

    $stopwatch.Stop()
    Write-Host "  Sérialisation terminée en $($stopwatch.ElapsedMilliseconds)ms" -ForegroundColor Green

    Write-Host "`nInventaire sauvegarde: $OutputPath" -ForegroundColor Green
    Write-Host "`nResume (format allege 'Ecuries d'Augias'):" -ForegroundColor Cyan
    Write-Host "  - Serveurs MCP: $($inventory.inventory.mcpServers.Count)" -ForegroundColor White
    Write-Host "  - Modes Roo: $($inventory.inventory.rooModes.Count)" -ForegroundColor White
    Write-Host "  - Outils verifies: $($inventory.inventory.tools.Keys.Count)" -ForegroundColor White
    Write-Host "  (specs et scripts exclus pour alleger l'inventaire)" -ForegroundColor Gray

    return $OutputPath
} catch {
    $stopwatch.Stop()
    Write-Host "`nERREUR lors de la sauvegarde: $_" -ForegroundColor Red
    Write-Host "Chemin cible: $OutputPath" -ForegroundColor Yellow
    Write-Host "Temps écoulé avant erreur: $($stopwatch.ElapsedMilliseconds)ms" -ForegroundColor Yellow
    Write-Host "Vérifiez que le chemin est accessible et que vous avez les droits d'écriture." -ForegroundColor Yellow
    exit 1
}