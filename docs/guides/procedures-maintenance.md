# Procédures de Maintenance du Dépôt

Ce document décrit les procédures de maintenance recommandées pour le dépôt `roo-extensions`. Ces procédures visent à maintenir la propreté, la cohérence et la stabilité du dépôt.

## Table des matières

1. [Nettoyage des fichiers temporaires](#nettoyage-des-fichiers-temporaires)
2. [Gestion du sous-module mcps/mcp-servers](#gestion-du-sous-module-mcpsmcp-servers)
3. [Bonnes pratiques pour la gestion des branches](#bonnes-pratiques-pour-la-gestion-des-branches)
4. [Utilisation du script de maintenance automatique](#utilisation-du-script-de-maintenance-automatique)

## Nettoyage des fichiers temporaires

Les fichiers temporaires et de sauvegarde peuvent s'accumuler au fil du temps et encombrer le dépôt. Bien que Git ignore la plupart de ces fichiers (grâce au fichier `.gitignore`), ils peuvent toujours causer des problèmes localement.

### Types de fichiers à nettoyer régulièrement

- **Fichiers temporaires** : `*.tmp`, `*.temp`
- **Fichiers de sauvegarde** : `*.bak`, `*.backup`, `*~`
- **Fichiers d'éditeurs** : `*.swp`, `*.swo` (Vim), `.DS_Store` (macOS)
- **Logs** : `*.log`

### Méthodes de nettoyage

#### Nettoyage manuel

Pour nettoyer manuellement les fichiers temporaires, vous pouvez utiliser les commandes suivantes :

**PowerShell** :
```powershell
# Rechercher les fichiers temporaires sans les supprimer
Get-ChildItem -Path . -Include *.tmp,*.temp,*.bak,*.backup,*.swp,*.swo,*~ -Recurse -File

# Supprimer les fichiers temporaires (à utiliser avec précaution)
Get-ChildItem -Path . -Include *.tmp,*.temp,*.bak,*.backup,*.swp,*.swo,*~ -Recurse -File | Remove-Item -Force
```

**Git** :
```bash
# Nettoyer les fichiers non suivis par Git
git clean -n  # Affiche les fichiers qui seraient supprimés sans les supprimer
git clean -fd  # Supprime les fichiers non suivis et les répertoires
```

#### Nettoyage automatique

Le script de maintenance automatique `maintenance-routine.ps1` inclut une fonction pour nettoyer les fichiers temporaires. Voir la section [Utilisation du script de maintenance automatique](#utilisation-du-script-de-maintenance-automatique) pour plus de détails.

## Gestion du sous-module mcps/mcp-servers

Le dépôt utilise un sous-module Git pour `mcps/mcp-servers`. Les sous-modules peuvent être difficiles à gérer et nécessitent une attention particulière.

### Initialisation du sous-module

Si le sous-module n'est pas initialisé après un clone du dépôt principal, exécutez :

```bash
git submodule init
git submodule update
```

### Mise à jour du sous-module

Pour mettre à jour le sous-module à la dernière version référencée par le dépôt principal :

```bash
git submodule update
```

Pour mettre à jour le sous-module à la dernière version disponible sur son dépôt distant :

```bash
cd mcps/mcp-servers
git checkout main  # ou la branche que vous souhaitez utiliser
git pull
cd ../..
git add mcps/mcp-servers
git commit -m "Mise à jour du sous-module mcps/mcp-servers"
```

### Vérification de l'état du sous-module

Pour vérifier l'état du sous-module :

```bash
git submodule status
```

Un préfixe `+` indique que la version locale du sous-module diffère de celle référencée par le dépôt principal.

### Bonnes pratiques pour les sous-modules

1. **Évitez de modifier directement les fichiers du sous-module** sauf si vous avez l'intention de contribuer à ce projet.
2. **Commitez toujours les changements de référence du sous-module** après une mise à jour.
3. **Vérifiez régulièrement** si le sous-module est à jour.
4. **Communiquez les changements** de sous-module à l'équipe.

## Bonnes pratiques pour la gestion des branches

Une bonne gestion des branches Git est essentielle pour maintenir un flux de travail efficace et éviter les conflits.

### Structure des branches

- **`main`** : Branche principale, stable et déployable.
- **Branches de fonctionnalités** : Nommées selon la convention `feature/nom-de-la-fonctionnalité`.
- **Branches de correction** : Nommées selon la convention `fix/description-du-problème`.
- **Branches de release** : Nommées selon la convention `release/x.y.z`.

### Cycle de vie des branches

1. **Création** : Créez une nouvelle branche à partir de `main` pour chaque fonctionnalité ou correction.
   ```bash
   git checkout main
   git pull
   git checkout -b feature/nouvelle-fonctionnalite
   ```

2. **Développement** : Travaillez sur votre branche, en faisant des commits réguliers.
   ```bash
   git add .
   git commit -m "Description claire des changements"
   ```

3. **Mise à jour** : Gardez votre branche à jour avec `main` pour éviter les conflits futurs.
   ```bash
   git checkout feature/nouvelle-fonctionnalite
   git merge main
   # ou
   git rebase main  # Si vous préférez un historique linéaire
   ```

4. **Fusion** : Une fois la fonctionnalité terminée, fusionnez-la dans `main`.
   ```bash
   git checkout main
   git merge --no-ff feature/nouvelle-fonctionnalite
   git push
   ```

5. **Nettoyage** : Supprimez les branches qui ont été fusionnées.
   ```bash
   git branch -d feature/nouvelle-fonctionnalite
   git push origin --delete feature/nouvelle-fonctionnalite  # Si la branche était sur le dépôt distant
   ```

### Bonnes pratiques générales

1. **Commits atomiques** : Chaque commit devrait représenter un changement logique unique.
2. **Messages de commit clairs** : Utilisez des messages descriptifs qui expliquent le "pourquoi" plutôt que le "quoi".
3. **Revue de code** : Faites réviser votre code avant de le fusionner dans `main`.
4. **Tests** : Assurez-vous que tous les tests passent avant de fusionner.
5. **Branches éphémères** : Ne gardez pas les branches de fonctionnalités trop longtemps.

## Utilisation du script de maintenance automatique

Le script `maintenance-routine.ps1` situé dans le répertoire `roo-config/` automatise plusieurs tâches de maintenance.

### Fonctionnalités du script

Le script effectue les opérations suivantes :

1. **Nettoyage des fichiers temporaires** : Recherche et supprime les fichiers temporaires et de sauvegarde.
2. **Vérification du sous-module** : S'assure que le sous-module `mcps/mcp-servers` est correctement initialisé et à jour.
3. **Vérification des branches Git** : Identifie les branches qui ont besoin d'être mises à jour ou qui peuvent être supprimées.

### Exécution du script

Pour exécuter le script, ouvrez PowerShell et naviguez jusqu'au répertoire racine du dépôt, puis exécutez :

```powershell
.\roo-config\maintenance-routine.ps1
```

### Journalisation

Le script génère des logs dans le fichier `logs/maintenance.log` et affiche également les informations dans la console. Les messages sont classés par niveau (`INFO`, `WARNING`, `ERROR`) pour faciliter l'identification des problèmes.

### Personnalisation

Vous pouvez personnaliser le script en modifiant les variables au début du fichier :

- `$RepoRoot` : Chemin vers la racine du dépôt.
- `$LogFile` : Chemin vers le fichier de log.

### Automatisation

Pour exécuter le script automatiquement à intervalles réguliers, vous pouvez créer une tâche planifiée :

**Windows (PowerShell)** :
```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File D:\Dev\roo-extensions\roo-config\maintenance-routine.ps1"
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 9am
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "RooExtensions-Maintenance" -Description "Maintenance automatique du dépôt roo-extensions"
```

## Conclusion

En suivant ces procédures de maintenance régulièrement, vous contribuerez à maintenir la qualité et la stabilité du dépôt `roo-extensions`. La combinaison de pratiques manuelles et automatisées garantit que le dépôt reste propre, bien organisé et facile à maintenir pour tous les contributeurs.

N'hésitez pas à suggérer des améliorations à ces procédures ou au script de maintenance automatique en créant une issue ou une pull request.