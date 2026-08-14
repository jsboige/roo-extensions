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
| [`scripts/worktrees/auto-cleanup.ps1`](../_archive/duplicates/auto-cleanup.ps1) | Cleanup automatique (archived — superseded by `cleanup-orphan-worktrees.ps1`) | Scheduler executor |
| [`scripts/worktrees/create-worktree.ps1`](create-worktree.ps1) | Création de worktree pour issue | Manuel |
| [`scripts/worktrees/cleanup-worktree.ps1`](cleanup-worktree.ps1) | Cleanup manuel après merge | Manuel |
| [`scripts/worktrees/submit-pr.ps1`](submit-pr.ps1) | Soumission PR depuis worktree | Manuel |
| [`scripts/claude/worktree-cleanup.ps1`](../claude/worktree-cleanup.ps1) | Cleanup avancé (alternative) | Manuel |
| [`scripts/maintenance/audit-worktrees-fleet.ps1`](../maintenance/audit-worktrees-fleet.ps1) | **Audit multi-dépôts** — tous les dépôts de la machine | Manuel / dispatch flotte |

---

## Portée : un dépôt vs toute la machine

Tous les scripts du tableau ci-dessus, sauf le dernier, sont scopés à `.claude/worktrees/` d'**un
seul** dépôt. C'est le bon périmètre pour le cycle normal issue → worktree → PR → merge, et ce n'est
pas ce qu'il faut pour une passe de ménage.

Mesuré sur `myia-ai-01` le 2026-08-14 : **83 worktrees enregistrés** — CoursIA 75, nanoclaw 5,
roo-extensions 3 — éparpillés dans `D:/CoursIA-wt/`, des scratchpads de session, `C:/Users/…/Temp/`,
`C:/wt*`, et un jusque dans `D:/CoursIA/.git/`. Un scan de `.claude/worktrees/` en voit quatre.

**Seul `git worktree list --porcelain`, interrogé depuis chaque dépôt, les révèle tous.** D'où
`audit-worktrees-fleet.ps1`, qui découvre d'abord les *dépôts* (répertoire contenant un `.git`
**répertoire** ; un `.git` *fichier* est un worktree) puis interroge chacun.

```powershell
# Inventaire complet de la machine, aucune modification
pwsh -File scripts/maintenance/audit-worktrees-fleet.ps1

# Un dépôt précis, puis suppression des seules classes prouvées sûres
pwsh -File scripts/maintenance/audit-worktrees-fleet.ps1 -Repos D:\roo-extensions -Apply
```

Le rapport part dans `$ROOSYNC_SHARED_PATH/worktree-audit/<machine>-<date>.md`.

Ce chemin est un montage Google Drive, qui échoue par intermittence (« Ressources système
insuffisantes »). Le script bascule alors sur `outputs/` en local, **relit le fichier écrit** pour
prouver qu'il existe, et n'annonce que le chemin réellement produit. Si les deux écritures
échouent, il le dit et **sort en 1** — un appelant scripté ne doit pas lire un succès dans une
exécution qui n'a rien livré.

### Ce qui est supprimé, ce qui ne l'est pas

La décision est prise par [`worktree-classify.ps1`](../maintenance/worktree-classify.ps1), pure et
couverte en CI par [`test-worktree-classify.ps1`](../testing/harness/test-worktree-classify.ps1).
L'ordre des tests **est** la propriété de sûreté :

