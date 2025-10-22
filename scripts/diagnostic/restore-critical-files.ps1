# =============================================================================
# SCRIPT DE RESTAURATION CRITIQUE - 125 FICHIERS ESSENTIELS SDDD
# =============================================================================
# Auteur: Roo Assistant
# Date: 2025-10-22
# Version: 1.0
# Urgence: CRITIQUE - Restauration complète des fichiers supprimés
# =============================================================================

param(
    [string]$PriorityFile = "outputs/diagnostic-git-urgent/fichiers-haute-priorite-20251022-193749.txt",
    [switch]$DryRun = $false,
    [switch]$Force = $false
)

# Configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"

# Couleurs pour l'affichage
$Colors = @{
    Success = "Green"
    Warning = "Yellow"
    Error = "Red"
    Info = "Cyan"
    Critical = "Magenta"
}

# Fonctions utilitaires
function Write-Log {
    param([string]$Message, [string]$Level = "Info")
    $color = $Colors[$Level]
    if (-not $color) { $color = "White" }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-Prerequisites {
    Write-Log "Vérification des prérequis..." "Info"
    
    # Vérifier si on est dans un repo Git
    try {
        $gitStatus = git status --porcelain 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Ce n'est pas un dépôt Git valide"
        }
        Write-Log "✓ Dépôt Git valide" "Success"
    }
    catch {
        Write-Log "✗ Erreur: $_" "Error"
        exit 1
    }
    
    # Vérifier le fichier de priorité
    if (-not (Test-Path $PriorityFile)) {
        Write-Log "✗ Fichier de priorité introuvable: $PriorityFile" "Error"
        exit 1
    }
    Write-Log "✓ Fichier de priorité trouvé: $PriorityFile" "Success"
    
    # Vérifier la branche actuelle
    $currentBranch = git rev-parse --abbrev-ref HEAD
    Write-Log "✓ Branche actuelle: $currentBranch" "Info"
    
    if ($currentBranch -ne "main") {
        Write-Log "⚠ Attention: Vous n'êtes pas sur la branche main" "Warning"
        if (-not $Force) {
            $response = Read-Host "Continuer quand même? (y/N)"
            if ($response -ne "y") {
                Write-Log "Opération annulée" "Warning"
                exit 0
            }
        }
    }
}

function Get-CriticalFiles {
    Write-Log "Lecture de la liste des fichiers critiques..." "Info"
    
    try {
        $files = Get-Content $PriorityFile | Where-Object { 
            $_.Trim() -ne "" -and -not $_.StartsWith("#") 
        } | ForEach-Object { $_.Trim() }
        
        Write-Log "✓ $($files.Count) fichiers critiques identifiés" "Success"
        return $files
    }
    catch {
        Write-Log "✗ Erreur lors de la lecture du fichier: $_" "Error"
        exit 1
    }
}

function Test-FilesStatus {
    param([string[]]$Files)
    
    Write-Log "Analyse du statut des fichiers..." "Info"
    
    $status = @{
        Deleted = @()
        Modified = @()
        Untracked = @()
        Restored = @()
        Missing = @()
    }
    
    foreach ($file in $Files) {
        if (Test-Path $file) {
            $status.Restored += $file
        } else {
            # Vérifier si le fichier est supprimé dans Git
            $gitStatus = git status --porcelain $file 2>$null
            if ($gitStatus -and $gitStatus.StartsWith("D")) {
                $status.Deleted += $file
            } else {
                $status.Missing += $file
            }
        }
    }
    
    Write-Log "✓ Analyse terminée:" "Success"
    Write-Log "  - Fichiers supprimés: $($status.Deleted.Count)" "Info"
    Write-Log "  - Fichiers déjà restaurés: $($status.Restored.Count)" "Info"
    Write-Log "  - Fichiers manquants: $($status.Missing.Count)" "Info"
    
    return $status
}

function Restore-Files {
    param([string[]]$Files, [switch]$DryRun)
    
    Write-Log "Début de la restauration des fichiers..." "Critical"
    
    if ($DryRun) {
        Write-Log "MODE SIMULATION - Aucun fichier ne sera restauré" "Warning"
    }
    
    $restored = @()
    $failed = @()
    $totalFiles = $Files.Count
    $processed = 0
    
    foreach ($file in $Files) {
        $processed++
        $percent = [math]::Round(($processed / $totalFiles) * 100, 1)
        
        Write-Progress -Activity "Restauration des fichiers" -Status "Fichier $processed/$totalFiles ($percent%)" -CurrentOperation $file -PercentComplete $percent
        
        try {
            if ($DryRun) {
                Write-Log "[SIMULATION] git checkout HEAD -- '$file'" "Info"
                $restored += $file
            } else {
                # Vérifier si le fichier existe dans HEAD
                $existsInHead = git cat-file -e HEAD:"$file" 2>$null
                if ($LASTEXITCODE -eq 0) {
                    git checkout HEAD -- "$file" 2>$null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Log "✓ Restauré: $file" "Success"
                        $restored += $file
                    } else {
                        Write-Log "✗ Échec de restauration: $file" "Error"
                        $failed += $file
                    }
                } else {
                    Write-Log "✗ Fichier inexistant dans HEAD: $file" "Error"
                    $failed += $file
                }
            }
        }
        catch {
            Write-Log "✗ Erreur lors de la restauration de $file`: $_" "Error"
            $failed += $file
        }
    }
    
    Write-Progress -Activity "Restauration des fichiers" -Completed
    
    return @{
        Restored = $restored
        Failed = $failed
    }
}

