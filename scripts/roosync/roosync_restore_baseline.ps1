#requires -Version 5.1
<#
.SYNOPSIS
    Script PowerShell autonome pour restaurer une baseline RooSync depuis un tag Git ou une sauvegarde

.DESCRIPTION
    Ce script permet de restaurer une baseline précédente depuis:
    - Un tag Git (format: baseline-vX.Y.Z)
    - Un fichier de sauvegarde (format: sync-config.ref.backup.TIMESTAMP.json)
    
    Il fait partie des scripts autonomes de la Phase 3B du projet SDDD.

.PARAMETER Source
    Source de la restauration (tag Git ou chemin de sauvegarde)

.PARAMETER CreateBackup
    Créer une sauvegarde de l'état actuel (défaut: true)

.PARAMETER UpdateReason
    Raison de la restauration (pour documentation)

.PARAMETER RestoredBy
    Auteur de la restauration (défaut: machine actuelle)

.PARAMETER DryRun
    Mode simulation sans exécution réelle (défaut: false)

.EXAMPLE
    .\roosync_restore_baseline.ps1 -Source "baseline-v1.0.0" -CreateBackup $true
    
    .\roosync_restore_baseline.ps1 -Source ".shared-state/.rollback/sync-config.ref.backup.20251108-120000.json" -DryRun $true

.NOTES
    - Ce script doit être exécuté depuis la racine du projet roo-extensions
    - Les tags Git doivent suivre le format baseline-vX.Y.Z
    - Les sauvegardes sont stockées dans .shared-state/.rollback/

.LINK
    https://github.com/rooveterinaryinc/roo-extensions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0, HelpMessage="Source de la restauration (tag Git ou chemin de sauvegarde)")]
    [string]$Source,
    
    [Parameter(HelpMessage="Créer une sauvegarde de l'état actuel (défaut: true)")]
    [bool]$CreateBackup = $true,
    
    [Parameter(HelpMessage="Raison de la restauration (pour documentation)")]
    [string]$UpdateReason = "",
    
    [Parameter(HelpMessage="Auteur de la restauration (défaut: machine actuelle)")]
    [string]$RestoredBy = "",
    
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
    
    # Vérifier si Git est installé
    try {
        $gitVersion = git --version 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Git n'est pas installé ou non accessible"
        }
        Write-Log "Git trouvé: $gitVersion" -Level "INFO"
    }
    catch {
        Write-Log "Erreur lors de la vérification de Git: $($_.Exception.Message)" -Level "ERROR"
        exit 1
    }
    
    # Vérifier si on est dans un dépôt Git
    try {
        $gitRepo = git rev-parse --is-inside-work-tree 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Le répertoire actuel n'est pas un dépôt Git"
        }
        Write-Log "Dépôt Git validé" -Level "INFO"
    }
    catch {
        Write-Log "Erreur lors de la validation du dépôt Git: $($_.Exception.Message)" -Level "ERROR"
        exit 1
    }
    
    Write-Log "Prérequis validés avec succès" -Level "INFO"
}

function Get-CurrentBaseline {
    Write-Log "Récupération de la baseline actuelle..." -Level "INFO"
    
    try {
        $baselinePath = ".shared-state/sync-config.ref.json"
        if (-not (Test-Path $baselinePath)) {
            throw "Aucune baseline trouvée à $baselinePath"
        }
        
        $baselineContent = Get-Content $baselinePath -Raw
        $baseline = $baselineContent | ConvertFrom-Json
        
        Write-Log "Baseline actuelle trouvée: $($baseline.machineId) v$($baseline.version)" -Level "INFO"
        return $baseline
    }
    catch {
        Write-Log "Erreur lors de la lecture de la baseline: $($_.Exception.Message)" -Level "ERROR"
        exit 1
    }
}

