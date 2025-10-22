# Configuration UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Paramètres
param(
    [string]$LogPath = "$env:TEMP\git-sync-$(Get-Date -Format 'yyyyMMdd-HHmmss').log",
    [switch]$Force
)

# Variables globales
$SyncResults = @{
    MainSync = @{ Success = $false; Actions = @(); Errors = @() }
    SubmoduleSync = @{ Success = $false; Actions = @(); Errors = @() }
}

# Fonction de logging
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    
    Write-Host $LogEntry -ForegroundColor $(
        switch ($Level) {
            "ERROR" { "Red" }
            "WARN" { "Yellow" }
            "SUCCESS" { "Green" }
            default { "White" }
        }
    )
    
    Add-Content -Path $LogPath -Value $LogEntry -Encoding UTF8
}

# Fonction pour exécuter les commandes Git
function Invoke-GitCommand {
    param(
        [string]$Command,
        [string]$Arguments = "",
        [switch]$IgnoreErrors = $false
    )
    
    $FullCommand = "git $Command $Arguments".Trim()
    Write-Log "Exécution: $FullCommand"
    
    try {
        $Result = Invoke-Expression $FullCommand 2>&1
        if ($LASTEXITCODE -ne 0 -and -not $IgnoreErrors) {
            throw "Commande Git échouée avec code de sortie $LASTEXITCODE"
        }
        Write-Log "Succès: $FullCommand" "SUCCESS"
        return $Result
    }
    catch {
        Write-Log "Erreur: $FullCommand - $($_.Exception.Message)" "ERROR"
        if (-not $IgnoreErrors) {
            throw
        }
        return $null
    }
}

# Fonction pour obtenir le statut complet Git
function Get-GitCompleteStatus {
    Write-Log "Analyse de l'état Git complet..."
    
    $Status = @{}
    
    # Vérifier si on est dans un repo Git
    try {
        $Status.IsGitRepo = $null -ne (Invoke-GitCommand "rev-parse" "--git-dir" -IgnoreErrors)
        if (-not $Status.IsGitRepo) {
            Write-Log "Ce n'est pas un repository Git" "ERROR"
            return $Status
        }
    }
    catch {
        $Status.IsGitRepo = $false
        Write-Log "Ce n'est pas un repository Git" "ERROR"
        return $Status
    }
    
    # Branch actuelle
    $BranchResult = Invoke-GitCommand "rev-parse" "--abbrev-ref" "HEAD"
    $Status.Branch = if ($BranchResult) { $BranchResult.Trim() } else { "unknown" }
    
    # Statut du working directory
    $GitStatus = Invoke-GitCommand "status" "--porcelain"
    $Status.IsClean = [string]::IsNullOrEmpty($GitStatus)
    $Status.ModifiedFiles = @()
    
    if (-not $Status.IsClean) {
        $Status.ModifiedFiles = $GitStatus -split "`n" | Where-Object { $_.Trim() -ne "" }
    }
    
    # Vérifier les conflits
    $Status.HasConflicts = $GitStatus -match "^[AU][AU]"
    
    # Statut des sous-modules
    $Status.Submodules = @()
    try {
        $SubmoduleStatus = Invoke-GitCommand "submodule" "status"
        if ($SubmoduleStatus) {
            foreach ($Line in $SubmoduleStatus -split "`n") {
                if ($Line.Trim() -ne "") {
                    $Parts = $Line -split " ", 3
                    $Status.Submodules += @{
                        Path = $Parts[1]
                        Commit = $Parts[0].Substring(1)
                        Status = switch ($Parts[0][0]) {
                            " " { "OK" }
                            "+" { "MODIFIED" }
                            "-" { "INITIALIZED" }
                            "U" { "CONFLICT" }
                            default { "UNKNOWN" }
                        }
                        Description = if ($Parts.Count -gt 2) { $Parts[2] } else { "" }
                    }
                }
            }
        }
    }
    catch {
        Write-Log "Erreur lors de l'analyse des sous-modules: $($_.Exception.Message)" "WARN"
    }
    
    # Information sur les commits en retard/en avance
    try {
        $Status.BehindCommits = 0
        $Status.AheadCommits = 0
        
        $RevList = Invoke-GitCommand "rev-list" "--count" "--left-right" "origin/$($Status.Branch)...HEAD" -IgnoreErrors
        if ($RevList -and $RevList -match "^\s*(\d+)\s+(\d+)\s*$") {
            $Status.BehindCommits = [int]$matches[1]
            $Status.AheadCommits = [int]$matches[2]
        }
    }
    catch {
        Write-Log "Impossible de déterminer le nombre de commits en retard/en avance" "WARN"
    }
    
    return $Status
}

