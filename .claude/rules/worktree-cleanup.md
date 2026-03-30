# Worktree Cleanup Protocol

**Version:** 2.0.0
**Created:** 2026-03-26
**Updated:** 2026-03-29
**Issues:** #856, #895

---

## CRITICAL BUG #895: Worktree Cleanup Obligatoire

**Le harnais scheduler PERD DU TRAVAIL sans cleanup automatique.**

### Problème

Le workflow PR → Worktree est incomplet :
1. ✅ Création worktree
2. ✅ Travail + commits
3. ✅ Création PR
4. ✅ Merge/Close
5. ❌ **MANQUE : Cleanup automatique du worktree et de la branche**

### Impact

- **33 branches wt/ orphelines** identifiées (Session 35)
- **16 commits uniques** non mergés dans main
- **14 PRs CLOSED** avec travail potentiellement valide
- **Travail récupéré :** ~2000 lignes (#866 + #856)

---

## Worktree Lifecycle Complet

### Étape 1 : Création (PR workflow)

```bash
# Créer le worktree
git worktree add .claude/worktrees/wt-{desc} -b wt/{desc}

# Travailler dans le worktree
cd .claude/worktrees/wt-{desc}
# ... commits, tests, ...
```

### Étape 2 : PR et Merge

```bash
# Créer la PR
gh pr create --title "type(#issue): description" --body "..."

# Après review et merge
```

### Étape 3 : CLEANUP OBLIGATOIRE (après merge/close)

```bash
# Retourner au repo principal
cd C:\dev\roo-extensions

# Supprimer le worktree
git worktree remove .claude/worktrees/wt-{desc}

# Supprimer la branche locale
git branch -D wt/{desc}
```

### Étape 4 : Vérification

```bash
# Vérifier les worktrees actifs
git worktree list

# Vérifier les branches wt/
git branch --list "wt/*"
```

---

## Automatisation - Tâche Planifiée

### Installation (Recommandé)

```powershell
# Créer la tâche planifiée (nécessite Admin)
.\scripts\claude\install-worktree-cleanup-scheduled-task.ps1

# Vérifier l'installation
schtasks /Query /TN "Roo-Worktree-Cleanup"

# Lancer manuellement pour tester
schtasks /Run /TN "Roo-Worktree-Cleanup"
```

### Paramètres de la tâche

- **Nom :** `Roo-Worktree-Cleanup`
- **Fréquence :** Quotidienne à 02:00
- **Action :** Exécuter `scripts/claude/worktree-cleanup.ps1 -Force`
- **Utilisateur :** SYSTEM

### Désinstallation

```powershell
.\scripts\claude\install-worktree-cleanup-scheduled-task.ps1 -Remove
```

---

## Script de Cleanup Manuel

**Location:** `scripts/claude/worktree-cleanup.ps1`

### Usage

```powershell
# Dry run (voir ce qui serait nettoyé)
powershell -ExecutionPolicy Bypass -File scripts/claude/worktree-cleanup.ps1 -WhatIf

# Exécuter le cleanup (avec confirmation)
powershell -ExecutionPolicy Bypass -File scripts/claude/worktree-cleanup.ps1

# Forcer sans confirmation
powershell -ExecutionPolicy Bypass -File scripts/claude/worktree-cleanup.ps1 -Force

# Seuil personnalisé (défaut: 30 jours)
powershell -ExecutionPolicy Bypass -File scripts/claude/worktree-cleanup.ps1 -StaleDays 14
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-WhatIf` | switch | false | Dry run mode (show what would be done) |
| `-Force` | switch | false | Skip confirmation prompts |
| `-StaleDays` | int | 30 | Days threshold for stale branches |
| `-WorktreePath` | string | `.claude/worktrees` | Path to worktrees directory |

---

## What It Cleans

### 1. Orphan Worktree Directories

Directories in `.claude/worktrees/` that are not active git worktrees.

**Detection:** Compare directory listing with `git worktree list`

### 2. Stale Branches

Local `wt/` branches with no active worktree and last commit > N days old.

**Detection:** `git branch --list "wt/*"` + commit date check

---

## Safety

- **VS Code check:** Script warns if VS Code is running (may have open worktrees)
- **WhatIf mode:** Always test with `-WhatIf` first
- **No remote deletion:** Only local branches are affected
- **Git gc recommendation:** Script suggests `git gc --prune=now` after cleanup

---

## When to Run

1. **Après chaque PR merge/close** (manuel, obligatoire)
2. **Tâche planifiée** (quotidien à 02:00, automatique)
3. **Session start** (optionnel, manuel - diagnostic)
4. **Periodic maintenance** (hebdomadaire/mensuel)

---

## Audit PRs CLOSED - Session 35

**PRs CLOSED avec travail récupérable identifié :**

| PR | Commits | Lignes | Branche | Statut |
|----|---------|--------|---------|--------|
| #870 | 2 | 1576 | wt/worker-myia-po-2025-20260326-042234 | **Recupéré** dans #893 |
| #846 | 11 | 1554 | wt/worker-myia-po-2026-20260324-175849 | À vérifier |
| #592 | 1 | 299 | wt/worker-myia-po-2025-20260307-071553 | À vérifier |
| #585 | 1 | 371 | wt/worker-myia-po-2025-20260306-231457 | À vérifier |
| #887 | 3 | 3 | wt/881-detaillevel-notools-filter | Submodule update |
| #880 | 3 | 3 | wt/852-claude-code-indexing | Submodule update |
| #878 | 3 | 3 | wt/858-timeout-60s | Submodule update |

**Note :** Les PRs avec seulement 3 lignes (submodule updates) sont probablement déjà mergés via d'autres PRs.

---

## Related

- Issue #856: Worktree cleanup protocol (Phase 1)
- Issue #895: CRITICAL BUG - Le harnais scheduler PERD DU TRAVAIL
- Rule `.claude/rules/pr-mandatory.md` - PR workflow avec cleanup obligatoire
- Doc `docs/roo-code/SCHEDULER_SYSTEM.md` - Scheduler worktree usage

---

**Last updated:** 2026-03-27

---

## Script

**Location:** `scripts/claude/worktree-cleanup.ps1` (consolidated from `.claude/scripts/` per #866)

**Legacy path still works:** `.claude/scripts/worktree-cleanup.ps1`

### Usage

```powershell
# Dry run (see what would be cleaned)
powershell -ExecutionPolicy Bypass -File scripts/claude/worktree-cleanup.ps1 -WhatIf

# Execute cleanup (with confirmation)
powershell -ExecutionPolicy Bypass -File scripts/claude/worktree-cleanup.ps1

# Force cleanup without confirmation
powershell -ExecutionPolicy Bypass -File scripts/claude/worktree-cleanup.ps1 -Force

# Custom stale threshold (default: 30 days)
powershell -ExecutionPolicy Bypass -File scripts/claude/worktree-cleanup.ps1 -StaleDays 14
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-WhatIf` | switch | false | Dry run mode (show what would be done) |
| `-Force` | switch | false | Skip confirmation prompts |
| `-StaleDays` | int | 30 | Days threshold for stale branches |
| `-WorktreePath` | string | `.claude/worktrees` | Path to worktrees directory |

---

## What It Cleans

### 1. Orphan Worktree Directories

Directories in `.claude/worktrees/` that are not active git worktrees.

**Detection:** Compare directory listing with `git worktree list`

### 2. Stale Branches

Local `wt/` branches with no active worktree and last commit > N days old.

**Detection:** `git branch --list "wt/*"` + commit date check

### 3. Git Worktree Prune (v2.0)

Cleans stale administrative records in `.git/worktrees/`.

**Detection:** `git worktree prune` (run automatically after cleanup)

### 4. Git GC (v2.0)

Runs `git gc --prune=now` automatically when orphans or stale branches are removed.

---

## Windows-Specific Handling (v2.0)

On Windows, long paths and locked files can prevent removal. The script uses a 4-strategy fallback:

1. **Standard `Remove-Item -Recurse -Force`** — works in most cases
2. **Long path prefix `\\?\`** — handles paths exceeding MAX_PATH (260 chars)
3. **cmd.exe `rmdir /s /q`** — handles some locked file cases better
4. **robocopy empty mirror** — nuclear option for stubborn directories

---

## Integration Points (v2.0)

### git-sync skill

Added **Etape 5b** after pull: check worktree count and run cleanup if > 2 active worktrees.

### debrief skill

Added **Phase 5b** at end of session: check worktrees and run cleanup before closing.

### Scheduler patrol (executor workflow)

Added worktree check in **Etape 1** after git pull: count worktrees and cleanup if needed.

---

## Safety

- **VS Code check:** Script warns if VS Code is running (may have open worktrees)
- **WhatIf mode:** Always test with `-WhatIf` first
- **No remote deletion:** Only local branches are affected
- **No force push:** Only local branches are affected
- **Git gc recommendation:** Script suggests `git gc --prune=now` after cleanup
- **VS Code restart required** if worktrees were removed while VS Code was running

---

## When to Run

1. **Session start** (optional, manual)
2. **After closing worktrees** (cleanup orphan branches)
3. **Periodic maintenance** (weekly/monthly)
4. **Automatically** via git-sync, debrief, and scheduler patrol (v2.0)

---

## Related

- Issue #856: Worktree cleanup protocol
- Rule `.claude/rules/pr-mandatory.md` - PR workflow for worktrees
- Doc `docs/roo-code/SCHEDULER_SYSTEM.md` - Scheduler worktree usage
- `.roo/scheduler-workflow-executor.md` - Executor workflow with worktree check

---

**Last updated:** 2026-03-29
