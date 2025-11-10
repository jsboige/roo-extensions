#requires -Version 5.1
<#
.SYNOPSIS
    Script PowerShell autonome pour exporter une baseline RooSync vers différents formats

.DESCRIPTION
    Ce script permet d'exporter une baseline vers les formats suivants:
    - JSON (format natif avec métadonnées complètes)
    - YAML (format lisible par l'homme)
    - CSV (format tabulaire pour analyse dans Excel)
    
    Il fait partie des scripts autonomes de la Phase 3B du projet SDDD.

.PARAMETER Format
    Format d'exportation: json, yaml, csv

.PARAMETER OutputPath
    Chemin de sortie pour le fichier exporté (optionnel)

.PARAMETER MachineId
    ID de la machine à exporter (optionnel, utilise la baseline actuelle si non spécifié)

.PARAMETER IncludeHistory
    Inclure l'historique des modifications (défaut: false)

.PARAMETER IncludeMetadata
    Inclure les métadonnées complètes (défaut: true)

.PARAMETER PrettyPrint
    Formater la sortie pour une meilleure lisibilité (défaut: true)

.PARAMETER DryRun
    Mode simulation sans exécution réelle (défaut: false)

.EXAMPLE
    .\roosync_export_baseline.ps1 -Format json -OutputPath "./baseline-export.json"
    
    .\roosync_export_baseline.ps1 -Format csv -IncludeMetadata $true -PrettyPrint $false
    
    .\roosync_export_baseline.ps1 -Format yaml -MachineId "myia-web-01" -DryRun $true

.NOTES
    - Ce script doit être exécuté depuis la racine du projet roo-extensions
    - Les exports sont créés dans le répertoire "exports/" par défaut
    - Le format CSV est idéal pour l'analyse dans des tableurs
    - Le format YAML est idéal pour la documentation et le versioning

.LINK
    https://github.com/rooveterinaryinc/roo-extensions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0, HelpMessage="Format d'exportation (json, yaml, csv)")]
    [ValidateSet("json", "yaml", "csv")]
    [string]$Format,
    
    [Parameter(HelpMessage="Chemin de sortie pour le fichier exporté (optionnel)")]
    [string]$OutputPath = "",
    
    [Parameter(HelpMessage="ID de la machine à exporter (optionnel, utilise la baseline actuelle si non spécifié)")]
    [string]$MachineId = "",
    
    [Parameter(HelpMessage="Inclure l'historique des modifications (défaut: false)")]
    [bool]$IncludeHistory = $false,
    
    [Parameter(HelpMessage="Inclure les métadonnées complètes (défaut: true)")]
    [bool]$IncludeMetadata = $true,
    
    [Parameter(HelpMessage="Formater la sortie pour une meilleure lisibilité (défaut: true)")]
    [bool]$PrettyPrint = $true,
    
    [Parameter(HelpMessage="Mode simulation sans exécution réelle (défaut: false)")]
    [bool]$DryRun = $false
)

# Configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"

# Fonctions utilitaires
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Color = "White"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARN"  { Write-Host $logMessage -ForegroundColor Yellow }
        "INFO"  { Write-Host $logMessage -ForegroundColor $Color }
        "DEBUG" { Write-Host $logMessage -ForegroundColor Gray }
        default { Write-Host $logMessage -ForegroundColor $Color }
    }
}

function Test-Prerequisites {
    Write-Log "Vérification des prérequis..." -Level "INFO"
    
    # Vérifier si le fichier baseline existe
    $baselinePath = ".shared-state/sync-config.ref.json"
    if (-not (Test-Path $baselinePath)) {
        throw "Aucune baseline trouvée à $baselinePath"
    }
    
    Write-Log "Prérequis validés avec succès" -Level "INFO"
}

function Get-BaselineData {
    param([string]$TargetMachineId)
    
    Write-Log "Récupération des données de baseline..." -Level "INFO"
    
    try {
        $baselinePath = ".shared-state/sync-config.ref.json"
        $baselineContent = Get-Content $baselinePath -Raw | ConvertFrom-Json
        
        if ($TargetMachineId -and $baselineContent.machineId -ne $TargetMachineId) {
            Write-Log "Machine cible spécifiée ($TargetMachineId) différente de la baseline actuelle ($($baselineContent.machineId))" -Level "WARN"
            Write-Log "Utilisation de la baseline actuelle quand même" -Level "INFO"
        }
        
        Write-Log "Baseline trouvée: $($baselineContent.machineId) v$($baselineContent.version)" -Level "INFO"
        return $baselineContent
    }
    catch {
        Write-Log "Erreur lors de la lecture de la baseline: $($_.Exception.Message)" -Level "ERROR"
        throw "Erreur lors de la lecture de la baseline: $($_.Exception.Message)"
    }
}

