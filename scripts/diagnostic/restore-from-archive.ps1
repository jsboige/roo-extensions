# Script pour restaurer les fichiers depuis l'archive vers leurs emplacements d'origine
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

# Lire la liste des fichiers à restaurer
$files = Get-Content "outputs/diagnostic-git-urgent/fichiers-haute-priorite-20251022-193749.txt"
$restored = @()
$failed = @()

Write-Log "Début de la restauration depuis l'archive..." "INFO"

foreach ($file in $files) {
    if ($file.Trim() -eq "") { continue }
    
    $sourceFile = "archive/docs-20251022/" + (Split-Path $file -Leaf)
    $targetDir = Split-Path $file -Parent
    
    try {
        # Créer le répertoire cible si nécessaire
        if (-not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }
        
        # Copier le fichier
        if (Test-Path $sourceFile) {
            Copy-Item -Path $sourceFile -Destination $file -Force
            Write-Log "✓ Restauré: $file" "SUCCESS"
            $restored += $file
        } else {
            Write-Log "✗ Source introuvable: $sourceFile" "ERROR"
            $failed += $file
        }
    }
    catch {
        Write-Log "✗ Erreur lors de la restauration de $file" "ERROR"
        $failed += $file
    }
}

Write-Log "======================================================================" "INFO"
Write-Log "RESTAURATION TERMINÉE" "INFO"
Write-Log "======================================================================" "INFO"
Write-Log "Fichiers restaurés: $($restored.Count)" "SUCCESS"
Write-Log "Fichiers en échec: $($failed.Count)" "ERROR"

# Générer le rapport
$reportPath = "outputs/restauration-critique/rapport-restauration-archive-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
$reportDir = Split-Path $reportPath -Parent
if (-not (Test-Path $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$report = "# RAPPORT DE RESTAURATION DEPUIS L'ARCHIVE`n"
$report += "Genere le: $timestamp`n`n"
$report += "### RESUMÉ DE L'OPÉRATION`n"
$report += "- Fichiers restaures avec succes: $($restored.Count)`n"
$report += "- Fichiers en echec: $($failed.Count)`n"
$report += "- Taux de succes: $([math]::Round(($restored.Count / [math]::Max(1, $restored.Count + $failed.Count)) * 100, 2))%`n`n"

$report += "### COMMANDES GIT POUR LE PROCHAIN COMMIT`n"
$report += "```powershell`n"
$report += "# Ajouter tous les fichiers restaures`n"
$report += "git add $($restored -join ' ')`n`n"
$report += "# Commit de restauration`n"
$report += "git commit -m `"RESTAURATION CRITIQUE - $($restored.Count) fichiers essentiels SDDD depuis archive - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`"`n`n"
$report += "# Pousser les changements`n"
$report += "git push origin main`n"
$report += "```n"

$report | Out-File -FilePath $reportPath -Encoding UTF8
Write-Log "Rapport généré: $reportPath" "INFO"