# Hook Pre-commit Git pour Roo Extensions

Ce document décrit le fonctionnement et l'utilisation du hook pre-commit mis en place pour prévenir les régressions dans le projet Roo Extensions.

## 🎯 Objectif

L'objectif de ce hook est d'exécuter automatiquement une suite de tests critiques avant chaque commit. Si les tests échouent, le commit est bloqué, garantissant ainsi que le code commité est toujours dans un état stable (du moins pour les fonctionnalités testées).

## ⚙️ Fonctionnement

Le hook est installé dans `.git/hooks/pre-commit`. C'est un script Bash (compatible Windows via Git Bash et PowerShell) qui :

1.  Détecte l'interpréteur PowerShell disponible (`pwsh` ou `powershell`).
2.  Exécute le script runner PowerShell : `scripts/git/pre-commit-runner.ps1`.
3.  Analyse le code de retour du runner.
4.  Bloque le commit (code de retour 1) ou l'autorise (code de retour 0).

### Le Runner PowerShell (`scripts/git/pre-commit-runner.ps1`)

Ce script est le cœur de la validation. Il est responsable de :
- Lancer les tests Pester définis dans la liste `$CriticalTests`.
- Afficher les résultats de manière lisible (couleurs, résumé).
- Retourner un code de sortie approprié.

**Tests actuellement exécutés :**
- `tests/Configuration.tests.ps1` : Validation du module de configuration.

## 🛠️ Installation

Si vous venez de cloner le dépôt, le hook n'est pas actif par défaut (Git ne versionne pas le répertoire `.git/hooks`).
Le fichier a été créé directement dans `.git/hooks/pre-commit` pour cette mission, mais pour une installation pérenne ou sur une autre machine, vous pouvez copier le script :

```bash
cp scripts/git/pre-commit-sample .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```
*(Note : Dans le cadre de cette tâche, le fichier a été créé directement en place)*

## 🚀 Utilisation

Le hook est automatique. Lorsque vous faites `git commit`, les tests se lancent.

**Exemple de sortie (Succès) :**
```text
🔄 [Pre-commit] Initialisation...
🚀 [Pre-commit] Exécution du runner PowerShell...
🔍 [Pre-commit] Lancement de la validation...
   Running tests/Configuration.tests.ps1... ✅ SUCCÈS

📊 [Pre-commit] Résumé :
   Total Tests : 3
   Succès      : 3
   Échecs      : 0

✅ [Pre-commit] Tous les tests critiques ont réussi. Commit autorisé.
```

**Exemple de sortie (Échec) :**
```text
...
   Running tests/Configuration.tests.ps1... ❌ ÉCHEC

📊 [Pre-commit] Résumé :
   Total Tests : 3
   Succès      : 2
   Échecs      : 1

⛔ [Pre-commit] Des tests critiques ont échoué. Le commit est bloqué.
   Veuillez corriger les erreurs avant de commiter.
```

## ⚠️ Contournement (Bypass)

En cas d'urgence absolue, ou si vous savez ce que vous faites (ex: commit de documentation uniquement), vous pouvez contourner le hook avec l'option `--no-verify` (ou `-n`) :

```bash
git commit -m "Message de commit" --no-verify
```

## ➕ Ajouter des tests

Pour ajouter de nouveaux tests à la validation pre-commit, modifiez le fichier `scripts/git/pre-commit-runner.ps1` et ajoutez le chemin de votre fichier de test Pester au tableau `$CriticalTests`.

```powershell
$CriticalTests = @(
    "tests/Configuration.tests.ps1",
    "tests/NouveauTestCritique.tests.ps1" # <--- Ajout
)