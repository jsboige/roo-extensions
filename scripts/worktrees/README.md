# Worktree Auto-Cleanup Protocol

**Issue :** #856, #895  
**Date :** 2026-03-27  
**Statut :** Implémenté

---

## Problème

Les worktrees Git créés pour le développement d'issues GitHub s'accumulent et ne sont pas automatiquement nettoyés après merge. Cela cause :

1. **Orphan worktrees** : Dossiers sur disque sans référence Git
2. **Stale branches** : Branches `wt/*` ou `feature/*` sans activité depuis >30 jours
3. **Perte de travail** : Worktrees non nettoyés dans les sessions scheduler (#895)
4. **Pollution du dépôt** : Accumulation de fichiers temporaires

---

## Solution

Un protocole d'auto-cleanup intégré au workflow scheduler executor.

### Scripts Implémentés

| Script | Description | Usage |
|--------|-------------|-------|
| [`scripts/worktrees/auto-cleanup.ps1`](../scripts/_archive/duplicates/auto-cleanup.ps1) | Cleanup automatique (archived — superseded by `cleanup-orphan-worktrees.ps1`) | Scheduler executor |
| [`scripts/worktrees/create-worktree.ps1`](../scripts/worktrees/create-worktree.ps1) | Création de worktree pour issue | Manuel |
| [`scripts/worktrees/cleanup-worktree.ps1`](../scripts/worktrees/cleanup-worktree.ps1) | Cleanup manuel après merge | Manuel |
| [`scripts/worktrees/submit-pr.ps1`](../scripts/worktrees/submit-pr.ps1) | Soumission PR depuis worktree | Manuel |
| [`scripts/claude/worktree-cleanup.ps1`](../scripts/claude/worktree-cleanup.ps1) | Cleanup avancé (alternative) | Manuel |

---

## Auto-Cleanup (Scheduler Executor)

### Commande

```powershell
.\scripts\maintenance\cleanup-orphan-worktrees.ps1 [-WhatIf] [-StaleDays 30]
```

### Paramètres

| Paramètre | Défaut | Description |
|-----------|--------|-------------|
| `-WhatIf` | false | Mode dry-run (sans modification) |
| `-StaleDays` | 30 | Branches sans activité depuis X jours |
| `-WorktreePath` | `.claude/worktrees` | Dossier des worktrees |

### Fonctionnalités

1. **Détection des worktrees actifs** : Via `git worktree list --porcelain`
2. **Détection des orphan directories** : Dossiers sans référence Git
3. **Détection des branches stales** : Branches `wt/*` ou `feature/*` sans activité
4. **Suppression des orphans** : `Remove-Item -Recurse -Force`
5. **Suppression des branches stales** : `git branch -D`
6. **Git garbage collection** : `git gc --prune=now`

### Résultat

```
=== Auto-Cleanup Report ===
Repository: d:/dev/roo-extensions
Date: 2026-03-27 10:40:00
Stale threshold: 30 days
Max worktrees: 2

[INFO] Active worktrees: 1
[INFO] Orphan directories: 0
[INFO] Stale branches (30 days): 0

[OK] No cleanup needed. All worktrees are valid.
```

---

## Workflow Standard

### Création d'un worktree

```powershell
# Créer un worktree pour une issue
.\scripts\worktrees\create-worktree.ps1 -IssueNumber 856
```

### Soumission d'une PR

```powershell
# Depuis le worktree
.\scripts\worktrees\submit-pr.ps1 -IssueNumber 856
```

### Cleanup après merge

```powershell
# Cleanup manuel après merge
.\scripts\worktrees\cleanup-worktree.ps1 -IssueNumber 856
```

### Auto-Cleanup (scheduler)

```powershell
# Exécuté automatiquement à chaque cycle scheduler
.\scripts\maintenance\cleanup-orphan-worktrees.ps1 -StaleDays 30
```

---

## Intégration Scheduler

Le cleanup est intégré à l'Étape 2c-idle du workflow executor :

```markdown
### 2c-idle : Veille Active ou Consolidation

#### Option 0 : Auto-Cleanup Worktrees (OBLIGATOIRE)

**Exécuter le cleanup automatique :**

```
execute_command(shell="powershell", command=".\\scripts\\maintenance\\cleanup-orphan-worktrees.ps1 -StaleDays 30 2>&1 | Select-Object -Last 30")
```

**Rapporter dans le bilan :** `Worktrees: {N} actifs, {M} orphelins supprimés, {K} branches stales supprimées`
```

---

## Configuration

### Paramètres recommandés

| Paramètre      | Valeur             | Raison                                       |
|----------------|--------------------|----------------------------------------------|
| `StaleDays`    | 30                 | Équilibre entre nettoyage et travail en cours |
| `WorktreePath` | `.claude/worktrees` | Isolé dans `.gitignore`                      |

### .gitignore

Le dossier des worktrees doit être ignoré :

```gitignore
# Worktrees
.claude/worktrees/
roo-extensions-wt/
```

---

## Maintenance

### Monitoring

Vérifier régulièrement l'état des worktrees :

```powershell
# Liste des worktrees
git worktree list

# Statistiques
.\scripts\worktrees\check-worktrees.ps1
```

### Dépannage

**Problème :** Worktree persiste après cleanup

**Solution :**
1. Vérifier que VS Code n'est pas ouvert sur le worktree
2. Utiliser `-Force` pour forcer la suppression
3. Redémarrer VS Code après cleanup

**Problème :** Branches stales non supprimées

**Solution :**
1. Vérifier qu'elles ne sont pas mergeables
2. Utiliser `git branch -D` manuellement
3. Augmenter `-StaleDays` si nécessaire

---

## Historique

| Date | Version | Changements |
|------|---------|-------------|
| 2026-03-27 | 1.0.0 | Implémentation initiale |

---

**Références :**
- Issue #856 : chore: Worktree cleanup protocol
- Issue #895 : Scheduler perd du travail - worktrees non nettoyés
- [`scripts/_archive/duplicates/auto-cleanup.ps1`](../scripts/_archive/duplicates/auto-cleanup.ps1) (archived — superseded by `cleanup-orphan-worktrees.ps1`)
