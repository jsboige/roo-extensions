# Nettoyage autonome de la documentation superflue
# Consolidation et archivage intelligents selon SDDD

param(
    [string]$ArchivePath = ".\archive\docs-$(Get-Date -Format 'yyyyMMdd')",
    [switch]$Force = $false,
    [switch]$DryRun = $false
)

# Configuration UTF-8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Variables de configuration
$ProjectRoot = $PSScriptRoot
$DocsRoot = ".\docs"
$DiagnosticsRoot = ".\docs\diagnostics"
$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$ReportPath = ".\docs\diagnostics\CLEANUP-REPORT-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
$Script:FileHashes = @{}
$CleanupResults = @{}

# Patterns pour identifier les fichiers superflus
$PatternsToArchive = @(
    "*rapport*",
    "*synthese*", 
    "*analyse*",
    "*checkpoint*",
    "*validation*",
    "*DIAGNOSTIC*",
    "*SDDD*",
    "*temp*",
    "*backup*",
    "*test*"
)

# Patterns pour les fichiers à conserver
$PatternsToKeep = @(
    "README.md",
    "INDEX.md",
    "*.md",
    "!*temp*",
    "!*backup*",
    "!*test*"
)

# Fonction de logging structuré
function Write-CleanupLog {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Category = "CLEANUP"
    )
    
    $LogTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$LogTimestamp] [$Level] [$Category] $Message"
    
    # Affichage console avec couleurs
    switch ($Level) {
        "ERROR" { Write-Host $LogEntry -ForegroundColor Red }
        "WARN" { Write-Host $LogEntry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $LogEntry -ForegroundColor Green }
        "INFO" { Write-Host $LogEntry -ForegroundColor White }
        "DEBUG" { Write-Host $LogEntry -ForegroundColor Gray }
        default { Write-Host $LogEntry -ForegroundColor White }
    }
}

# Fonction d'analyse de documentation
function Get-DocumentationAnalysis {
    Write-CleanupLog "DEBUT analyse documentation complète" -Level "INFO"
    
    $Analysis = @{
        TotalFiles = 0
        TotalSize = 0
        DuplicateFiles = @()
        ObsoleteFiles = @()
        ArchiveCandidates = @()
        FilesToKeep = @()
        Directories = @()
    }
    
    # Vérification que le répertoire docs existe
    if (-not (Test-Path $DocsRoot)) {
        Write-CleanupLog "ERREUR Répertoire documentation non trouvé: $DocsRoot" -Level "ERROR"
        return $Analysis
    }
    
    # Analyse récursive avec boucle foreach
    Get-ChildItem -Path $DocsRoot -Recurse -File | ForEach-Object {
        $Analysis.TotalFiles++
        $Analysis.TotalSize += $_.Length
        
        # Détection des duplications par contenu
        try {
            $Hash = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash
            if ($Script:FileHashes.ContainsKey($Hash)) {
                $Analysis.DuplicateFiles += @{
                    Original = $Script:FileHashes[$Hash]
                    Duplicate = $_.FullName
                    Size = $_.Length
                    Hash = $Hash
                }
            } else {
                $Script:FileHashes[$Hash] = $_.FullName
            }
        } catch {
            Write-CleanupLog "ATTENTION Erreur hash fichier: $($_.FullName)" -Level "WARN"
        }
        
        # Détection des candidats à l'archivage
        $ShouldArchive = $false
        foreach ($Pattern in $PatternsToArchive) {
            if ($_.Name -like $Pattern -and $_.Name -notlike "*README*") {
                $Analysis.ArchiveCandidates += @{
                    Path = $_.FullName
                    Name = $_.Name
                    Size = $_.Length
                    LastModified = $_.LastWriteTime
                    Pattern = $Pattern
                }
                $ShouldArchive = $true
                break
            }
        }
        
        # Identification des fichiers à conserver
        if (-not $ShouldArchive) {
            $Analysis.FilesToKeep += @{
                Path = $_.FullName
                Name = $_.Name
                Size = $_.Length
                LastModified = $_.LastWriteTime
            }
        }
    }
    
    # Analyse des répertoires
    Get-ChildItem -Path $DocsRoot -Recurse -Directory | ForEach-Object {
        $Analysis.Directories += @{
            Path = $_.FullName
            Name = $_.Name
            FileCount = (Get-ChildItem -Path $_.FullName -File | Measure-Object).Count
            LastModified = $_.LastWriteTime
        }
    }
    
    Write-CleanupLog "SUCCES Analyse terminée: $($Analysis.TotalFiles) fichiers, $($Analysis.TotalSize/1MB) MB" -Level "SUCCESS"
    return $Analysis
}