function Test-TagExists {
    param([string]$TagName)
    
    try {
        $null = git rev-parse --verify "refs/tags/$TagName" 2>$null
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

function Restore-FromGitTag {
    param([string]$TagName)
    
    Write-Log "Restauration depuis le tag Git: $TagName" -Level "INFO"
    
    if ($DryRun) {
        Write-Log "[DRY-RUN] git show $TagName`:sync-config.ref.json" -Level "INFO"
        return @{
            machineId = "dry-run-machine"
            version = "dry-run-version"
            lastUpdated = "dry-run-date"
        }
    }
    
    try {
        $baselineContent = git show "$TagName`:sync-config.ref.json" 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Erreur lors de la récupération du tag: $baselineContent"
        }
        
        $baseline = $baselineContent | ConvertFrom-Json
        
        if (-not $baseline.machineId -or -not $baseline.version) {
            throw "Baseline invalide: champs requis manquants"
        }
        
        Write-Log "Baseline récupérée depuis le tag" -Level "INFO"
        return $baseline
    }
    catch {
        Write-Log "Erreur lors de la restauration depuis le tag: $($_.Exception.Message)" -Level "ERROR"
        throw "Erreur lors de la restauration depuis le tag: $($_.Exception.Message)"
    }
}

function Restore-FromBackup {
    param([string]$BackupPath)
    
    Write-Log "Restauration depuis la sauvegarde: $BackupPath" -Level "INFO"
    
    if (-not (Test-Path $BackupPath)) {
        throw "Fichier de sauvegarde non trouvé: $BackupPath"
    }
    
    if ($DryRun) {
        Write-Log "[DRY-RUN] Lecture du fichier de sauvegarde" -Level "INFO"
        return @{
            machineId = "dry-run-machine"
            version = "dry-run-version"
            lastUpdated = "dry-run-date"
        }
    }
    
    try {
        $backupContent = Get-Content $BackupPath -Raw
        $baseline = $backupContent | ConvertFrom-Json
        
        if (-not $baseline.machineId -or -not $baseline.version) {
            throw "Baseline invalide: champs requis manquants"
        }
        
        Write-Log "Baseline récupérée depuis la sauvegarde" -Level "INFO"
        return $baseline
    }
    catch {
        Write-Log "Erreur lors de la restauration depuis la sauvegarde: $($_.Exception.Message)" -Level "ERROR"
        throw "Erreur lors de la restauration depuis la sauvegarde: $($_.Exception.Message)"
    }
}

function Create-Backup-CurrentBaseline {
    param([object]$CurrentBaseline)
    
    Write-Log "Création d'une sauvegarde de l'état actuel..." -Level "INFO"
    
    if ($DryRun) {
        Write-Log "[DRY-RUN] Création d'une sauvegarde" -Level "INFO"
        return ".shared-state/.rollback/sync-config.ref.backup.dry-run.json"
    }
    
    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
        $backupPath = ".shared-state/.rollback/sync-config.ref.backup.$timestamp.json"
        
        # Créer le répertoire de sauvegarde si nécessaire
        $backupDir = ".shared-state/.rollback"
        if (-not (Test-Path $backupDir)) {
            New-Item -ItemType Directory -Path $backupDir -Force
        }
        
        $backupJson = $CurrentBaseline | ConvertTo-Json -Depth 10
        Set-Content -Path $backupPath -Value $backupJson -Encoding UTF8
        
        Write-Log "✅ Sauvegarde créée: $backupPath" -Level "INFO"
        return $backupPath
    }
    catch {
        Write-Log "Erreur lors de la création de la sauvegarde: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Apply-RestoredBaseline {
    param(
        [object]$RestoredBaseline,
        [string]$Source,
        [string]$SourceTag
    )
    
    Write-Log "Application de la baseline restaurée..." -Level "INFO"
    
    if ($DryRun) {
        Write-Log "[DRY-RUN] Application de la baseline restaurée" -Level "INFO"
        Write-Log "[DRY-RUN] Machine: $($RestoredBaseline.machineId)" -Level "INFO"
        Write-Log "[DRY-RUN] Version: $($RestoredBaseline.version)" -Level "INFO"
        Write-Log "[DRY-RUN] Source: $SourceTag" -Level "INFO"
        return $true
    }
    
    try {
        $baselinePath = ".shared-state/sync-config.ref.json"
        
        # Mettre à jour la date de restauration
        $restoredBaseline.lastUpdated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        
        $baselineJson = $restoredBaseline | ConvertTo-Json -Depth 10
        Set-Content -Path $baselinePath -Value $baselineJson -Encoding UTF8
        
        Write-Log "✅ Baseline appliquée avec succès" -Level "INFO"
        Write-Log "Machine: $($RestoredBaseline.machineId)" -Level "INFO"
        Write-Log "Version: $($RestoredBaseline.version)" -Level "INFO"
        Write-Log "Source: $SourceTag" -Level "INFO"
        
        return $true
    }
    catch {
        Write-Log "Erreur lors de l'application de la baseline: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Programme principal
function Main {
    Write-Log "=== Script de Restauration Baseline RooSync ===" -Level "INFO"
    Write-Log "Source: $Source" -Level "INFO"
    Write-Log "CreateBackup: $CreateBackup" -Level "INFO"
    Write-Log "UpdateReason: $UpdateReason" -Level "INFO"
    Write-Log "RestoredBy: $RestoredBy" -Level "INFO"
    Write-Log "DryRun: $DryRun" -Level "INFO"
    
    if ($DryRun) {
        Write-Log "*** MODE SIMULATION ACTIVÉ ***" -Level "WARN" -Color "Yellow"
    }
    
    try {
        # 1. Vérifier les prérequis
        Test-Prerequisites
        
        # 2. Récupérer la baseline actuelle pour sauvegarde
        $currentBaseline = Get-CurrentBaseline
        
        # 3. Déterminer le type de source et restaurer
        $sourceType = ""
        $sourceTag = ""
        $restoredBaseline = $null
        
        if ($Source.StartsWith("baseline-v")) {
            # Restauration depuis un tag Git
            $sourceType = "tag"
            $sourceTag = $Source
            $restoredBaseline = Restore-FromGitTag -TagName $Source
        }
        elseif ($Source.Contains("sync-config.ref.backup.")) {
            # Restauration depuis un fichier de sauvegarde
            $sourceType = "backup"
            $sourceTag = $Source
            $restoredBaseline = Restore-FromBackup -BackupPath $Source
        }
        else {
            Write-Log "Source de restauration non reconnue: $Source. Utilisez un tag Git (baseline-vX.Y.Z) ou un chemin de sauvegarde." -Level "ERROR"
            exit 1
        }
        
        # 4. Créer une sauvegarde de l'état actuel si demandé
        $backupPath = $null
        if ($CreateBackup -and $currentBaseline) {
            $backupPath = Create-Backup-CurrentBaseline -CurrentBaseline $currentBaseline
        }
        
        # 5. Appliquer la baseline restaurée
        $applied = Apply-RestoredBaseline -RestoredBaseline $restoredBaseline -Source $Source -SourceTag $sourceTag
        
        # 6. Afficher le résumé
        Write-Log "=== Opération terminée ===" -Level "INFO"
        Write-Log "Source: $Source" -Level "INFO"
        Write-Log "Type: $sourceType" -Level "INFO"
        Write-Log "Machine restaurée: $($restoredBaseline.machineId)" -Level "INFO"
        Write-Log "Version restaurée: $($restoredBaseline.version)" -Level "INFO"
        
        if ($backupPath) { Write-Log "✓ Sauvegarde créée: $backupPath" -Level "INFO" -Color "Green" }
        if ($applied) { Write-Log "✓ Baseline appliquée" -Level "INFO" -Color "Green" }
        
        if ($DryRun) {
            Write-Log "*** Simulation terminée (aucune modification réelle) ***" -Level "WARN" -Color "Yellow"
        }
        else {
            Write-Log "Restauration baseline terminée avec succès" -Level "INFO" -Color "Green"
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