# Script pour vérifier et mettre à jour les chemins dans les scripts d'escalade
# Ce script vérifie si les scripts font référence à des fichiers qui ont été déplacés
# et met à jour les chemins en conséquence

# Fonction pour mettre à jour les chemins dans un fichier
function Update-FilePaths {
    param (
        [string]$FilePath,
        [hashtable]$PathMappings
    )

    $content = Get-Content -Path $FilePath -Raw
    $updated = $false

    foreach ($oldPath in $PathMappings.Keys) {
        $newPath = $PathMappings[$oldPath]
        if ($content -match [regex]::Escape($oldPath)) {
            $content = $content -replace [regex]::Escape($oldPath), $newPath
            $updated = $true
            Write-Host "Mise à jour du chemin dans $FilePath : $oldPath -> $newPath" -ForegroundColor Yellow
        }
    }

    if ($updated) {
        Set-Content -Path $FilePath -Value $content -Force
        Write-Host "Fichier mis à jour : $FilePath" -ForegroundColor Green
    } else {
        Write-Host "Aucune mise à jour nécessaire pour : $FilePath" -ForegroundColor Cyan
    }
}

# Définition des mappages de chemins (ancien -> nouveau)
$pathMappings = @{
    'Join-Path -Path $scriptPath -ChildPath "recommended-config.json"' = 'Join-Path -Path (Split-Path -Parent $scriptPath) -ChildPath "roo-config\settings\escalation\recommended-config.json"'
    'Join-Path -Path $scriptPath -ChildPath "..\test-results"' = 'Join-Path -Path (Split-Path -Parent $scriptPath) -ChildPath "tests\results"'
    'Join-Path -Path $scriptPath -ChildPath "..\test-data"' = 'Join-Path -Path (Split-Path -Parent $scriptPath) -ChildPath "tests\data"'
    'Join-Path -Path $scriptPath -ChildPath "..\templates"' = 'Join-Path -Path (Split-Path -Parent $scriptPath) -ChildPath "templates"'
    'Join-Path -Path $scriptPath -ChildPath "..\docs"' = 'Join-Path -Path (Split-Path -Parent $scriptPath) -ChildPath "docs\escalation"'
    'Join-Path -Path (Split-Path -Parent $scriptPath) -ChildPath "configs\escalation\recommended-config.json"' = 'Join-Path -Path (Split-Path -Parent $scriptPath) -ChildPath "roo-config\settings\escalation\recommended-config.json"'
    'Join-Path -Path (Split-Path -Parent $scriptPath) -ChildPath "test-results"' = 'Join-Path -Path (Split-Path -Parent $scriptPath) -ChildPath "tests\results"'
    'Join-Path -Path (Split-Path -Parent $scriptPath) -ChildPath "test-data"' = 'Join-Path -Path (Split-Path -Parent $scriptPath) -ChildPath "tests\data"'
}

# Liste des scripts à vérifier
$scripts = Get-ChildItem -Path "scripts/escalation" -Filter "*.ps1" -File

# Mise à jour des chemins dans chaque script
foreach ($script in $scripts) {
    Write-Host "Vérification du script : $($script.FullName)" -ForegroundColor Blue
    Update-FilePaths -FilePath $script.FullName -PathMappings $pathMappings
}

# Vérification des chemins dans les scripts de test
$testScripts = Get-ChildItem -Path "tests/escalation" -Filter "*.ps1" -File -ErrorAction SilentlyContinue
if ($testScripts) {
    foreach ($script in $testScripts) {
        Write-Host "Vérification du script de test : $($script.FullName)" -ForegroundColor Blue
        Update-FilePaths -FilePath $script.FullName -PathMappings $pathMappings
    }
}

Write-Host "Mise à jour des chemins terminée." -ForegroundColor Green

# Création d'un fichier .gitignore à la racine s'il n'existe pas déjà
$gitignorePath = ".gitignore"
if (-not (Test-Path $gitignorePath)) {
    $gitignoreContent = @"
# Fichiers temporaires
*.tmp
*.temp
*.swp
*~
*.bak
*.backup

# Répertoires spécifiques
logs/
temp/
.vscode/
node_modules/

# Fichiers de configuration locaux
.env
.env.local
.DS_Store
Thumbs.db
"@
    Set-Content -Path $gitignorePath -Value $gitignoreContent -Force
    Write-Host "Fichier .gitignore créé à la racine du projet." -ForegroundColor Green
}

# Vérification des répertoires vides qui peuvent être supprimés
$emptyDirs = @(
    "backup"
)

foreach ($dir in $emptyDirs) {
    if (Test-Path $dir) {
        $isEmpty = (Get-ChildItem -Path $dir -Force | Measure-Object).Count -eq 0
        if ($isEmpty) {
            Remove-Item -Path $dir -Force
            Write-Host "Répertoire vide supprimé : $dir" -ForegroundColor Yellow
        } else {
            Write-Host "Répertoire non vide, conservation : $dir" -ForegroundColor Cyan
        }
    }
}

# Création des répertoires de logs et rapports pour les scripts d'escalade
$logsDir = "scripts/maintenance/logs/escalation"
$reportsDir = "scripts/maintenance/reports"

if (-not (Test-Path $logsDir)) {
    New-Item -Path $logsDir -ItemType Directory -Force | Out-Null
    Write-Host "Répertoire de logs créé : $logsDir" -ForegroundColor Green
}

if (-not (Test-Path $reportsDir)) {
    New-Item -Path $reportsDir -ItemType Directory -Force | Out-Null
    Write-Host "Répertoire de rapports créé : $reportsDir" -ForegroundColor Green
}

Write-Host "Organisation du dépôt terminée avec succès." -ForegroundColor Green