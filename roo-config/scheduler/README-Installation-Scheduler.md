# Guide d'Installation et Configuration du Scheduler Roo Environment

## Vue d'ensemble

Ce guide détaille l'installation et la configuration du système de synchronisation automatisé pour l'environnement Roo via un dépôt Git. Le système est conçu pour fonctionner de manière non-interactive via le Planificateur de tâches Windows.

## Architecture du Système

### Composants Principaux

1. **`sync_roo_environment.ps1`** - Script principal de synchronisation
2. **`setup-scheduler.ps1`** - Script d'installation et gestion du scheduler
3. **`validate-sync.ps1`** - Script de validation et diagnostic
4. **Planificateur de tâches Windows** - Exécution automatisée

### Fichiers de Configuration Synchronisés

Le système synchronise automatiquement les fichiers suivants :

#### Paramètres Principaux
- `roo-config/settings/settings.json`
- `roo-config/settings/servers.json`
- `roo-config/settings/modes.json`
- `roo-config/escalation-test-config.json`
- `roo-config/qwen3-profiles/qwen3-parameters.json`

#### Scripts et Maintenance
- Tous les fichiers `.ps1` sous `roo-config/` (récursif)

#### Modes et Profils
- `roo-modes/configs/modes.json`
- `roo-modes/configs/new-roomodes.json`
- `roo-modes/configs/standard-modes.json`
- `roo-modes/configs/vscode-custom-modes.json`
- Tous les fichiers `.json` sous `roo-modes/n5/configs/`

#### Documentation
- Tous les fichiers `.md` sous `roo-config/` et `roo-modes/` (récursif)

## Installation

### Prérequis

1. **Droits Administrateur** - Requis pour créer des tâches planifiées
2. **PowerShell 5.1+** - Version minimale supportée
3. **Git** - Installé et configuré
4. **Dépôt Git** - Cloné dans `d:/roo-extensions`
5. **Connectivité réseau** - Accès au dépôt distant

### Étape 1 : Vérification de l'Environnement

```powershell
# Vérifier la version PowerShell
$PSVersionTable.PSVersion

# Vérifier Git
git --version

# Vérifier le dépôt
cd d:/roo-extensions
git status
```

### Étape 2 : Test du Script de Synchronisation

```powershell
# Tester le script principal
cd d:/roo-extensions
.\roo-config\scheduler\setup-scheduler.ps1 -Action test
```

### Étape 3 : Installation de la Tâche Planifiée

```powershell
# Installation avec intervalle par défaut (30 minutes)
.\roo-config\scheduler\setup-scheduler.ps1 -Action install

# Installation avec intervalle personnalisé (15 minutes)
.\roo-config\scheduler\setup-scheduler.ps1 -Action install -ScheduleInterval 15
```

### Étape 4 : Vérification de l'Installation

```powershell
# Vérifier le statut de la tâche
.\roo-config\scheduler\setup-scheduler.ps1 -Action status

# Diagnostic complet
.\roo-config\scheduler\validate-sync.ps1 -Action full
```

## Configuration

### Paramètres du Scheduler

Le script `setup-scheduler.ps1` accepte les paramètres suivants :

| Paramètre | Description | Défaut |
|-----------|-------------|---------|
| `ScheduleInterval` | Intervalle en minutes | 30 |
| `TaskName` | Nom de la tâche planifiée | RooEnvironmentSync |
| `ScriptPath` | Chemin vers le script de sync | d:\roo-extensions\sync_roo_environment.ps1 |

### Personnalisation du Script Principal

Dans `sync_roo_environment.ps1`, vous pouvez modifier :

```powershell
# Variables de configuration
$MainBranch = "main"        # Branche principale
$MaxLogSize = 10MB          # Taille max du log avant rotation
```

## Utilisation

### Commandes de Gestion

```powershell
# Installer la tâche planifiée
.\setup-scheduler.ps1 -Action install

# Désinstaller la tâche planifiée
.\setup-scheduler.ps1 -Action uninstall

# Vérifier le statut
.\setup-scheduler.ps1 -Action status

# Tester le script de synchronisation
.\setup-scheduler.ps1 -Action test
```

### Commandes de Diagnostic

```powershell
# Diagnostic complet
.\validate-sync.ps1 -Action full

# Vérification rapide
.\validate-sync.ps1 -Action quick

# Afficher les logs (50 dernières lignes)
.\validate-sync.ps1 -Action logs

# Afficher les logs (100 dernières lignes)
.\validate-sync.ps1 -Action logs -LogLines 100

# Vérifier les conflits
.\validate-sync.ps1 -Action conflicts

# Vérifier la santé du système
.\validate-sync.ps1 -Action health
```

