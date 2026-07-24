# Répertoire des Scripts

Ce répertoire centralise tous les scripts PowerShell et JavaScript utilisés pour l'outillage et l'automatisation du projet RooSync.

**Dernière mise à jour :** 2026-07-16

---

## Scripts à la racine

| Script | Description |
|--------|-------------|
| `run-tests.ps1` | Exécution des tests Vitest avec options CI |
| `cleanup-orphan-branches.ps1` | Nettoyage des branches orphelines (PR merged/closed) |
| `audit-rules-footprint.ps1` | Audit de l'empreinte des règles .claude/rules/ |
| `sync-roo-alwaysallow.js` | Synchronisation des permissions alwaysAllow Roo |

---

## Sous-répertoires (43)

### Coordination & Synchronisation

| Répertoire | Scripts | Description |
|------------|---------|-------------|
| `roosync/` | 20 | Synchronisation multi-machines RooSync (indexation, storage, config sync) |
| `dashboard-scheduler/` | 10 | Dashboard listener + scheduler (wake-claude, heartbeat, condensation, listener diagnostics) |
| `messaging/` | 4 | Communication inter-machines (ventilation, inbox) |
| `gdrive/` | 1 | Intégration Google Drive |
| `gdrivefs-watchdog/` | 2 | Watchdog GoogleDriveFS.exe (silent-exit #2875) — relance auto quand le process meurt |
| `scheduler/` | 3 | Configuration du scheduler Roo |

### MCP & Services

| Répertoire | Scripts | Description |
|------------|---------|-------------|
| `mcp/` | 17 | Gestion et validation des serveurs MCP (build, validate, deploy, env backup/restore, zombie cleanup) |
| `mcp-watchdog/` | 6 | Surveillance et redémarrage automatique des MCP |
| `qdrant/` | 5 | Gestion Qdrant (backup, restore, diagnostics) |
| `postgres/` | 2 | Sauvegarde Postgres (backup dump, schtask install) |
| `copilot/` | 1 | Configuration VS Code Copilot MCP |
| `deployment/` | 14 | Déploiement des configurations (install-mcps, migrate-roo-to-zoo) |
| `roo-settings/` | 2 | Gestion des paramètres Roo Code |

### Git & Workflow

| Répertoire | Scripts | Description |
|------------|---------|-------------|
| `git/` | 2 | Opérations Git (pre-commit hooks, branch triage) |
| `git-workflow/` | 7 | Workflow Git avancé (submodules, commit, branches) |
| `github/` | 4 | Intégration GitHub (sync-project, set-fields, review-bot) |
| `worktrees/` | 4 | Gestion des worktrees Git (création, cleanup, merge) |
| `hermes-watchdog/` | 4 | Surveillance du bot Hermes (cluster manager) |

### Claude Code & Agents

| Répertoire | Scripts | Description |
|------------|---------|-------------|
| `claude/` | 14 | Scripts Claude Code (spawn workers, switch-provider, validation) |
| `claude-md/` | 1 | Génération CLAUDE.md machine-level |
| `memory/` | 2 | Gestion mémoire agents (inject, redistribute) |
| `review/` | 4 | Reviews automatisées (PR review, code review) |
| `scheduling/` | 17 | Scripts de planification (copilot dispatcher, schtasks, tool-usage snapshot) |

### Infrastructure & Système

| Répertoire | Scripts | Description |
|------------|---------|-------------|
| `infra/` | 6 | Infrastructure (win-cli timeout guard, ripgrep diagnostic, Docker) |
| `install/` | 1 | Installation initiale |
| `setup/` | 6 | Configuration environnement (Git hooks, auto-login, VS Code) |
| `windows/` | 3 | Spécifique Windows (WSL, startup, Docker) |
| `zoo-scheduler/` | 6 | Migration et gestion du scheduler Zoo Code (globalState migration, health check) |

### Diagnostic & Monitoring

| Répertoire | Scripts | Description |
|------------|---------|-------------|
| `diagnostic/` | 12 | Diagnostic environnement (MCP, GDrive, Qdrant, submodules) |
| `monitoring/` | 13 | Monitoring continu (health checks, metrics, alerts) |
| `inventory/` | 4 | Inventaire machines et configurations |

### Validation & Tests

| Répertoire | Scripts | Description |
|------------|---------|-------------|
| `testing/` | 8 | Tests unitaires et E2E (Pester, Vitest, Playwright) |
| `validation/` | 13 | Validation fonctionnelle (build, CI, configs, MCP drift, commit citations) |
| `audit/` | 1 | Audit de qualité (rules footprint) |

### Maintenance & Cleanup

| Répertoire | Scripts | Description |
|------------|---------|-------------|
| `maintenance/` | 16 | Maintenance récurrente (cleanup, sync, index repair, idle patrol, MCP stdio zombies) |
| `cleanup/` | 1 | Nettoyage général |
| `_archive/` | 1 | Scripts archivés (référence seulement) |

### Encodage & Format

| Répertoire | Scripts | Description |
|------------|---------|-------------|
| `encoding/` | 36 | Correction encodage fichiers (BOM, UTF-8, emoji) |
| `utf8/` | 3 | Conversion UTF-8 spécifique |

### Analyse & Documentation

| Répertoire | Scripts | Description |
|------------|---------|-------------|
| `analysis/` | 6 | Analyse de code et métriques (branches, commits, complexity) |
| `docs/` | 7 | Génération et maintenance de documentation |
| `benchmarks/` | 1 | Benchmarks de performance |
| `common/` | 2 | Utilitaires partagés (extension paths, submodule deletion guards) |

### Autres

| Répertoire | Scripts | Description |
|------------|---------|-------------|
| `jupyter/` | 1 | Intégration Jupyter notebooks |

---

## Références

- Architecture du dépôt : [`docs/architecture/repository-map.md`](../docs/architecture/repository-map.md)
- Guide technique RooSync : [`docs/roosync/GUIDE-TECHNIQUE-v2.3.md`](../docs/roosync/GUIDE-TECHNIQUE-v2.3.md)
- Inventaire des outils MCP : [`.claude/rules/tool-availability.md`](../.claude/rules/tool-availability.md)
