# Script pour organiser les fichiers du dépôt roo-extensions
# Ce script crée les répertoires nécessaires et déplace les fichiers dans les emplacements appropriés

# Création des répertoires
$directories = @(
    "configs/escalation",
    "docs/escalation",
    "scripts/escalation",
    "templates",
    "tests/escalation"
)

foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        Write-Host "Création du répertoire: $dir"
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
}

# Déplacement des fichiers liés aux tests d'escalade
$filesToMove = @{
    # Fichiers à déplacer vers scripts/escalation
    "monitor-escalation-performance.ps1" = "scripts/escalation/"
    "setup-test-environment.ps1" = "scripts/escalation/"
    "generate-escalation-matrix.ps1" = "scripts/escalation/"
    "update-escalation-thresholds.ps1" = "scripts/escalation/"
    "escalation-feedback.ps1" = "scripts/escalation/"
    "generate-recommendation.ps1" = "scripts/escalation/"
    "analyze-test-results.ps1" = "scripts/escalation/"
    
    # Fichiers à déplacer vers templates
    "test-log-template.md" = "templates/"
    "escalation-dashboard.html" = "templates/"
    "comparison-report-template.md" = "templates/"
    
    # Fichiers à déplacer vers configs/escalation
    "recommended-config.json" = "configs/escalation/"
    
    # Fichiers à déplacer vers docs/escalation
    "rapport-tests-escalade.md" = "docs/escalation/"
    "comparison-report.md" = "docs/escalation/"
    "final-comparison-report.md" = "docs/escalation/"
    "continuous-evaluation-guide.md" = "docs/escalation/"
    "deployment-guide.md" = "docs/escalation/"
}

# Déplacement des fichiers
foreach ($file in $filesToMove.Keys) {
    $destination = $filesToMove[$file]
    if (Test-Path $file) {
        Write-Host "Déplacement de $file vers $destination"
        Move-Item -Path $file -Destination $destination -Force
    } else {
        Write-Host "Fichier non trouvé: $file"
    }
}

# Suppression des fichiers temporaires et des répertoires vides
$tempFiles = @(
    "*.bak",
    "*.tmp",
    "*.temp",
    "*~"
)

foreach ($pattern in $tempFiles) {
    $files = Get-ChildItem -Path . -Filter $pattern -Recurse -File
    foreach ($file in $files) {
        Write-Host "Suppression du fichier temporaire: $($file.FullName)"
        Remove-Item -Path $file.FullName -Force
    }
}

# Vérification des répertoires vides
$emptyDirs = @(
    "backup"
)

foreach ($dir in $emptyDirs) {
    if (Test-Path $dir) {
        $isEmpty = (Get-ChildItem -Path $dir -Force | Measure-Object).Count -eq 0
        if ($isEmpty) {
            Write-Host "Suppression du répertoire vide: $dir"
            Remove-Item -Path $dir -Force
        }
    }
}

# Vérification des fichiers de test dans mcps/backup-mcp-servers/tests et mcps/mcp-servers/tests
# qui sont dupliqués et peuvent être consolidés
$testDirs = @(
    "mcps/backup-mcp-servers/tests",
    "mcps/mcp-servers/tests"
)

# Création d'un répertoire pour les tests MCP
if (-not (Test-Path "tests/mcp")) {
    Write-Host "Création du répertoire: tests/mcp"
    New-Item -Path "tests/mcp" -ItemType Directory -Force | Out-Null
}

# Déplacement des fichiers de test JavaScript vers tests/mcp
foreach ($dir in $testDirs) {
    if (Test-Path $dir) {
        $jsFiles = Get-ChildItem -Path $dir -Filter "*.js" -File
        foreach ($file in $jsFiles) {
            $destFile = "tests/mcp/$($file.Name)"
            if (-not (Test-Path $destFile)) {
                Write-Host "Copie de $($file.FullName) vers $destFile"
                Copy-Item -Path $file.FullName -Destination $destFile -Force
            }
        }
    }
}

Write-Host "Organisation des fichiers terminée."