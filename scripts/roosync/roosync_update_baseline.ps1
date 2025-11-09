#requires -Version 5.1
<#
.SYNOPSIS
    Script PowerShell autonome pour mettre à jour la configuration baseline RooSync v2.1

.DESCRIPTION
    Ce script permet de mettre à jour la configuration baseline en utilisant
    une machine spécifique comme nouvelle référence. Il intègre les fonctionnalités
    de versioning, sauvegarde automatique et validation.

.PARAMETER MachineId
    ID de la machine à utiliser comme nouvelle baseline (obligatoire)

.PARAMETER Version
    Version de la baseline (optionnel, auto-généré si non spécifié)

.PARAMETER CreateBackup
    Créer une sauvegarde de l'ancienne baseline (défaut: $true)

.PARAMETER UpdateReason
    Raison de la mise à jour (pour documentation)

.PARAMETER UpdatedBy
    Auteur de la mise à jour (défaut: machine actuelle)

.PARAMETER Force
    Forcer la mise à jour même si des validations échouent (défaut: $false)

.PARAMETER DryRun
    Mode simulation - ne pas appliquer les changements (défaut: $false)

.EXAMPLE
    .\roosync_update_baseline.ps1 -MachineId "MYIA-WEB1" -UpdateReason "Mise à jour mensuelle"

.EXAMPLE
    .\roosync_update_baseline.ps1 -MachineId "MYIA-AI-01" -Version "2.1.5" -CreateBackup $true -Force $true

.NOTES
    Auteur: Roo Code Mode
    Version: 2.1.0
    Date: 2025-11-08
    Compatible: RooSync v2.1+
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0, HelpMessage="ID de la machine à utiliser comme nouvelle baseline")]
    [string]$MachineId,

    [Parameter(HelpMessage="Version de la baseline (auto-généré si non spécifié)")]
    [string]$Version,

    [Parameter(HelpMessage="Créer une sauvegarde de l'ancienne baseline")]
    [bool]$CreateBackup = $true,

    [Parameter(HelpMessage="Raison de la mise à jour")]
    [string]$UpdateReason,

    [Parameter(HelpMessage="Auteur de la mise à jour")]
    [string]$UpdatedBy,

    [Parameter(HelpMessage="Forcer la mise à jour même si des validations échouent")]
    [bool]$Force = $false,

    [Parameter(HelpMessage="Mode simulation - ne pas appliquer les changements")]
    [bool]$DryRun = $false
)

# Configuration UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ProgressPreference = 'SilentlyContinue'

# Variables globales
$ScriptVersion = "2.1.0"
$ScriptName = "roosync_update_baseline"
$LogFile = "logs/roosync-update-baseline-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$ConfigFile = "roo-config/sync-config.json"
$BaselineFile = "sync-config.ref.json"
$DashboardFile = "sync-dashboard.json"
$RoadmapFile = "sync-roadmap.md"

# Fonctions utilitaires
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    
    # Écrire dans la console avec couleur
    switch ($Level) {
        "SUCCESS" { Write-Host $LogEntry -ForegroundColor Green }
        "ERROR" { Write-Host $LogEntry -ForegroundColor Red }
        "WARN" { Write-Host $LogEntry -ForegroundColor Yellow }
        "INFO" { Write-Host $LogEntry -ForegroundColor White }
        "DEBUG" { Write-Host $LogEntry -ForegroundColor Gray }
        default { Write-Host $LogEntry }
    }
    
    # Écrire dans le fichier de log
    $LogDir = Split-Path $LogFile -Parent
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }
    Add-Content -Path $LogFile -Value $LogEntry -Encoding UTF8
}

function Test-Prerequisites {
    Write-Log "Vérification des prérequis..."
    
    # Vérifier PowerShell 5.1+
    if ($PSVersionTable.PSVersion.Major -lt 5 -or ($PSVersionTable.PSVersion.Major -eq 5 -and $PSVersionTable.PSVersion.Minor -lt 1)) {
        throw "PowerShell 5.1+ requis. Version actuelle: $($PSVersionTable.PSVersion)"
    }
    
    # Vérifier les modules requis
    $RequiredModules = @()
    foreach ($Module in $RequiredModules) {
        if (-not (Get-Module -Name $Module -ListAvailable)) {
            throw "Module requis non trouvé: $Module"
        }
    }
    
    # Vérifier la configuration RooSync
    if (-not (Test-Path $ConfigFile)) {
        throw "Fichier de configuration RooSync non trouvé: $ConfigFile"
    }
    
    # Vérifier le répertoire partagé
    try {
        $Config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        $SharedPath = $Config.sharedPath
        if (-not (Test-Path $SharedPath)) {
            throw "Répertoire partagé RooSync non trouvé: $SharedPath"
        }
        $script:SharedPath = $SharedPath
    }
    catch {
        throw "Erreur lors de la lecture de la configuration RooSync: $($_.Exception.Message)"
    }
    
    Write-Log "Prérequis vérifiés avec succès" "SUCCESS"
}