| Classe | Condition | Action |
|---|---|---|
| `MAIN` | working tree du dépôt | conserver |
| `ORPHAN-DIR` | working tree sur disque qu'aucun dépôt n'enregistre | conserver, **rapporter** |
| `GHOST` | répertoire absent, ou cible `gitdir:` disparue | **supprimer** |
| `DIRTY` | `status --porcelain` non vide | conserver, rapporter |
| `MERGED` | HEAD ancêtre de `origin/<défaut>` | **supprimer** |
| `MERGED-BY-PR` | PR `MERGED` **et** HEAD = le commit mergé | **supprimer** |
| `PR-MERGED-DIVERGED` | PR `MERGED` mais HEAD ≠ le commit mergé | conserver, **rapporter** |
| `PR-OPEN` / `PR-CLOSED` | PR ouverte / fermée sans merge | conserver, rapporter |
| `PR-FORGOTTEN` | commits en avance, aucune PR | conserver, **rapporter** |
| `DETACHED-LANDED` | detached HEAD, mais chaque patch est déjà sur `origin/<défaut>` | **supprimer** (branche `rescue/` d'abord) |
| `DETACHED-ORPHANABLE` | detached HEAD, commits dont le patch n'est nulle part en amont | conserver, rapporter |

Quatre subtilités décident de la justesse, et sont chacune épinglées par un test :

- **`DIRTY` l'emporte sur tout signal de merge.** Un worktree dont la PR est mergée peut porter du
  travail non commité ; le supprimer parce que la PR a atterri détruit exactement ce que personne
  n'a encore vu. Vérifié en conditions réelles : salir `wt-bump-974` (PR #3102 mergée) le fait
  passer de `MERGED-BY-PR` à `DIRTY` et le sort des supprimables.
- **L'ascendance git ne prouve pas « non mergé ».** Une branche squash-mergée reste « en avance »
  sur `main` alors que son contenu a atterri — et toutes les branches `wt/*` d'ici sont
  squash-mergées. C'est pourquoi l'état de la **PR** est interrogé avant toute conclusion tirée de
  la topologie.
- **Une PR mergée ne répond que du commit qu'elle a mergé.** Les commits que ce commit ne peut pas
  atteindre ne sont jamais passés par la PR et n'ont jamais été relus — les compter comme « mergés »
  est faux. Le test porte donc sur les commits **en avance** sur le head de la PR, et non sur
  l'inégalité des deux SHA : un checkout resté **en arrière** a lui aussi un SHA différent, alors
  que son contenu est entièrement dans le merge. Mesuré : sur trois worktrees CoursIA dont le HEAD
  différait du head de leur PR mergée, **un seul** était en avance (`pr9962`, +1) ; les deux autres
  étaient 4 et 45 commits en arrière. Lire l'inégalité comme une divergence se trompait deux fois
  sur trois.

  À noter : c'est un raffinement du **rapport**, pas un garde-fou contre la perte. Retirer un
  worktree ne supprime jamais sa branche — ces commits survivent dans tous les cas. Le garde contre
  la perte réelle reste la branche `rescue/` des worktrees detached, qui n'atteignent jamais cette
  règle (sans branche, pas de PR).
- **Un detached HEAD hors de la ligne d'ascendance ne prouve rien non plus.** C'est le même piège du
  squash-merge, en pire : sans nom de branche, il n'y a aucune PR à interroger pour s'en sortir.
  C'est l'**identité de patch** qui tranche — `git cherry <défaut> <head>` marque `-` un commit dont
  un patch équivalent existe déjà en amont, `+` sinon. Mesuré sur ai-01 : sur **17** worktrees
  detached retenus comme « travail potentiellement orphelin », **14** ne portaient que des patchs
  déjà sur `main` (des heads de PR squash-mergées) ; **3** seulement portaient du travail jamais
  livré. Lire « pas ancêtre » comme « non mergé » gonflait la pile manuelle d'un facteur 5.

  La suppression est ici sûre pour deux raisons indépendantes : le contenu est prouvé en amont,
  **et** la branche `rescue/` est créée avant retrait, donc les commits restent atteignables même si
  l'identité de patch se trompait. Si `git cherry` ne peut pas tourner, la mesure est déclarée
  absente et le worktree reste dans la pile manuelle — jamais supprimable par défaut.

Le cas `pr9962` révèle aussi pourquoi la résolution de PR ne peut pas se faire sur le seul nom de branche :
`pr9962` n'est le `headRefName` d'aucune PR (celui de la #9962 est `feature/c9959-check-lane-paths`),
donc une requête `--head pr9962` ne trouve rien et la branche se lit comme « aucune PR », c'est-à-dire
du travail oublié. Une branche de la forme exacte `pr<N>` est donc résolue **par numéro**.

Et un piège mesuré : **`git worktree list` ne signale pas `prunable`** pour un worktree dont le
`gitdir:` pointe vers un répertoire disparu (0 prunable sur les 75 entrées CoursIA, dont deux
étaient des coquilles vides). La détection lit donc la cible du pointeur, pas le drapeau de git.

Avant toute suppression, une branche `rescue/<nom>-<sha>` est créée sur le HEAD des worktrees
detached — assurance contre une erreur de classification, non poussée. Les suppressions passent par
`Test-SafeDeletionPath` ([`scripts/common/path-guards.ps1`](../common/path-guards.ps1), gardes
submodule #2772 et anti-imbrication #2123), et par `git worktree remove` **sans** `--force` : git
refuse alors un worktree sale, ce qui ne peut se produire que si la classification s'est trompée.

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
- [`scripts/_archive/duplicates/auto-cleanup.ps1`](../_archive/duplicates/auto-cleanup.ps1) (archived — superseded by `cleanup-orphan-worktrees.ps1`)
