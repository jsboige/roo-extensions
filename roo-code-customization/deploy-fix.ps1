<#
.SYNOPSIS
    Script pour déployer (hot-swap) ou restaurer (rollback) une version de développement de l'extension.
.DESCRIPTION
    Ce script automatise le processus de remplacement des fichiers de l'extension par une version de développement
    et permet de restaurer la version originale à partir d'une sauvegarde.
.PARAMETER Action
    Spécifie l'opération à effectuer. Les valeurs acceptées sont 'Deploy' et 'Rollback'.
.EXAMPLE
    .\deploy-fix.ps1 -Action Deploy
    Déploie les modifications depuis le répertoire source vers le répertoire cible.
.EXAMPLE
    .\deploy-fix.ps1 -Action Rollback
    Restaure l'extension à partir de la sauvegarde.
.NOTES
    Ce script requiert d'être exécuté avec des privilèges d'administrateur pour modifier les répertoires d'extensions.
#>

# Script unittestable. La directive #Requires a été supprimée pour les tests.

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Action à effectuer : 'Deploy' ou 'Rollback'.")]
    [ValidateSet('Deploy', 'Rollback')]
    [string]$Action,

    [Parameter(Mandatory = $false, HelpMessage = "Répertoire source contenant les fichiers de développement.")]
    [string]$sourceDir = "c:/dev/roo-extensions/roo-code/dist",

    [Parameter(Mandatory = $false, HelpMessage = "Répertoire de destination de l'extension.")]
    [string]$targetDir = "C:/Users/jsboi/.vscode/extensions/rooveterinaryinc.roo-cline-3.25.6/dist",

    [Parameter(Mandatory = $false, HelpMessage = "Répertoire de sauvegarde de la version originale.")]
    [string]$backupDir = "C:/Users/jsboi/.vscode/extensions/rooveterinaryinc.roo-cline-3.25.6/dist_backup"
)

# --- Logique Principale ---
switch ($Action) {
    'Deploy' {
        Write-Host "--- DÉPLOIEMENT EN COURS ---" -ForegroundColor Cyan
        try {
            # 1. Agréger les fichiers de build dans un répertoire de staging ($sourceDir)
            $projectRoot = "c:/dev/roo-extensions/roo-code"
            Write-Host "--- AGRÉGATION DES FICHIERS DE BUILD ---" -ForegroundColor Cyan
            Write-Host "Nettoyage et création du répertoire de staging '$sourceDir'."
            if (Test-Path -Path $sourceDir) {
                Remove-Item -Path $sourceDir -Recurse -Force
            }
            New-Item -Path $sourceDir -ItemType Directory -Force | Out-Null
            
            Write-Host "Recherche des répertoires 'dist' dans '$projectRoot' (hors node_modules)..."
            $distDirectories = Get-ChildItem -Path $projectRoot -Recurse -Directory -Filter "dist" -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notlike "*node_modules*" }

            if ($null -eq $distDirectories) {
                throw "Aucun répertoire 'dist' trouvé après compilation. Le déploiement ne peut pas continuer."
            }
            
            Write-Host "Répertoires 'dist' à agréger :"
            $distDirectories.FullName | ForEach-Object { Write-Host "- $_" }
            
            foreach ($distDir in $distDirectories) {
                if ($distDir.FullName -eq $sourceDir) {
                    continue
                }
                Write-Host "Copie du contenu de '$($distDir.FullName)' vers '$sourceDir'"
                Copy-Item -Path "$($distDir.FullName)\*" -Destination $sourceDir -Recurse -Force -ErrorAction Stop
            }
            
            Write-Host "Agrégation terminée."

            # 2. Vérifier si le répertoire source (staging) existe et n'est pas vide
            if (-not (Test-Path -Path $sourceDir -PathType Container) -or -not (Get-ChildItem -Path $sourceDir)) {
                throw "Le répertoire source '$sourceDir' est introuvable ou vide après l'agrégation. La compilation a peut-être échoué."
            }

            # 2. Gérer la sauvegarde du répertoire original
            if (-not (Test-Path -Path $backupDir -PathType Container)) {
                Write-Host "Création de la sauvegarde : renommage de '$targetDir' en '$backupDir'."
                if (Test-Path -Path $targetDir -PathType Container) {
                    Rename-Item -Path $targetDir -NewName ($backupDir | Split-Path -Leaf) -ErrorAction Stop
                } else {
                    Write-Host "Le répertoire cible '$targetDir' n'existe pas, aucune sauvegarde n'est nécessaire pour le moment."
                }
            } else {
                Write-Host "Le répertoire de sauvegarde '$backupDir' existe déjà. Aucune action de sauvegarde supplémentaire n'est requise."
            }

            # 3. Supprimer l'ancien répertoire cible (s'il existe) et le recréer
            if (Test-Path -Path $targetDir -PathType Container) {
                Write-Host "Suppression de l'ancien répertoire cible '$targetDir' pour une installation propre."
                Remove-Item -Path $targetDir -Recurse -Force -ErrorAction Stop
            }
            Write-Host "Création du nouveau répertoire cible '$targetDir'."
            New-Item -Path $targetDir -ItemType Directory -ErrorAction Stop | Out-Null
            
            # 4. Copier les nouveaux fichiers de développement
            Write-Host "Copie du contenu de '$sourceDir' vers '$targetDir'."
            Copy-Item -Path "$sourceDir\*" -Destination $targetDir -Recurse -Force -ErrorAction Stop

            Write-Host -ForegroundColor Green "Succès : Déploiement terminé."
        }
        catch {
            Write-Error "ÉCHEC CRITIQUE DU DÉPLOIEMENT : $($_.Exception.Message)"
            throw $_ # Propager l'exception pour les tests
        }
    }
    'Rollback' {
        Write-Host "--- RESTAURATION (ROLLBACK) EN COURS ---" -ForegroundColor Cyan
        try {
            # 1. Vérifier si la sauvegarde existe
            if (-not (Test-Path -Path $backupDir -PathType Container)) {
                throw "Répertoire de sauvegarde '$backupDir' introuvable. Impossible de restaurer."
            }

            # 2. Supprimer le répertoire cible actuel (contenant les modifications)
            if (Test-Path -Path $targetDir -PathType Container) {
                Write-Host "Suppression du répertoire actuellement déployé '$targetDir'."
                Remove-Item -Path $targetDir -Recurse -Force -ErrorAction Stop
            }

            # 3. Restaurer la sauvegarde en la renommant
            Write-Host "Restauration de la sauvegarde : renommage de '$backupDir' en '$targetDir'."
            Rename-Item -Path $backupDir -NewName ($targetDir | Split-Path -Leaf) -ErrorAction Stop

            Write-Host -ForegroundColor Green "Succès : Restauration terminée."
        }
        catch {
            Write-Error "ÉCHEC CRITIQUE DE LA RESTAURATION : $($_.Exception.Message)"
            throw $_ # Propager l'exception pour les tests
        }
    }
}