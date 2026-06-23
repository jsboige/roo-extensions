# Consolidation Scripts — Provenance Vérifiée (Superseded + Worktree)

**Date:** 2026-06-23
**Machine:** myia-po-2024 (Claude Code, GLM)
**Epic parent:** #2639 — Workstream 4 (tâche #2641)
**Complète:** [`CONSOLIDATION-PLAN-EPIC-2639.md`](./CONSOLIDATION-PLAN-EPIC-2639.md) (po-2025 + ai-01, 2026-06-22) — Tâche fille B (livrable)
**Méthodologie:** `no-deletion-without-proof` — chaque claim vérifié par `grep` callers + existence fichier. **Investigation only, PAS de suppression dans ce document.**

---

## ⚠️ Correction matérielle du plan initial (Tâche A — worktree)

Le plan initial ([§1.1](./CONSOLIDATION-PLAN-EPIC-2639.md)) identifie **3** scripts worktree-cleanup. L'analyse des callers révèle **6** scripts apparentés, dont **`maintenance/cleanup-orphan-worktrees.ps1` — le script du schtask live (daily 03:15) — était omis du plan**.

**Conséquence si le plan exécuté tel quel :** la consolidation des 3 scripts listés pourrait fusionner des scripts de **fonctions différentes** (schtask scheduled / workflow PR / scheduled-task alternatif) et **ignorer le script actif le plus critique**, risquant de casser le cleanup journalier référencé par `start-claude-worker.ps1`.

→ La Tâche A doit être **re-scopée** avant exécution (voir §2).

---

## 1. Scripts superseded — matrice old → new (Tâche B, vérifiée)

Tous les candidats archivés existent dans `scripts/_archive/duplicates/`. Statut de remplacement vérifié (fichier de remplacement présent) :

| Script archivé (`_archive/duplicates/`) | Fonction | Remplacement actif (VÉRIFIÉ) | Équivalence fonctionnelle |
|------------------------------------------|----------|------------------------------|---------------------------|
| `compile-mcp-servers.ps1` | Compilation MCP | `scripts/mcp/validate-before-push.ps1` ✅ existe | **À confirmer** au moment exécution (diff ligne-à-ligne non fait ici) |
| `mcp-monitor.ps1` | Monitoring MCP | `scripts/mcp-watchdog/mcp-chain-healthcheck.ps1` ✅ existe | **À confirmer** — ⚠️ le plan initial citait `scripts/monitoring/mcp-health.ps1` qui **n'existe pas** ; replacement réel = `mcp-watchdog/` |
| `Convert-McpSettings-Fixed.ps1` | Conversion MCP settings | `scripts/deployment/deploy-claude-mcp-settings.ps1` ✅ existe | **À confirmer** |
| `validate-deployment-simple.ps1` | Validation déploiement | `scripts/validation/validate-deployment.ps1` ✅ existe | **À confirmer** |

**`scripts/monitoring/`** existe mais contient `advanced-monitoring.ps1`, `daily-monitoring.ps1`, `alert-system.ps1`, `check-embeddings.ps1`, `dashboard-generator.ps1` — **pas** `mcp-health.ps1`. La mention du plan pour `mcp-monitor.ps1` est donc **incorrecte** ; le vrai remplaçant est `mcp-watchdog/mcp-chain-healthcheck.ps1` (vérifié).

**Statut global :** les 4 scripts sont dans `_archive/duplicates/` (déjà archivés, pas en chemin actif). La suppression éventuelle est **basse priorité** — ils ne sont plus sur le chemin d'exécution. L'action utile = documenter la matrice de superseding (ce document) + confirmer l'équivalence fonctionnelle au moment d'une éventuelle suppression.

---

## 2. Scripts worktree-cleanup — analyse des callers (Tâche A, re-scopée)

**6 scripts apparentés** (le plan en listait 3). Callers vérifiés via `grep -rln` (excl. `_archive` + self + worktrees) :

