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

param(
    [Parameter(Mandatory=$false)]
    [string]$MachineId = $env:COMPUTERNAME,

    [Parameter(Mandatory=$false)]
    [string]$OutputPath
)

# Définir OutputPath avec chemin absolu basé sur ROOSYNC_SHARED_PATH si non fourni
# CORRECTION SDDD : Utiliser ROOSYNC_SHARED_PATH depuis .env pour RooSync
if (-not $OutputPath) {
    $sharedStatePath = $env:ROOSYNC_SHARED_PATH
    if (-not $sharedStatePath) {
        Write-Error "ERREUR CRITIQUE: ROOSYNC_SHARED_PATH n'est pas définie. Veuillez configurer cette variable d'environnement dans le fichier .env."
        exit 1
    }
    $inventoriesDir = Join-Path $sharedStatePath "inventories"
    if (-not (Test-Path $inventoriesDir)) {
        New-Item -ItemType Directory -Path $inventoriesDir -Force | Out-Null
    }
    $OutputPath = Join-Path $inventoriesDir "machine-inventory-$MachineId.json"
}

# Configuration des chemins
$RooExtensionsPath = Resolve-Path (Join-Path $PSScriptRoot "..\..")
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
# 3. Specifications SDDD
# ===============================
Write-Host "`nCollecte des specifications SDDD..." -ForegroundColor Yellow
try {
    $specsPath = "$RooConfigPath\specifications"
    if (Test-Path $specsPath) {
        $specs = Get-ChildItem -Path $specsPath -Filter "*.md" | Where-Object { $_.Name -ne "README.md" }
        foreach ($spec in $specs) {
            $specInfo = @{
                name = $spec.Name
                path = $spec.FullName.Replace("$RooExtensionsPath\", "")
                size = $spec.Length
                lastModified = $spec.LastWriteTime.ToString("yyyy-MM-dd")
            }
            $inventory.inventory.sdddSpecs += $specInfo
            Write-Host "  OK $($spec.Name)" -ForegroundColor Green
        }
    } else {
        Write-Host "  Repertoire specifications non trouve" -ForegroundColor Yellow
        $inventory.inventory.sdddSpecs += @{ status = "absent" }
    }
} catch {
    Write-Host "  Erreur lors de la lecture des specs: $_" -ForegroundColor Red
    $inventory.inventory.sdddSpecs += @{ status = "error"; error = $_.Exception.Message }
}

# ===============================
# 4. Scripts disponibles
# ===============================
Write-Host "`nInventaire des scripts..." -ForegroundColor Yellow
try {
    if (Test-Path $ScriptsPath) {
        $scriptDirs = Get-ChildItem -Path $ScriptsPath -Directory
        foreach ($dir in $scriptDirs) {
            $scripts = Get-ChildItem -Path $dir.FullName -Filter "*.ps1" -Recurse -Depth 3
            $category = $dir.Name
            $inventory.inventory.scripts.categories[$category] = @()

            foreach ($script in $scripts) {
                $scriptInfo = @{
                    name = $script.Name
                    path = $script.FullName.Replace("$RooExtensionsPath\", "")
                    category = $category
                }
                $inventory.inventory.scripts.categories[$category] += $scriptInfo
                $inventory.inventory.scripts.all += $scriptInfo
                Write-Host "  OK [$category] $($script.Name)" -ForegroundColor Green
            }
        }

        $rootScripts = Get-ChildItem -Path $ScriptsPath -Filter "*.ps1"
        if ($rootScripts.Count -gt 0) {
            $inventory.inventory.scripts.categories["root"] = @()
            foreach ($script in $rootScripts) {
                $scriptInfo = @{
                    name = $script.Name
                    path = $script.FullName.Replace("$RooExtensionsPath\", "")
                    category = "root"
                }
                $inventory.inventory.scripts.categories["root"] += $scriptInfo
                $inventory.inventory.scripts.all += $scriptInfo
                Write-Host "  OK [root] $($script.Name)" -ForegroundColor Green
            }
        }
    } else {
        Write-Host "  Repertoire scripts non trouve" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  Erreur lors de l'inventaire des scripts: $_" -ForegroundColor Red
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
    
    # Node version (vérification rapide sans blocage)
    try {
        $nodeVersion = pwsh -c "node --version 2>$null" 2>$null
        if ($nodeVersion) {
            $inventory.inventory.tools.node = @{
                version = $nodeVersion.Trim()
            }
            Write-Host "  OK Node $nodeVersion" -ForegroundColor Green
        } else {
            Write-Host "  Node non trouvé" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  Node non disponible" -ForegroundColor Yellow
    }
    
    # Python version (vérification rapide sans blocage)
    try {
        $pythonVersion = pwsh -c "python --version 2>&1" 2>$null
        if ($pythonVersion) {
            $inventory.inventory.tools.python = @{
                version = $pythonVersion.Trim()
            }
            Write-Host "  OK Python $pythonVersion" -ForegroundColor Green
        } else {
            Write-Host "  Python non trouvé" -ForegroundColor Yellow
        }
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
# 6. Sauvegarde de l'inventaire
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
    # -Depth 5 est suffisant pour la structure de l'inventaire
    # -Compress réduit la taille du fichier et accélère l'écriture
    $inventory | ConvertTo-Json -Depth 5 -Compress | Set-Content -Path $OutputPath -Encoding UTF8
    
    $stopwatch.Stop()
    Write-Host "  Sérialisation terminée en $($stopwatch.ElapsedMilliseconds)ms" -ForegroundColor Green

    Write-Host "`nInventaire sauvegarde: $OutputPath" -ForegroundColor Green
    Write-Host "`nResume:" -ForegroundColor Cyan
    Write-Host "  - Serveurs MCP: $($inventory.inventory.mcpServers.Count)" -ForegroundColor White
    Write-Host "  - Modes Roo: $($inventory.inventory.rooModes.Count)" -ForegroundColor White
    Write-Host "  - Specifications SDDD: $($inventory.inventory.sdddSpecs.Count)" -ForegroundColor White
    Write-Host "  - Scripts: $($inventory.inventory.scripts.all.Count)" -ForegroundColor White
    Write-Host "  - Outils verifies: $($inventory.inventory.tools.Keys.Count)" -ForegroundColor White

    return $OutputPath
} catch {
    $stopwatch.Stop()
    Write-Host "`nERREUR lors de la sauvegarde: $_" -ForegroundColor Red
    Write-Host "Chemin cible: $OutputPath" -ForegroundColor Yellow
    Write-Host "Temps écoulé avant erreur: $($stopwatch.ElapsedMilliseconds)ms" -ForegroundColor Yellow
    Write-Host "Vérifiez que le chemin est accessible et que vous avez les droits d'écriture." -ForegroundColor Yellow
    exit 1
}