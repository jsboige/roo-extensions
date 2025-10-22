# =============================================================================
# SCRIPT DE VALIDATION POST-RESTAURATION CRITIQUE SDDD
# =============================================================================
param(
    [string]$PriorityFile = "outputs/diagnostic-git-urgent/fichiers-haute-priorite-20251022-193749.txt",
    [string]$ReportPath = ""
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
        "CRITICAL" { "Magenta" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-RestoredFiles {
    param([string[]]$Files)
    
    Write-Log "Validation des fichiers restaures..." "INFO"
    
    $results = @{
        Valid = @()
        Invalid = @()
        Missing = @()
        WrongSize = @()
        TotalFiles = $Files.Count
    }
    
    foreach ($file in $Files) {
        if ($file.Trim() -eq "") { continue }
        
        if (Test-Path $file) {
            $fileInfo = Get-Item $file
            if ($fileInfo.Length -gt 0) {
                $results.Valid += $file
                Write-Log "✓ Valide: $file ($([math]::Round($fileInfo.Length / 1KB, 2)) KB)" "SUCCESS"
            } else {
                $results.WrongSize += $file
                Write-Log "⚠ Fichier vide: $file" "WARNING"
            }
        } else {
            $results.Missing += $file
            Write-Log "✗ Manquant: $file" "ERROR"
        }
    }
    
    $results.Invalid = $results.WrongSize + $results.Missing
    
    Write-Log "Validation terminee:" "INFO"
    Write-Log "  - Fichiers valides: $($results.Valid.Count)" "SUCCESS"
    Write-Log "  - Fichiers invalides: $($results.Invalid.Count)" "ERROR"
    Write-Log "  - Fichiers manquants: $($results.Missing.Count)" "ERROR"
    Write-Log "  - Fichiers vides: $($results.WrongSize.Count)" "WARNING"
    
    return $results
}

function Get-GitStatus {
    Write-Log "Analyse du statut Git..." "INFO"
    
    $gitStatus = git status --porcelain
    $statusLines = $gitStatus -split "`n"
    
    $status = @{
        Added = @()
        Modified = @()
        Untracked = @()
        TotalChanges = 0
    }
    
    foreach ($line in $statusLines) {
        if ($line.Trim() -eq "") { continue }
        
        $statusCode = $line.Substring(0, 2)
        $filePath = $line.Substring(3)
        
        switch ($statusCode) {
            "A " { $status.Added += $filePath }
            " M" { $status.Modified += $filePath }
            "M " { $status.Modified += $filePath }
            "?? " { $status.Untracked += $filePath }
        }
    }
    
    $status.TotalChanges = $status.Added.Count + $status.Modified.Count + $status.Untracked.Count
    
    Write-Log "Statut Git:" "INFO"
    Write-Log "  - Fichiers ajoutes: $($status.Added.Count)" "SUCCESS"
    Write-Log "  - Fichiers modifies: $($status.Modified.Count)" "WARNING"
    Write-Log "  - Fichiers non suivis: $($status.Untracked.Count)" "INFO"
    Write-Log "  - Total changements: $($status.TotalChanges)" "INFO"
    
    return $status
}

function New-ValidationReport {
    param(
        [hashtable]$FileValidation,
        [hashtable]$GitStatus,
        [string]$ReportPath
    )
    
    Write-Log "Generation du rapport de validation..." "INFO"
    
    if ($ReportPath -eq "") {
        $ReportPath = "outputs/restauration-critique/rapport-validation-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $report = "# RAPPORT DE VALIDATION POST-RESTAURATION CRITIQUE SDDD`n"
    $report += "Genere le: $timestamp`n`n"
    
    $report += "## RESUMÉ DE LA VALIDATION`n"
    $report += "- **Fichiers critiques attendus**: $($FileValidation.TotalFiles)`n"
    $report += "- **Fichiers valides**: $($FileValidation.Valid.Count)`n"
    $report += "- **Fichiers invalides**: $($FileValidation.Invalid.Count)`n"
    $report += "- **Taux de succes**: $([math]::Round(($FileValidation.Valid.Count / [math]::Max(1, $FileValidation.TotalFiles)) * 100, 2))%`n`n"
    
    $report += "## STATUT GIT`n"
    $report += "- **Fichiers ajoutes**: $($GitStatus.Added.Count)`n"
    $report += "- **Fichiers modifies**: $($GitStatus.Modified.Count)`n"
    $report += "- **Fichiers non suivis**: $($GitStatus.Untracked.Count)`n"
    $report += "- **Total changements**: $($GitStatus.TotalChanges)`n`n"
    
    if ($FileValidation.Valid.Count -gt 0) {
        $report += "## FICHIERS VALIDÉS AVEC SUCCÈS`n"
        $report += "Total: $($FileValidation.Valid.Count) fichiers`n`n"
        $report += "```powershell`n"
        foreach ($file in $FileValidation.Valid) {
            $report += "$file`n"
        }
        $report += "```n`n"
    }
    
    if ($FileValidation.Invalid.Count -gt 0) {
        $report += "## FICHIERS INVALIDES`n"
        $report += "Total: $($FileValidation.Invalid.Count) fichiers`n`n"
        
        if ($FileValidation.Missing.Count -gt 0) {
            $report += "### Fichiers manquants`n"
            foreach ($file in $FileValidation.Missing) {
                $report += "- $file`n"
            }
            $report += "`n"
        }
        
        if ($FileValidation.WrongSize.Count -gt 0) {
            $report += "### Fichiers vides ou corrompus`n"
            foreach ($file in $FileValidation.WrongSize) {
                $report += "- $file`n"
            }
            $report += "`n"
        }
    }
    
    $report += "## COMMANDES GIT POUR FINALISER LA RESTAURATION`n"
    $report += "```powershell`n"
    $report += "# Ajouter tous les fichiers restaures`n"
    $report += "git add $($FileValidation.Valid -join ' ')`n`n"
    $report += "# Verifier le statut avant commit`n"
    $report += "git status`n`n"
    $report += "# Commit de restauration (APRES VALIDATION UTILISATEUR)`n"
    $report += "git commit -m `"RESTAURATION CRITIQUE - $($FileValidation.Valid.Count) fichiers essentiels SDDD - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`"`n`n"
    $report += "# Pousser les changements (APRES VALIDATION FINALE)`n"
    $report += "git push origin main`n"
    $report += "```n`n"
    
    $report += "## VALIDATIONS RECOMMANDÉES`n"
    $report += "1. ✅ Verifier manuellement quelques fichiers restaures`n"
    $report += "2. ⏳ Executer les tests de base du projet`n"
    $report += "3. ⏳ Valider la compilation des MCPs`n"
    $report += "4. ⏳ Confirmer le fonctionnement de l'architecture SDDD`n"
    $report += "5. 🔄 Faire un backup final avant le push`n`n"
    
    $report += "## INFORMATIONS SYSTÈME`n"
    $report += "- **Branche actuelle**: $(git rev-parse --abbrev-ref HEAD)`n"
    $report += "- **Hash du commit**: $(git rev-parse HEAD)`n"
    $report += "- **Branche de sauvegarde**: backup-before-restoration`n"
    $report += "- **Date de validation**: $timestamp`n"
    
    $reportDir = Split-Path $ReportPath -Parent
    if (-not (Test-Path $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }
    
    $report | Out-File -FilePath $ReportPath -Encoding UTF8
    Write-Log "✓ Rapport de validation genere: $ReportPath" "SUCCESS"
    
    return $ReportPath
}

# SCRIPT PRINCIPAL
try {
    Write-Log "======================================================================" "CRITICAL"
    Write-Log "VALIDATION POST-RESTAURATION CRITIQUE SDDD" "CRITICAL"
    Write-Log "======================================================================" "CRITICAL"
    
    # Lecture des fichiers critiques
    $criticalFiles = Get-Content $PriorityFile | Where-Object { $_.Trim() -ne "" }
    Write-Log "✓ $($criticalFiles.Count) fichiers critiques a valider" "INFO"
    
    # Validation des fichiers
    $fileValidation = Test-RestoredFiles -Files $criticalFiles
    
    # Analyse du statut Git
    $gitStatus = Get-GitStatus
    
    # Generation du rapport
    $reportPath = New-ValidationReport -FileValidation $fileValidation -GitStatus $gitStatus -ReportPath $ReportPath
    
    # Resume final
    Write-Log "======================================================================" "CRITICAL"
    Write-Log "VALIDATION TERMINÉE" "CRITICAL"
    Write-Log "======================================================================" "CRITICAL"
    Write-Log "Fichiers valides: $($fileValidation.Valid.Count)/$($fileValidation.TotalFiles)" "SUCCESS"
    Write-Log "Taux de succes: $([math]::Round(($fileValidation.Valid.Count / [math]::Max(1, $fileValidation.TotalFiles)) * 100, 2))%" "INFO"
    Write-Log "Changements Git: $($gitStatus.TotalChanges)" "INFO"
    Write-Log "Rapport complet: $reportPath" "INFO"
    
    if ($fileValidation.Invalid.Count -gt 0) {
        Write-Log "⚠ ATTENTION: $($fileValidation.Invalid.Count) fichiers necessitent une attention particuliere" "WARNING"
        exit 1
    } else {
        Write-Log "🎉 SUCCÈS COMPLET: Tous les fichiers ont ete valides avec succes!" "SUCCESS"
        Write-Log "Prêt pour le commit de restauration!" "SUCCESS"
    }
}
catch {
    Write-Log "✗ ERREUR CRITIQUE lors de la validation: $_" "ERROR"
    exit 1
}