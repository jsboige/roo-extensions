<#
.SYNOPSIS
    Exécute des tâches de maintenance, de nettoyage et d'organisation pour le workspace roo-extensions.

.DESCRIPTION
    Ce script est un outil centralisé pour maintenir la propreté et l'organisation du dépôt.
    Il peut opérer selon deux modes principaux : 'Clean' pour supprimer les fichiers résiduels,
    et 'Organize' pour déplacer les fichiers mal placés et générer de la documentation.

.PARAMETER Clean
    Active le mode de nettoyage. Supprime les fichiers temporaires, les anciennes sauvegardes, etc.

.PARAMETER Organize
    Active le mode d'organisation. Déplace les rapports orphelins, range les templates, etc.

.PARAMETER Mode
    Définit le niveau de nettoyage. "Safe" (défaut) est non destructif, "Aggressive" supprime plus de fichiers.
    ValideSet: "Safe", "Aggressive"

.PARAMETER GenerateDocs
    Si spécifié, le script (re)génère des fichiers Markdown documentant l'architecture du projet.

.PARAMETER DryRun
    Simule toutes les opérations sans modifier, déplacer ou supprimer aucun fichier.

.PARAMETER Force
    Force les opérations sans demander de confirmation.

.EXAMPLE
    .\Invoke-WorkspaceMaintenance.ps1 -Clean -Mode Aggressive
    Description: Exécute un nettoyage agressif de l'espace de travail.

.EXAMPLE
    .\Invoke-WorkspaceMaintenance.ps1 -Organize -GenerateDocs
    Description: Réorganise les fichiers et génère la documentation d'architecture.

.EXAMPLE
    .\Invoke-WorkspaceMaintenance.ps1 -DryRun
    Description: Simule toutes les actions (nettoyage en mode Safe et organisation).

.NOTES
    Auteur: Roo (IA) - consolidé le 20/08/2025
#>
[CmdletBinding(DefaultParameterSetName='All')]
param(
    [Parameter(ParameterSetName='Clean')]
    [Parameter(ParameterSetName='All')]
    [switch]$Clean,

    [Parameter(ParameterSetName='Organize')]
    [Parameter(ParameterSetName='All')]
    [switch]$Organize,

    [Parameter(Mandatory=$false)]
    [ValidateSet("Safe", "Aggressive")]
    [string]$Mode = "Safe",

    [Parameter(Mandatory=$false)]
    [switch]$GenerateDocs,

    [Parameter(Mandatory=$false)]
    [switch]$DryRun,

    [Parameter(Mandatory=$false)]
    [switch]$Force
)

#region Fonctions Utilitaires
$LogPath = "scripts/maintenance/reports/maintenance-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
$BackupPath = "cleanup-backups/maintenance-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry
    Add-Content -Path $LogPath -Value $logEntry
}

function Initialize-Log {
    $modeRunning = @()
    if ($Clean -or $PSCmdlet.ParameterSetName -eq 'All') { $modeRunning += "Clean (Mode: $Mode)" }
    if ($Organize -or $PSCmdlet.ParameterSetName -eq 'All') { $modeRunning += "Organize" }
    if ($GenerateDocs) { $modeRunning += "GenerateDocs" }

    @"
# Rapport de Maintenance du Workspace
**Date :** $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')
**Mode(s) exécuté(s) :** $($modeRunning -join ', ')
**Simulation (DryRun) :** $DryRun

---
"@ | Set-Content -Path $LogPath
}

function Request-Confirmation {
    param ([string]$Prompt)
    if ($Force -or $DryRun) { return $true }
    $confirmation = Read-Host "$Prompt (oui/non)"
    if ($confirmation -match '^(oui|o|yes|y)$') {
        return $true
    }
    Write-Log "Opération annulée par l'utilisateur." "WARNING"
    return $false
}
#endregion

#region Fonctions de Nettoyage
function Remove-TemporaryFiles {
    Write-Log "--- Recherche de fichiers temporaires (Mode: $Mode) ---" "SECTION"
    $patterns = @("*.tmp", "*.temp", "*~", "Thumbs.db")
    if ($Mode -eq 'Aggressive') {
        $patterns += ".DS_Store"
    }

    $filesToRemove = Get-ChildItem -Path "." -Include $patterns -Recurse -File -ErrorAction SilentlyContinue

    if ($filesToRemove.Count -eq 0) {
        Write-Log "Aucun fichier temporaire trouvé."
        return
    }

    Write-Log "Trouvé $($filesToRemove.Count) fichier(s) temporaire(s) à supprimer."
    foreach ($file in $filesToRemove) {
        if ($DryRun) {
            Write-Log "[SIMULATION] Supprimerait: $($file.FullName)"
        } else {
            try {
                Remove-Item $file.FullName -Force -ErrorAction Stop
                Write-Log "Supprimé: $($file.FullName)" "SUCCESS"
            } catch {
                Write-Log "ERREUR lors de la suppression de $($file.FullName): $($_.Exception.Message)" "ERROR"
            }
        }
    }
}

function Remove-OldBackups {
    Write-Log "--- Recherche d'anciennes sauvegardes (plus de 7 jours) ---" "SECTION"
    $backupRoot = "cleanup-backups"
    if (-not (Test-Path $backupRoot)) { return }

    $backupDirs = Get-ChildItem $backupRoot -Directory | Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-7) }

    if ($backupDirs.Count -eq 0) {
        Write-Log "Aucune sauvegarde ancienne trouvée."
        return
    }

    if (-not (Request-Confirmation "Supprimer $($backupDirs.Count) ancien(s) répertoire(s) de sauvegarde ?")) { return }
    
    foreach ($dir in $backupDirs) {
        if ($DryRun) {
            Write-Log "[SIMULATION] Supprimerait le répertoire de sauvegarde: $($dir.FullName)"
        } else {
            Remove-Item $dir.FullName -Recurse -Force
            Write-Log "Supprimé: $($dir.FullName)" "SUCCESS"
        }
    }
}

