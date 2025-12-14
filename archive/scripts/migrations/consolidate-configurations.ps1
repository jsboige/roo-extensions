#!/usr/bin/env pwsh
# Script de consolidation des configurations - Phase 5

param(
    [switch]$DryRun = $false,
    [switch]$Verbose = $false
)

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

# Chemins de base
$rootPath = "c:/dev/roo-extensions"
$rooModesConfigs = "$rootPath/roo-modes/configs"
$rooConfigModes = "$rootPath/roo-config/modes"
$encodingFixPath = "$rootPath/encoding-fix"
$backupPath = "$rootPath/cleanup-backups/20250527-012300/phase5"
$logFile = "$backupPath/consolidation-log-$timestamp.txt"

# Fonction de logging
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
    Write-Host $logEntry
    if (Test-Path (Split-Path $logFile -Parent)) {
        Add-Content -Path $logFile -Value $logEntry
    }
}

# Fonction pour comparer deux fichiers JSON
function Compare-JsonFiles {
    param([string]$File1, [string]$File2)
    
    try {
        $content1 = Get-Content $File1 -Raw | ConvertFrom-Json
        $content2 = Get-Content $File2 -Raw | ConvertFrom-Json
        
        $json1 = $content1 | ConvertTo-Json -Depth 100 -Compress
        $json2 = $content2 | ConvertTo-Json -Depth 100 -Compress
        
        return @{
            Identical = ($json1 -eq $json2)
            Size1 = (Get-Item $File1).Length
            Size2 = (Get-Item $File2).Length
            LastWrite1 = (Get-Item $File1).LastWriteTime
            LastWrite2 = (Get-Item $File2).LastWriteTime
        }
    }
    catch {
        Write-Log "Erreur lors de la comparaison de $File1 et $File2 : $_" "ERROR"
        return $null
    }
}

