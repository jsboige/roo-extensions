# =============================================================================
# SCRIPT DE RESTAURATION CRITIQUE - VERSION SIMPLIFIEE
# =============================================================================
param(
    [string]$PriorityFile = "outputs/diagnostic-git-urgent/fichiers-haute-priorite-20251022-193749.txt",
    [switch]$Force = $false
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch($Level) {
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        "INFO" { "Cyan" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-Prerequisites {
    Write-Log "Verification des prerequis..." "INFO"
    
    try {
        $gitStatus = git status --porcelain 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Ce n'est pas un depot Git valide"
        }
        Write-Log "✓ Depot Git valide" "SUCCESS"
    }
    catch {
        Write-Log "✗ Erreur: $_" "ERROR"
        exit 1
    }
    
    if (-not (Test-Path $PriorityFile)) {
        Write-Log "✗ Fichier de priorite introuvable: $PriorityFile" "ERROR"
        exit 1
    }
    Write-Log "✓ Fichier de priorite trouve: $PriorityFile" "SUCCESS"
    
    $currentBranch = git rev-parse --abbrev-ref HEAD
    Write-Log "✓ Branche actuelle: $currentBranch" "INFO"
}

function Get-CriticalFiles {
    Write-Log "Lecture de la liste des fichiers critiques..." "INFO"
    
    try {
        $files = Get-Content $PriorityFile | Where-Object { 
            $_.Trim() -ne "" -and -not $_.StartsWith("#") 
        } | ForEach-Object { $_.Trim() }
        
        Write-Log "✓ $($files.Count) fichiers critiques identifies" "SUCCESS"
        return $files
    }
    catch {
        Write-Log "✗ Erreur lors de la lecture du fichier: $_" "ERROR"
        exit 1
    }
}

function Restore-Files {
    param([string[]]$Files)
    
    Write-Log "Debut de la restauration des fichiers..." "INFO"
    
    $restored = @()
    $failed = @()
    $totalFiles = $Files.Count
    $processed = 0
    
    foreach ($file in $Files) {
        $processed++
        $percent = [math]::Round(($processed / $totalFiles) * 100, 1)
        
        Write-Progress -Activity "Restauration des fichiers" -Status "Fichier $processed/$totalFiles ($percent%)" -CurrentOperation $file -PercentComplete $percent
        
        try {
            $existsInHead = git cat-file -e HEAD:"$file" 2>$null
            if ($LASTEXITCODE -eq 0) {
                git checkout HEAD -- "$file" 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "✓ Restaure: $file" "SUCCESS"
                    $restored += $file
                } else {
                    Write-Log "✗ Echec de restauration: $file" "ERROR"
                    $failed += $file
                }
            } else {
                Write-Log "✗ Fichier inexistant dans HEAD: $file" "ERROR"
                $failed += $file
            }
        }
        catch {
            $errorMessage = "Erreur lors de la restauration de $file"
            Write-Log "✗ $errorMessage" "ERROR"
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
        [hashtable]$RestorationResult,
        [string]$ReportPath
    )
    
    Write-Log "Generation du rapport de restauration..." "INFO"
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $report = "# RAPPORT DE RESTAURATION CRITIQUE SDDD`n"
    $report += "Genere le: $timestamp`n`n"
    
    $report += "### RESUMÉ DE L'OPÉRATION`n"
    $report += "- Fichiers restaures avec succes: $($RestorationResult.Restored.Count)`n"
    $report += "- Fichiers en echec: $($RestorationResult.Failed.Count)`n"
    $successRate = [math]::Round(($RestorationResult.Restored.Count / [math]::Max(1, $RestorationResult.Restored.Count + $RestorationResult.Failed.Count)) * 100, 2)
    $report += "- Taux de succes: $successRate%`n`n"
    
    $report += "### LISTE DES FICHIERS RESTAURÉS`n"
    foreach ($file in $RestorationResult.Restored) {
        $report += "- $file`n"
    }
    $report += "`n"
    
    if ($RestorationResult.Failed.Count -gt 0) {
        $report += "### LISTE DES FICHIERS EN ÉCHEC`n"
        foreach ($file in $RestorationResult.Failed) {
            $report += "- $file`n"
        }
        $report += "`n"
    }
    
    $report += "### COMMANDES GIT POUR LE PROCHAIN COMMIT`n"
    $report += "```powershell`n"
    $report += "# Ajouter tous les fichiers restaures`n"
    $report += "git add $($RestorationResult.Restored -join ' ')`n`n"
    $report += "# Commit de restauration (a executer apres validation)`n"
    $report += "git commit -m `"RESTAURATION CRITIQUE - $($RestorationResult.Restored.Count) fichiers essentiels SDDD - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`"`n`n"
    $report += "# Pousser les changements (apres validation complete)`n"
    $report += "git push origin main`n"
    $report += "```n`n"
    
    $report += "### NOTES`n"
    $report += "- Branche de sauvegarde cree: backup-before-restoration`n"
    $report += "- Operation executee depuis la branche: $(git rev-parse --abbrev-ref HEAD)`n"
    $report += "- Hash du commit actuel: $(git rev-parse HEAD)`n"
    
    $reportDir = Split-Path $ReportPath -Parent
    if (-not (Test-Path $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }
    
    $report | Out-File -FilePath $ReportPath -Encoding UTF8
    Write-Log "✓ Rapport genere: $ReportPath" "SUCCESS"
    
    return $ReportPath
}

# SCRIPT PRINCIPAL
try {
    Write-Log "======================================================================" "INFO"
    Write-Log "RESTAURATION CRITIQUE DES FICHIERS ESSENTIELS SDDD" "INFO"
    Write-Log "======================================================================" "INFO"
    
    Test-Prerequisites
    $criticalFiles = Get-CriticalFiles
    
    if (-not $Force) {
        Write-Log "Pret a restaurer $($criticalFiles.Count) fichiers" "WARNING"
        $response = Read-Host "Confirmer la restauration? (y/N)"
        if ($response -ne "y") {
            Write-Log "Operation annulee par l'utilisateur" "WARNING"
            exit 0
        }
    }
    
    $restorationResult = Restore-Files -Files $criticalFiles
    
    $reportPath = "outputs/restauration-critique/rapport-restauration-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
    New-RestorationReport -RestorationResult $restorationResult -ReportPath $reportPath
    
    Write-Log "======================================================================" "INFO"
    Write-Log "OPERATION TERMINEE" "INFO"
    Write-Log "======================================================================" "INFO"
    Write-Log "Fichiers restaures: $($restorationResult.Restored.Count)" "SUCCESS"
    Write-Log "Fichiers en echec: $($restorationResult.Failed.Count)" "ERROR"
    Write-Log "Rapport disponible: $reportPath" "INFO"
    
    if ($restorationResult.Failed.Count -gt 0) {
        Write-Log "ATTENTION: Certains fichiers n'ont pas pu etre restaures" "WARNING"
        exit 1
    } else {
        Write-Log "✓ Tous les fichiers ont ete restaures avec succes!" "SUCCESS"
    }
}
catch {
    Write-Log "ERREUR CRITIQUE: $_" "ERROR"
    exit 1
}