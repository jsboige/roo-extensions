# Script Git Sync - Submodule Hierarchy
# Date: 2025-10-15
# Objectif: Synchroniser la hierarchie complete des sous-modules

$ErrorActionPreference = "Stop"

Write-Host "`n=== GIT SYNC - SUBMODULE HIERARCHY ===" -ForegroundColor Cyan

# Etape 1: Commiter dans mcps/internal
Write-Host "`n[1/4] Synchronisation mcps/internal..." -ForegroundColor Yellow
Set-Location "d:/dev/roo-extensions/mcps/internal"
Write-Host "[INFO] Working directory: $(Get-Location)" -ForegroundColor Gray

git status --short
git add servers/roo-state-manager

$commitMsgFile = "commit-msg-internal.txt"
"chore(submodules): update roo-state-manager to c609b60" | Out-File -FilePath $commitMsgFile -Encoding UTF8
"" | Out-File -FilePath $commitMsgFile -Append -Encoding UTF8
"Phase 1 partial: 7 tests fixed + documentation" | Out-File -FilePath $commitMsgFile -Append -Encoding UTF8

git commit -F $commitMsgFile
Remove-Item $commitMsgFile -ErrorAction SilentlyContinue
$internalCommit = git rev-parse --short HEAD
Write-Host "[OK] mcps/internal commit: $internalCommit" -ForegroundColor Green

# Push mcps/internal
git pull --rebase origin main
git push origin main
Write-Host "[OK] mcps/internal pushed" -ForegroundColor Green

# Etape 2: Commiter dans roo-extensions
Write-Host "`n[2/4] Synchronisation roo-extensions..." -ForegroundColor Yellow
Set-Location "d:/dev/roo-extensions"
Write-Host "[INFO] Working directory: $(Get-Location)" -ForegroundColor Gray

git status --short
git add mcps/internal

$commitMsgFile = "commit-msg-main.txt"
"chore(submodules): sync mcps/internal - roo-state-manager phase 1" | Out-File -FilePath $commitMsgFile -Encoding UTF8
"" | Out-File -FilePath $commitMsgFile -Append -Encoding UTF8
"Updates:" | Out-File -FilePath $commitMsgFile -Append -Encoding UTF8
"- mcps/internal: $internalCommit" | Out-File -FilePath $commitMsgFile -Append -Encoding UTF8
"- roo-state-manager: c609b60" | Out-File -FilePath $commitMsgFile -Append -Encoding UTF8
"" | Out-File -FilePath $commitMsgFile -Append -Encoding UTF8
"Progress: 372 to 379 of 478 tests" | Out-File -FilePath $commitMsgFile -Append -Encoding UTF8
"Status: Ready for Phase 1 completion" | Out-File -FilePath $commitMsgFile -Append -Encoding UTF8

git commit -F $commitMsgFile
Remove-Item $commitMsgFile -ErrorAction SilentlyContinue
$mainCommit = git rev-parse --short HEAD
Write-Host "[OK] roo-extensions commit: $mainCommit" -ForegroundColor Green

# Push roo-extensions
git pull --rebase origin main
git push origin main
Write-Host "[OK] roo-extensions pushed" -ForegroundColor Green

# Resume
Write-Host "`n=== RESUME ===" -ForegroundColor Cyan
Write-Host "roo-state-manager: c609b60" -ForegroundColor White
Write-Host "mcps/internal:     $internalCommit" -ForegroundColor White
Write-Host "roo-extensions:    $mainCommit" -ForegroundColor White
Write-Host "Status: Fully synchronized" -ForegroundColor Green
Write-Host "`n[OK] Hierarchie complete synchronisee" -ForegroundColor Green