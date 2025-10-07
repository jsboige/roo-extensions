# Script de déploiement autonome - Version simplifiée et robuste
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('Deploy', 'Rollback')]
    [string]$Action = 'Deploy'
)

Write-Host "`n=== DÉPLOIEMENT EXTENSION ROO ===" -ForegroundColor Cyan

# Configuration
$projectRoot = "c:/dev/roo-code"
$stagingDir = "c:/dev/roo-extensions/roo-code/dist"
$extensionsPath = "$env:USERPROFILE\.vscode\extensions"

# Fonction: Trouver la dernière extension
function Find-LatestRooExtension {
    Write-Host "`nRecherche de l'extension Roo..." -ForegroundColor Yellow
    $extensions = Get-ChildItem -Path $extensionsPath -Directory -Filter "rooveterinaryinc.roo-cline-*" -ErrorAction Stop |
        Sort-Object Name -Descending
    
    if ($extensions.Count -eq 0) {
        throw "Aucune extension Roo trouvée dans $extensionsPath"
    }
    
    Write-Host "Extensions disponibles:" -ForegroundColor Cyan
    $extensions | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Gray }
    
    $latest = $extensions[0]
    Write-Host "`n✅ Extension sélectionnée: $($latest.Name)" -ForegroundColor Green
    return $latest.FullName
}

# Fonction: Agréger les fichiers de build
function Build-StagingDirectory {
    Write-Host "`n--- AGRÉGATION DES FICHIERS ---" -ForegroundColor Cyan
    
    # Nettoyer staging
    if (Test-Path $stagingDir) {
        Write-Host "Nettoyage: $stagingDir"
        Remove-Item $stagingDir -Recurse -Force
    }
    
    Write-Host "Création: $stagingDir"
    New-Item -Path $stagingDir -ItemType Directory -Force | Out-Null
    
    # Trouver tous les dist
    Write-Host "Recherche des répertoires 'dist' dans $projectRoot..."
    $distDirs = Get-ChildItem -Path $projectRoot -Recurse -Directory -Filter "dist" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notlike "*node_modules*" -and $_.FullName -ne $stagingDir }
    
    if ($distDirs.Count -eq 0) {
        throw "Aucun répertoire 'dist' trouvé après build"
    }
    
    Write-Host "Répertoires trouvés: $($distDirs.Count)"
    foreach ($dir in $distDirs) {
        Write-Host "  Copie: $($dir.FullName)" -ForegroundColor Gray
        Copy-Item -Path "$($dir.FullName)\*" -Destination $stagingDir -Recurse -Force -ErrorAction Stop
    }
    
    # Copier webview-ui explicitement
    $webviewUiBuildPath = Join-Path $projectRoot "src\webview-ui\build"
    if (Test-Path $webviewUiBuildPath) {
        $webviewUiTargetPath = Join-Path $stagingDir "webview-ui"
        Write-Host "  Copie: $webviewUiBuildPath (webview-ui)" -ForegroundColor Gray
        Copy-Item -Path $webviewUiBuildPath -Destination $webviewUiTargetPath -Recurse -Force -ErrorAction Stop
    } else {
        Write-Host "⚠️  Webview-ui build non trouvé à: $webviewUiBuildPath" -ForegroundColor Yellow
    }
    
    # Vérifier contenu
    $fileCount = (Get-ChildItem $stagingDir -Recurse -File).Count
    Write-Host "✅ $fileCount fichiers agrégés" -ForegroundColor Green
}

# Fonction: Déployer
function Deploy-Extension {
    param([string]$ExtensionPath)
    
    $targetDir = Join-Path $ExtensionPath "dist"
    $backupDir = Join-Path $ExtensionPath "dist_backup"
    
    Write-Host "`n--- DÉPLOIEMENT ---" -ForegroundColor Cyan
    Write-Host "Cible: $targetDir"
    
    # Backup si nécessaire
    if (Test-Path $targetDir) {
        if (-not (Test-Path $backupDir)) {
            Write-Host "Création backup: $backupDir"
            Rename-Item -Path $targetDir -NewName (Split-Path $backupDir -Leaf) -ErrorAction Stop
        } else {
            Write-Host "Backup existe déjà: $backupDir"
        }
    }
    
    # Créer nouveau dist
    if (Test-Path $targetDir) {
        Write-Host "Suppression ancien dist..."
        Remove-Item $targetDir -Recurse -Force
    }
    
    Write-Host "Création nouveau dist..."
    New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
    
    # Copier fichiers
    Write-Host "Copie des fichiers..."
    Copy-Item -Path "$stagingDir\*" -Destination $targetDir -Recurse -Force -ErrorAction Stop
    
    $fileCount = (Get-ChildItem $targetDir -Recurse -File).Count
    Write-Host "✅ $fileCount fichiers déployés" -ForegroundColor Green
}

# Fonction: Rollback
function Rollback-Extension {
    param([string]$ExtensionPath)
    
    $targetDir = Join-Path $ExtensionPath "dist"
    $backupDir = Join-Path $ExtensionPath "dist_backup"
    
    Write-Host "`n--- ROLLBACK ---" -ForegroundColor Cyan
    
    if (-not (Test-Path $backupDir)) {
        throw "Backup introuvable: $backupDir"
    }
    
    if (Test-Path $targetDir) {
        Write-Host "Suppression dist actuel..."
        Remove-Item $targetDir -Recurse -Force
    }
    
    Write-Host "Restauration backup..."
    Rename-Item -Path $backupDir -NewName (Split-Path $targetDir -Leaf) -ErrorAction Stop
    
    Write-Host "✅ Rollback terminé" -ForegroundColor Green
}

# === EXÉCUTION PRINCIPALE ===
try {
    $extensionPath = Find-LatestRooExtension
    
    if ($Action -eq 'Deploy') {
        Build-StagingDirectory
        Deploy-Extension -ExtensionPath $extensionPath
    } else {
        Rollback-Extension -ExtensionPath $extensionPath
    }
    
    Write-Host "`n=== SUCCÈS ===" -ForegroundColor Green
    Write-Host "Extension: $extensionPath" -ForegroundColor Cyan
    Write-Host "`n⚠️  REDÉMARREZ VSCODE pour appliquer les changements" -ForegroundColor Yellow
}
catch {
    Write-Host "`n❌ ERREUR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}