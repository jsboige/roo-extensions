# Configuration du Scheduler

## Fichiers de Configuration

Ce répertoire contient les fichiers de configuration pour le système de scheduling.

### Structure

| Fichier | Responsabilité | Scripts Utilisateurs |
| --- | --- | --- |
| `scheduler-config.json` | Configuration générale du scheduler (execution, monitoring, storage, security, performance) | `scheduler-manager.ps1`, `install-scheduler.ps1` |
| `environments.json` | Profils d'environnement (development, testing, production) | `scheduler-manager.ps1`, `install-scheduler.ps1` |
| `modules-config.json` | Configuration des modules (core, utilities, integrations) avec ordre de chargement | `scheduler-manager.ps1`, `install-scheduler.ps1` |

### Fichier Parent

Le fichier `../config.json` (à la racine de `roo-config/scheduler/`) contient la configuration principale du système de synchronisation Git :

- Configuration Git (branches, messages de commit)
- Configuration Windows Task Scheduler
- Fichiers à synchroniser
- Validation et gestion d'erreurs

### Orchestration

Le fichier `../daily-orchestration.json` contient la configuration des phases d'orchestration quotidienne (diagnostic, synchronization, testing, cleanup, improvement).

## Environnements

| Environnement | Usage | Active |
| --- | --- | --- |
| `development` | Développement local, debug activé | ✅ Par défaut |
| `testing` | Tests et validation | ❌ |
| `production` | Production | ❌ |

Pour changer d'environnement, modifier `defaultEnvironment` dans `environments.json`.

## Modules

Ordre de chargement :

1. `utilities.logger` - Logging
2. `core.taskManager` - Gestion des tâches
3. `utilities.metrics` - Métriques
4. `utilities.healthCheck` - Vérification santé
5. `core.queueManager` - File d'attente
6. `core.executionEngine` - Moteur d'exécution
7. `integrations.rooModes` - Intégration modes Roo
8. `integrations.mcpServers` - Intégration MCP
9. `integrations.vscodeExtension` - Extension VS Code (désactivée)

---

*Documentation générée le 2026-01-22*
