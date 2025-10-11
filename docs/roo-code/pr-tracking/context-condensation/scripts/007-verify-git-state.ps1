# Vérification de l'état Git et des versions
# Date: 2025-10-08

Write-Host "`n=== VERIFICATION ETAT GIT ===" -ForegroundColor Cyan

Set-Location "C:\dev\roo-code"

# 1. Branche actuelle
Write-Host "`n1. Branche actuelle:" -ForegroundColor Yellow
$branch = git branch --show-current
Write-Host "  $branch" -ForegroundColor Green

# 2. Derniers commits
Write-Host "`n2. Derniers commits:" -ForegroundColor Yellow
git log --oneline -5

# 3. Modifications non commitées
Write-Host "`n3. Fichiers modifies non commites:" -ForegroundColor Yellow
$status = git status --porcelain
if ($status) {
    Write-Host $status -ForegroundColor Red
    Write-Host "`n[ATTENTION] Modifications non commitees detectees!" -ForegroundColor Red
} else {
    Write-Host "  [OK] Aucune modification non commitee" -ForegroundColor Green
}

# 4. Fichiers staged
Write-Host "`n4. Fichiers staged:" -ForegroundColor Yellow
$staged = git diff --cached --name-only
if ($staged) {
    Write-Host $staged -ForegroundColor Cyan
} else {
    Write-Host "  [OK] Aucun fichier staged" -ForegroundColor Green
}

# 5. Version extension active
Write-Host "`n5. Version extension active dans VSCode:" -ForegroundColor Yellow
$extDirs = Get-ChildItem "$env:USERPROFILE\.vscode\extensions" -Filter "rooveterinaryinc.roo-cline-*" | 
    Sort-Object LastWriteTime -Descending
$extDirs | ForEach-Object { 
    Write-Host "  $($_.Name) - $($_.LastWriteTime)" -ForegroundColor Gray 
}

# 6. Date dernier build webview-ui
Write-Host "`n6. Date dernier build webview-ui:" -ForegroundColor Yellow
if (Test-Path "src\webview-ui\build\assets\index.js") {
    $buildDate = (Get-Item "src\webview-ui\build\assets\index.js").LastWriteTime
    Write-Host "  $buildDate" -ForegroundColor Green
} else {
    Write-Host "  [ERREUR] Build webview-ui introuvable" -ForegroundColor Red
}

Write-Host "`n=== FIN VERIFICATION ===" -ForegroundColor Cyan