# Script pour ajouter l'auto-review dans le workflow du scheduler
# Modifie les fichiers workflow pour détecter les nouveaux commits

$ErrorActionPreference = "Stop"

Write-Host "[MODIFICATION] Ajout de l'auto-review dans le workflow..." -ForegroundColor Green

# Chemins des fichiers workflow
$coordinatorWorkflow = ".roo/scheduler-workflow-coordinator.md"
$executorWorkflow = ".roo/scheduler-workflow-executor.md"

# Vérifier que les fichiers existent
if (-not (Test-Path $coordinatorWorkflow)) {
    Write-Host "[ERREUR] Fichier introuvable: $coordinatorWorkflow" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $executorWorkflow)) {
    Write-Host "[ERREUR] Fichier introuvable: $executorWorkflow" -ForegroundColor Red
    exit 1
}

# Contenu à ajouter pour la détection des commits
$gitCheckContent = @"
### Etape 1d : Vérification des nouveaux commits (Auto-Review)

Après le pull git, vérifier s'il y a de nouveaux commits:

```
execute_command(shell="gitbash", command="git log --oneline -2")
execute_command(shell="gitbash", command="git rev-parse HEAD~1")
```

Si HEAD différent de HEAD~1 (nouveau commit local):

1. Appeler le script d'auto-review:
   execute_command(shell="powershell", command="cd D:/Dev/roo-extensions/scripts/review; .\start-auto-review.ps1")
2. Si échec: noter dans le bilan mais continuer

**Raison:** Détecter les commits locaux (push manuel ou autre source) et lancer une review automatique.
"@

# Ajouter la section au workflow coordinateur
try {
    $content = Get-Content $coordinatorWorkflow -Raw
    if ($content -notmatch "### Etape 1d") {
        # Insérer avant la section suivante
        $insertPoint = $content.IndexOf("### Etape 2a")
        if ($insertPoint -gt 0) {
            $newContent = $content.Substring(0, $insertPoint) + "`n`n" + $gitCheckContent + "`n`n" + $content.Substring($insertPoint)
            $newContent | Set-Content $coordinatorWorkflow -NoNewline
            Write-Host "[SUCCES] Section 1d ajoutée au workflow coordinateur" -ForegroundColor Green
        }
    } else {
        Write-Host "[INFO] La section 1d existe déjà dans le coordinateur" -ForegroundColor Yellow
    }
} catch {
    Write-Host "[ERREUR] modification coordinateur: $_" -ForegroundColor Red
    exit 1
}

# Contenu pour les exécutants (détection simple)
$executorGitCheck = @"
### Etape 2c : Vérification commits locale (si exécuteur)

Optionnel: si le scheduler tourne sur une machine avec des commits locaux:

```
execute_command(shell="gitbash", command="git log --oneline -2")
```

Si nouveau commit local: déléguer à auto-review via code-complex.

**Note:** Cette étape est optionnelle et peut être activée par machine selon le besoin.
"@

# Ajouter au workflow executor
try {
    $content = Get-Content $executorWorkflow -Raw
    if ($content -notmatch "### Etape 2c") {
        $insertPoint = $content.IndexOf("### Etape 3")
        if ($insertPoint -gt 0) {
            $newContent = $content.Substring(0, $insertPoint) + "`n`n" + $executorGitCheck + "`n`n" + $content.Substring($insertPoint)
            $newContent | Set-Content $executorWorkflow -NoNewline
            Write-Host "[SUCCES] Section 2c ajoutée au workflow executor" -ForegroundColor Green
        }
    } else {
        Write-Host "[INFO] La section 2c existe déjà dans l'executor" -ForegroundColor Yellow
    }
} catch {
    Write-Host "[ERREUR] modification executor: $_" -ForegroundColor Red
    exit 1
}

# Régénérer les modes
Write-Host "[MODIFICATION] Régénération des modes..."
try {
    node roo-config/scripts/generate-modes.js
    Copy-Item roo-config/modes/generated/simple-complex.roomodes .roomodes
    Write-Host "[SUCCES] Modes régénérés avec succès" -ForegroundColor Green
} catch {
    Write-Host "[ERREUR] échec de la régénération des modes: $_" -ForegroundColor Red
    exit 1
}

Write-Host "[MODIFICATION] Ajout de l'auto-review terminé!" -ForegroundColor Green
Write-Host "N'oubliez pas de:" -ForegroundColor Yellow
Write-Host "1. Commiter les modifications: git add . && git commit -m 'feat: Ajout auto-review sk-agent'" -ForegroundColor Yellow
Write-Host "2. Pousser: git push" -ForegroundColor Yellow
Write-Host "3. Redémarrer VS Code pour appliquer les nouveaux modes" -ForegroundColor Yellow