# Fonction pour synchroniser les sous-modules
function Sync-GitSubmodules {
    Write-Log "Synchronisation des sous-modules..."
    
    try {
        # Initialiser les sous-modules si nécessaire
        Write-Log "Initialisation des sous-modules..."
        Invoke-GitCommand "submodule" "init"
        
        # Mettre à jour les sous-modules
        Write-Log "Mise à jour des sous-modules..."
        Invoke-GitCommand "submodule" "update" "--init" "--recursive"
        
        # Synchroniser les sous-modules
        Write-Log "Synchronisation des sous-modules..."
        Invoke-GitCommand "submodule" "sync" "--recursive"
        
        $SyncResults.SubmoduleSync.Success = $true
        $SyncResults.SubmoduleSync.Actions += "Initialisation"
        $SyncResults.SubmoduleSync.Actions += "Mise à jour"
        $SyncResults.SubmoduleSync.Actions += "Synchronisation"
        
        Write-Log "Sous-modules synchronisés avec succès" "SUCCESS"
    }
    catch {
        $SyncResults.SubmoduleSync.Success = $false
        $SyncResults.SubmoduleSync.Errors += $_.Exception.Message
        Write-Log "Erreur lors de la synchronisation des sous-modules: $($_.Exception.Message)" "ERROR"
    }
}

# Fonction de synchronisation principale
function Sync-GitRepository {
    param(
        [switch]$Force
    )
    
    Write-Log "Démarrage de la synchronisation Git complète..."
    
    $SyncResults.MainSync = @{
        Success = $false
        Actions = @()
        Errors = @()
    }
    
    try {
        # Récupérer les informations initiales
        $InitialStatus = Get-GitCompleteStatus
        
        if (-not $InitialStatus.IsGitRepo) {
            throw "Ce n'est pas un repository Git valide"
        }
        
        Write-Log "Repository: $($InitialStatus.Branch)"
        Write-Log "Commits en retard: $($InitialStatus.BehindCommits)"
        Write-Log "Commits en avance: $($InitialStatus.AheadCommits)"
        
        # Étape 1: Synchroniser les sous-modules d'abord
        Sync-GitSubmodules
        
        # Étape 2: Stash des modifications locales si Force
        if ($Force -and -not $InitialStatus.IsClean) {
            Write-Log "Stash des modifications locales (mode Force)..."
            try {
                Invoke-GitCommand "stash" "push" "-m" "Auto-stash before sync $(Get-Date -Format 'yyyyMMdd-HHmmss')"
                $SyncResults.MainSync.Actions += "Stash des modifications locales"
                Write-Log "Modifications locales mises en stash" "SUCCESS"
            }
            catch {
                Write-Log "Impossible de stash les modifications: $($_.Exception.Message)" "WARN"
            }
        }
        
        # Étape 3: Fetch depuis le remote
        Write-Log "Récupération des informations depuis le remote..."
        Invoke-GitCommand "fetch" "--all" "--prune"
        $SyncResults.MainSync.Actions += "Fetch depuis remote"
        
        # Étape 4: Pull avec rebase
        Write-Log "Pull avec rebase..."
        if ($Force) {
            Invoke-GitCommand "pull" "--rebase" "--force"
        } else {
            Invoke-GitCommand "pull" "--rebase"
        }
        $SyncResults.MainSync.Actions += "Pull avec rebase"
        
        # Étape 5: Synchroniser à nouveau les sous-modules après le pull
        Write-Log "Synchronisation finale des sous-modules..."
        Invoke-GitCommand "submodule" "update" "--init" "--recursive"
        $SyncResults.MainSync.Actions += "Synchronisation finale sous-modules"
        
        $SyncResults.MainSync.Success = $true
        Write-Log "Synchronisation principale terminée avec succès" "SUCCESS"
        
        # Étape 6: Restorer le stash si Force
        if ($Force -and -not $InitialStatus.IsClean) {
            Write-Log "Restauration des modifications locales depuis le stash..."
            try {
                $StashList = Invoke-GitCommand "stash" "list"
                if ($StashList -match "Auto-stash before sync") {
                    Invoke-GitCommand "stash" "pop"
                    $SyncResults.MainSync.Actions += "Restauration du stash"
                    Write-Log "Modifications locales restaurées" "SUCCESS"
                }
            }
            catch {
                Write-Log "Impossible de restaurer le stash: $($_.Exception.Message)" "WARN"
            }
        }
    }
    catch {
        $SyncResults.MainSync.Success = $false
        $SyncResults.MainSync.Errors += $_.Exception.Message
        Write-Log "Erreur lors de la synchronisation principale: $($_.Exception.Message)" "ERROR"
    }
}