function Export-JsonFormat {
    param(
        [object]$BaselineData,
        [object]$ExportData,
        [bool]$PrettyPrint
    )
    
    Write-Log "Génération de l'export JSON..." -Level "INFO"
    
    if ($PrettyPrint) {
        return $ExportData | ConvertTo-Json -Depth 10
    } else {
        return $ExportData | ConvertTo-Json -Compress
    }
}

function Export-YamlFormat {
    param(
        [object]$BaselineData,
        [object]$ExportData
    )
    
    Write-Log "Génération de l'export YAML..." -Level "INFO"
    
    # Conversion simple vers YAML
    $yamlLines = @()
    $yamlLines += "# Export Baseline RooSync"
    $yamlLines += "# Généré le: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $yamlLines += ""
    
    if ($IncludeMetadata) {
        $yamlLines += "metadata:"
        $yamlLines += "  machineId: $($BaselineData.machineId)"
        $yamlLines += "  version: $($BaselineData.version)"
        $yamlLines += "  lastUpdated: $($BaselineData.lastUpdated)"
        $yamlLines += ""
    }
    
    $yamlLines += "configuration:"
    $config = $BaselineData.config
    $yamlLines += "  roo:"
    $yamlLines += "    modes: $($config.roo.modes -join ', ')"
    $yamlLines += "    mcpSettings: $($config.roo.mcpSettings | ConvertTo-Json -Compress)"
    $yamlLines += "    userSettings: $($config.roo.userSettings | ConvertTo-Json -Compress)"
    $yamlLines += "  hardware:"
    $yamlLines += "    cpu: $($config.hardware.cpu)"
    $yamlLines += "    ram: $($config.hardware.ram)"
    $yamlLines += "    disks: $($config.hardware.disks | ConvertTo-Json -Compress)"
    if ($config.hardware.gpu) {
        $yamlLines += "    gpu: $($config.hardware.gpu)"
    }
    $yamlLines += "  software:"
    $yamlLines += "    powershell: $($config.software.powershell)"
    $yamlLines += "    node: $($config.software.node)"
    $yamlLines += "    python: $($config.software.python)"
    $yamlLines += "  system:"
    $yamlLines += "    os: $($config.system.os)"
    $yamlLines += "    architecture: $($config.system.architecture)"
    
    return $yamlLines -join "`n"
}

function Export-CsvFormat {
    param(
        [object]$BaselineData,
        [object]$ExportData
    )
    
    Write-Log "Génération de l'export CSV..." -Level "INFO"
    
    $csvLines = @()
    $csvLines += "Type,Catégorie,Paramètre,Valeur,Description"
    
    # Métadonnées
    if ($IncludeMetadata) {
        $csvLines += "Metadata,machineId,machineId,$($BaselineData.machineId),Identifiant unique de la machine"
        $csvLines += "Metadata,version,version,$($BaselineData.version),Version de la baseline"
        $csvLines += "Metadata,lastUpdated,lastUpdated,$($BaselineData.lastUpdated),Date de dernière mise à jour"
    }
    
    # Configuration
    $config = $BaselineData.config
    
    # Configuration Roo
    $csvLines += "Config,roo.modes,modes,$($config.roo.modes -join ';'),Modes Roo disponibles"
    $csvLines += "Config,roo.mcpSettings,mcpSettings,$($config.roo.mcpSettings | ConvertTo-Json -Compress),Paramètres MCP"
    $csvLines += "Config,roo.userSettings,userSettings,$($config.roo.userSettings | ConvertTo-Json -Compress),Paramètres utilisateur"
    
    # Configuration Hardware
    $csvLines += "Hardware,cpu,cpu,$($config.hardware.cpu),Processeur"
    $csvLines += "Hardware,ram,ram,$($config.hardware.ram),Mémoire RAM"
    $csvLines += "Hardware,disks,disks,$($config.hardware.disks | ConvertTo-Json -Compress),Disques de stockage"
    if ($config.hardware.gpu) {
        $csvLines += "Hardware,gpu,gpu,$($config.hardware.gpu),Carte graphique"
    }
    
    # Configuration Software
    $csvLines += "Software,powershell,powershell,$($config.software.powershell),Version PowerShell"
    $csvLines += "Software,node,node,$($config.software.node),Version Node.js"
    $csvLines += "Software,python,python,$($config.software.python),Version Python"
    
    # Configuration System
    $csvLines += "System,os,os,$($config.system.os),Système d'exploitation"
    $csvLines += "System,architecture,architecture,$($config.system.architecture),Architecture système"
    
    return $csvLines -join "`n"
}

