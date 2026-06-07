# Répertoire des Scripts

Ce répertoire centralise tous les scripts PowerShell et JavaScript utilisés pour l'outillage et l'automatisation du projet RooSync.

**Dernière mise à jour :** 2026-06-07

---

## Scripts à la racine

| Script | Description |
|--------|-------------|
| `run-tests.ps1` | Exécution des tests Vitest avec options CI |
| `cleanup-orphan-branches.ps1` | Nettoyage des branches orphelines (PR merged/closed) |
| `audit-rules-footprint.ps1` | Audit de l'empreinte des règles .claude/rules/ |
| `sync-roo-alwaysallow.js` | Synchronisation des permissions alwaysAllow Roo |

---

## Sous-répertoires (42)

### Coordination & Synchronisation

| Répertoire | Scripts | Description |
|------------|---------|-------------|
| `roosync/` | 20 | Synchronisation multi-machines RooSync (indexation, storage, config sync) |
| `dashboard-scheduler/` | 8 | Dashboard listener + scheduler (wake-claude, heartbeat, condensation) |
| `messaging/` | 4 | Communication inter-machines (ventilation, inbox) |
| `gdrive/` | 1 | Intégration Google Drive |
| `scheduler/` | 3 | Configuration du scheduler Roo |

### MCP & Services

| Répertoire | Scripts | Description |
|------------|---------|-------------|
| `mcp/` | 14 | Gestion et validation des serveurs MCP (build, validate, deploy) |
| `mcp-watchdog/` | 6 | Surveillance et redémarrage automatique des MCP |
| `qdrant/` | 5 | Gestion Qdrant (backup, restore, diagnostics) |
| `copilot/` | 1 | Configuration VS Code Copilot MCP |
| `deployment/` | 14 | Déploiement des configurations (install-mcps, migrate-roo-to-zoo) |
| `roo-settings/` | 2 | Gestion des paramètres Roo Code |

### Git & Workflow

| Répertoire | Scripts | Description |
|------------|---------|-------------|
| `git/` | 1 | Opérations Git basiques |
| `git-workflow/` | 7 | Workflow Git avancé (submodules, commit, branches) |
| `github/` | 4 | Intégration GitHub (sync-project, set-fields, review-bot) |
| `worktrees/` | 4 | Gestion des worktrees Git (création, cleanup, merge) |
| `hermes-watchdog/` | 4 | Surveillance du bot Hermes (cluster manager) |

### Claude Code & Agents

| Répertoire | Scripts | Description |
|------------|---------|-------------|
| `claude/` | 14 | Scripts Claude Code (spawn workers, switch-provider, validation) |
| `claude-md/` | 1 | Gestion CLAUDE.md |
| `memory/` | 2 | Gestion mémoire agents (inject, redistribute) |
| `review/` | 4 | Reviews automatisées (PR review, code review) |
| `scheduling/` | 16 | Scripts de planification (copilot dispatcher, schtasks) |

### Infrastructure & Système

| Répertoire | Scripts | Description |
|------------|---------|-------------|
| `infra/` | 6 | Infrastructure (win-cli timeout guard, ripgrep diagnostic) |
| `install/` | 1 | Installation initiale |
| `setup/` | 6 | Configuration environnement |
| `windows/` | 3 | Spécifique Windows (WSL, startup) |
| `zoo-scheduler/` | 4 | Migration et gestion du scheduler Zoo Code |

### Diagnostic & Monitoring

| Répertoire | Scripts | Description |
|------------|---------|-------------|
| `diagnostic/` | 12 | Diagnostic environnement (MCP, GDrive, Qdrant, submodules) |
| `monitoring/` | 13 | Monitoring continu (health checks, metrics, alerts) |
| `inventory/` | 3 | Inventaire machines et configurations |

### Validation & Tests

| Répertoire | Scripts | Description |
|------------|---------|-------------|
| `testing/` | 8 | Tests unitaires et E2E |
| `validation/` | 11 | Validation fonctionnelle (build, CI, configs) |
| `audit/` | 1 | Audit de qualité |

### Maintenance & Cleanup

| Répertoire | Scripts | Description |
|------------|---------|-------------|
| `maintenance/` | 14 | Maintenance récurrente (cleanup, sync, index repair) |
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
| `analysis/` | 6 | Analyse de code et métriques |
| `docs/` | 7 | Génération et maintenance de documentation |
| `benchmarks/` | 1 | Benchmarks de performance |
| `common/` | 1 | Utilitaires partagés |

### Autres

| Répertoire | Scripts | Description |
|------------|---------|-------------|
| `jupyter/` | 1 | Intégration Jupyter notebooks |

---

## Références

- Architecture du dépôt : [`docs/architecture/repository-map.md`](../docs/architecture/repository-map.md)
- Guide technique RooSync : [`docs/roosync/GUIDE-TECHNIQUE-v2.3.md`](../docs/roosync/GUIDE-TECHNIQUE-v2.3.md)
- Inventaire des outils MCP : [`.claude/rules/tool-availability.md`](../.claude/rules/tool-availability.md)
