# Documentation des Tâches Planifiées

## Vue d'ensemble

Ce répertoire contient la documentation des tâches planifiées pour l'environnement Roo Extensions.

## Systèmes de Scheduling Disponibles

### 1. Roo Scheduler (Extension VS Code)

Extension légère pour tâches récurrentes simples pendant le développement.

- **Documentation** : [roo-scheduler-analysis.md](../../roo-code/roo-scheduler-analysis.md)
- **Cas d'usage** : Revue de code, linting, suggestions de refactoring

### 2. Orchestration Quotidienne (PowerShell)

Système d'orchestration multi-phases pour automatisation lourde.

- **Scripts** : `roo-config/scheduler/`
- **Configuration** : `roo-config/scheduler/daily-orchestration.json`
- **Cas d'usage** : Sync Git, tests, validation configs, nettoyage

## Procédures Documentées

| Procédure | Description | Fichier |
| --- | --- | --- |
| Sync Repository Settings | Synchronisation paramètres de dépôt | [settings_sync_procedure.md](settings_sync_procedure.md) |

## Configuration Générale

Les configurations de scheduling se trouvent dans :

- `.roo/schedules.json` - Configuration JSON des schedules
- `roo-config/scheduler/config/` - Configurations système

## Logs et Monitoring

- **Logs orchestration** : `roo-config/scheduler/logs/`
- **Métriques** : `roo-config/scheduler/metrics/`
- **Escalades** : `roo-config/scheduler/logs/escalations-{yyyyMM}.json`

## Voir Aussi

- [daily-monitoring-system.md](../daily-monitoring-system.md) - Système de surveillance quotidienne
- [mcp-debug-logging-system.md](../mcp-debug-logging-system.md) - Logging des MCPs

---

*Index créé le 2026-01-22*
