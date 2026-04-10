# Répertoire des Scripts

Ce répertoire centralise tous les scripts PowerShell et JavaScript utilisés pour l'outillage et l'automatisation du projet. Les scripts sont organisés en sous-répertoires basés sur leur fonctionnalité.

**Consolidation #481 (2026-02-17) :** Réduction de 65 → 14 fichiers racine + ventilation en sous-répertoires spécialisés.

**À la racine :** Scripts temporaires pour la consolidation en cours (phase1, phase2, search)

---

## Structure des Répertoires (29 sous-répertoires)

### Scripts de Maintenance (racine)
- `phase1-archive-obsolete.ps1` - Archivage scripts obsolètes
- `phase2-ventilate.ps1` - Ventilation scripts dans sous-répertoires
- `phase2-ventilate-clean.ps1` - Version propre de ventilation
- `search-task-instruction-exhaustive.ps1` - Recherche dans tâches Roo

### Diagnostic & Debug
- `/diagnostic` : Outils pour le diagnostic de l'environnement technique
  - `/hierarchy` : Scripts de debug hiérarchie des tâches (9 scripts)

### Git & Workflow
- `/git` : Scripts d'opération Git
- `/git-workflow` : Scripts de workflow Git complexes (commit, submodule, retour main)

### Encoding & Format
- `/encoding` : Scripts pour la correction de l'encodage des fichiers (BOM, UTF-8, emoji)
- `/utf8` : Scripts spécifiques UTF-8

### MCP & Services
- `/mcp` : Scripts de gestion et validation des serveurs MCP
- `/roosync` : Scripts de synchronisation multi-machines

### Maintenance & Cleanup
- `/maintenance` : Outils pour la maintenance du projet
- `/cleanup` : Scripts de nettoyage

### Tests & Validation
- `/testing` : Scripts de tests unitaires et E2E
- `/validation` : Scripts de validation fonctionnelle

### Setup & Install
- `/setup` : Scripts pour la configuration initiale
- `/install` : Scripts d'installation des dépendances

### Analysis
- `/analysis` : Scripts d'analyse de code et commits
- `/audit` : Scripts d'audit

### Monitoring
- `/monitoring` : Scripts de monitoring
- `/inventory` : Scripts d'inventaire

### Messaging
- `/messaging` : Scripts de ventilation et communication

### Scheduling
- `/scheduling` : Scripts liés au scheduler Roo

### Autres
- `/deployment` : Scripts pour le déploiement des configurations
- `/docs` : Scripts de documentation
- `/memory` : Scripts de gestion mémoire
- `/worktrees` : Scripts de gestion des worktrees
- `/benchmarks` : Scripts de benchmark
- `/claude-md` : Scripts spécifiques Claude MD
- `/demo-scripts` : Démos et exemples
- `/transients` : Scripts temporaires

---

Pour plus de détails sur l'architecture, voir [`docs/architecture/repository-map.md`](../docs/architecture/repository-map.md).