function Prepare-ExportData {
    param([object]$BaselineData)
    
    Write-Log "Préparation des données d'export..." -Level "INFO"
    
    $exportData = @{
        exportInfo = @{
            timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
            format = $Format.ToUpper()
            exportedBy = "roosync_export_baseline.ps1"
            version = "1.0.0"
        }
    }
    
    if ($IncludeMetadata) {
        $exportData.metadata = @{
            machineId = $BaselineData.machineId
            version = $BaselineData.version
            lastUpdated = $BaselineData.lastUpdated
        }
    }
    
    $exportData.configuration = $BaselineData.config
    
    if ($IncludeHistory) {
        $exportData.history = @() # Pas d'historique dans la structure actuelle
    }
    
    $exportData.statistics = @{
        totalParameters = Count-Parameters $BaselineData.config
        lastModified = $BaselineData.lastUpdated
        exportTimestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    }
    
    return $exportData
}

function Count-Parameters {
    param([object]$Config)
    
    $count = 0
    
    function Count-Recursive {
        param([object]$Obj)
        
        if ($Obj -is [array]) {
            $Obj | ForEach-Object { Count-Recursive $_ }
        }
        elseif ($Obj -is [hashtable] -or $Obj -is [PSCustomObject]) {
            $Obj.Values | ForEach-Object { Count-Recursive $_ }
        }
        else {
            $script:count++
        }
    }
    
    Count-Recursive $Config
    return $count
}

# Programme principal
function Main {
    Write-Log "=== Script d'Export Baseline RooSync ===" -Level "INFO"
    Write-Log "Format: $Format" -Level "INFO"
    Write-Log "OutputPath: $OutputPath" -Level "INFO"
    Write-Log "MachineId: $MachineId" -Level "INFO"
    Write-Log "IncludeHistory: $IncludeHistory" -Level "INFO"
    Write-Log "IncludeMetadata: $IncludeMetadata" -Level "INFO"
    Write-Log "PrettyPrint: $PrettyPrint" -Level "INFO"
    Write-Log "DryRun: $DryRun" -Level "INFO"
    
    if ($DryRun) {
        Write-Log "*** MODE SIMULATION ACTIVÉ ***" -Level "WARN" -Color "Yellow"
    }
    
    try {
        # 1. Vérifier les prérequis
        Test-Prerequisites
        
        # 2. Récupérer les données de baseline
        $baselineData = Get-BaselineData -TargetMachineId $MachineId
        
        # 3. Préparer les données d'export
        $exportData = Prepare-ExportData -BaselineData $baselineData
        
        # 4. Générer le contenu selon le format
        $content = ""
        $extension = ""
        
        switch ($Format.ToLower()) {
            "json" {
                $content = Export-JsonFormat -BaselineData $baselineData -ExportData $exportData -PrettyPrint $PrettyPrint
                $extension = ".json"
            }
            "yaml" {
                $content = Export-YamlFormat -BaselineData $baselineData -ExportData $exportData
                $extension = ".yaml"
            }
            "csv" {
                $content = Export-CsvFormat -BaselineData $baselineData -ExportData $exportData
                $extension = ".csv"
            }
            default {
                throw "Format non supporté: $Format"
            }
        }
        
        # 5. Déterminer le chemin de sortie
        $finalOutputPath = $OutputPath
        if (-not $finalOutputPath) {
            $timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
            $filename = "baseline-export-$($baselineData.machineId)-$timestamp$extension"
            $finalOutputPath = Join-Path (Get-Location) "exports" $filename
        }
        
        # 6. Créer le répertoire de sortie si nécessaire
        $outputDir = Split-Path $finalOutputPath -Parent
        if ($outputDir -and -not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
            Write-Log "Répertoire de sortie créé: $outputDir" -Level "INFO"
        }
        
        # 7. Écrire le fichier d'export
        if (-not $DryRun) {
            Set-Content -Path $finalOutputPath -Value $content -Encoding UTF8
            Write-Log "✅ Fichier d'export créé: $finalOutputPath" -Level "INFO"
        } else {
            Write-Log "[DRY-RUN] Fichier d'export serait créé: $finalOutputPath" -Level "INFO"
        }
        
        # 8. Afficher le résumé
        Write-Log "=== Opération terminée ===" -Level "INFO"
        Write-Log "Machine: $($baselineData.machineId)" -Level "INFO"
        Write-Log "Version: $($baselineData.version)" -Level "INFO"
        Write-Log "Format: $Format" -Level "INFO"
        Write-Log "Fichier: $finalOutputPath" -Level "INFO"
        Write-Log "Taille: $($content.Length) octets" -Level "INFO"
        Write-Log "Paramètres: $(Count-Parameters $baselineData.config)" -Level "INFO"
        
        if ($DryRun) {
            Write-Log "*** Simulation terminée (aucune modification réelle) ***" -Level "WARN" -Color "Yellow"
        }
        else {
            Write-Log "Export baseline terminé avec succès" -Level "INFO" -Color "Green"
        }
    }
    catch {
        Write-Log "Erreur fatale: $($_.Exception.Message)" -Level "ERROR"
        Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level "ERROR"
        exit 1
    }
}

# Point d'entrée
try {
    Main
}
catch {
    Write-Log "Erreur non gérée: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level "ERROR"
    exit 1
}