| Script | Rôle (inféré des callers) | Callers actifs | Statut |
|--------|----------------------------|----------------|--------|
| `maintenance/cleanup-orphan-worktrees.ps1` | **Cleanup schtask (daily 03:15)** | `scheduling/start-claude-worker.ps1`, `maintenance/install-worktree-cleanup-schtask.ps1`, `testing/unit/worktree-husk-prevention.Tests.ps1` | **🔴 ACTIF — critique (worker + schtask + test)** — *omis du plan* |
| `worktrees/cleanup-worktree.ps1` | Cleanup post-merge PR unique | `worktrees/create-worktree.ps1`, `worktrees/submit-pr.ps1` | **🟢 ACTIF — workflow PR** |
| `claude/worktree-cleanup.ps1` | Cleanup complet (worktrees + branches loc + remote) | `claude/install-worktree-cleanup-scheduled-task.ps1`, skills `debrief`/`git-sync`, `.roo/scheduler-workflow-executor.md` | **🟢 ACTIF — scheduled-task alternatif + skills** |
| `_archive/duplicates/cleanup-worktrees.ps1` | Cleanup automatique orphelins | `worktrees/check-worktrees.ps1` (réf.) + docs | **⚪ ARCHIVÉ** (vieux) |
| `maintenance/install-worktree-cleanup-schtask.ps1` | Installeur schtask (#1) | — (entry-point utilisateur) | **🟢 ACTIF — installeur** |
| `claude/install-worktree-cleanup-scheduled-task.ps1` | Installeur scheduled-task (#3) | — (entry-point utilisateur) | **🟢 ACTIF — installeur** |

### Conclusion Tâche A

- **Pas 3 scripts dupliqués** : ce sont **3 familles fonctionnelles distinctes** :
  1. **Scheduled cleanup (daily)** — `maintenance/cleanup-orphan-worktrees.ps1` (+ son installeur)
  2. **PR-workflow cleanup** — `worktrees/cleanup-worktree.ps1`
  3. **Scheduled-task alternatif** — `claude/worktree-cleanup.ps1` (+ son installeur)
- **Ne PAS fusionner aveuglément** : `maintenance/cleanup-orphan-worktrees.ps1` est sur le **chemin critique** (`start-claude-worker.ps1` + schtask + test unitaire). Toute consolidation doit préserver son contrat d'appel exact.
- PR antérieure **#2617** (MERGED) a déjà consolidé une paire worktree-cleanup (archive v1.0) — vérifier que ce travail n'a pas déjà résolu une partie du périmètre avant de recréer une Tâche A.
- **Recommandation :** re-scope Tâche A en *« aligner les 3 familles »* (documentation croisée + flags d'usage) plutôt que *« consolider en 1 script »* — le risque de régression sur le schtask live l'emporte sur le bénéfice de déduplication.

---

## 3. Méthodologie de prouvance appliquée

Pour chaque script ci-dessus, la preuve de statut repose sur :

```bash
# Existence fichier
[ -f scripts/<path> ]

# Callers (preuve d'usage actif) — excl. _archive, self, worktrees
grep -rln "<script-name>" scripts .claude docs --include="*.ps1" --include="*.json" --include="*.md" --include="*.js" \
  | grep -v "_archive" | grep -v "/<script-name>"

# Replacement présent
[ -e scripts/<replacement-path> ]
```

**Non fait ici (à faire au moment d'une suppression effective) :**
- `git log -S "<script-name>" --since="90 days ago"` — activité récente
- Diff ligne-à-ligne old vs new pour confirmer équivalence fonctionnelle 100%
- `npx vitest run` post-suppression

---

## 4. Liens &下一步

- **Plan parent :** [`CONSOLIDATION-PLAN-EPIC-2639.md`](./CONSOLIDATION-PLAN-EPIC-2639.md) (Tâches A–D)
- **PR antérieure worktree :** #2617 (MERGED — consolidate worktree-cleanup pair, archive v1.0)
- **Issues :** #2641 (WS4), #2639 (Epic)
- **Action recommandée :** avant d'exécuter Tâche A, (1) vérifier ce que #2617 a déjà résolu, (2) re-scope en alignement plutôt que fusion, (3) préserver le contrat `cleanup-orphan-worktrees.ps1` (worker + schtask + test).

---

**Provenance :** vérification par myia-po-2024 (Claude Code, GLM), 2026-06-23. Complète le plan po-2025/ai-01 en corrigeant 2 inexactitudes matérielles (comptage worktree + mapping mcp-monitor) détectées par application stricte de `no-deletion-without-proof`.