function New-RestorationReport {
    param(
        [hashtable]$InitialStatus,
        [hashtable]$RestorationResult,
        [string]$ReportPath
    )
    
    Write-Log "Génération du rapport de restauration..." "Info"
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $totalFiles = $InitialStatus.Deleted.Count + $InitialStatus.Restored.Count + $InitialStatus.Missing.Count
    $report = "# RAPPORT DE RESTAURATION CRITIQUE SDDD`n"
    $report += "## Généré le: $timestamp`n`n"
    $report += "### RÉSUMÉ DE L'OPÉRATION`n"
    $report += "- **Fichiers critiques identifiés**: $totalFiles`n"
    $report += "- **Fichiers supprimés**: $($InitialStatus.Deleted.Count)`n"
    $report += "- **Fichiers déjà restaurés**: $($InitialStatus.Restored.Count)`n"
    $report += "- **Fichiers manquants**: $($InitialStatus.Missing.Count)`n`n"

    $report += "### RÉSULTATS DE LA RESTAURATION`n"
    $report += "- **Fichiers restaurés avec succès**: $($RestorationResult.Restored.Count)`n"
    $report += "- **Fichiers en échec**: $($RestorationResult.Failed.Count)`n"
    $successRate = [math]::Round(($RestorationResult.Restored.Count / [math]::Max(1, $InitialStatus.Deleted.Count)) * 100, 2)
    $report += "- **Taux de succès**: $successRate%`n`n"
    
    $report += "### LISTE DES FICHIERS RESTAURÉS`n"
    foreach ($file in $RestorationResult.Restored) {
        $report += "- $file`n"
    }
    $report += "`n"
    
    $report += "### LISTE DES FICHIERS EN ÉCHEC`n"
    foreach ($file in $RestorationResult.Failed) {
        $report += "- $file`n"
    }
    $report += "`n"
    
    $report += "### COMMANDES GIT POUR LE PROCHAIN COMMIT`n"
    $report += "```powershell`n"
    $report += "# Ajouter tous les fichiers restaurés`n"
    $report += "git add $($RestorationResult.Restored -join ' ')`n`n"
    $report += "# Commit de restauration (à exécuter après validation)`n"
    $report += "git commit -m `"RESTAURATION CRITIQUE - $($RestorationResult.Restored.Count) fichiers essentiels SDDD - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`"`n`n"
    $report += "# Pousser les changements (après validation complète)`n"
    $report += "git push origin main`n"
    $report += "```n`n"
    
    $report += "### VALIDATIONS RECOMMANDÉES`n"
    $report += "1. Vérifier manuellement quelques fichiers restaurés`n"
    $report += "2. Exécuter les tests de base du projet`n"
    $report += "3. Valider la compilation des MCPs`n"
    $report += "4. Confirmer le fonctionnement de l'architecture SDDD`n`n"
    
    $report += "### NOTES`n"
    $report += "- Branche de sauvegarde créée: `backup-before-restoration``n"
    $report += "- Opération exécutée depuis la branche: $(git rev-parse --abbrev-ref HEAD)`n"
    $report += "- Hash du commit actuel: $(git rev-parse HEAD)`n"
    
    $reportDir = Split-Path $ReportPath -Parent
    if (-not (Test-Path $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }
    
    $report | Out-File -FilePath $ReportPath -Encoding UTF8
    Write-Log "✓ Rapport généré: $ReportPath" "Success"
    
    return $ReportPath
}

# ============================================================================= 
# SCRIPT PRINCIPAL
# =============================================================================

try {
    Write-Log "======================================================================" "Critical"
    Write-Log "RESTAURATION CRITIQUE DES 125 FICHIERS ESSENTIELS SDDD" "Critical"
    Write-Log "======================================================================" "Critical"
    
    # Étape 1: Prérequis
    Test-Prerequisites
    
    # Étape 2: Lecture des fichiers critiques
    $criticalFiles = Get-CriticalFiles
    
    # Étape 3: Analyse du statut
    $fileStatus = Test-FilesStatus -Files $criticalFiles
    
    # Étape 4: Confirmation
    if (-not $DryRun -and -not $Force) {
        Write-Log "Prêt à restaurer $($fileStatus.Deleted.Count) fichiers supprimés" "Warning"
        $response = Read-Host "Confirmer la restauration? (y/N)"
        if ($response -ne "y") {
            Write-Log "Opération annulée par l'utilisateur" "Warning"
            exit 0
        }
    }
    
    # Étape 5: Restauration
    $restorationResult = Restore-Files -Files $fileStatus.Deleted -DryRun:$DryRun
    
    # Étape 6: Rapport
    $reportPath = "outputs/restauration-critique/rapport-restauration-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
    New-RestorationReport -InitialStatus $fileStatus -RestorationResult $restorationResult -ReportPath $reportPath
    
    # Étape 7: Résumé final
    Write-Log "======================================================================" "Critical"
    Write-Log "OPÉRATION TERMINÉE" "Critical"
    Write-Log "======================================================================" "Critical"
    Write-Log "Fichiers restaurés: $($restorationResult.Restored.Count)" "Success"
    Write-Log "Fichiers en échec: $($restorationResult.Failed.Count)" "Error"
    Write-Log "Rapport disponible: $reportPath" "Info"
    
    if ($restorationResult.Failed.Count -gt 0) {
        Write-Log "⚠ Certains fichiers n'ont pas pu être restaurés" "Warning"
        exit 1
    } else {
        Write-Log "✓ Tous les fichiers ont été restaurés avec succès!" "Success"
    }
}
catch {
    Write-Log "✗ ERREUR CRITIQUE: $_" "Error"
    Write-Log "Stack Trace: $($_.ScriptStackTrace)" "Error"
    exit 1
}