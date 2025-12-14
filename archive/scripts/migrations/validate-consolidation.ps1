#!/usr/bin/env pwsh
# Script de validation de la consolidation - Phase 5

param(
    [switch]$Verbose = $false
)

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

# Chemins de base
$rootPath = "c:/dev/roo-extensions"
$backupPath = "$rootPath/cleanup-backups/20250527-012300/phase5"
$logFile = "$backupPath/validation-log-$timestamp.txt"

# Fonction de logging
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
    Write-Host $logEntry
    if (Test-Path (Split-Path $logFile -Parent)) {
        Add-Content -Path $logFile -Value $logEntry
    }
}

# Fonction de validation
function Validate-Consolidation {
    Write-Log "DEBUT DE LA VALIDATION DE LA CONSOLIDATION" "INFO"
    
    $validationResults = @{
        DuplicatesRemoved = $false
        EncodingScriptsMoved = $false
        DocumentationArchived = $false
        BackupsCreated = $false
        ConfigsAccessible = $false
        TotalIssues = 0
    }
    
    # 1. Vérifier que les doublons ont été supprimés
    Write-Log "=== VERIFICATION DES DOUBLONS ===" "INFO"
    
    $newRooModes = "$rootPath/roo-modes/configs/new-roomodes.json"
    $vscodeCustom = "$rootPath/roo-modes/configs/vscode-custom-modes.json"
    
    if (-not (Test-Path $newRooModes) -and (Test-Path $vscodeCustom)) {
        Write-Log "Doublon supprime correctement: new-roomodes.json supprime, vscode-custom-modes.json conserve" "SUCCESS"
        $validationResults.DuplicatesRemoved = $true
    } elseif ((Test-Path $newRooModes) -and -not (Test-Path $vscodeCustom)) {
        Write-Log "Doublon supprime correctement: vscode-custom-modes.json supprime, new-roomodes.json conserve" "SUCCESS"
        $validationResults.DuplicatesRemoved = $true
    } elseif ((Test-Path $newRooModes) -and (Test-Path $vscodeCustom)) {
        Write-Log "PROBLEME: Les deux fichiers doublons existent encore" "ERROR"
        $validationResults.TotalIssues++
    } else {
        Write-Log "PROBLEME: Aucun des fichiers doublons n'existe" "ERROR"
        $validationResults.TotalIssues++
    }
    
    # 2. Vérifier que les scripts encoding ont été déplacés
    Write-Log "=== VERIFICATION DES SCRIPTS ENCODING ===" "INFO"
    
    $encodingScriptsDir = "$rootPath/roo-config/scripts/encoding"
    $essentialScripts = @(
        "apply-encoding-fix.ps1",
        "apply-encoding-fix-simple.ps1",
        "fix-encoding.ps1",
        "fix-encoding-simple.ps1",
        "validate-deployment.ps1",
        "validate-deployment-simple.ps1",
        "backup-profile.ps1",
        "restore-profile.ps1"
    )
    
    $movedScripts = 0
    foreach ($script in $essentialScripts) {
        $targetPath = "$encodingScriptsDir/$script"
        if (Test-Path $targetPath) {
            Write-Log "Script trouve: $script" "SUCCESS"
            $movedScripts++
        } else {
            Write-Log "Script manquant: $script" "ERROR"
            $validationResults.TotalIssues++
        }
    }
    
    if ($movedScripts -eq $essentialScripts.Count) {
        Write-Log "Tous les scripts essentiels ont ete deplaces correctement" "SUCCESS"
        $validationResults.EncodingScriptsMoved = $true
    } else {
        Write-Log "PROBLEME: $($essentialScripts.Count - $movedScripts) scripts manquants" "ERROR"
    }
    
    # 3. Vérifier que la documentation a été archivée
    Write-Log "=== VERIFICATION DE L'ARCHIVAGE DOCUMENTATION ===" "INFO"
    
    $archiveDir = "$rootPath/roo-config/archive/encoding-fix"
    if (Test-Path $archiveDir) {
        $archivedDocs = Get-ChildItem "$archiveDir/*.md" -ErrorAction SilentlyContinue
        if ($archivedDocs.Count -gt 0) {
            Write-Log "Documentation archivee: $($archivedDocs.Count) fichiers .md trouves" "SUCCESS"
            foreach ($doc in $archivedDocs) {
                Write-Log "  - $($doc.Name)" "INFO"
            }
            $validationResults.DocumentationArchived = $true
        } else {
            Write-Log "PROBLEME: Aucune documentation trouvee dans l'archive" "ERROR"
            $validationResults.TotalIssues++
        }
    } else {
        Write-Log "PROBLEME: Repertoire d'archive non trouve" "ERROR"
        $validationResults.TotalIssues++
    }
    
    # 4. Vérifier que les sauvegardes ont été créées
    Write-Log "=== VERIFICATION DES SAUVEGARDES ===" "INFO"
    
    $duplicatesBackup = "$backupPath/duplicates"
    if (Test-Path $duplicatesBackup) {
        $backupFiles = Get-ChildItem $duplicatesBackup -ErrorAction SilentlyContinue
        if ($backupFiles.Count -gt 0) {
            Write-Log "Sauvegardes des doublons trouvees: $($backupFiles.Count) fichiers" "SUCCESS"
            $validationResults.BackupsCreated = $true
        } else {
            Write-Log "AVERTISSEMENT: Repertoire de sauvegarde vide" "WARN"
        }
    } else {
        Write-Log "AVERTISSEMENT: Repertoire de sauvegarde des doublons non trouve" "WARN"
    }
    
    # 5. Vérifier l'accessibilité des configurations consolidées
    Write-Log "=== VERIFICATION DE L'ACCESSIBILITE DES CONFIGURATIONS ===" "INFO"
    
    $configDirs = @(
        "$rootPath/roo-config/modes",
        "$rootPath/roo-modes/configs",
        "$rootPath/roo-config/scripts/encoding",
        "$rootPath/roo-config/archive/encoding-fix"
    )
    
    $accessibleDirs = 0
    foreach ($dir in $configDirs) {
        if (Test-Path $dir) {
            $files = Get-ChildItem $dir -ErrorAction SilentlyContinue
            Write-Log "Repertoire accessible: $dir ($($files.Count) elements)" "SUCCESS"
            $accessibleDirs++
        } else {
            Write-Log "PROBLEME: Repertoire inaccessible: $dir" "ERROR"
            $validationResults.TotalIssues++
        }
    }
    
    if ($accessibleDirs -eq $configDirs.Count) {
        Write-Log "Toutes les configurations consolidees sont accessibles" "SUCCESS"
        $validationResults.ConfigsAccessible = $true
    }
    
    return $validationResults
}