# Fonction pour générer le rapport
function New-SyncReport {
    param(
        [hashtable]$SyncResults,
        [hashtable]$FinalStatus
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $RepoRoot = (Get-Location).Path
    
    $Report = @"
# RAPPORT DE SYNCHRONISATION GIT COMPLÈTE
**Généré le**: $Timestamp  
**Repository**: $RepoRoot  
**Branche**: $($FinalStatus.Branch)

## RÉSUMÉ GLOBAL

| Élément | État | Détails |
|---------|------|---------|
| Synchronisation principale | $(if ($SyncResults.MainSync.Success) { "SUCCÈS" } else { "ÉCHEC" }) | $($SyncResults.MainSync.Actions.Count) actions effectuées |
| Sous-modules | $(if ($SyncResults.SubmoduleSync.Success) { "SUCCÈS" } else { "ÉCHEC" }) | $($FinalStatus.Submodules.Count) sous-modules |
| Working directory | $(if ($FinalStatus.IsClean) { "PROPRE" } else { "MODIFIÉ" }) | $($FinalStatus.ModifiedFiles.Count) fichiers modifiés |
| Conflits | $(if ($FinalStatus.HasConflicts) { "CONFLITS" } else { "AUCUN" }) | - |

## DÉTAILS TECHNIQUES

### État Actuel du Repository
- **Branche**: $($FinalStatus.Branch)
- **Commits en retard**: $($FinalStatus.BehindCommits)
- **Commits en avance**: $($FinalStatus.AheadCommits)
- **Working directory propre**: $(if ($FinalStatus.IsClean) { "Oui" } else { "Non" })
- **Conflits détectés**: $(if ($FinalStatus.HasConflicts) { "Oui" } else { "Non" })

### Actions Effectuées - Synchronisation Principale
$($SyncResults.MainSync.Actions | ForEach-Object { "- $_`n" })

### Actions Effectuées - Sous-modules
$($SyncResults.SubmoduleSync.Actions | ForEach-Object { "- $_`n" })

### État des Sous-modules
$($FinalStatus.Submodules | ForEach-Object { "- [$($_.Status)] $($_.Path) - $($_.Description)`n" })

### Fichiers Modifiés
$($FinalStatus.ModifiedFiles | ForEach-Object { "- $_`n" })

### Erreurs Rencontrées
$($SyncResults.MainSync.Errors + $SyncResults.SubmoduleSync.Errors | ForEach-Object { "- $_`n" })

---
*Généré par sync-git-complete.ps1*
"@
    
    $ReportPath = "$env:TEMP\git-sync-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
    $Report | Out-File -FilePath $ReportPath -Encoding UTF8
    
    Write-Log "Rapport généré: $ReportPath" "SUCCESS"
    return $ReportPath
}

# Point d'entrée principal
try {
    Write-Log "DÉMARRAGE DE LA SYNCHRONISATION GIT COMPLÈTE" "SUCCESS"
    Write-Log "Mode Force: $Force"
    Write-Log "Fichier de log: $LogPath"
    
    # Vérifier les prérequis
    Write-Log "Vérification des prérequis..."
    
    # Vérifier si Git est installé
    try {
        $GitVersion = Invoke-GitCommand "--version"
        Write-Log "Git trouvé: $GitVersion" "SUCCESS"
    }
    catch {
        Write-Log "Git n'est pas installé ou pas dans le PATH" "ERROR"
        exit 1
    }
    
    # Exécuter la synchronisation
    Sync-GitRepository -Force:$Force
    
    # Obtenir le statut final
    $FinalStatus = Get-GitCompleteStatus
    
    # Générer le rapport
    $ReportPath = New-SyncReport -SyncResults $SyncResults -FinalStatus $FinalStatus
    
    # Afficher le résumé
    Write-Log "RÉSUMÉ DE LA SYNCHRONISATION" "SUCCESS"
    Write-Log "Synchronisation principale: $(if ($SyncResults.MainSync.Success) { 'SUCCÈS' } else { 'ÉCHEC' })"
    Write-Log "Sous-modules: $(if ($SyncResults.SubmoduleSync.Success) { 'SUCCÈS' } else { 'ÉCHEC' })"
    Write-Log "Rapport détaillé: $ReportPath"
    
    if ($SyncResults.MainSync.Success -and $SyncResults.SubmoduleSync.Success) {
        Write-Log "SYNCHRONISATION TERMINÉE AVEC SUCCÈS" "SUCCESS"
        exit 0
    } else {
        Write-Log "SYNCHRONISATION TERMINÉE AVEC DES ERREURS" "WARN"
        exit 1
    }
}
catch {
    Write-Log "ERREUR CRITIQUE: $($_.Exception.Message)" "ERROR"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" "ERROR"
    exit 1
}