# Script de déploiement de l'orchestration dynamique bidirectionnelle
# Validation et déploiement des configurations mises à jour

param(
    [switch]$ValidateOnly,
    [switch]$Force
)

# Fonctions de validation

function Test-JsonFileValidity {
    param(
        [string]$Path
    )
    Write-Host "  Vérification du fichier JSON: $Path"
    try {
        $fileContent = Get-Content $Path -Raw -Encoding UTF8
        # Supprimer le BOM si présent
        $fileContent = $fileContent.Trim([char]0xFEFF)
        $fileContent | ConvertFrom-Json -ErrorAction Stop | Out-Null
        Write-Host "    [OK] Fichier JSON valide." -ForegroundColor Green
        return $true
    } catch {
        Write-Host "    [ERREUR] Fichier JSON invalide: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Test-OrchestrationInstructions {
    param(
        [string]$Path
    )
    Write-Host "  Contrôle des instructions d'orchestration dans: $Path"
    try {
        $fileContent = Get-Content $Path -Raw -Encoding UTF8
        # Supprimer le BOM si présent
        $fileContent = $fileContent.Trim([char]0xFEFF)
        $content = $fileContent | ConvertFrom-Json
        # Supposons que les instructions d'orchestration se trouvent dans une propriété 'instructions' ou 'prompt'
        # et contiennent le mot "orchestration"
        $hasOrchestration = $false
        if ($content.instructions -like "*orchestration*" -or $content.prompt -like "*orchestration*") {
            $hasOrchestration = $true
        }
        
        # Pour les fichiers de modes, nous pouvons vérifier les 'model_instructions'
        if ($content.modes) {
            foreach ($mode in $content.modes) {
                if ($mode.model_instructions -like "*orchestration*") {
                    $hasOrchestration = $true
                    break
                }
            }
        }

        if ($hasOrchestration) {
            Write-Host "    [OK] Instructions d'orchestration trouvées." -ForegroundColor Green
            return $true
        } else {
            Write-Host "    [AVERTISSEMENT] Aucune instruction d'orchestration spécifique trouvée." -ForegroundColor Yellow
            return $false
        }
    } catch {
        Write-Host "    [ERREUR] Impossible de lire ou d'analyser le fichier pour les instructions: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Test-ArchitectureConsistency {
    param(
        [string]$StandardConfigPath,
        [string]$N5ConfigPath
    )
    Write-Host "  Vérification de la cohérence entre les architectures:"
    Write-Host "    Standard: $StandardConfigPath"
    Write-Host "    N5: $N5ConfigPath"

    try {
        $standardConfig = Get-Content $StandardConfigPath | ConvertFrom-Json
        $n5Config = Get-Content $N5ConfigPath | ConvertFrom-Json

        # Exemple de vérification : comparer les noms des modes
        $standardModeNames = $standardConfig.customModes.slug | Sort-Object
        $n5ModeNames = $n5Config.customModes.slug | Sort-Object

        $diff = Compare-Object $standardModeNames $n5ModeNames

        if ($null -eq $diff) {
            Write-Host "    [OK] Cohérence des noms de modes vérifiée." -ForegroundColor Green
            return $true
        } else {
            Write-Host "    [AVERTISSEMENT] Incohérences détectées dans les noms de modes:" -ForegroundColor Yellow
            $diff | ForEach-Object {
                Write-Host "      $($_.SideIndicator) $($_.InputObject)" -ForegroundColor Yellow
            }
            return $false
        }
    } catch {
        Write-Host "    [ERREUR] Impossible de vérifier la cohérence: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Fonctions de sauvegarde

function New-Backup {
    param(
        [string]$SourcePath,
        [string]$BackupPath
    )
    Write-Host "  Création de la sauvegarde de $SourcePath vers $BackupPath"
    try {
        if (-not (Test-Path $BackupPath)) {
            New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
        }
        Copy-Item -Path $SourcePath -Destination $BackupPath -Recurse -Force -ErrorAction Stop | Out-Null
        Write-Host "    [OK] Sauvegarde créée avec succès." -ForegroundColor Green
        return $true
    } catch {
        Write-Host "    [ERREUR] Échec de la création de la sauvegarde: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Fonctions de déploiement

function Deploy-Configurations {
    param(
        [string]$SourcePath,
        [string]$DestinationPath
    )
    Write-Host "  Déploiement de $SourcePath vers $DestinationPath"
    try {
        Copy-Item -Path $SourcePath -Destination $DestinationPath -Recurse -Force -ErrorAction Stop | Out-Null
        Write-Host "    [OK] Déploiement effectué avec succès." -ForegroundColor Green
        return $true
    } catch {
        Write-Host "    [ERREUR] Échec du déploiement: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Verify-DeploymentIntegrity {
    param(
        [string]$SourcePath,
        [string]$DestinationPath
    )
    Write-Host "  Vérification de l'intégrité du déploiement entre $SourcePath et $DestinationPath"
    try {
        $sourceFiles = Get-ChildItem $SourcePath -Recurse | Where-Object { -not $_.PSIsContainer }
        $destinationFiles = Get-ChildItem $DestinationPath -Recurse | Where-Object { -not $_.PSIsContainer }

        $allGood = $true

        foreach ($sFile in $sourceFiles) {
            $relativePath = $sFile.FullName.Substring($SourcePath.Length).TrimStart('\')
            $dFile = Join-Path $DestinationPath $relativePath

            if (-not (Test-Path $dFile)) {
                Write-Host "    [ERREUR] Fichier manquant dans la destination: $relativePath" -ForegroundColor Red
                $allGood = $false
                continue
            }
            if ((Get-Item $sFile).Length -ne (Get-Item $dFile).Length) {
                Write-Host "    [AVERTISSEMENT] Taille de fichier différente pour: $relativePath" -ForegroundColor Yellow
                $allGood = $false
            }
            # Potentiellement ajouter une vérification de hachage ici pour une intégrité plus robuste
        }

        if ($allGood) {
            Write-Host "    [OK] Intégrité du déploiement vérifiée." -ForegroundColor Green
            return $true
        } else {
            Write-Host "    [ERREUR] Discrépances détectées lors de la vérification de l'intégrité." -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "    [ERREUR] Impossible de vérifier l'intégrité du déploiement: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Génération du rapport

function Generate-ValidationReport {
    param(
        [array]$ValidationResults,
        [array]$DeploymentResults,
        [string]$ReportPath
    )
    $timestamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
    $reportFileName = "validation-report-$timestamp.md"
    $fullReportPath = Join-Path $ReportPath $reportFileName

    Write-Host "  Génération du rapport de validation: $fullReportPath"

    $reportContent = @"
# Rapport de Validation et de Déploiement de l'Orchestration Dynamique

**Date et Heure :** $timestamp

## Résultat de la Validation des Configurations

| Test                     | Résultat | Détails                                 |
|--------------------------|----------|-----------------------------------------|
$(
$ValidationResults | ForEach-Object {
    "| $($_.TestName) | $($_.Result) | $($_.Details) |"
}
)

## Résultat du Déploiement

| Opération                | Résultat | Détails                                 |
|--------------------------|----------|-----------------------------------------|
$(
$DeploymentResults | ForEach-Object {
    "| $($_.Operation) | $($_.Result) | $($_.Details) |"
}
)

## Modifications Apportées (Résumé)
- Fichiers JSON validés et copiés.
- Sauvegardes créées dans le dossier de sauvegarde.

## Confirmation du Succès
$(
    if ($ValidationResults.Where({$_.Result -eq 'ERREUR'}).Count -eq 0 -and $DeploymentResults.Where({$_.Result -eq 'ERREUR'}).Count -eq 0) {
        "Le script a terminé son exécution avec succès. Toutes les validations ont réussi et le déploiement a été effectué."
    } else {
        "Des erreurs ou des avertissements ont été détectés. Veuillez consulter le rapport pour plus de détails."
    }
)
"@

    try {
        $reportContent | Set-Content $fullReportPath -Encoding UTF8 -Force
        Write-Host "    [OK] Rapport généré avec succès." -ForegroundColor Green
        return $true
    } catch {
        Write-Host "    [ERREUR] Échec de la génération du rapport: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}


# Logique principale du script

$ValidationResults = @()
$DeploymentResults = @()

# --- Chemins des configurations (à ajuster si nécessaire) ---
$StandardConfigPath = "roo-config/modes/standard-modes.json"
$N5ConfigPath = "roo-modes/n5/configs/n5-modes-roo-compatible.json"
$BackupDirectory = ".\backups"
$DeploymentDestinationDirectory = ".\deployed-configs" # Exemple de destination, à adapter

# --- Validation des configurations ---
Write-Host "`n--- Démarrage de la Validation des Configurations ---`n"

# 1. Vérifier que les fichiers JSON sont valides
$jsonValidationStandard = Test-JsonFileValidity -Path $StandardConfigPath
$resultStandardJson = if ($jsonValidationStandard) {"SUCCÈS"} else {"ERREUR"}
$ValidationResults += @{ TestName = "Validation JSON (Standard)"; Result = $resultStandardJson; Details = "Fichier: $StandardConfigPath" }

$jsonValidationN5 = Test-JsonFileValidity -Path $N5ConfigPath
$resultN5Json = if ($jsonValidationN5) {"SUCCÈS"} else {"ERREUR"}
$ValidationResults += @{ TestName = "Validation JSON (N5)"; Result = $resultN5Json; Details = "Fichier: $N5ConfigPath" }

# 2. Contrôler la présence des instructions d'orchestration dans les prompts
$orchestrationCheckStandard = Test-OrchestrationInstructions -Path $StandardConfigPath
$resultOrchestrationStandard = if ($orchestrationCheckStandard) {"SUCCÈS"} else {"AVERTISSEMENT"}
$ValidationResults += @{ TestName = "Instructions Orchestration (Standard)"; Result = $resultOrchestrationStandard; Details = "Fichier: $StandardConfigPath" }

$orchestrationCheckN5 = Test-OrchestrationInstructions -Path $N5ConfigPath
$resultOrchestrationN5 = if ($orchestrationCheckN5) {"SUCCÈS"} else {"AVERTISSEMENT"}
$ValidationResults += @{ TestName = "Instructions Orchestration (N5)"; Result = $resultOrchestrationN5; Details = "Fichier: $N5ConfigPath" }

# 3. Valider la cohérence entre les architectures standard et N5
$consistencyCheck = Test-ArchitectureConsistency -StandardConfigPath $StandardConfigPath -N5ConfigPath $N5ConfigPath
$resultConsistency = if ($consistencyCheck) {"SUCCÈS"} else {"ERREUR"}
$ValidationResults += @{ TestName = "Cohérence Architectures"; Result = $resultConsistency; Details = "Fichiers: Standard et N5" }

Write-Host "`n--- Fin de la Validation des Configurations ---`n"

# Vérifier si toutes les validations critiques ont réussi
$allCriticalValidationsPassed = $jsonValidationStandard -and $jsonValidationN5 -and $consistencyCheck

if (-not $allCriticalValidationsPassed) {
    Write-Host "`n[ERREUR] Des validations critiques ont échoué. Le déploiement ne sera pas effectué." -ForegroundColor Red
    Generate-ValidationReport -ValidationResults $ValidationResults -DeploymentResults $DeploymentResults -ReportPath ".\docs"
    exit 1
}

# --- Déploiement sécurisé ---
if ($ValidateOnly) {
    Write-Host "`nLe mode 'Validation Seule' est activé. Le déploiement ne sera pas effectué." -ForegroundColor Cyan
} else {
    Write-Host "`n--- Démarrage du Déploiement ---`n"

    if (-not $Force) {
        $confirm = Read-Host "Confirmez-vous le déploiement des configurations (O/N)?"
        if ($confirm -ne 'O') {
            Write-Host "Déploiement annulé par l'utilisateur." -ForegroundColor Yellow
            Generate-ValidationReport -ValidationResults $ValidationResults -DeploymentResults $DeploymentResults -ReportPath ".\docs"
            exit 0
        }
    }

    # Créer le répertoire de sauvegarde horodaté
    $timestamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
    $currentBackupPath = Join-Path $BackupDirectory "backup-$timestamp"
    
    # 1. Créer des sauvegardes avant déploiement
    $backupStandard = New-Backup -SourcePath $StandardConfigPath -BackupPath $currentBackupPath
    $resultBackupStandard = if ($backupStandard) {"SUCCÈS"} else {"ERREUR"}
    $DeploymentResults += @{ Operation = "Sauvegarde Standard"; Result = $resultBackupStandard; Details = "Source: $StandardConfigPath" }

    $backupN5 = New-Backup -SourcePath $N5ConfigPath -BackupPath $currentBackupPath
    $resultBackupN5 = if ($backupN5) {"SUCCÈS"} else {"ERREUR"}
    $DeploymentResults += @{ Operation = "Sauvegarde N5"; Result = $resultBackupN5; Details = "Source: $N5ConfigPath" }

    if (-not ($backupStandard -and $backupN5)) {
        Write-Host "`n[ERREUR] Échec de la création des sauvegardes. Le déploiement est annulé." -ForegroundColor Red
        Generate-ValidationReport -ValidationResults $ValidationResults -DeploymentResults $DeploymentResults -ReportPath ".\docs"
        exit 1
    }

    # 2. Copier les configurations mises à jour
    # Assurez-vous que le répertoire de destination existe
    if (-not (Test-Path $DeploymentDestinationDirectory)) {
        New-Item -ItemType Directory -Path $DeploymentDestinationDirectory -Force | Out-Null
    }

    $deployStandard = Deploy-Configurations -SourcePath $StandardConfigPath -DestinationPath (Join-Path $DeploymentDestinationDirectory (Split-Path $StandardConfigPath -Leaf))
    $resultDeployStandard = if ($deployStandard) {"SUCCÈS"} else {"ERREUR"}
    $DeploymentResults += @{ Operation = "Déploiement Standard"; Result = $resultDeployStandard; Details = "Source: $StandardConfigPath, Destination: $DeploymentDestinationDirectory" }

    $deployN5 = Deploy-Configurations -SourcePath $N5ConfigPath -DestinationPath (Join-Path $DeploymentDestinationDirectory (Split-Path $N5ConfigPath -Leaf))
    $resultDeployN5 = if ($deployN5) {"SUCCÈS"} else {"ERREUR"}
    $DeploymentResults += @{ Operation = "Déploiement N5"; Result = $resultDeployN5; Details = "Source: $N5ConfigPath, Destination: $DeploymentDestinationDirectory" }

    if (-not ($deployStandard -and $deployN5)) {
        Write-Host "`n[ERREUR] Échec du déploiement des configurations." -ForegroundColor Red
        Generate-ValidationReport -ValidationResults $ValidationResults -DeploymentResults $DeploymentResults -ReportPath ".\docs"
        exit 1
    }

    # 3. Vérifier l'intégrité après déploiement
    $verifyStandard = Verify-DeploymentIntegrity -SourcePath $StandardConfigPath -DestinationPath (Join-Path $DeploymentDestinationDirectory (Split-Path $StandardConfigPath -Leaf))
    $resultVerifyStandard = if ($verifyStandard) {"SUCCÈS"} else {"ERREUR"}
    $DeploymentResults += @{ Operation = "Vérification Intégrité Standard"; Result = $resultVerifyStandard; Details = "Source: $StandardConfigPath, Destination: $DeploymentDestinationDirectory" }

    $verifyN5 = Verify-DeploymentIntegrity -SourcePath $N5ConfigPath -DestinationPath (Join-Path $DeploymentDestinationDirectory (Split-Path $N5ConfigPath -Leaf))
    $resultVerifyN5 = if ($verifyN5) {"SUCCÈS"} else {"ERREUR"}
    $DeploymentResults += @{ Operation = "Vérification Intégrité N5"; Result = $resultVerifyN5; Details = "Source: $N5ConfigPath, Destination: $DeploymentDestinationDirectory" }

    Write-Host "`n--- Fin du Déploiement ---`n"
}

# --- Génération du rapport de validation ---
Write-Host "`n--- Génération du Rapport ---`n"
$reportGenerated = Generate-ValidationReport -ValidationResults $ValidationResults -DeploymentResults $DeploymentResults -ReportPath ".\docs"

if ($reportGenerated) {
    Write-Host "`nScript terminé. Veuillez consulter le rapport pour un résumé détaillé." -ForegroundColor Green
} else {
    Write-Host "`nScript terminé avec des erreurs lors de la génération du rapport." -ForegroundColor Red
}

exit 0