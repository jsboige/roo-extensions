#requires -Version 5.1
<#
.SYNOPSIS
    Script PowerShell autonome pour versionner la baseline RooSync avec tags Git

.DESCRIPTION
    Ce script permet de créer des tags Git pour versionner la baseline actuelle,
    de mettre à jour le CHANGELOG-baseline.md, et de pousser les tags vers le dépôt distant.
    Il fait partie des scripts autonomes de la Phase 3B du projet SDDD.

.PARAMETER Version
    Version de la baseline (format: X.Y.Z)

.PARAMETER Message
    Message du tag Git (défaut: auto-généré)

.PARAMETER PushTags
    Pousser les tags vers le dépôt distant (défaut: true)

.PARAMETER CreateChangelog
    Mettre à jour le CHANGELOG-baseline.md (défaut: true)

.PARAMETER DryRun
    Mode simulation sans exécution réelle (défaut: false)

.EXAMPLE
    .\roosync_version_baseline.ps1 -Version "1.2.0" -Message "Version stable avec corrections critiques"
    
    .\roosync_version_baseline.ps1 -Version "1.2.1" -PushTags $false -DryRun $true

.NOTES
    - Ce script doit être exécuté depuis la racine du projet roo-extensions
    - Il utilise l'outil MCP roosync_version_baseline
    - Le format de version doit être sémantique (X.Y.Z)