function Get-CurrentBaseline {
    Write-Log "Analyse de la baseline actuelle..."
    
    $BaselinePath = Join-Path $script:SharedPath $BaselineFile
    if (-not (Test-Path $BaselinePath)) {
        Write-Log "Aucune baseline existante trouvée" "WARN"
        return $null
    }
    
    try {
        $Baseline = Get-Content $BaselinePath -Raw | ConvertFrom-Json
        Write-Log "Baseline actuelle trouvée: $($Baseline.machineId) v$($Baseline.version)"
        return $Baseline
    }
    catch {
        Write-Log "Erreur lors de la lecture de la baseline: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

function Get-MachineInventory {
    param([string]$TargetMachineId)
    
    Write-Log "Collecte de l'inventaire pour la machine: $TargetMachineId"
    
    # Chemin du script d'inventaire
    $InventoryScript = Join-Path $PSScriptRoot "inventory\Get-MachineInventory.ps1"
    if (-not (Test-Path $InventoryScript)) {
        throw "Script d'inventaire non trouvé: $InventoryScript"
    }
    
    try {
        # Exécuter le script d'inventaire
        $InventoryCmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$InventoryScript`" -MachineId `"$TargetMachineId`""
        Write-Log "Exécution: $InventoryCmd" "DEBUG"
        
        $Result = Invoke-Expression $InventoryCmd
        
        # Parser le résultat JSON
        if ($Result -match '\{.*\}') {
            $Inventory = $Result | ConvertFrom-Json
            Write-Log "Inventaire collecté avec succès pour $TargetMachineId" "SUCCESS"
            return $Inventory
        }
        else {
            throw "Le script d'inventaire n'a pas retourné de JSON valide"
        }
    }
    catch {
        Write-Log "Erreur lors de la collecte de l'inventaire: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function New-BaselineVersion {
    if ($Version) {
        return $Version
    }
    
    # Générer une version automatique: YYYY.MM.DD-HHMM
    $Now = Get-Date
    return "$($Now.ToString('yyyy.MM.dd'))-$($Now.ToString('HHmm'))"
}

function Backup-CurrentBaseline {
    param([object]$CurrentBaseline)
    
    if (-not $CurrentBaseline -or -not $CreateBackup) {
        Write-Log "Sauvegarde de baseline désactivée ou aucune baseline existante"
        return $null
    }
    
    Write-Log "Création de la sauvegarde de la baseline actuelle..."
    
    $Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $BackupPath = Join-Path $script:SharedPath ".rollback\sync-config.ref.backup.$Timestamp.json"
    
    try {
        $BackupDir = Split-Path $BackupPath -Parent
        if (-not (Test-Path $BackupDir)) {
            New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
        }
        
        $CurrentBaseline | ConvertTo-Json -Depth 10 | Out-File -FilePath $BackupPath -Encoding UTF8
        Write-Log "Sauvegarde créée: $BackupPath" "SUCCESS"
        return $BackupPath
    }
    catch {
        Write-Log "Erreur lors de la création de la sauvegarde: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Update-Dashboard {
    param(
        [string]$NewMachineId,
        [string]$NewVersion,
        [string]$OldMachineId
    )
    
    Write-Log "Mise à jour du dashboard..."
    
    $DashboardPath = Join-Path $script:SharedPath $DashboardFile
    if (-not (Test-Path $DashboardPath)) {
        Write-Log "Dashboard non trouvé, création d'un nouveau dashboard" "WARN"
        $Dashboard = @{
            version = "2.1.0"
            lastUpdate = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
            overallStatus = "synced"
            machines = @{}
            stats = @{
                totalDiffs = 0
                totalDecisions = 0
                appliedDecisions = 0
                pendingDecisions = 0
            }
        }
    }
    else {
        try {
            $Dashboard = Get-Content $DashboardPath -Raw | ConvertFrom-Json
        }
        catch {
            Write-Log "Erreur lors de la lecture du dashboard: $($_.Exception.Message)" "ERROR"
            throw
        }
    }
    
    # Mettre à jour les informations de baseline
    $Dashboard.baselineMachine = $NewMachineId
    $Dashboard.baselineVersion = $NewVersion
    $Dashboard.lastBaselineUpdate = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
    $Dashboard.lastUpdate = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
    
    # Mettre à jour le statut de la machine baseline
    if (-not $Dashboard.machines.ContainsKey($NewMachineId)) {
        $Dashboard.machines[$NewMachineId] = @{}
    }
    $Dashboard.machines[$NewMachineId].isBaseline = $true
    $Dashboard.machines[$NewMachineId].lastBaselineUpdate = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
    
    # Retirer le statut baseline de l'ancienne machine si elle existe
    if ($OldMachineId -and $Dashboard.machines.ContainsKey($OldMachineId)) {
        $Dashboard.machines[$OldMachineId].isBaseline = $false
    }
    
    try {
        $Dashboard | ConvertTo-Json -Depth 10 | Out-File -FilePath $DashboardPath -Encoding UTF8
        Write-Log "Dashboard mis à jour avec succès" "SUCCESS"
    }
    catch {
        Write-Log "Erreur lors de la mise à jour du dashboard: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Update-Roadmap {
    param(
        [string]$NewMachineId,
        [string]$NewVersion,
        [string]$OldMachineId,
        [string]$BackupPath,
        [string]$Reason,
        [string]$Author
    )
    
    Write-Log "Mise à jour du roadmap..."
    
    $RoadmapPath = Join-Path $script:SharedPath $RoadmapFile
    $Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
    
    $UpdateEntry = @"

## 🔄 Mise à Jour Baseline - $Timestamp

**Machine baseline précédente :** $(if ($OldMachineId) { $OldMachineId } else { 'Aucune' })
**Nouvelle machine baseline :** $NewMachineId (v$NewVersion)
**Raison :** $(if ($Reason) { $Reason } else { 'Mise à jour manuelle' })
**Effectuée par :** $(if ($Author) { $Author } else { 'Système' })
**Sauvegarde créée :** $(if ($BackupPath) { 'Oui' } else { 'Non' })

---

"@
    
    try {
        if (Test-Path $RoadmapPath) {
            $CurrentContent = Get-Content $RoadmapPath -Raw -Encoding UTF8
            $NewContent = $CurrentContent + $UpdateEntry
        }
        else {
            $NewContent = "# RooSync - Roadmap de Synchronisation`n`n$UpdateEntry"
        }
        
        $NewContent | Out-File -FilePath $RoadmapPath -Encoding UTF8
        Write-Log "Roadmap mis à jour avec succès" "SUCCESS"
    }
    catch {
        Write-Log "Erreur lors de la mise à jour du roadmap: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function New-BaselineConfig {
    param(
        [object]$Inventory,
        [string]$TargetMachineId,
        [string]$Version
    )
    
    Write-Log "Création de la nouvelle configuration baseline..."
    
    $BaselineConfig = @{
        machineId = $TargetMachineId
        version = $Version
        lastUpdated = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
        config = @{
            roo = @{
                modes = @($Inventory.roo.modes | ForEach-Object { $_.slug })
                mcpSettings = @{}
                userSettings = @{}
            }
            hardware = @{
                cpu = "$($Inventory.hardware.cpu.name) ($($Inventory.hardware.cpu.cores) cores)"
                ram = "$([math]::Round($Inventory.hardware.memory.total / 1GB, 2))GB"
                disks = @($Inventory.hardware.disks | ForEach-Object { 
                    @{
                        name = $_.drive
                        size = "$([math]::Round($_.size / 1GB, 2))GB"
                    }
                })
            }
            software = @{
                powershell = $Inventory.software.powershell
                node = if ($Inventory.software.node) { $Inventory.software.node } else { 'N/A' }
                python = if ($Inventory.software.python) { $Inventory.software.python } else { 'N/A' }
            }
            system = @{
                os = $Inventory.system.os
                architecture = $Inventory.system.architecture
            }
        }
    }
    
    # Ajouter les paramètres MCP si disponibles
    if ($Inventory.roo.mcpServers) {
        $BaselineConfig.config.roo.mcpSettings = @{}
        foreach ($Mcp in $Inventory.roo.mcpServers) {
            $BaselineConfig.config.roo.mcpSettings[$Mcp.name] = @{
                enabled = $Mcp.enabled
                command = $Mcp.command
                transportType = $Mcp.transportType
                alwaysAllow = $Mcp.alwaysAllow
                description = $Mcp.description
            }
        }
    }
    
    return $BaselineConfig
}

# Programme principal
function Main {
    try {
        Write-Log "DÉMARRAGE DU SCRIPT DE MISE À JOUR BASELINE - $ScriptVersion" "SUCCESS"
        Write-Log "Machine cible: $MachineId"
        Write-Log "Version: $(if ($Version) { $Version } else { 'Auto-générée' })"
        Write-Log "Créer sauvegarde: $CreateBackup"
        Write-Log "Mode DryRun: $DryRun"
        Write-Log "Fichier de log: $LogFile"
        
        # 1. Vérifier les prérequis
        Test-Prerequisites
        
        # 2. Analyser la baseline actuelle
        $CurrentBaseline = Get-CurrentBaseline
        $OldMachineId = if ($CurrentBaseline) { $CurrentBaseline.machineId } else { $null }
        
        # 3. Collecter l'inventaire de la machine cible
        $Inventory = Get-MachineInventory -TargetMachineId $MachineId
        if (-not $Inventory) {
            throw "Impossible de collecter l'inventaire pour la machine: $MachineId"
        }
        
        # 4. Générer la nouvelle version
        $NewVersion = New-BaselineVersion
        Write-Log "Nouvelle version: $NewVersion"
        
        # 5. Créer la sauvegarde si nécessaire
        $BackupPath = Backup-CurrentBaseline -CurrentBaseline $CurrentBaseline
        
        # 6. Créer la nouvelle configuration baseline
        $NewBaseline = New-BaselineConfig -Inventory $Inventory -TargetMachineId $MachineId -Version $NewVersion
        
        # 7. Valider la nouvelle baseline
        Write-Log "Validation de la nouvelle baseline..."
        if (-not $NewBaseline.machineId -or -not $NewBaseline.version) {
            throw "Configuration baseline invalide: machineId ou version manquant"
        }
        Write-Log "Baseline validée avec succès" "SUCCESS"
        
        # 8. Appliquer les changements si pas en mode DryRun
        if (-not $DryRun) {
            $BaselinePath = Join-Path $script:SharedPath $BaselineFile
            
            try {
                $NewBaseline | ConvertTo-Json -Depth 10 | Out-File -FilePath $BaselinePath -Encoding UTF8
                Write-Log "Nouvelle baseline écrite: $BaselinePath" "SUCCESS"
                
                # 9. Mettre à jour le dashboard
                Update-Dashboard -NewMachineId $MachineId -NewVersion $NewVersion -OldMachineId $OldMachineId
                
                # 10. Mettre à jour le roadmap
                $Author = if ($UpdatedBy) { $UpdatedBy } else { $env:COMPUTERNAME }
                Update-Roadmap -NewMachineId $MachineId -NewVersion $NewVersion -OldMachineId $OldMachineId -BackupPath $BackupPath -Reason $UpdateReason -Author $Author
                
                Write-Log "Mise à jour de la baseline terminée avec succès" "SUCCESS"
            }
            catch {
                Write-Log "Erreur lors de l'application des changements: $($_.Exception.Message)" "ERROR"
                throw
            }
        }
        else {
            Write-Log "MODE DRYRUN: Changements non appliqués" "WARN"
            Write-Log "Nouvelle baseline (preview):"
            $NewBaseline | ConvertTo-Json -Depth 5 | Write-Host
        }
        
        # 11. Afficher le résumé
        Write-Log "RÉSUMÉ DE L'OPÉRATION" "SUCCESS"
        Write-Log "  Machine baseline précédente: $(if ($OldMachineId) { $OldMachineId } else { 'Aucune' })"
        Write-Log "  Nouvelle machine baseline: $MachineId (v$NewVersion)"
        Write-Log "  Sauvegarde créée: $(if ($BackupPath) { 'Oui - ' + $BackupPath } else { 'Non' })"
        Write-Log "  Raison: $(if ($UpdateReason) { $UpdateReason } else { 'Non spécifiée' })"
        Write-Log "  Auteur: $(if ($UpdatedBy) { $UpdatedBy } else { $env:COMPUTERNAME })"
        
        if ($DryRun) {
            Write-Log "MODE DRYRUN: Utilisez -DryRun:`$false pour appliquer les changements" "WARN"
        }
    }
    catch {
        Write-Log "ERREUR FATALE: $($_.Exception.Message)" "ERROR"
        Write-Log "Stack trace: $($_.ScriptStackTrace)" "ERROR"
        exit 1
    }
}

# Point d'entrée principal
try {
    Main
    exit 0
}
catch {
    Write-Log "ERREUR NON GÉRÉE: $($_.Exception.Message)" "ERROR"
    exit 99
}