# Fonction pour générer le rapport
function Generate-ValidationReport {
    param([hashtable]$Results)
    
    Write-Log "=== RAPPORT DE VALIDATION ===" "INFO"
    
    $successCount = 0
    $totalChecks = 5
    
    if ($Results.DuplicatesRemoved) { $successCount++ }
    if ($Results.EncodingScriptsMoved) { $successCount++ }
    if ($Results.DocumentationArchived) { $successCount++ }
    if ($Results.BackupsCreated) { $successCount++ }
    if ($Results.ConfigsAccessible) { $successCount++ }
    
    Write-Log "RESULTATS DE LA VALIDATION:" "INFO"
    Write-Log "  - Doublons supprimes: $(if ($Results.DuplicatesRemoved) { 'OUI' } else { 'NON' })" "INFO"
    Write-Log "  - Scripts encoding deplaces: $(if ($Results.EncodingScriptsMoved) { 'OUI' } else { 'NON' })" "INFO"
    Write-Log "  - Documentation archivee: $(if ($Results.DocumentationArchived) { 'OUI' } else { 'NON' })" "INFO"
    Write-Log "  - Sauvegardes creees: $(if ($Results.BackupsCreated) { 'OUI' } else { 'NON' })" "INFO"
    Write-Log "  - Configurations accessibles: $(if ($Results.ConfigsAccessible) { 'OUI' } else { 'NON' })" "INFO"
    Write-Log "  - Total des problemes: $($Results.TotalIssues)" "INFO"
    
    $successRate = [math]::Round(($successCount / $totalChecks) * 100, 1)
    Write-Log "TAUX DE REUSSITE: $successRate% ($successCount/$totalChecks)" "INFO"
    
    if ($Results.TotalIssues -eq 0 -and $successCount -eq $totalChecks) {
        Write-Log "VALIDATION REUSSIE: La consolidation a ete effectuee correctement" "SUCCESS"
        return $true
    } else {
        Write-Log "VALIDATION ECHOUEE: Des problemes ont ete detectes" "ERROR"
        return $false
    }
}

# Fonction principale
function Main {
    Write-Log "DEBUT DE LA VALIDATION - PHASE 5" "INFO"
    Write-Log "Timestamp: $timestamp" "INFO"
    
    # Créer le répertoire de log si nécessaire
    New-Item -Path (Split-Path $logFile -Parent) -ItemType Directory -Force | Out-Null
    
    # Initialiser le fichier de log
    "Log de Validation de la Consolidation - Phase 5" | Set-Content -Path $logFile -Encoding UTF8
    "Timestamp: $timestamp" | Add-Content -Path $logFile
    "" | Add-Content -Path $logFile
    
    try {
        # Exécuter la validation
        $results = Validate-Consolidation
        
        # Générer le rapport
        $success = Generate-ValidationReport -Results $results
        
        Write-Log "Log detaille: $logFile" "INFO"
        
        return $success
    }
    catch {
        Write-Log "ERREUR LORS DE LA VALIDATION: $_" "ERROR"
        return $false
    }
}

# Exécution
Main