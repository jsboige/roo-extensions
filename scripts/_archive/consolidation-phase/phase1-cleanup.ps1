# Phase 1 - Quick Wins (risque faible)
# Grand nettoyage et consolidation depot - issue #470

Write-Host "=== Phase 1 : Quick Wins ===" -ForegroundColor Cyan

# 1. Supprimer mcps/tests/github-projects/ (~10 fichiers, MCP deprecie #368)
Write-Host "`n[1/5] Vérification mcps/tests/github-projects/" -ForegroundColor Yellow
if (Test-Path "mcps/tests/github-projects") {
    $files = Get-ChildItem "mcps/tests/github-projects" -Recurse
    if ($files.Count -gt 0) {
        Write-Host "   → Suppression de $($files.Count) fichiers" -ForegroundColor Red
        Remove-Item "mcps/tests/github-projects" -Recurse -Force
    } else {
        Write-Host "   → Déjà vide, rien à faire" -ForegroundColor Green
    }
} else {
    Write-Host "   → Déjà supprimé" -ForegroundColor Green
}

# 2. Supprimer rapports timestampes > 3 mois dans mcps/tests/reports/
Write-Host "`n[2/5] Vérification mcps/tests/reports/" -ForegroundColor Yellow
$threeMonthsAgo = (Get-Date).AddMonths(-3)
$oldReports = Get-ChildItem "mcps/tests/reports" -File | Where-Object { $_.LastWriteTime -lt $threeMonthsAgo }
if ($oldReports.Count -gt 0) {
    Write-Host "   → Suppression de $($oldReports.Count) rapports anciens" -ForegroundColor Red
    $oldReports | Remove-Item -Force
} else {
    Write-Host "   → Aucun rapport ancien trouvé" -ForegroundColor Green
}

# 3. Deplacer .claude/investigation-461-phase1.md vers docs/architecture/investigations/
Write-Host "`n[3/5] Déplacement .claude/investigation-461-phase1.md" -ForegroundColor Yellow
if (Test-Path ".claude/investigation-461-phase1.md") {
    $lines = (Get-Content ".claude/investigation-461-phase1.md").Count
    Write-Host "   → Déplacement de $lines lignes" -ForegroundColor Cyan
    New-Item -ItemType Directory -Path "docs/architecture/investigations" -Force | Out-Null
    Move-Item ".claude/investigation-461-phase1.md" "docs/architecture/investigations/" -Force
} else {
    Write-Host "   → Fichier non trouvé" -ForegroundColor Red
}

# 4. Deplacer .claude/proposals/todo11-*.md vers docs/architecture/proposals/
Write-Host "`n[4/5] Vérification .claude/proposals/todo11-*.md" -ForegroundColor Yellow
$todoFiles = Get-ChildItem ".claude/proposals" -Filter "todo11-*.md" -File
if ($todoFiles.Count -gt 0) {
    $lines = ($todoFiles | ForEach-Object { (Get-Content $_.FullName).Count }) -join " + "
    Write-Host "   → Déplacement de $lines lignes" -ForegroundColor Cyan
    New-Item -ItemType Directory -Path "docs/architecture/proposals" -Force | Out-Null
    $todoFiles | Move-Item -Destination "docs/architecture/proposals/" -Force
} else {
    Write-Host "   → Fichier non trouvé" -ForegroundColor Red
}

# 5. Supprimer docs/archive/roosync-v2-1-*.md (5 fichiers, ~70KB, supersedes par v2.3)
Write-Host "`n[5/5] Vérification docs/archive/roosync-v2-1-*.md" -ForegroundColor Yellow
$v2Files = Get-ChildItem "docs/archive" -Filter "roosync-v2-1-*.md" -File
if ($v2Files.Count -gt 0) {
    $size = ($v2Files | ForEach-Object { $_.Length }) -join " + "
    Write-Host "   → Suppression de $($v2Files.Count) fichiers ($size bytes)" -ForegroundColor Red
    $v2Files | Remove-Item -Force
} else {
    Write-Host "   → Fichiers non trouvés" -ForegroundColor Green
}

Write-Host "`n=== Phase 1 Terminée ===" -ForegroundColor Green
Write-Host "Vérifiez git status pour voir les changements." -ForegroundColor Yellow