# Fonction principale
function Main {
    Write-Log "DEBUT DE LA CONSOLIDATION DES CONFIGURATIONS - PHASE 5" "INFO"
    Write-Log "Timestamp: $timestamp" "INFO"
    Write-Log "Mode: $(if ($DryRun) { 'DRY-RUN' } else { 'EXECUTION' })" "INFO"
    
    # Créer le répertoire de log
    New-Item -Path $backupPath -ItemType Directory -Force | Out-Null
    
    # Initialiser le fichier de log
    "Log de Consolidation des Configurations - Phase 5" | Set-Content -Path $logFile -Encoding UTF8
    "Timestamp: $timestamp" | Add-Content -Path $logFile
    "Mode: $(if ($DryRun) { 'DRY-RUN' } else { 'EXECUTION' })" | Add-Content -Path $logFile
    "" | Add-Content -Path $logFile
    
    try {
        # 1. Analyser les doublons
        Write-Log "=== ANALYSE DES DOUBLONS ===" "INFO"
        
        $newRooModes = "$rooModesConfigs/new-roomodes.json"
        $vscodeCustom = "$rooModesConfigs/vscode-custom-modes.json"
        
        if ((Test-Path $newRooModes) -and (Test-Path $vscodeCustom)) {
            $comparison = Compare-JsonFiles $newRooModes $vscodeCustom
            if ($comparison -and $comparison.Identical) {
                Write-Log "DOUBLON IDENTIFIE: new-roomodes.json et vscode-custom-modes.json sont identiques" "WARN"
                Write-Log "new-roomodes.json: $($comparison.Size1) bytes, modifie: $($comparison.LastWrite1)" "INFO"
                Write-Log "vscode-custom-modes.json: $($comparison.Size2) bytes, modifie: $($comparison.LastWrite2)" "INFO"
                
                $keepFile = if ($comparison.LastWrite1 -gt $comparison.LastWrite2) { $newRooModes } else { $vscodeCustom }
                $removeFile = if ($keepFile -eq $newRooModes) { $vscodeCustom } else { $newRooModes }
                
                Write-Log "Action: Garder $keepFile, supprimer $removeFile" "INFO"
                
                if (-not $DryRun) {
                    $backupFile = "$backupPath/duplicates/$(Split-Path $removeFile -Leaf)"
                    New-Item -Path (Split-Path $backupFile -Parent) -ItemType Directory -Force | Out-Null
                    Copy-Item $removeFile $backupFile -Force
                    Remove-Item $removeFile -Force
                    Write-Log "Doublon supprime et sauvegarde" "SUCCESS"
                }
            } else {
                Write-Log "Les fichiers new-roomodes.json et vscode-custom-modes.json sont differents" "INFO"
            }
        }
        
        # 2. Analyser standard-modes.json
        Write-Log "=== ANALYSE DES FICHIERS STANDARD-MODES ===" "INFO"
        
        $rooModesStandard = "$rooModesConfigs/standard-modes.json"
        $rooConfigStandard = "$rooConfigModes/standard-modes.json"
        
        if ((Test-Path $rooModesStandard) -and (Test-Path $rooConfigStandard)) {
            $rooModesInfo = Get-Item $rooModesStandard
            $rooConfigInfo = Get-Item $rooConfigStandard
            
            Write-Log "roo-modes/configs/standard-modes.json: $($rooModesInfo.Length) bytes, modifie: $($rooModesInfo.LastWriteTime)" "INFO"
            Write-Log "roo-config/modes/standard-modes.json: $($rooConfigInfo.Length) bytes, modifie: $($rooConfigInfo.LastWriteTime)" "INFO"
            
            $comparison = Compare-JsonFiles $rooModesStandard $rooConfigStandard
            if ($comparison) {
                if ($comparison.Identical) {
                    Write-Log "Les deux fichiers standard-modes.json sont identiques" "INFO"
                    
                    $keepFile = if ($rooModesInfo.LastWriteTime -gt $rooConfigInfo.LastWriteTime) { $rooModesStandard } else { $rooConfigStandard }
                    $removeFile = if ($keepFile -eq $rooModesStandard) { $rooConfigStandard } else { $rooModesStandard }
                    
                    Write-Log "Action: Garder $keepFile, supprimer $removeFile" "INFO"
                    
                    if (-not $DryRun) {
                        $backupFile = "$backupPath/identical/$(Split-Path $removeFile -Leaf)"
                        New-Item -Path (Split-Path $backupFile -Parent) -ItemType Directory -Force | Out-Null
                        Copy-Item $removeFile $backupFile -Force
                        Remove-Item $removeFile -Force
                        Write-Log "Fichier identique supprime et sauvegarde" "SUCCESS"
                    }
                } else {
                    Write-Log "Les fichiers standard-modes.json different - fusion manuelle necessaire" "WARN"
                    $recommendedKeep = if ($rooModesInfo.LastWriteTime -gt $rooConfigInfo.LastWriteTime) { $rooModesStandard } else { $rooConfigStandard }
                    Write-Log "Recommandation: garder $recommendedKeep (plus recent)" "INFO"
                }
            }
        }
        
        # 3. Traiter encoding-fix
        Write-Log "=== TRAITEMENT DU REPERTOIRE ENCODING-FIX ===" "INFO"
        
        if (Test-Path $encodingFixPath) {
            Write-Log "Source: $encodingFixPath" "INFO"
            Write-Log "Scripts -> $rootPath/roo-config/scripts/encoding" "INFO"
            Write-Log "Archive -> $rootPath/roo-config/archive/encoding-fix" "INFO"
            
            if (-not $DryRun) {
                # Créer les répertoires cibles
                New-Item -Path "$rootPath/roo-config/scripts/encoding" -ItemType Directory -Force | Out-Null
                New-Item -Path "$rootPath/roo-config/archive/encoding-fix" -ItemType Directory -Force | Out-Null
                
                # Scripts essentiels à déplacer
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
                
                # Déplacer les scripts essentiels
                foreach ($script in $essentialScripts) {
                    $sourcePath = "$encodingFixPath/$script"
                    if (Test-Path $sourcePath) {
                        $targetPath = "$rootPath/roo-config/scripts/encoding/$script"
                        Copy-Item $sourcePath $targetPath -Force
                        Write-Log "Script deplace: $script" "SUCCESS"
                    } else {
                        Write-Log "Script non trouve: $script" "WARN"
                    }
                }
                
                # Archiver la documentation
                $docFiles = Get-ChildItem "$encodingFixPath/*.md" -ErrorAction SilentlyContinue
                foreach ($doc in $docFiles) {
                    $targetPath = "$rootPath/roo-config/archive/encoding-fix/$($doc.Name)"
                    Copy-Item $doc.FullName $targetPath -Force
                    Write-Log "Documentation archivee: $($doc.Name)" "SUCCESS"
                }
            }
        }
        
        Write-Log "CONSOLIDATION TERMINEE AVEC SUCCES" "SUCCESS"
        Write-Log "Log detaille: $logFile" "INFO"
        
        return $true
    }
    catch {
        Write-Log "ERREUR LORS DE LA CONSOLIDATION: $_" "ERROR"
        return $false
    }
}

# Exécution
Main