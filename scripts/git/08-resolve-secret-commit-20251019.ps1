# Script pour résoudre le problème de clé API dans l'historique Git
Write-Host "=== RÉSOLUTION DU PROBLÈME DE CLÉ API DANS L'HISTORIQUE ===" -ForegroundColor Cyan

Write-Host "Problème: GitHub détecte une clé API OpenAI dans le commit 4d9f748" -ForegroundColor Yellow
Write-Host "Solution: Utiliser git rebase pour modifier le commit problématique" -ForegroundColor Green

# Étape 1: Créer un backup avant rebase
$backupBranch = "backup-before-rebase-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
git branch $backupBranch
Write-Host "✅ Branch de backup créée : $backupBranch" -ForegroundColor Green

# Étape 2: Identifier le commit à modifier
$problematicCommit = "4d9f748"
Write-Host "Commit problématique identifié : $problematicCommit" -ForegroundColor Yellow

# Étape 3: Lancer le rebase interactif
Write-Host "`nLancement du rebase interactif pour modifier le commit $problematicCommit" -ForegroundColor Yellow
Write-Host "Cette opération va modifier l'historique Git" -ForegroundColor Red
Write-Host "Instructions:" -ForegroundColor White
Write-Host "1. Changer 'pick' par 'edit' pour le commit $problematicCommit" -ForegroundColor White
Write-Host "2. Sauvegarder et quitter l'éditeur" -ForegroundColor White
Write-Host "3. Exécuter les commandes de correction automatiques" -ForegroundColor White

# Démarrer le rebase interactif
git rebase -i $problematicCommit^

Write-Host "`n=== OPÉRATION TERMINÉE ===" -ForegroundColor Cyan
Write-Host "Vérifiez l'état du repository avec:" -ForegroundColor Yellow
Write-Host "git status" -ForegroundColor White
Write-Host "git log --oneline -5" -ForegroundColor White