<#
.SYNOPSIS
    Fournit des outils d'analyse et de nettoyage pour le dépôt Git.

.DESCRIPTION
    Ce script centralise plusieurs opérations de maintenance Git. Il peut générer un rapport
    détaillé sur l'état du dépôt (modifications, fichiers non suivis), trouver et
    supprimer des "répertoires fantômes" (vides ou inutiles), et nettoyer les branches locales
    qui ont déjà été fusionnées.

.PARAMETER Status
    Affiche un rapport complet sur l'état de Git, incluant les modifications de fichiers et
    les répertoires fantômes détectés.

.PARAMETER Clean
    Active le mode de nettoyage. Doit être utilisé avec -FindGhostDirs ou -PruneBranches.

.PARAMETER FindGhostDirs
    Détecte les répertoires qui sont vides ou qui ne contiennent que des fichiers temporaires.
    Peut être combiné avec -Remove pour les supprimer.

.PARAMETER RemoveGhostDirs
    Supprime les répertoires fantômes identifiés par -FindGhostDirs.

.PARAMETER PruneBranches
    Supprime les branches locales qui ont déjà été fusionnées dans la branche principale (main/master).
    C'est une opération sûre pour nettoyer l'espace de travail local.

.PARAMETER DryRun
    Simule les opérations de nettoyage sans rien supprimer.

.EXAMPLE
    .\Invoke-GitMaintenance.ps1 -Status
    Description: Affiche le rapport d'état du dépôt.

.EXAMPLE
    .\Invoke-GitMaintenance.ps1 -Clean -PruneBranches
    Description: Supprime toutes les branches locales déjà fusionnées.

.EXAMPLE
    .\Invoke-GitMaintenance.ps1 -Clean -FindGhostDirs -RemoveGhostDirs -DryRun
    Description: Montre quels répertoires fantômes seraient supprimés.

.NOTES
    Auteur: Roo (IA) - consolidé le 20/08/2025
#>
[CmdletBinding(DefaultParameterSetName='Status')]
param(
    [Parameter(ParameterSetName='Status', Mandatory=$true)]
    [switch]$Status,

    [Parameter(ParameterSetName='Clean', Mandatory=$true)]
    [switch]$Clean,

    [Parameter(ParameterSetName='Clean')]
    [switch]$FindGhostDirs,

    [Parameter(ParameterSetName='Clean')]
    [switch]$RemoveGhostDirs,

    [Parameter(ParameterSetName='Clean')]
    [switch]$PruneBranches,
    
    [Parameter()]
    [switch]$DryRun
)

#region Fonctions d'Analyse
function Get-GitStatusReport {
    Write-Host "--- Analyse de 'git status' ---" -ForegroundColor Cyan
    $gitStatus = git status --porcelain
    if (-not $gitStatus) {
        Write-Host "Le répertoire de travail est propre." -ForegroundColor Green
        return $null
    }

    $report = @{
        'Modified' = @(); 'Deleted' = @(); 'Added' = @(); 'Renamed' = @(); 'Untracked' = @()
    }

    foreach ($line in $gitStatus) {
        $status = $line.Substring(0, 2).Trim()
        $file = $line.Substring(3)
        switch ($status) {
            'M'  { $report['Modified'] += $file }
            'D'  { $report['Deleted'] += $file }
            'A'  { $report['Added'] += $file }
            'R'  { $report['Renamed'] += $file }
            '??' { $report['Untracked'] += $file }
        }
    }
    
    Write-Host "Résumé des modifications :"
    $report.GetEnumerator() | ForEach-Object { Write-Host ("- {0,-10}: {1}" -f $_.Name, $_.Value.Count) }
    return $report
}

function Find-GhostDirectories {
    Write-Host "`n--- Recherche des répertoires fantômes ---" -ForegroundColor Cyan
    $ghostDirs = @()
    $tempFilesPatterns = @('.gitkeep', '.DS_Store', 'Thumbs.db', 'desktop.ini')

    $allDirs = Get-ChildItem -Path . -Directory -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { 
        $_.FullName -notmatch '\\\.git'
    }

    foreach ($dir in $allDirs) {
        $items = Get-ChildItem -Path $dir.FullName -Force -ErrorAction SilentlyContinue
        if ($items.Count -eq 0) {
            $ghostDirs += @{ Path = $dir.FullName; Type = "Vide"; Reason = "Aucun fichier" }
        }
        elseif (($items | Where-Object { !$_.PSIsContainer -and $_.Name -notin $tempFilesPatterns }).Count -eq 0) {
            $ghostDirs += @{ Path = $dir.FullName; Type = "Temporaire"; Reason = "Contient seulement des fichiers temporaires" }
        }
    }

    if ($ghostDirs.Count -gt 0) {
        Write-Host "Trouvé $($ghostDirs.Count) répertoire(s) fantôme(s):" -ForegroundColor Yellow
        $ghostDirs | ForEach-Object { Write-Host ("- {0} ({1})" -f $_.Path, $_.Type) }
    } else {
        Write-Host "Aucun répertoire fantôme détecté." -ForegroundColor Green
    }
    return $ghostDirs
}

function Get-PrunableBranches {
    Write-Host "`n--- Recherche des branches locales fusionnées ---" -ForegroundColor Cyan
    
    # Assurer que nous sommes à jour avec le remote
    git remote update origin --prune
    
    # La commande varie un peu selon l'OS pour le parsing
    $mergedBranches = git branch --merged | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "*" -and $_ -ne "main" -and $_ -ne "master" }

    if ($mergedBranches.Count -gt 0) {
        Write-Host "Trouvé $($mergedBranches.Count) branche(s) locale(s) pouvant être supprimée(s):" -ForegroundColor Yellow
        $mergedBranches | ForEach-Object { Write-Host "- $_" }
    } else {
        Write-Host "Aucune branche locale fusionnée à nettoyer." -ForegroundColor Green
    }
    return $mergedBranches
}
#endregion

# --- EXÉCUTION PRINCIPALE ---

if ($Status) {
    Get-GitStatusReport
    Find-GhostDirectories
}

if ($Clean) {
    if ($FindGhostDirs) {
        $ghosts = Find-GhostDirectories
        if ($RemoveGhostDirs -and $ghosts) {
            Write-Host "`n--- Suppression des répertoires fantômes ---" -ForegroundColor Cyan
            if($DryRun) { Write-Host "[SIMULATION] Les répertoires ci-dessus seraient supprimés." -ForegroundColor Magenta }
            else {
                foreach($dir in $ghosts) {
                    try {
                        Remove-Item $dir.Path -Recurse -Force -ErrorAction Stop
                        Write-Host "Supprimé: $($dir.Path)" -ForegroundColor Green
                    } catch {
                        Write-Host "ERREUR lors de la suppression de $($dir.Path): $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
            }
        }
    }

    if ($PruneBranches) {
        $branches = Get-PrunableBranches
        if ($branches) {
            Write-Host "`n--- Nettoyage des branches locales fusionnées ---" -ForegroundColor Cyan
            if($DryRun) { Write-Host "[SIMULATION] Les branches ci-dessus seraient supprimées." -ForegroundColor Magenta }
            else {
                foreach($branch in $branches) {
                    git branch -d $branch
                    Write-Host "Supprimé: $branch" -ForegroundColor Green
                }
            }
        }
    }
}