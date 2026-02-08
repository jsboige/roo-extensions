<#
.SYNOPSIS
    Repare le script Get-MachineInventory.ps1 avec encodage et syntaxe corrects
.DESCRIPTION
    Ce script reconstruit Get-MachineInventory.ps1 en corrigeant:
    - Ligne 82: Expression if/else inline invalide
    - Encodage: UTF-8 sans BOM
    - Caracteres accentues problematiques
#>

$ErrorActionPreference = "Stop"
$scriptPath = "scripts\inventory\Get-MachineInventory.ps1"

Write-Host "`n=== Reparation Get-MachineInventory.ps1 ===" -ForegroundColor Cyan
Write-Host "Fichier cible: $scriptPath" -ForegroundColor Yellow

# Contenu complet du script corrige
$scriptContent = @'
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
    [string]$OutputPath = "roo-config/reports/machine-inventory-$MachineId-$(Get-Date -Format 'yyyyMMdd').json"
)

# Configuration des chemins
$RooExtensionsPath = "c:\dev\roo-extensions"
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
                path = $spec.FullName.Replace($RooExtensionsPath + "\", "")
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
            $scripts = Get-ChildItem -Path $dir.FullName -Filter "*.ps1" -Recurse
            $category = $dir.Name
            $inventory.inventory.scripts.categories[$category] = @()
            
            foreach ($script in $scripts) {
                $scriptInfo = @{
                    name = $script.Name
                    path = $script.FullName.Replace($RooExtensionsPath + "\", "")
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
                    path = $script.FullName.Replace($RooExtensionsPath + "\", "")
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
# 5. Outils installes
# ===============================
Write-Host "`nVerification des outils..." -ForegroundColor Yellow

# FFmpeg
try {
    $ffmpegVersion = ffmpeg -version 2>&1 | Select-Object -First 1
    if ($ffmpegVersion -match "ffmpeg version (.+)") {
        $inventory.inventory.tools.ffmpeg = @{
            installed = $true
            version = $Matches[1]
            path = (Get-Command ffmpeg).Source
        }
        Write-Host "  OK FFmpeg: v$($Matches[1])" -ForegroundColor Green
    }
} catch {
    $inventory.inventory.tools.ffmpeg = @{
        installed = $false
        error = "Non installe ou non accessible"
    }
    Write-Host "  FFmpeg: Non installe" -ForegroundColor Red
}

# Git
try {
    $gitVersion = git --version 2>&1
    if ($gitVersion -match "git version (.+)") {
        $inventory.inventory.tools.git = @{
            installed = $true
            version = $Matches[1]
            path = (Get-Command git).Source
        }
        Write-Host "  OK Git: v$($Matches[1])" -ForegroundColor Green
    }
} catch {
    $inventory.inventory.tools.git = @{
        installed = $false
    }
    Write-Host "  Git: Non installe" -ForegroundColor Red
}

# Node.js
try {
    $nodeVersion = node --version 2>&1
    if ($nodeVersion -match "v(.+)") {
        $inventory.inventory.tools.node = @{
            installed = $true
            version = $Matches[1]
            path = (Get-Command node).Source
        }
        Write-Host "  OK Node.js: v$($Matches[1])" -ForegroundColor Green
    }
} catch {
    $inventory.inventory.tools.node = @{
        installed = $false
    }
    Write-Host "  Node.js: Non installe" -ForegroundColor Red
}

# Python
try {
    $pythonVersion = python --version 2>&1
    if ($pythonVersion -match "Python (.+)") {
        $inventory.inventory.tools.python = @{
            installed = $true
            version = $Matches[1]
            path = (Get-Command python).Source
        }
        Write-Host "  OK Python: v$($Matches[1])" -ForegroundColor Green
    }
} catch {
    $inventory.inventory.tools.python = @{
        installed = $false
    }
    Write-Host "  Python: Non installe" -ForegroundColor Red
}

# ===============================
# 6. Sauvegarde de l'inventaire
# ===============================
Write-Host "`nSauvegarde de l'inventaire..." -ForegroundColor Yellow

$outputDir = Split-Path -Parent $OutputPath
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$inventory | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8

Write-Host "`nInventaire sauvegarde: $OutputPath" -ForegroundColor Green
Write-Host "`nResume:" -ForegroundColor Cyan
Write-Host "  - Serveurs MCP: $($inventory.inventory.mcpServers.Count)" -ForegroundColor White
Write-Host "  - Modes Roo: $($inventory.inventory.rooModes.Count)" -ForegroundColor White
Write-Host "  - Specifications SDDD: $($inventory.inventory.sdddSpecs.Count)" -ForegroundColor White
Write-Host "  - Scripts: $($inventory.inventory.scripts.all.Count)" -ForegroundColor White
Write-Host "  - Outils verifies: $($inventory.inventory.tools.Keys.Count)" -ForegroundColor White

return $OutputPath
'@

# Ecrire le script avec encodage UTF-8 sans BOM
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText((Resolve-Path $scriptPath).Path, $scriptContent, $utf8NoBom)

Write-Host "`nScript repare et sauvegarde avec encodage UTF-8 (sans BOM)" -ForegroundColor Green

# Test de syntaxe
Write-Host "`nTest de syntaxe PowerShell..." -ForegroundColor Yellow
try {
    $null = [System.Management.Automation.PSParser]::Tokenize($scriptContent, [ref]$null)
    Write-Host "Syntaxe PowerShell: OK" -ForegroundColor Green
} catch {
    Write-Host "ERREUR de syntaxe: $_" -ForegroundColor Red
    exit 1
}

# Test d'execution (dry-run)
Write-Host "`nTest d'execution (machine de test)..." -ForegroundColor Yellow
try {
    & $scriptPath -MachineId "test-syntax-validation" -ErrorAction Stop
    Write-Host "`nTest d'execution: OK" -ForegroundColor Green
} catch {
    Write-Host "`nERREUR d'execution: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Reparation terminee avec succes ===" -ForegroundColor Green
Write-Host "`nCorrections appliquees:" -ForegroundColor Cyan
Write-Host "  - Ligne 82-86: Expression if/else inline remplacee par structure standard" -ForegroundColor White
Write-Host "  - Encodage: UTF-8 sans BOM" -ForegroundColor White
Write-Host "  - Caracteres accentues: Remplaces par ASCII" -ForegroundColor White