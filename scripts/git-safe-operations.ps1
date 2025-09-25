# Script de sécurité Git pour éviter les push --force accidentels
# Auteur: Roo Debug Agent
# Date: 25/09/2025

# Configuration des alias Git sécurisés
Write-Host "🔧 Configuration des alias Git sécurisés..." -ForegroundColor Cyan

# Push sécurisé avec --force-with-lease
git config --global alias.safe-push "push --force-with-lease"

# Rebase interactif avec autostash
git config --global alias.safe-rebase "rebase --interactive --autostash"

# Status détaillé
git config --global alias.st "status -sb"

# Log graphique amélioré
git config --global alias.lg "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"

Write-Host "✅ Alias configurés avec succès" -ForegroundColor Green

# Fonction de sauvegarde avant opération risquée
function Create-GitBackup {
    param(
        [string]$Operation = "operation"
    )
    
    $backupBranch = "backup-$Operation-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    git branch $backupBranch
    Write-Host "✅ Branche de sauvegarde créée : $backupBranch" -ForegroundColor Green
    return $backupBranch
}

# Fonction de vérification avant push
function Test-SafePush {
    $currentBranch = git rev-parse --abbrev-ref HEAD
    
    if ($currentBranch -eq "main" -or $currentBranch -eq "master") {
        Write-Host "⚠️  ATTENTION : Vous êtes sur la branche $currentBranch" -ForegroundColor Yellow
        Write-Host "Vérifications de sécurité :" -ForegroundColor Cyan
        
        # Vérifier les commits locaux non pushés
        $unpushed = git log origin/$currentBranch..$currentBranch --oneline
        if ($unpushed) {
            Write-Host "📝 Commits locaux non pushés :" -ForegroundColor Cyan
            Write-Host $unpushed
        }
        
        # Vérifier les différences avec origin
        $ahead = git rev-list --count origin/$currentBranch..$currentBranch
        $behind = git rev-list --count $currentBranch..origin/$currentBranch
        
        Write-Host "📊 État : $ahead commits en avance, $behind commits en retard" -ForegroundColor Cyan
        
        if ($behind -gt 0) {
            Write-Host "⚠️  ATTENTION : Votre branche est en retard sur origin!" -ForegroundColor Red
            Write-Host "Un push --force écrasera $behind commits sur le serveur!" -ForegroundColor Red
            
            $response = Read-Host "Voulez-vous créer une branche de sauvegarde ? (o/n)"
            if ($response -eq 'o' -or $response -eq 'O') {
                Create-GitBackup -Operation "pre-push"
            }
        }
        
        Write-Host "`nCommandes recommandées :" -ForegroundColor Green
        Write-Host "  git push                    # Push normal" -ForegroundColor White
        Write-Host "  git safe-push               # Push avec --force-with-lease" -ForegroundColor White
        Write-Host "  git pull --rebase          # Synchroniser avec origin" -ForegroundColor White
    }
}

# Fonction pour analyser les commits orphelins
function Get-OrphanCommits {
    Write-Host "🔍 Recherche des commits orphelins..." -ForegroundColor Cyan
    
    $orphans = git fsck --lost-found 2>&1 | Select-String "commit" | ForEach-Object {
        $sha = $_.Line -replace '.*commit\s+', ''
        $info = git show --oneline --no-patch $sha 2>$null
        if ($info) {
            [PSCustomObject]@{
                SHA = $sha.Substring(0, 8)
                Message = $info -replace '^[a-f0-9]+\s+', ''
            }
        }
    }
    
    if ($orphans) {
        Write-Host "📦 Commits orphelins trouvés :" -ForegroundColor Yellow
        $orphans | Format-Table -AutoSize
        
        Write-Host "`nPour récupérer un commit : git cherry-pick <SHA>" -ForegroundColor Green
        Write-Host "Pour créer une branche : git branch recovery-branch <SHA>" -ForegroundColor Green
    } else {
        Write-Host "✅ Aucun commit orphelin trouvé" -ForegroundColor Green
    }
}

# Menu principal
function Show-GitSafetyMenu {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "     Git Safety Tools - Roo Extensions  " -ForegroundColor White
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Créer une branche de sauvegarde" -ForegroundColor Yellow
    Write-Host "2. Vérifier avant un push" -ForegroundColor Yellow
    Write-Host "3. Rechercher les commits orphelins" -ForegroundColor Yellow
    Write-Host "4. Afficher le reflog récent" -ForegroundColor Yellow
    Write-Host "5. Configurer les hooks de protection" -ForegroundColor Yellow
    Write-Host "6. Quitter" -ForegroundColor Yellow
    Write-Host ""
    
    $choice = Read-Host "Choisissez une option (1-6)"
    
    switch ($choice) {
        "1" {
            $op = Read-Host "Nom de l'opération (ex: rebase, merge)"
            Create-GitBackup -Operation $op
            Pause
            Show-GitSafetyMenu
        }
        "2" {
            Test-SafePush
            Pause
            Show-GitSafetyMenu
        }
        "3" {
            Get-OrphanCommits
            Pause
            Show-GitSafetyMenu
        }
        "4" {
            Write-Host "📜 Reflog récent :" -ForegroundColor Cyan
            git reflog --date=iso --format='%cd | %gd | %gs' -n 20
            Pause
            Show-GitSafetyMenu
        }
        "5" {
            Write-Host "📝 Création du hook pre-push..." -ForegroundColor Cyan
            $hookPath = ".git/hooks/pre-push"
            $hookContent = @'
#!/bin/sh
# Hook de protection contre les push --force sur main
protected_branch='main'
current_branch=$(git symbolic-ref HEAD | sed -e 's,.*/\(.*\),\1,')

if [ "$current_branch" = "$protected_branch" ]; then
    echo "⚠️  Push vers $protected_branch détecté!"
    echo "Utilisez 'git push --force-with-lease' au lieu de '--force'"
    read -p "Continuer ? (y/n) " -n 1 -r < /dev/tty
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi
'@
            $hookContent | Out-File -FilePath $hookPath -Encoding UTF8
            Write-Host "✅ Hook créé dans $hookPath" -ForegroundColor Green
            Pause
            Show-GitSafetyMenu
        }
        "6" {
            Write-Host "Au revoir ! 👋" -ForegroundColor Green
            return
        }
        default {
            Write-Host "Option invalide" -ForegroundColor Red
            Pause
            Show-GitSafetyMenu
        }
    }
}

# Si le script est exécuté directement, afficher le menu
if ($MyInvocation.InvocationName -ne '.') {
    Show-GitSafetyMenu
}

# Export des fonctions pour utilisation dans d'autres scripts
Export-ModuleMember -Function Create-GitBackup, Test-SafePush, Get-OrphanCommits, Show-GitSafetyMenu