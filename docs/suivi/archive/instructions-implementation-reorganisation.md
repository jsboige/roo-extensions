# Instructions d'implémentation du plan de réorganisation

Ce document fournit les instructions détaillées pour implémenter le plan de réorganisation du dépôt Roo Extensions tel que défini dans le fichier [plan-reorganisation-depot.md](plan-reorganisation-depot.md).

## 1. Création des nouveaux répertoires

Exécutez les commandes suivantes pour créer la nouvelle structure de répertoires :

```powershell
# Création des répertoires principaux
New-Item -Path "modules" -ItemType Directory -Force
New-Item -Path "modules/form-validator" -ItemType Directory -Force
New-Item -Path "modules/form-validator/tests" -ItemType Directory -Force

New-Item -Path "mcps/internal" -ItemType Directory -Force
New-Item -Path "mcps/external" -ItemType Directory -Force

New-Item -Path "scripts/deployment" -ItemType Directory -Force
New-Item -Path "scripts/maintenance" -ItemType Directory -Force
New-Item -Path "scripts/migration" -ItemType Directory -Force

New-Item -Path "tests/data" -ItemType Directory -Force
New-Item -Path "tests/results" -ItemType Directory -Force
New-Item -Path "tests/results/n5" -ItemType Directory -Force
New-Item -Path "tests/scripts" -ItemType Directory -Force

New-Item -Path "roo-code/docs" -ItemType Directory -Force
New-Item -Path "docs/guides" -ItemType Directory -Force

New-Item -Path "roo-config/settings/escalation" -ItemType Directory -Force

New-Item -Path "archive/legacy" -ItemType Directory -Force
```

## 2. Déplacement des fichiers

### 2.1 Fichiers à la racine

Exécutez les commandes suivantes pour déplacer les fichiers de la racine vers leurs nouveaux emplacements :

```powershell
# Module de validation de formulaire
Move-Item -Path "form-validator-client.js" -Destination "modules/form-validator/form-validator-client.js" -Force
Move-Item -Path "form-validator-README.md" -Destination "modules/form-validator/README.md" -Force
Move-Item -Path "form-validator-test.js" -Destination "modules/form-validator/tests/form-validator-test.js" -Force
Move-Item -Path "form-validator.html" -Destination "modules/form-validator/form-validator.html" -Force
Move-Item -Path "form-validator.js" -Destination "modules/form-validator/form-validator.js" -Force

# Documentation
Move-Item -Path "roo-code-documentation.md" -Destination "roo-code/docs/README.md" -Force
Move-Item -Path "instructions-modification-prompts.md" -Destination "docs/guides/instructions-modification-prompts.md" -Force

# Scripts PowerShell
Move-Item -Path "migrate-to-profiles.ps1" -Destination "scripts/migration/migrate-to-profiles.ps1" -Force
Move-Item -Path "update-mode-prompts-fixed.ps1" -Destination "scripts/maintenance/update-mode-prompts-fixed.ps1" -Force
Move-Item -Path "update-mode-prompts-v2.ps1" -Destination "scripts/maintenance/update-mode-prompts-v2.ps1" -Force
Move-Item -Path "update-mode-prompts.ps1" -Destination "scripts/maintenance/update-mode-prompts.ps1" -Force
Move-Item -Path "update-script-paths.ps1" -Destination "scripts/maintenance/update-script-paths.ps1" -Force
Move-Item -Path "organize-repo.ps1" -Destination "scripts/maintenance/organize-repo.ps1" -Force
```

### 2.2 Répertoires à réorganiser

Exécutez les commandes suivantes pour réorganiser les répertoires :

```powershell
# Suppression du répertoire NVIDIA Corporation (à adapter selon les besoins)
# Remove-Item -Path "NVIDIA Corporation" -Recurse -Force

# Réorganisation des configurations
Move-Item -Path "configs/escalation/*" -Destination "roo-config/settings/escalation/" -Force
Remove-Item -Path "configs" -Recurse -Force

# Réorganisation des tests
Move-Item -Path "test-data/*" -Destination "tests/data/" -Force
Remove-Item -Path "test-data" -Recurse -Force

Move-Item -Path "test-results/*" -Destination "tests/results/" -Force
Remove-Item -Path "test-results" -Recurse -Force

Move-Item -Path "roo-modes/n5/test-results/*" -Destination "tests/results/n5/" -Force
Remove-Item -Path "roo-modes/n5/test-results" -Recurse -Force

# Réorganisation des MCPs
Move-Item -Path "mcps/mcp-servers/*" -Destination "mcps/internal/" -Force
Remove-Item -Path "mcps/mcp-servers" -Recurse -Force

Move-Item -Path "mcps/external-mcps/*" -Destination "mcps/external/" -Force
Remove-Item -Path "mcps/external-mcps" -Recurse -Force
```

## 3. Mise à jour des références

Après avoir déplacé les fichiers, il faudra mettre à jour les références dans les fichiers pour refléter les nouveaux chemins. Cette étape nécessite une analyse manuelle des fichiers pour identifier et corriger les références.

Voici quelques exemples de références à mettre à jour :

1. Dans les fichiers markdown, mettre à jour les liens relatifs vers d'autres fichiers
2. Dans les scripts PowerShell, mettre à jour les chemins des fichiers
3. Dans les fichiers de configuration, mettre à jour les chemins des fichiers

## 4. Tests après réorganisation

Après avoir effectué la réorganisation, il est important de tester que tout fonctionne correctement :

1. Vérifier que tous les scripts PowerShell fonctionnent avec les nouveaux chemins
2. Vérifier que tous les liens dans la documentation sont valides
3. Vérifier que les configurations sont correctement chargées
4. Exécuter les tests pour s'assurer qu'ils fonctionnent toujours

## 5. Mise à jour de la documentation

Mettre à jour la documentation pour refléter la nouvelle structure :

1. Mettre à jour le README.md principal pour décrire la nouvelle structure
2. Créer ou mettre à jour les README.md dans chaque répertoire principal
3. Mettre à jour les guides d'utilisation pour refléter les nouveaux chemins

## 6. Recommandations supplémentaires

### 6.1 Nettoyage du répertoire archive

Évaluer le contenu du répertoire archive et décider pour chaque élément :
- S'il doit être intégré dans la nouvelle structure
- S'il doit être conservé dans archive/legacy
- S'il doit être supprimé

### 6.2 Standardisation des READMEs

S'assurer que chaque répertoire principal a un fichier README.md qui explique :
- Le rôle du répertoire
- Son contenu
- Comment l'utiliser
- Les liens vers la documentation connexe

### 6.3 Création d'un .gitignore

Créer ou mettre à jour le fichier .gitignore pour exclure :
- Les fichiers temporaires
- Les logs
- Les répertoires comme NVIDIA Corporation
- Les fichiers de sauvegarde

## 7. Suivi de la réorganisation

Créer un document de suivi pour :
- Documenter les changements effectués
- Noter les problèmes rencontrés et leurs solutions
- Identifier les améliorations futures possibles

## Notes importantes

- **Sauvegarde** : Avant de commencer la réorganisation, assurez-vous de faire une sauvegarde complète du dépôt.
- **Git** : Si vous utilisez Git, considérez l'utilisation de branches pour la réorganisation.
- **Approche incrémentale** : Envisagez d'effectuer la réorganisation par étapes plutôt que tout en une fois.
- **Communication** : Informez tous les contributeurs des changements à venir et de la nouvelle structure.