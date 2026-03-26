# Guide de Déploiement - Claude Worker Schedulers

## Vue d'ensemble

Ce guide explique comment déployer les tâches Windows Task Scheduler pour le Claude Worker sur toutes les machines exécutrices du système RooSync.

## Prérequis

### 1. Configuration SSH

Les connexions SSH doivent être configurées dans `mcps/external/win-cli/config/win_cli_config.json` :

```json
{
  "ssh": {
    "enabled": true,
    "connections": {
      "myia-po-2023": {
        "host": "myia-po-2023.local",
        "port": 22,
        "username": "jsboi",
        "password": "<votre_mot_de_passe>"
      },
      "myia-po-2024": {
        "host": "myia-po-2024.local",
        "port": 22,
        "username": "jsboi",
        "password": "<votre_mot_de_passe>"
      },
      "myia-po-2025": {
        "host": "myia-po-2025.local",
        "port": 22,
        "username": "jsboi",
        "password": "<votre_mot_de_passe>"
      },
      "myia-po-2026": {
        "host": "myia-po-2026.local",
        "port": 22,
        "username": "jsboi",
        "password": "<votre_mot_de_passe>"
      },
      "myia-web1": {
        "host": "myia-web1.local",
        "port": 22,
        "username": "jsboi",
        "password": "<votre_mot_de_passe>"
      }
    }
  }
}
```

**IMPORTANT :** Remplacez `<votre_mot_de_passe>` par les mots de passe réels.

### 2. Prérequis sur les machines cibles

Chaque machine doit avoir :

- **Claude CLI installé** : `npm install -g @anthropic-ai/claude-code`
- **GitHub CLI authentifié** avec scope `project` :
  ```bash
  gh auth login
  gh auth refresh --hostname github.com -s project
  ```
- **Repo roo-extensions cloné** à jour :
  ```bash
  cd D:\Dev\roo-extensions
  git pull
  ```

## Méthodes de Déploiement

### Méthode 1 : Script Automatisé (Recommandé)

Utilisez le script `deploy-schedulers.ps1` pour déployer sur toutes les machines :

```powershell
# Déploiement complet (worker + meta-audit sur toutes les machines)
cd D:\Dev\roo-extensions\scripts\scheduling
.\deploy-schedulers.ps1

# Déploiement sélectif (seulement worker sur certaines machines)
.\deploy-schedulers.ps1 -Machines myia-po-2023,myia-po-2024 -TaskTypes worker

# Mode simulation (dry-run)
.\deploy-schedulers.ps1 -DryRun
```

### Méthode 2 : Déploiement Manuel

Pour chaque machine, exécutez manuellement :

```powershell
# Sur myia-po-2023
ssh jsboi@myia-po-2023.local "cd D:\\Dev\\roo-extensions ; git pull ; powershell -ExecutionPolicy Bypass -File scripts\\scheduling\\setup-scheduler.ps1 -Action install"

ssh jsboi@myia-po-2023.local "cd D:\\Dev\\roo-extensions ; powershell -ExecutionPolicy Bypass -File scripts\\scheduling\\setup-scheduler.ps1 -Action install -TaskType meta-audit"

# Vérification
ssh jsboi@myia-po-2023.local "cd D:\\Dev\\roo-extensions ; powershell -ExecutionPolicy Bypass -File scripts\\scheduling\\setup-scheduler.ps1 -Action list"
ssh jsboi@myia-po-2023.local "cd D:\\Dev\\roo-extensions ; powershell -ExecutionPolicy Bypass -File scripts\\scheduling\\setup-scheduler.ps1 -Action list -TaskType meta-audit"
```

Répétez pour chaque machine : myia-po-2024, myia-po-2025, myia-po-2026, myia-web1.

## Types de Tâches

### Worker (6h, Sonnet)

- **Fréquence** : Toutes les 6 heures
- **Modèle** : Sonnet (avec auto-escalation vers Opus)
- **Rôle** : Exécuteur - traite toutes les issues GitHub dispatchées
- **Machines** : Toutes les machines exécutrices

### Meta-Audit (72h, Opus)

- **Fréquence** : Toutes les 72 heures
- **Modèle** : Opus
- **Rôle** : Meta-Analyste - analyse les traces Roo et Claude
- **Machines** : Toutes les machines exécutrices

## Vérification

Après déploiement, vérifiez que les tâches sont installées :

```powershell
# Sur chaque machine
schtasks /Query /TN "Claude-Worker"
schtasks /Query /TN "Claude-Meta-Audit"
```

Les tâches doivent être en état "Ready".

## Dépannage

### Erreur de connexion SSH

```
✗ Connexion SSH échouée vers myia-po-2023
```

**Solutions :**
1. Vérifiez que le service SSH est actif sur la machine cible
2. Vérifiez les identifiants dans `win_cli_config.json`
3. Testez manuellement : `ssh jsboi@myia-po-2023.local hostname`

### Erreur d'installation

```
✗ Erreur installation worker sur myia-po-2023
```

**Solutions :**
1. Vérifiez que le repo est à jour : `git pull`
2. Vérifiez que PowerShell est accessible
3. Consultez les logs dans `D:\Dev\roo-extensions\.claude\logs\`

### Tâche non trouvée

```
ERROR: Task not found
```

**Solutions :**
1. Réinstallez avec `setup-scheduler.ps1 -Action install`
2. Vérifiez les permissions administrateur
3. Consultez le Task Scheduler Windows

## Contraintes Spécifiques

### myia-web1

- **Tests** : Toujours utiliser `--maxWorkers=1`
- **Chemin GDrive** : `C:\Drive\.shortcut-targets-by-id\{ID}\.shared-state` (pas `G:\Mon Drive\`)
- **Seuil condensation** : 80% minimum

## Maintenance

### Mise à jour des tâches

Pour mettre à jour une tâche existante :

```powershell
# Réinstaller (remplace la configuration existante)
.\setup-scheduler.ps1 -Action install -TaskType worker
```

### Suppression des tâches

```powershell
# Sur chaque machine
.\setup-scheduler.ps1 -Action remove -TaskType worker
.\setup-scheduler.ps1 -Action remove -TaskType meta-audit
```

## Références

- Issue #859 : Déploiement schtasks Claude Worker
- Script principal : `scripts/scheduling/setup-scheduler.ps1`
- Script de déploiement : `scripts/scheduling/deploy-schedulers.ps1`
- Documentation architecture : `docs/architecture/scheduling-claude-code.md`

---

**Dernière mise à jour :** 2026-03-26
