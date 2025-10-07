# Script de deplacement des rapports de tests vers docs/rapports/tests/
# Utilise git mv pour preserver l'historique Git

Write-Host "=== Deplacement des rapports de tests ===" -ForegroundColor Cyan

# Creer la structure de dossiers de destination
Write-Host "`nCreation de la structure de dossiers..." -ForegroundColor Yellow
$directories = @(
    "docs\rapports\tests\escalation",
    "docs\rapports\tests\functional"
)

foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "  OK Cree: $dir" -ForegroundColor Green
    } else {
        Write-Host "  INFO Existe deja: $dir" -ForegroundColor Gray
    }
}

# Deplacer les fichiers avec git mv
Write-Host "`nDeplacement des fichiers avec git mv..." -ForegroundColor Yellow
$moves = @(
    @{
        Source = "tests\escalation\rapport-tests-escalade.md"
        Dest = "docs\rapports\tests\escalation\rapport-tests-escalade.md"
    },
    @{
        Source = "tests\functional\Jupyter_MCP_Test_Report.md"
        Dest = "docs\rapports\tests\functional\Jupyter_MCP_Test_Report.md"
    }
)

$movedCount = 0
foreach ($move in $moves) {
    if (Test-Path $move.Source) {
        git mv $move.Source $move.Dest
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  OK Deplace: $($move.Source) -> $($move.Dest)" -ForegroundColor Green
            $movedCount++
        } else {
            Write-Host "  ERREUR Echec: $($move.Source)" -ForegroundColor Red
        }
    } else {
        Write-Host "  ATTENTION Fichier non trouve: $($move.Source)" -ForegroundColor Yellow
    }
}

Write-Host "`n$movedCount fichier(s) deplace(s)" -ForegroundColor Cyan

# Cycle Git complet
Write-Host "`n=== Cycle Git ===" -ForegroundColor Cyan

Write-Host "`n1. git add ." -ForegroundColor Yellow
git add .
if ($LASTEXITCODE -eq 0) {
    Write-Host "  OK Modifications ajoutees" -ForegroundColor Green
} else {
    Write-Host "  ERREUR lors de git add" -ForegroundColor Red
    exit 1
}

Write-Host "`n2. git commit" -ForegroundColor Yellow
git commit -m "chore(docs): move test reports to documentation folder"
if ($LASTEXITCODE -eq 0) {
    Write-Host "  OK Commit cree" -ForegroundColor Green
} else {
    Write-Host "  ATTENTION Aucune modification a committer ou erreur" -ForegroundColor Yellow
}

Write-Host "`n3. git pull --rebase" -ForegroundColor Yellow
git pull --rebase
if ($LASTEXITCODE -eq 0) {
    Write-Host "  OK Pull rebase reussi" -ForegroundColor Green
} else {
    Write-Host "  ERREUR lors du pull rebase" -ForegroundColor Red
    exit 1
}

Write-Host "`n4. git push" -ForegroundColor Yellow
git push
if ($LASTEXITCODE -eq 0) {
    Write-Host "  OK Push reussi" -ForegroundColor Green
} else {
    Write-Host "  ERREUR lors du push" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Operation terminee avec succes ===" -ForegroundColor Green
Write-Host "Les rapports de tests ont ete deplaces vers docs/rapports/tests/" -ForegroundColor Cyan