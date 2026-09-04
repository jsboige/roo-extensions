# Répertoire des Scripts

Ce répertoire centralise tous les scripts PowerShell et JavaScript utilisés pour l'outillage et l'automatisation du projet RooSync.

**Dernière mise à jour :** 2026-09-04 (alignement 3 familles worktree-cleanup, #3422)

---

## Scripts à la racine

| Script | Description |
|--------|-------------|
| `run-tests.ps1` | Exécution des tests Vitest avec options CI |
| `cleanup-orphan-branches.ps1` | Nettoyage des branches orphelines (PR merged/closed) |
| `audit-rules-footprint.ps1` | Audit de l'empreinte des règles .claude/rules/ |
| `sync-roo-alwaysallow.js` | Synchronisation des permissions alwaysAllow Roo |

---

## Sous-répertoires (46)

> **Recompte vérifié firsthand le 2026-08-31** (`git ls-files scripts/ | awk -F/'{print $2}' | sort -u`). Item #3319 audit Haiku po-2026 — voir [issue #3319](https://github.com/jsboige/roo-extensions/issues/3319) pour les sources.

### Coordination & Synchronisation

| Répertoire | Scripts | Description |
|------------|---------|-------------|
| `roosync/` | 33 | Synchronisation multi-machines RooSync (indexation, storage, config sync) |
| `dashboard-scheduler/` | 11 | Dashboard listener + scheduler (wake-claude, heartbeat, condensation, listener diagnostics) |
| `messaging/` | 5 | Communication inter-machines (ventilation, inbox) |
| `gdrive/` | 1 | Intégration Google Drive |
| `gdrivefs-watchdog/` | 3 | Watchdog GoogleDriveFS.exe (silent-exit #2875 + hung-process + cooldown #2933) — relance auto quand le process meurt |
| `scheduler/` | 7 | Configuration du scheduler Roo |
| `helpers/` | 1 | Utilitaires de revue (review-dedup-helper) |

### MCP & Services

| Répertoire | Scripts | Description |
|------------|---------|-------------|
| `mcp/` | 18 | Gestion et validation des serveurs MCP (build, validate, deploy, env backup/restore, zombie cleanup) |
| `mcp-watchdog/` | 7 | Surveillance et redémarrage automatique des MCP (+ vérificateur de déploiement #3394) |
| `qdrant/` | 6 | Gestion Qdrant (backup, restore, diagnostics) |
| `postgres/` | 3 | Sauvegarde Postgres (backup dump, schtask install) |
| `copilot/` | 1 | Configuration VS Code Copilot MCP |
| `deployment/` | 15 | Déploiement des configurations (install-mcps, migrate-roo-to-zoo) |
| `roo-settings/` | 3 | Gestion des paramètres Roo Code |

### Git & Workflow

| Répertoire | Scripts | Description |
|------------|---------|-------------|
| `git/` | 2 | Opérations Git (pre-commit hooks, branch triage) |
| `git-workflow/` | 7 | Workflow Git avancé (submodules, commit, branches) |
| `github/` | 5 | Intégration GitHub (sync-project, set-fields, review-bot) |
| `worktrees/` | 4 | Gestion des worktrees Git (création, cleanup, merge) |
| `hermes-watchdog/` | 4 | Surveillance du bot Hermes (cluster manager) |

### Claude Code & Agents

| Répertoire | Scripts | Description |
|------------|---------|-------------|
| `claude/` | 15 | Scripts Claude Code (spawn workers, switch-provider, validation) |
| `claude-md/` | 1 | Génération CLAUDE.md machine-level |
| `memory/` | 3 | Gestion mémoire agents (inject, redistribute, audit d'atteignabilité) |
| `review/` | 4 | Reviews automatisées (PR review, code review) |
| `scheduling/` | 27 | Scripts de planification (copilot dispatcher, schtasks, tool-usage snapshot) |

#### Stack worker Mistral Vibe (`scheduling/`, #3202)

- `start-vibe-worker.ps1` — worker d'un tick Vibe : lock anti-chevauchement **atomique** (`CreateNew` + `FileShare.None`, #3277 — deux invocations same-seconde → un seul worker, l'autre `exit 75` sans consommer le dispatch), heartbeat (pattern `Write-WorkerHeartbeat`), injection du payload `[WAKE-VIBE]` via la variable d'environnement `VIBE_WAKE_PAYLOAD`, logs horodatés UTC dans `outputs/scheduling/logs/vibe-worker-*.log`.
- `setup-vibe-scheduler.ps1` — install/remove/list/test de la tâche planifiée `Vibe-Worker` (launcher VBS caché, garde d'appropriation via marker `Vibe worker (#3202)`).
- `vibe-acp-driver.py` — client ACP headless pour `vibe-acp.exe` (extension VS Code Mistral) : initialize → session/new → session/prompt ; exit codes 0 `PROMPT_OK`, 2 `INITIALIZE_FAILED`, 3 `SESSION_NEW_FAILED`, 4 `PROMPT_ERROR`, 5 `PROMPT_TIMEOUT`, 6 `BAD_ARGS`/`NO_EXE`.
- `vibe-profiles/coursia.json` — profil workspace (workspace, harnessCommand, intervalHours) consommé par le worker via `-ConfigPath`.

### Infrastructure & Système

| Répertoire | Scripts | Description |
|------------|---------|-------------|
| `infra/` | 9 | Infrastructure (win-cli timeout guard, ripgrep diagnostic, Docker) |
| `install/` | 1 | Installation initiale |
| `setup/` | 6 | Configuration environnement (Git hooks, auto-login, VS Code) |
| `windows/` | 3 | Spécifique Windows (WSL, startup, Docker) |
| `zoo-scheduler/` | 6 | Migration et gestion du scheduler Zoo Code (globalState migration, health check) |

### Diagnostic & Monitoring

| Répertoire | Scripts | Description |
|------------|---------|-------------|
| `diagnostic/` | 23 | Diagnostic environnement (MCP, GDrive, Qdrant, submodules, tool_use dupliqués #3276) |
| `monitoring/` | 13 | Monitoring continu (health checks, metrics, alerts) |
| `inventory/` | 6 | Inventaire machines et configurations |

### Validation & Tests

| Répertoire | Scripts | Description |
|------------|---------|-------------|
| `testing/` | 27 | Tests unitaires et E2E (Pester, Vitest, Playwright) |
| `validation/` | 13 | Validation fonctionnelle (build, CI, configs, MCP drift, commit citations) |
| `audit/` | 4 | Audit de qualité (rules footprint) |

### Maintenance & Cleanup

| Répertoire | Scripts | Description |
|------------|---------|-------------|
| `maintenance/` | 20 | Maintenance récurrente (cleanup, sync, index repair, idle patrol, MCP stdio zombies) |
| `cleanup/` | 1 | Nettoyage général |
| `backup/` | 1 | Archivage transcripts Claude (TranscriptArchive, schtask `ClaudeTranscriptArchive` 04:41) |
| `_archive/` | 30 | Scripts archivés (référence seulement) |

#### Worktree cleanup — alignement des 3 familles (#3422, 2026-09-04)

Il existe **3 familles fonctionnelles distinctes** de scripts worktree-cleanup, **non** à fusionner
mais à aligner (documentation croisée). Voir `docs/cleanup/CONSOLIDATION-SCRIPTS-SUPERSEDED.md` §2 +
PR #3422.

| Famille | Scripts | Entrée | Callers actifs |
|---|---|---|---|
| **F1 — Scheduled cleanup (chemin critique)** | `maintenance/cleanup-orphan-worktrees.ps1` (+ `maintenance/install-worktree-cleanup-schtask.ps1`) | `-Execute -DaysThreshold 7` | 🔴 `scheduling/start-claude-worker.ps1` + schtask live `MCP-Worktree-Cleanup` (weekly Sunday 03:00, SYSTEM) + `testing/unit/worktree-husk-prevention.Tests.ps1` (CI `unit-pester`) |
| **F2 — PR-workflow cleanup** | `worktrees/cleanup-worktree.ps1` | `-IssueNumber N` (requis) | 🟢 `worktrees/create-worktree.ps1`, `worktrees/submit-pr.ps1` |
| **F3 — Scheduled-task alternatif + skills** | `claude/worktree-cleanup.ps1` (+ `claude/install-worktree-cleanup-scheduled-task.ps1`) | `-Force` / `-WhatIf` / `-StaleDays 30` | 🟢 skills `debrief`/`git-sync`, `.roo/scheduler-workflow-executor.md` + schtask `Roo-Worktree-Cleanup` (daily 02:00, SYSTEM) |
| (archivé) | `_archive/duplicates/cleanup-worktrees.ps1` | — | ⚪ Référence seulement (`worktrees/check-worktrees.ps1`, docs) |

**Pourquoi 3 et pas 1 :** scopes incompatibles (F1 vs F3 : trigger/cadence/flags différents ;
F2 : entrée par IssueNumber). Fusionner F1 avec F3 toucherait le contrat de 3 appelants critiques
(worker + schtask + test unitaire) — risque de régression inacceptable. PR antérieure #2617 (MERGED
2026-06-18) avait déjà consolidé une paire **docs** (`reference/worktree-cleanup*.md`) — périmètre
différent.

**Vérifications croisées par fichier :** chaque script porte désormais un en-tête `.FAMILY` (ou
`# FAMILY:`) renvoyant aux 4 autres scripts actifs.

### Encodage & Format

| Répertoire | Scripts | Description |
|------------|---------|-------------|
| `encoding/` | 36 | Correction encodage fichiers (BOM, UTF-8, emoji) |
| `utf8/` | 3 | Conversion UTF-8 spécifique |

### Analyse & Documentation

| Répertoire | Scripts | Description |
|------------|---------|-------------|
| `analysis/` | 6 | Analyse de code et métriques (branches, commits, complexity) |
| `docs/` | 8 | Génération et maintenance de documentation |
| `benchmarks/` | 3 | Benchmarks de performance |
| `common/` | 4 | Utilitaires partagés (extension paths, submodule deletion guards) |

### Autres

| Répertoire | Scripts | Description |
|------------|---------|-------------|
| `jupyter/` | 1 | Intégration Jupyter notebooks |

---

## Références

- Architecture du dépôt : [`docs/architecture/repository-map.md`](../docs/architecture/repository-map.md)
- Guide technique RooSync : [`docs/roosync/GUIDE-TECHNIQUE-v2.3.md`](../docs/roosync/GUIDE-TECHNIQUE-v2.3.md)
- Inventaire des outils MCP : [`.claude/rules/tool-availability.md`](../.claude/rules/tool-availability.md)