## Surveillance et Maintenance

### Fichiers de Log

1. **`sync_log.txt`** - Log principal de synchronisation
2. **`sync_conflicts/`** - Répertoire des logs de conflits
3. **`scheduler_setup.log`** - Log d'installation du scheduler

### Rotation des Logs

Le système effectue automatiquement une rotation des logs quand ils dépassent 10MB :
- Le log actuel est renommé avec un timestamp
- Un nouveau log est créé

### Surveillance Recommandée

1. **Vérification quotidienne** :
   ```powershell
   .\validate-sync.ps1 -Action quick
   ```

2. **Vérification hebdomadaire** :
   ```powershell
   .\validate-sync.ps1 -Action full
   ```

3. **Surveillance des conflits** :
   ```powershell
   .\validate-sync.ps1 -Action conflicts
   ```

## Gestion des Erreurs

### Types d'Erreurs Communes

#### 1. Conflits Git
- **Symptôme** : Fichiers dans `sync_conflicts/`
- **Solution** : Résolution manuelle des conflits puis relance

#### 2. Problèmes de Connectivité
- **Symptôme** : Erreurs de `git pull`
- **Solution** : Vérifier la connectivité réseau et les credentials

#### 3. Fichiers JSON Invalides
- **Symptôme** : Erreurs de validation JSON
- **Solution** : Corriger la syntaxe JSON dans les fichiers concernés

#### 4. Permissions Insuffisantes
- **Symptôme** : Erreurs d'accès aux fichiers
- **Solution** : Vérifier les permissions du répertoire

### Codes de Sortie

| Code | Signification |
|------|---------------|
| 0 | Succès |
| 1 | Erreur générale |

### Résolution des Problèmes

1. **Vérifier les logs** :
   ```powershell
   .\validate-sync.ps1 -Action logs -LogLines 100
   ```

2. **Diagnostic complet** :
   ```powershell
   .\validate-sync.ps1 -Action full
   ```

3. **Test manuel** :
   ```powershell
   .\setup-scheduler.ps1 -Action test
   ```

## Sécurité

### Bonnes Pratiques

1. **Exécution en tant que SYSTEM** - La tâche planifiée s'exécute avec le compte SYSTEM
2. **Logs sécurisés** - Les logs ne contiennent pas d'informations sensibles
3. **Validation des entrées** - Tous les paramètres sont validés
4. **Gestion des erreurs** - Arrêt sécurisé en cas d'erreur critique

### Permissions Requises

- **Lecture/Écriture** sur `d:/roo-extensions`
- **Exécution** de Git et PowerShell
- **Accès réseau** au dépôt distant
- **Droits administrateur** pour l'installation du scheduler

## Dépannage Avancé

### Réinitialisation Complète

```powershell
# 1. Désinstaller la tâche
.\setup-scheduler.ps1 -Action uninstall

# 2. Nettoyer les logs
Remove-Item sync_log.txt -ErrorAction SilentlyContinue
Remove-Item sync_conflicts\* -ErrorAction SilentlyContinue

# 3. Vérifier le dépôt Git
git status
git stash clear

# 4. Réinstaller
.\setup-scheduler.ps1 -Action install
```

### Debug Mode

Pour activer un mode de debug plus verbeux, modifiez temporairement dans `sync_roo_environment.ps1` :

```powershell
$ErrorActionPreference = "Continue"  # Au lieu de "Stop"
```

### Vérification Manuelle des Fichiers

```powershell
# Vérifier la validité JSON de tous les fichiers de config
Get-ChildItem -Path "roo-config", "roo-modes" -Filter "*.json" -Recurse | ForEach-Object {
    Try {
        Get-Content -Raw $_.FullName | ConvertFrom-Json | Out-Null
        Write-Host "✓ $($_.Name)"
    } Catch {
        Write-Host "✗ $($_.Name): $($_.Exception.Message)"
    }
}
```

## Support et Maintenance

### Mise à Jour du Système

1. **Mise à jour des scripts** : Les scripts sont automatiquement synchronisés
2. **Mise à jour de la tâche planifiée** : Réinstaller si nécessaire
3. **Vérification post-mise à jour** : Toujours exécuter un diagnostic complet

### Contact et Support

- **Logs** : Toujours inclure les logs récents lors d'une demande de support
- **Diagnostic** : Exécuter `validate-sync.ps1 -Action full` avant de signaler un problème
- **Environnement** : Préciser la version de Windows, PowerShell et Git

---

*Guide d'installation version 1.0 - Dernière mise à jour : $(Get-Date -Format 'yyyy-MM-dd')*