.LINK
    https://github.com/rooveterinaryinc/roo-extensions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0, HelpMessage="Version de la baseline (format: X.Y.Z)")]
    [string]$Version,
    
    [Parameter(HelpMessage="Message du tag Git (défaut: auto-généré)")]
    [string]$Message = "",
    
    [Parameter(HelpMessage="Pousser les tags vers le dépôt distant (défaut: true)")]
    [bool]$PushTags = $true,
    
    [Parameter(HelpMessage="Mettre à jour le CHANGELOG-baseline.md (défaut: true)")]
    [bool]$CreateChangelog = $true,
    
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
    
    # Vérifier le format de version
    if ($Version -notmatch '^\d+\.\d+\.\d+(-[a-zA-Z0-9]+)?$') {
        Write-Log "Format de version invalide: $Version. Attendu: X.Y.Z" -Level "ERROR"
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

function Create-GitTag {
    param(
        [string]$TagName,
        [string]$TagMessage
    )
    
    Write-Log "Création du tag Git: $TagName" -Level "INFO"
    
    if ($DryRun) {
        Write-Log "[DRY-RUN] git tag -a $TagName -m `"$TagMessage`"" -Level "INFO"
        return $true
    }
    
    try {
        $result = git tag -a $TagName -m $TagMessage 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Erreur lors de la création du tag: $result"
        }
        Write-Log "Tag Git créé avec succès: $TagName" -Level "INFO"
        return $true
    }
    catch {
        Write-Log "Erreur lors de la création du tag Git: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Push-GitTags {
    Write-Log "Pousser les tags vers le dépôt distant..." -Level "INFO"
    
    if ($DryRun) {
        Write-Log "[DRY-RUN] git push --tags" -Level "INFO"
        return $true
    }
    
    try {
        $result = git push --tags 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Erreur lors du push des tags: $result"
        }
        Write-Log "Tags poussés avec succès" -Level "INFO"
        return $true
    }
    catch {
        Write-Log "Erreur lors du push des tags: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Update-Changelog {
    param(
        [string]$Version,
        [string]$MachineId,
        [string]$TagName,
        [string]$TagMessage
    )
    
    Write-Log "Mise à jour du CHANGELOG-baseline.md..." -Level "INFO"
    
    try {
        $changelogPath = ".shared-state/CHANGELOG-baseline.md"
        $changelogContent = ""
        
        # Lire le contenu existant
        if (Test-Path $changelogPath) {
            $changelogContent = Get-Content $changelogPath -Raw
        }
        else {
            # Créer l'en-tête du CHANGELOG
            $changelogContent = "# CHANGELOG Baseline RooSync`n`nToutes les modifications notables de la baseline.`n`n"
        }
        
        # Préparer l'entrée de version
        $versionEntry = @"
## [$Version] - $(Get-Date -Format "yyyy-MM-dd")

### Machine Baseline
- **Machine**: $MachineId
- **Version**: $Version
- **Dernière mise à jour**: $((Get-CurrentBaseline).lastUpdated)

### Modifications
- $TagMessage

### Tag Git
- `$TagName`

---

"@
        
        # Insérer au début du fichier (après l'en-tête)
        $headerEndIndex = $changelogContent.IndexOf("`n`n")
        if ($headerEndIndex -ne -1) {
            $newContent = $changelogContent.Substring(0, $headerEndIndex + 2) + $versionEntry + $changelogContent.Substring($headerEndIndex + 2)
        }
        else {
            $newContent = $changelogContent + $versionEntry
        }
        
        if ($DryRun) {
            Write-Log "[DRY-RUN] Écriture du CHANGELOG-baseline.md" -Level "INFO"
            Write-Log "[DRY-RUN] Contenu: $($newContent.Substring(0, [Math]::Min(200, $newContent.Length)))..." -Level "DEBUG"
            return $true
        }
        
        # Écrire le fichier mis à jour
        Set-Content -Path $changelogPath -Value $newContent -Encoding UTF8
        Write-Log "CHANGELOG mis à jour avec succès" -Level "INFO"
        return $true
    }
    catch {
        Write-Log "Erreur lors de la mise à jour du CHANGELOG: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Update-BaselineVersion {
    param([string]$Version)
    
    Write-Log "Mise à jour de la version dans la baseline..." -Level "INFO"
    
    try {
        $baselinePath = ".shared-state/sync-config.ref.json"
        $baseline = Get-CurrentBaseline
        
        # Mettre à jour la version
        $baseline.version = $Version
        $baseline.lastUpdated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        
        if ($DryRun) {
            Write-Log "[DRY-RUN] Mise à jour de la baseline vers v$Version" -Level "INFO"
            return $true
        }
        
        # Écrire le fichier mis à jour
        $baselineJson = $baseline | ConvertTo-Json -Depth 10
        Set-Content -Path $baselinePath -Value $baselineJson -Encoding UTF8
        Write-Log "Baseline mise à jour vers v$Version" -Level "INFO"
        return $true
    }
    catch {
        Write-Log "Erreur lors de la mise à jour de la baseline: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Programme principal
function Main {
    Write-Log "=== Script de Versioning Baseline RooSync ===" -Level "INFO"
    Write-Log "Version: $Version" -Level "INFO"
    Write-Log "Message: $Message" -Level "INFO"
    Write-Log "PushTags: $PushTags" -Level "INFO"
    Write-Log "CreateChangelog: $CreateChangelog" -Level "INFO"
    Write-Log "DryRun: $DryRun" -Level "INFO"
    
    if ($DryRun) {
        Write-Log "*** MODE SIMULATION ACTIVÉ ***" -Level "WARN" -Color "Yellow"
    }
    
    try {
        # 1. Vérifier les prérequis
        Test-Prerequisites
        
        # 2. Récupérer la baseline actuelle
        $baseline = Get-CurrentBaseline
        
        # 3. Préparer le tag et le message
        $tagName = "baseline-v$Version"
        $tagMessage = $Message
        if (-not $tagMessage) {
            $tagMessage = "Baseline version $Version - Machine: $($baseline.machineId)"
        }
        
        # 4. Vérifier si le tag existe déjà
        if (Test-TagExists $tagName) {
            Write-Log "Le tag $tagName existe déjà. Utilisez une autre version." -Level "ERROR"
            exit 1
        }
        
        # 5. Créer le tag Git
        $tagCreated = Create-GitTag -TagName $tagName -TagMessage $tagMessage
        if (-not $tagCreated) {
            exit 1
        }
        
        # 6. Pousser le tag si demandé
        $tagPushed = $false
        if ($PushTags) {
            $tagPushed = Push-GitTags
        }
        
        # 7. Mettre à jour le CHANGELOG si demandé
        $changelogUpdated = $false
        if ($CreateChangelog) {
            $changelogUpdated = Update-Changelog -Version $Version -MachineId $baseline.machineId -TagName $tagName -TagMessage $tagMessage
        }
        
        # 8. Mettre à jour la version dans la baseline
        $baselineUpdated = Update-BaselineVersion -Version $Version
        
        # 9. Afficher le résumé
        Write-Log "=== Opération terminée ===" -Level "INFO"
        Write-Log "Version: $Version" -Level "INFO" -Color "Green"
        Write-Log "Tag: $tagName" -Level "INFO"
        Write-Log "Machine baseline: $($baseline.machineId)" -Level "INFO"
        
        if ($tagCreated) { Write-Log "✓ Tag créé" -Level "INFO" -Color "Green" }
        if ($tagPushed) { Write-Log "✓ Tag poussé" -Level "INFO" -Color "Green" }
        if ($changelogUpdated) { Write-Log "✓ CHANGELOG mis à jour" -Level "INFO" -Color "Green" }
        if ($baselineUpdated) { Write-Log "✓ Baseline mise à jour" -Level "INFO" -Color "Green" }
        
        if ($DryRun) {
            Write-Log "*** Simulation terminée (aucune modification réelle) ***" -Level "WARN" -Color "Yellow"
        }
        else {
            Write-Log "Versioning baseline terminé avec succès" -Level "INFO" -Color "Green"
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