function Remove-AggressiveCleanTargets {
    if ($Mode -ne 'Aggressive') { return }
    Write-Log "--- Nettoyage Agressif ---" "SECTION"

    $targets = @{
        "sync_conflicts" = "Répertoire de conflits de synchronisation";
        "encoding-fix" = "Ancien répertoire de scripts d'encodage (si consolidé)";
    }

    foreach($target in $targets.GetEnumerator()) {
        if (Test-Path $target.Name) {
            if (-not (Request-Confirmation "Supprimer le répertoire $($target.Name) ? ($($target.Value))")) { continue }
            if ($DryRun) {
                Write-Log "[SIMULATION] Supprimerait: $($target.Name)"
            } else {
                Remove-Item $target.Name -Recurse -Force
                Write-Log "Supprimé: $($target.Name)" "SUCCESS"
            }
        }
    }
}
#endregion

#region Fonctions d'Organisation
function Move-OrphanedReports {
    Write-Log "--- Recherche de rapports orphelins à la racine ---" "SECTION"
    $orphanFiles = Get-ChildItem -Path "." -File | Where-Object { $_.Name -match "^RAPPORT-.*\.md$" -or $_.Name -eq "README-AGENTS-EPITA.md" }
    $targetDir = "docs/reports"

    if ($orphanFiles.Count -eq 0) {
        Write-Log "Aucun rapport orphelin trouvé."
        return
    }

    if (-not (Test-Path $targetDir) -and !$DryRun) { New-Item -ItemType Directory -Path $targetDir -Force }

    foreach($file in $orphanFiles) {
        $destination = Join-Path $targetDir $file.Name
        if ($DryRun) {
            Write-Log "[SIMULATION] Déplacerait $($file.Name) vers $destination"
        } else {
            Move-Item $file.FullName -Destination $destination -Force
            Write-Log "Déplacé: $($file.FullName) -> $destination" "SUCCESS"
        }
    }
}

function Organize-TemplatesDirectory {
    Write-Log "--- Organisation du répertoire 'templates' ---" "SECTION"
    $sourceDir = "templates"
    if (-not (Test-Path $sourceDir)) { return }

    $targetDir = "docs/templates"
    if (-not (Test-Path $targetDir) -and !$DryRun) { New-Item -ItemType Directory -Path $targetDir -Force }

    $templates = Get-ChildItem -Path $sourceDir -File

    foreach ($template in $templates) {
        if ($template.Name -eq "escalation-dashboard.html" -and $template.Length -eq 0) {
            if($DryRun){ Write-Log "[SIMULATION] Supprimerait le template vide: $($template.FullName)" }
            else { Remove-Item $template.FullName -Force; Write-Log "Supprimé (vide): $($template.FullName)" "SUCCESS" }
        } else {
            $destination = Join-Path $targetDir $template.Name
            if($DryRun){ Write-Log "[SIMULATION] Déplacerait: $($template.FullName) -> $destination" }
            else { Move-Item $template.FullName -Destination $destination -Force; Write-Log "Déplacé: $($template.FullName) -> $destination" "SUCCESS" }
        }
    }
    
    if (-not $DryRun -and (Get-ChildItem -Path $sourceDir -ErrorAction SilentlyContinue).Count -eq 0) {
        Remove-Item $sourceDir -Force
        Write-Log "Répertoire source 'templates' supprimé car vide." "SUCCESS"
    }
}
#endregion

#region Fonctions de Documentation
function Generate-ArchitectureDocs {
    Write-Log "--- Génération de la documentation d'architecture ---" "SECTION"
    $docDir = "docs/architecture"
    if(-not (Test-Path $docDir) -and !$DryRun) { New-Item $docDir -ItemType Directory -Force }

    $docContent = @"
# Structure roo-modes/ vs roo-config/modes/
**Date de documentation :** $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')
## Rôles Distincts
### roo-modes/
- **Rôle:** Développement et gestion avancée des modes
- **Usage:** Atelier de développement
### roo-config/modes/
- **Rôle:** Configuration active des modes pour l'environnement
- **Usage:** Configuration opérationnelle
## Recommandation
**GARDER LES DEUX STRUCTURES** - Elles servent des objectifs différents et ne sont pas redondantes.
---
*Documentation générée par Invoke-WorkspaceMaintenance.ps1*
"@
    $docPath = Join-Path $docDir "roo-modes-vs-roo-config-modes.md"
    if($DryRun) { Write-Log "[SIMULATION] Écrirait la documentation dans $docPath" }
    else { Set-Content -Path $docPath -Value $docContent; Write-Log "Documentation créée: $docPath" "SUCCESS" }
}
#endregion

# --- EXÉCUTION PRINCIPALE ---
if (-not (Test-Path (Split-Path $LogPath -Parent))) { New-Item -Path (Split-Path $LogPath -Parent) -ItemType Directory -Force | Out-Null }
Initialize-Log


if ($Clean -or $PSCmdlet.ParameterSetName -eq 'All') {
    Remove-TemporaryFiles
    Remove-OldBackups
    Remove-AggressiveCleanTargets
}

if ($Organize -or $PSCmdlet.ParameterSetName -eq 'All') {
    Move-OrphanedReports
    Organize-TemplatesDirectory
}

if ($GenerateDocs) {
    Generate-ArchitectureDocs
}

Write-Log "Maintenance terminée." "END"
Write-Host "`n=== MAINTENANCE TERMINÉE ===" -ForegroundColor Green
Write-Host "Rapport complet disponible à l'adresse suivante : $LogPath" -ForegroundColor Yellow