# Fonction d'archivage des fichiers obsolètes
function Archive-ObsoleteFiles {
    param([array]$Files)
    
    Write-CleanupLog "DEBUT archivage fichiers obsolètes" -Level "INFO"
    
    if ($Files.Count -eq 0) {
        Write-CleanupLog "INFO Aucun fichier à archiver" -Level "INFO"
        return @{ ArchivedCount = 0; TotalSize = 0; Errors = @() }
    }
    
    # Création du répertoire d'archive
    if (-not (Test-Path $ArchivePath)) {
        New-Item -Path $ArchivePath -ItemType Directory -Force | Out-Null
        Write-CleanupLog "INFO Création répertoire archive: $ArchivePath" -Level "INFO"
    }
    
    $ArchiveResult = @{
        ArchivedCount = 0
        TotalSize = 0
        Errors = @()
        ArchivedFiles = @()
    }
    
    foreach ($File in $Files) {
        try {
            # Utilisation de Copy-Item au lieu de Move-Item pour éviter les problèmes de chemin
            $FileName = Split-Path $File.Path -Leaf
            $ArchiveFilePath = Join-Path $ArchivePath $FileName
            
            # Gestion des noms dupliqués dans l'archive
            $Counter = 1
            while (Test-Path $ArchiveFilePath) {
                $NameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
                $Extension = [System.IO.Path]::GetExtension($FileName)
                $ArchiveFilePath = Join-Path $ArchivePath "$NameWithoutExt-$Counter$Extension"
                $Counter++
            }
            
            if (-not $DryRun) {
                Copy-Item -Path $File.Path -Destination $ArchiveFilePath -Force
                Remove-Item -Path $File.Path -Force
                $ArchiveResult.ArchivedFiles += @{
                    Original = $File.Path
                    Archived = $ArchiveFilePath
                    Size = $File.Size
                }
                $ArchiveResult.ArchivedCount++
                $ArchiveResult.TotalSize += $File.Size
                
                $SizeKB = [math]::Round($File.Size/1KB, 2)
                Write-CleanupLog "DEBUG Archive: $($File.Name) ($SizeKB KB)" -Level "DEBUG"
            } else {
                $SizeKB = [math]::Round($File.Size/1KB, 2)
                Write-CleanupLog "DEBUG [DRY RUN] Serait archive: $($File.Name) ($SizeKB KB)" -Level "DEBUG"
                $ArchiveResult.ArchivedCount++
                $ArchiveResult.TotalSize += $File.Size
            }
        } catch {
            $ErrorMsg = "Erreur archivage $($File.Path): $($_.Exception.Message)"
            $ArchiveResult.Errors += $ErrorMsg
            Write-CleanupLog $ErrorMsg -Level "ERROR"
        }
    }
    
    $TotalSizeMB = [math]::Round($ArchiveResult.TotalSize/1MB, 2)
    Write-CleanupLog "SUCCES Archivage terminé: $($ArchiveResult.ArchivedCount) fichiers, $TotalSizeMB MB" -Level "SUCCESS"
    return $ArchiveResult
}

