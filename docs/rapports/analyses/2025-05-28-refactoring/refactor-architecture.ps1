# Script de Refactorisation Architecturale
# Fichier : refactor-architecture.ps1
# Version: 1.0
# Date: 2025-05-28
# Description: Refactorise le système pour utiliser des chemins relatifs et le rendre portable

param(
    [switch]$DryRun = $false,
    [switch]$Verbose = $false,
    [string]$Phase = "1"  # 1, 2, 3, ou "all"
)

# Configuration
$BackupDir = "refactor-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$LogFile = "refactor-log-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
$ReportFile = "refactor-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"

# Initialisation
$Global:RefactorLog = @()
$Global:ModifiedFiles = @()
$Global:Errors = @()

function Write-RefactorLog {
    param([string]$Message, [string]$Level = "INFO")
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    Write-Host $logEntry -ForegroundColor $(
        switch ($Level) {
            "ERROR" { "Red" }
            "WARNING" { "Yellow" }
            "SUCCESS" { "Green" }
            "CRITICAL" { "Magenta" }
            default { "White" }
        }
    )
    
    $Global:RefactorLog += $logEntry
    Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8
}

function Backup-File {
    param([string]$FilePath)
    
    try {
        $relativePath = $FilePath.Replace((Get-Location).Path + "\", "")
        $backupPath = Join-Path $BackupDir $relativePath
        $backupDirPath = Split-Path $backupPath -Parent
        
        if (!(Test-Path $backupDirPath)) {
            New-Item -ItemType Directory -Path $backupDirPath -Force | Out-Null
        }
        
        Copy-Item -Path $FilePath -Destination $backupPath -Force
        Write-RefactorLog "Sauvegarde créée: $backupPath"
        return $true
    } catch {
        Write-RefactorLog "Erreur lors de la sauvegarde de $FilePath : $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Refactor-PowerShellScript {
    param([string]$FilePath)
    
    try {
        $content = Get-Content -Path $FilePath -Raw -Encoding UTF8
        $originalContent = $content
        $modified = $false
        
        # Refactorisation 1: Variables de chemin principal
        if ($content -match '\$RepoPath\s*=\s*"[^"]*roo-extensions[^"]*"') {
            $content = $content -replace '\$RepoPath\s*=\s*"[^"]*roo-extensions[^"]*"', '$RepoPath = $PSScriptRoot'
            $modified = $true
            Write-RefactorLog "Refactorisé: Variable RepoPath vers PSScriptRoot"
        }
        
        # Refactorisation 2: Variables BasePath
        if ($content -match 'BasePath\s*=\s*"[^"]*roo-extensions[^"]*"') {
            $content = $content -replace 'BasePath\s*=\s*"[^"]*roo-extensions[^"]*"', 'BasePath = $PSScriptRoot'
            $modified = $true
            Write-RefactorLog "Refactorisé: Variable BasePath vers PSScriptRoot"
        }
        
        # Refactorisation 3: LogFile et ConflictLogDir relatifs
        if ($content -match '\$LogFile\s*=\s*"[^"]*roo-extensions[^"]*"') {
            $content = $content -replace '\$LogFile\s*=\s*"[^"]*roo-extensions([^"]*)"', '$LogFile = Join-Path $PSScriptRoot "$1"'
            $modified = $true
            Write-RefactorLog "Refactorisé: Variable LogFile vers chemin relatif"
        }
        
        if ($content -match '\$ConflictLogDir\s*=\s*"[^"]*roo-extensions([^"]*)"') {
            $content = $content -replace '\$ConflictLogDir\s*=\s*"[^"]*roo-extensions([^"]*)"', '$ConflictLogDir = Join-Path $PSScriptRoot "$1"'
            $modified = $true
            Write-RefactorLog "Refactorisé: Variable ConflictLogDir vers chemin relatif"
        }
        
        # Refactorisation 4: Set-Location vers chemin relatif
        if ($content -match 'Set-Location\s+"[^"]*roo-extensions[^"]*"') {
            $content = $content -replace 'Set-Location\s+"[^"]*roo-extensions[^"]*"', 'Set-Location $PSScriptRoot'
            $modified = $true
            Write-RefactorLog "Refactorisé: Set-Location vers PSScriptRoot"
        }
        
        # Refactorisation 5: Commentaires d'en-tête
        if ($content -match '#\s*Fichier\s*:\s*[^/\\]*[/\\]roo-extensions') {
            $relativePath = $FilePath.Replace((Get-Location).Path + "\", "").Replace("\", "/")
            $content = $content -replace '#\s*Fichier\s*:\s*[^/\\]*[/\\]roo-extensions([^\r\n]*)', "# Fichier : ./$relativePath"
            $modified = $true
            Write-RefactorLog "Refactorisé: Commentaire d'en-tête vers chemin relatif"
        }
        
        if ($modified) {
            if (!$DryRun) {
                if (Backup-File $FilePath) {
                    [System.IO.File]::WriteAllText($FilePath, $content, [System.Text.UTF8Encoding]::new($false))
                    Write-RefactorLog "Script PowerShell refactorisé: $FilePath" "SUCCESS"
                    return @{ Success = $true; Modified = $true }
                }
            } else {
                Write-RefactorLog "[DRY RUN] Aurait refactorisé: $FilePath" "INFO"
                return @{ Success = $true; Modified = $true }
            }
        }
        
        return @{ Success = $true; Modified = $false }
        
    } catch {
        $errorMsg = "Erreur lors de la refactorisation de $FilePath : $($_.Exception.Message)"
        Write-RefactorLog $errorMsg "ERROR"
        $Global:Errors += $errorMsg
        return @{ Success = $false; Modified = $false }
    }
}

function Refactor-JsonConfig {
    param([string]$FilePath)
    
    try {
        $content = Get-Content -Path $FilePath -Raw -Encoding UTF8
        $originalContent = $content
        $modified = $false
        
        # Refactorisation: repository_path vers chemin dynamique
        if ($content -match '"repository_path"\s*:\s*"[^"]*roo-extensions[^"]*"') {
            # Pour l'instant, on utilise une variable d'environnement ou un placeholder
            $content = $content -replace '"repository_path"\s*:\s*"[^"]*roo-extensions[^"]*"', '"repository_path": "{{DYNAMIC_BASE_PATH}}"'
            $modified = $true
            Write-RefactorLog "Refactorisé: repository_path vers placeholder dynamique"
        }
        
        # Refactorisation: Commandes MCP vers chemins relatifs
        if ($content -match '"command"\s*:\s*"[^"]*roo-extensions') {
            $content = $content -replace '"command"\s*:\s*"[^"]*roo-extensions([^"]*)"', '"command": "{{DYNAMIC_BASE_PATH}}$1"'
            $modified = $true
            Write-RefactorLog "Refactorisé: Commandes MCP vers chemins dynamiques"
        }
        
        if ($modified) {
            if (!$DryRun) {
                if (Backup-File $FilePath) {
                    [System.IO.File]::WriteAllText($FilePath, $content, [System.Text.UTF8Encoding]::new($false))
                    Write-RefactorLog "Configuration JSON refactorisée: $FilePath" "SUCCESS"
                    return @{ Success = $true; Modified = $true }
                }
            } else {
                Write-RefactorLog "[DRY RUN] Aurait refactorisé: $FilePath" "INFO"
                return @{ Success = $true; Modified = $true }
            }
        }
        
        return @{ Success = $true; Modified = $false }
        
    } catch {
        $errorMsg = "Erreur lors de la refactorisation de $FilePath : $($_.Exception.Message)"
        Write-RefactorLog $errorMsg "ERROR"
        $Global:Errors += $errorMsg
        return @{ Success = $false; Modified = $false }
    }
}

function Refactor-Documentation {
    param([string]$FilePath)
    
    try {
        $content = Get-Content -Path $FilePath -Raw -Encoding UTF8
        $originalContent = $content
        $modified = $false
        
        # Refactorisation: Remplacer les chemins absolus par des exemples génériques
        if ($content -match '[cd]\s+[a-zA-Z]:[/\\][^/\\]*roo-extensions') {
            $content = $content -replace '[cd]\s+[a-zA-Z]:[/\\][^/\\]*roo-extensions[^/\\]*', 'cd $ROO_EXTENSIONS_PATH'
            $modified = $true
            Write-RefactorLog "Refactorisé: Commandes cd vers variable d'environnement"
        }
        
        # Refactorisation: Chemins dans la documentation
        if ($content -match '[a-zA-Z]:[/\\][^/\\]*roo-extensions') {
            $content = $content -replace '[a-zA-Z]:[/\\][^/\\]*roo-extensions([^/\\]*)', './roo-extensions$1'
            $modified = $true
            Write-RefactorLog "Refactorisé: Chemins absolus vers chemins relatifs dans documentation"
        }
        
        if ($modified) {
            if (!$DryRun) {
                if (Backup-File $FilePath) {
                    [System.IO.File]::WriteAllText($FilePath, $content, [System.Text.UTF8Encoding]::new($false))
                    Write-RefactorLog "Documentation refactorisée: $FilePath" "SUCCESS"
                    return @{ Success = $true; Modified = $true }
                }
            } else {
                Write-RefactorLog "[DRY RUN] Aurait refactorisé: $FilePath" "INFO"
                return @{ Success = $true; Modified = $true }
            }
        }
        
        return @{ Success = $true; Modified = $false }
        
    } catch {
        $errorMsg = "Erreur lors de la refactorisation de $FilePath : $($_.Exception.Message)"
        Write-RefactorLog $errorMsg "ERROR"
        $Global:Errors += $errorMsg
        return @{ Success = $false; Modified = $false }
    }
}

# Définition des phases
$Phase1Files = @(
    "sync_roo_environment.ps1",
    "roo-config/scheduler/config.json",
    "roo-config/scheduler/orchestration-engine.ps1",
    "roo-config/scheduler/self-improvement.ps1",
    "roo-config/scheduler/test-daily-orchestration.ps1",
    "roo-config/scheduler/test-orchestration-simple.ps1"
)

$Phase2Files = @(
    "mcps/README.md",
    "roo-config/settings/servers.json"
)

$Phase3Files = @(
    "docs/rapports/rapport-synthese-global.md",
    "mcps/CORRECTIONS.md",
    "roo-config/scheduler/README-Installation-Scheduler.md"
)

# Début de la refactorisation
Write-RefactorLog "=== DÉBUT DE LA REFACTORISATION ARCHITECTURALE ===" "INFO"
Write-RefactorLog "Phase sélectionnée: $Phase" "INFO"
Write-RefactorLog "Mode: $(if ($DryRun) { 'DRY RUN' } else { 'EXECUTION' })" "INFO"

# Créer le répertoire de sauvegarde
if (!$DryRun) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    Write-RefactorLog "Répertoire de sauvegarde créé: $BackupDir" "INFO"
}

# Déterminer les fichiers à traiter
$filesToProcess = @()
switch ($Phase) {
    "1" { $filesToProcess = $Phase1Files }
    "2" { $filesToProcess = $Phase2Files }
    "3" { $filesToProcess = $Phase3Files }
    "all" { $filesToProcess = $Phase1Files + $Phase2Files + $Phase3Files }
    default { 
        Write-RefactorLog "Phase invalide: $Phase. Utiliser 1, 2, 3, ou 'all'" "ERROR"
        exit 1
    }
}

Write-RefactorLog "Fichiers à traiter: $($filesToProcess.Count)" "INFO"

# Traitement des fichiers
$processedCount = 0
$modifiedCount = 0

foreach ($file in $filesToProcess) {
    if (Test-Path $file) {
        Write-RefactorLog "Traitement: $file" "INFO"
        
        $result = $null
        $extension = [System.IO.Path]::GetExtension($file).ToLower()
        
        switch ($extension) {
            ".ps1" { $result = Refactor-PowerShellScript -FilePath $file }
            ".json" { $result = Refactor-JsonConfig -FilePath $file }
            ".md" { $result = Refactor-Documentation -FilePath $file }
            default { 
                Write-RefactorLog "Type de fichier non supporté: $extension" "WARNING"
                continue
            }
        }
        
        if ($result.Success) {
            $processedCount++
            if ($result.Modified) {
                $modifiedCount++
                $Global:ModifiedFiles += $file
            }
        }
    } else {
        Write-RefactorLog "Fichier non trouvé: $file" "WARNING"
    }
}

# Génération du rapport final
$report = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Phase = $Phase
    Mode = if ($DryRun) { "DRY_RUN" } else { "EXECUTION" }
    Summary = @{
        FilesProcessed = $processedCount
        FilesModified = $modifiedCount
        ErrorCount = $Global:Errors.Count
    }
    ModifiedFiles = $Global:ModifiedFiles
    Errors = $Global:Errors
    BackupDirectory = if (!$DryRun) { $BackupDir } else { "N/A (Dry Run)" }
}

$report | ConvertTo-Json -Depth 10 | Out-File -FilePath $ReportFile -Encoding UTF8

# Résumé final
Write-RefactorLog "=== RÉSUMÉ DE LA REFACTORISATION ===" "INFO"
Write-RefactorLog "Phase: $Phase" "INFO"
Write-RefactorLog "Fichiers traités: $processedCount" "INFO"
Write-RefactorLog "Fichiers modifiés: $modifiedCount" "INFO"
Write-RefactorLog "Erreurs: $($Global:Errors.Count)" "INFO"

if ($Global:Errors.Count -gt 0) {
    Write-RefactorLog "ERREURS DÉTECTÉES:" "ERROR"
    foreach ($error in $Global:Errors) {
        Write-RefactorLog "  - $error" "ERROR"
    }
}

Write-RefactorLog "Rapport sauvegardé: $ReportFile" "INFO"
Write-RefactorLog "Log sauvegardé: $LogFile" "INFO"

if (!$DryRun) {
    Write-RefactorLog "Sauvegarde créée dans: $BackupDir" "INFO"
}

Write-RefactorLog "=== FIN DE LA REFACTORISATION ===" "INFO"

# Code de sortie
if ($Global:Errors.Count -gt 0) {
    exit 1
} else {
    exit 0
}