# Fonction de création d'index centralisé
function New-CentralizedIndex {
    param([string]$DocsPath)
    
    Write-CleanupLog "DEBUT Création index centralisé documentation" -Level "INFO"
    
    $IndexPath = Join-Path $DocsPath "INDEX.md"
    
    # Construction du contenu avec concaténation simple
    $IndexContent = "# INDEX CENTRALISE DE LA DOCUMENTATION`n"
    $IndexContent += "**Genere le :** $Timestamp`n"
    $IndexContent += "**Script :** cleanup-documentation.ps1`n`n"
    $IndexContent += "---`n`n"
    $IndexContent += "## STRUCTURE DES REPERTOIRES`n`n"
    
    # Ajout de la structure des répertoires
    if (Test-Path $DocsPath) {
        Get-ChildItem -Path $DocsPath -Directory | ForEach-Object {
            $IndexContent += "`n### REPERTOIRE: $($_.Name)`n`n"
            Get-ChildItem -Path $_.FullName -File -Recurse | ForEach-Object {
                $RelativePath = $_.FullName.Replace($DocsPath, "").TrimStart("\", "/")
                $SizeKB = [math]::Round($_.Length / 1KB, 2)
                $IndexContent += "- FICHIER: [$($_.Name)]($RelativePath) ($SizeKB KB)`n"
            }
        }
    }
    
    $IndexContent += "`n---`n`n"
    $IndexContent += "## STATISTIQUES`n`n"
    $IndexContent += "- **Total fichiers analyses :** $($CleanupResults.Analysis.TotalFiles)`n"
    $TotalSizeMB = [math]::Round($CleanupResults.Analysis.TotalSize/1MB, 2)
    $IndexContent += "- **Taille totale :** $TotalSizeMB MB`n"
    $IndexContent += "- **Fichiers archives :** $($CleanupResults.ArchiveResult.ArchivedCount)`n"
    $ArchiveSizeMB = [math]::Round($CleanupResults.ArchiveResult.TotalSize/1MB, 2)
    $IndexContent += "- **Espace libere :** $ArchiveSizeMB MB`n"
    $IndexContent += "- **Fichiers conserves :** $($CleanupResults.Analysis.FilesToKeep.Count)`n`n"
    $IndexContent += "---`n`n"
    $IndexContent += "*Index genere automatiquement par le script de nettoyage SDDD*"
    
    try {
        $IndexContent | Out-File -FilePath $IndexPath -Encoding UTF8
        Write-CleanupLog "SUCCES Index centralisé créé: $IndexPath" -Level "SUCCESS"
        return @{ Success = $true; Path = $IndexPath }
    } catch {
        Write-CleanupLog "ERREUR Erreur création index: $($_.Exception.Message)" -Level "ERROR"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

# Fonction de génération de rapport
function New-CleanupReport {
    param(
        [hashtable]$Results,
        [string]$ArchiveDir
    )
    
    Write-CleanupLog "DEBUT Generation rapport nettoyage documentation" -Level "INFO"
    
    # Construction du rapport avec concaténation simple
    $ReportContent = "# RAPPORT DE NETTOYAGE DOCUMENTATION SDDD`n"
    $ReportContent += "**Genere le :** $Timestamp`n"
    $ReportContent += "**Script :** cleanup-documentation.ps1`n"
    $Mode = if ($DryRun) { "DRY RUN" } else { "EXECUTION REELLE" }
    $ReportContent += "**Mode :** $Mode`n`n"
    $ReportContent += "---`n`n"
    $ReportContent += "## RESUME DE L'OPERATION`n`n"
    
    $ReportContent += "| Metrique | Valeur |`n"
    $ReportContent += "|----------|--------|`n"
    $ReportContent += "| Fichiers analyses | $($Results.Analysis.TotalFiles) |`n"
    $TotalSizeMB = [math]::Round($Results.Analysis.TotalSize/1MB, 2)
    $ReportContent += "| Taille totale analysee | $TotalSizeMB MB |`n"
    $ReportContent += "| Fichiers en double | $($Results.Analysis.DuplicateFiles.Count) |`n"
    $ReportContent += "| Fichiers archives | $($Results.ArchiveResult.ArchivedCount) |`n"
    $ArchiveSizeMB = [math]::Round($Results.ArchiveResult.TotalSize/1MB, 2)
    $ReportContent += "| Espace libere | $ArchiveSizeMB MB |`n"
    $ReportContent += "| Fichiers conserves | $($Results.Analysis.FilesToKeep.Count) |`n"
    $ReportContent += "| Erreurs rencontrees | $($Results.ArchiveResult.Errors.Count) |`n`n"
    
    $ReportContent += "---`n`n"
    $ReportContent += "## DETAILS PAR CATEGORIE`n`n"
    $ReportContent += "### Fichiers Archives`n"
    
    if ($Results.ArchiveResult.ArchivedFiles.Count -gt 0) {
        $Results.ArchiveResult.ArchivedFiles | ForEach-Object {
            $SizeKB = [math]::Round($_.Size / 1KB, 2)
            $FileName = $_.Original.Split('\')[-1]
            $ReportContent += "`n- FICHIER: **$FileName** → $SizeKB KB"
        }
    } else {
        $ReportContent += "`n- INFO Aucun fichier archive"
    }
    
    $ReportContent += "`n`n### Fichiers en Double`n"
    
    if ($Results.Analysis.DuplicateFiles.Count -gt 0) {
        $Results.Analysis.DuplicateFiles | ForEach-Object {
            $ReportContent += "`n- DOUBLE: **Original:** $($_.Original)`n  - **Duplique:** $($_.Duplicate)"
        }
    } else {
        $ReportContent += "`n- SUCCES Aucun fichier en double détecté"
    }
    
    $ReportContent += "`n`n### Fichiers Conserves`n"
    
    if ($Results.Analysis.FilesToKeep.Count -gt 0) {
        $Results.Analysis.FilesToKeep | ForEach-Object {
            $SizeKB = [math]::Round($_.Size / 1KB, 2)
            $ReportContent += "`n- FICHIER: **$($_.Name)** ($SizeKB KB)"
        }
    }
    
    if ($Results.ArchiveResult.Errors.Count -gt 0) {
        $ReportContent += "`n`n---`n`n"
        $ReportContent += "## ERREURS RENCONTREES`n"
        $Results.ArchiveResult.Errors | ForEach-Object {
            $ReportContent += "`n- ERREUR $_"
        }
    }
    
    $ReportContent += "`n`n---`n`n"
    $ReportContent += "## ARCHIVE`n`n"
    $ReportContent += "**Chemin de l'archive :** $ArchiveDir`n"
    $ReportContent += "**Fichiers archives :** $($Results.ArchiveResult.ArchivedCount)`n"
    $ArchiveSizeMB = [math]::Round($Results.ArchiveResult.TotalSize/1MB, 2)
    $ReportContent += "**Espace total libere :** $ArchiveSizeMB MB`n`n"
    
    $ReportContent += "---`n`n"
    $ReportContent += "## PATTERNS UTILISES`n`n"
    $ReportContent += "### Patterns d'archivage :`n"
    $PatternsToArchive | ForEach-Object { $ReportContent += "- $_`n" }
    
    $ReportContent += "`n### Patterns de conservation :`n"
    $PatternsToKeep | ForEach-Object { $ReportContent += "- $_`n" }
    
    $ReportContent += "`n---`n`n"
    $ReportContent += "## RECOMMANDATIONS`n`n"
    $ReportContent += "1. **Verifier le contenu de l'archive** avant suppression definitive`n"
    $ReportContent += "2. **Mettre a jour les references** dans les fichiers conserves`n"
    $ReportContent += "3. **Planifier un nettoyage regulier** (mensuel recommande)`n"
    $ReportContent += "4. **Documenter les patterns** spécifiques à votre projet`n`n"
    $ReportContent += "---`n`n"
    $ReportContent += "*Rapport genere automatiquement par le script de nettoyage SDDD*`n"
    $ReportContent += "*Conformément aux spécifications techniques SDDD*"
    
    try {
        # Création du répertoire diagnostics si nécessaire
        $DiagnosticsDir = Split-Path $ReportPath -Parent
        if (-not (Test-Path $DiagnosticsDir)) {
            New-Item -Path $DiagnosticsDir -ItemType Directory -Force | Out-Null
        }
        
        $ReportContent | Out-File -FilePath $ReportPath -Encoding UTF8
        Write-CleanupLog "SUCCES Rapport généré: $ReportPath" -Level "SUCCESS"
        return @{ Success = $true; Path = $ReportPath }
    } catch {
        Write-CleanupLog "ERREUR Erreur génération rapport: $($_.Exception.Message)" -Level "ERROR"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

# Bloc principal de nettoyage
try {
    Write-CleanupLog "DEBUT NETTOYAGE DOCUMENTATION AUTONOME SDDD" -Level "SUCCESS"
    Write-CleanupLog "Timestamp: $Timestamp" -Level "INFO"
    Write-CleanupLog "Repertoire documentation: $DocsRoot" -Level "INFO"
    Write-CleanupLog "Repertoire archive: $ArchivePath" -Level "INFO"
    
    # Phase 1 : Analyse complète
    Write-CleanupLog "Phase 1 : Analyse documentation existante" -Level "INFO"
    $CleanupResults.Analysis = Get-DocumentationAnalysis
    
    # Phase 2 : Identification duplications
    Write-CleanupLog "Phase 2 : Identification duplications" -Level "INFO"
    $CleanupResults.Duplicates = $CleanupResults.Analysis.DuplicateFiles
    Write-CleanupLog "Duplications trouvées: $($CleanupResults.Duplicates.Count)" -Level "INFO"
    
    # Phase 3 : Archivage fichiers obsolètes
    Write-CleanupLog "Phase 3 : Archivage fichiers obsolètes" -Level "INFO"
    if ($DryRun) {
        Write-CleanupLog "MODE DRY RUN - Aucune modification effectuée" -Level "WARN"
    }
    $CleanupResults.ArchiveResult = Archive-ObsoleteFiles -Files $CleanupResults.Analysis.ArchiveCandidates
    
    # Phase 4 : Création index centralisé
    Write-CleanupLog "Phase 4 : Création index centralisé" -Level "INFO"
    $CleanupResults.IndexResult = New-CentralizedIndex -DocsPath $DocsRoot
    
    # Phase 5 : Génération rapport
    Write-CleanupLog "Phase 5 : Génération rapport nettoyage" -Level "INFO"
    $CleanupResults.ReportResult = New-CleanupReport -Results $CleanupResults -ArchiveDir $ArchivePath
    
    # Phase 6 : Affichage résumé final
    Write-CleanupLog "" -Level "INFO"
    Write-CleanupLog "RESUME FINAL DU NETTOYAGE" -Level "SUCCESS"
    Write-CleanupLog "========================================" -Level "SUCCESS"
    Write-CleanupLog "Fichiers analyses : $($CleanupResults.Analysis.TotalFiles)" -Level "INFO"
    $TotalSizeMB = [math]::Round($CleanupResults.Analysis.TotalSize/1MB, 2)
    Write-CleanupLog "Taille totale : $TotalSizeMB MB" -Level "INFO"
    Write-CleanupLog "Fichiers en double : $($CleanupResults.Duplicates.Count)" -Level "INFO"
    Write-CleanupLog "Fichiers archives : $($CleanupResults.ArchiveResult.ArchivedCount)" -Level "INFO"
    $ArchiveSizeMB = [math]::Round($CleanupResults.ArchiveResult.TotalSize/1MB, 2)
    Write-CleanupLog "Espace libere : $ArchiveSizeMB MB" -Level "INFO"
    Write-CleanupLog "Fichiers conserves : $($CleanupResults.Analysis.FilesToKeep.Count)" -Level "INFO"
    Write-CleanupLog "Erreurs : $($CleanupResults.ArchiveResult.Errors.Count)" -Level "INFO"
    Write-CleanupLog "" -Level "INFO"
    Write-CleanupLog "Rapport détaillé : $ReportPath" -Level "INFO"
    Write-CleanupLog "Archive créée : $ArchivePath" -Level "INFO"
    Write-CleanupLog "" -Level "INFO"
    
    if ($CleanupResults.ArchiveResult.Errors.Count -gt 0) {
        Write-CleanupLog "ATTENTION NETTOYAGE TERMINE AVEC ERREURS" -Level "WARN"
        exit 1
    } else {
        Write-CleanupLog "SUCCES NETTOYAGE DOCUMENTATION TERMINE AVEC SUCCES" -Level "SUCCESS"
    }
}
catch {
    Write-CleanupLog "ERREUR CRITIQUE NETTOYAGE : $($_.Exception.Message)" -Level "ERROR"
    Write-CleanupLog "Stack Trace : $($_.ScriptStackTrace)" -Level "ERROR"
    exit 1
}