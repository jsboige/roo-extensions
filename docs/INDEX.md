# INDEX CENTRALISE DE LA DOCUMENTATION

**Derniere mise a jour:** 2026-02-09
**Version:** 4.0 (Post-consolidation #435)

---

## Structure docs/ (11 repertoires)

```
docs/
├── architecture/     # Architecture, orchestration, analyses, planning
├── archive/          # Contenu historique/obsolete
├── deployment/       # Deploiement, infrastructure, hardware
├── dev/              # Configuration, debugging, encoding, fixes, tests, refactoring
├── git/              # Historique git, stash, merge reports
├── guides/           # Guides utilisateur, installation, depannage
├── knowledge/        # Base de connaissances (WORKSPACE_KNOWLEDGE.md)
├── mcp/              # Documentation MCP (roo-state-manager, repairs, troubleshooting)
├── roo-code/         # Documentation Roo Code, PRs, ADR
├── roosync/          # Protocoles RooSync, integration, versions
├── suivi/            # Suivi projet, coordination, monitoring, rapports, incidents
├── INDEX.md          # Ce fichier
└── README.md         # Vue d'ensemble documentation
```

---

## Documentation RooSync

### Guides Principaux
- [README.md](roosync/README.md) - Documentation principale RooSync
- [GUIDE_UTILISATION_ROOSYNC.md](roosync/GUIDE_UTILISATION_ROOSYNC.md) - Guide d'utilisation complet
- [ARCHITECTURE_ROOSYNC.md](roosync/ARCHITECTURE_ROOSYNC.md) - Architecture technique
- [GESTION_MULTI_AGENT.md](roosync/GESTION_MULTI_AGENT.md) - Gestion multi-agent

### Guides Techniques
- [GUIDE-TECHNIQUE-v2.3.md](roosync/GUIDE-TECHNIQUE-v2.3.md) - Guide technique v2.3 (actuel)
- [GUIDE-TECHNIQUE-v2.1.md](roosync/GUIDE-TECHNIQUE-v2.1.md) - Guide technique v2.1 (legacy)
- [GUIDE-DEVELOPPEUR-v2.1.md](roosync/GUIDE-DEVELOPPEUR-v2.1.md) - Guide developpeur
- [GUIDE-OPERATIONNEL-UNIFIE-v2.1.md](roosync/GUIDE-OPERATIONNEL-UNIFIE-v2.1.md) - Guide operationnel

### Changelogs et Versions
- [CHANGELOG-v2.3.md](roosync/CHANGELOG-v2.3.md) - Changelog v2.3
- [CHANGELOG-v2.2.md](roosync/CHANGELOG-v2.2.md) - Changelog v2.2
- [TRANSITIONS_VERSIONS_V2.1_V2.2_V2.3.md](roosync/TRANSITIONS_VERSIONS_V2.1_V2.2_V2.3.md) - Transitions de versions
- [PLAN_MIGRATION_V2.1_V2.3.md](roosync/PLAN_MIGRATION_V2.1_V2.3.md) - Plan de migration

### Integration (deplace depuis docs/integration/)
- [roosync/integration/](roosync/integration/) - 20+ documents d'integration RooSync

### Methodologie
- [PROTOCOLE_SDDD.md](roosync/PROTOCOLE_SDDD.md) - Protocole SDDD

---

## Architecture

### Architecture Systeme
- [01-main-architecture.md](architecture/01-main-architecture.md) - Architecture principale
- [architecture-orchestration-5-niveaux.md](architecture/architecture-orchestration-5-niveaux.md) - Orchestration 5 niveaux
- [ARCHITECTURE_GIT.md](architecture/ARCHITECTURE_GIT.md) - Architecture Git
- [repository-map.md](architecture/repository-map.md) - Carte du depot
- [ARCHITECTURE_2_NIVEAUX.md](architecture/ARCHITECTURE_2_NIVEAUX.md) - Architecture 2 niveaux (ex-sddd/)

### Roo State Manager
- [roo-state-manager-architecture.md](architecture/roo-state-manager-architecture.md) - Architecture
- [roo-state-manager-parsing-refactoring.md](architecture/roo-state-manager-parsing-refactoring.md) - Refactoring parsing

### RooSync Architecture
- [roosync-real-diff-detection-design.md](architecture/roosync-real-diff-detection-design.md) - Detection de differences
- [roosync-temporal-messages-architecture.md](architecture/roosync-temporal-messages-architecture.md) - Messages temporels
- [roosync-orchestration-synthesis-20251013.md](architecture/roosync-orchestration-synthesis-20251013.md) - Synthese orchestration (ex-orchestration/)
- [roosync-v2-evolution-synthesis-20251015.md](architecture/roosync-v2-evolution-synthesis-20251015.md) - Evolution v2 (ex-orchestration/)

### Analyses (fusionnees depuis analysis/ + investigations/ + investigation/)
- [ROO_TASK_FORENSICS_2026-02-08.md](architecture/ROO_TASK_FORENSICS_2026-02-08.md) - Forensics taches
- [6b-roosync-archaeology.md](architecture/6b-roosync-archaeology.md) - Archeologie RooSync
- [roosync-v1-vs-v2-gap-analysis.md](architecture/roosync-v1-vs-v2-gap-analysis.md) - Gap analysis v1 vs v2
- [inventaire-outils-mcp-avant-sync.md](architecture/inventaire-outils-mcp-avant-sync.md) - Inventaire outils MCP
- [task-hierarchy-analysis-20251203.md](architecture/task-hierarchy-analysis-20251203.md) - Analyse hierarchie taches
- [EXTRACTION-NEW-TASK-TAGS-SPECS.md](architecture/EXTRACTION-NEW-TASK-TAGS-SPECS.md) - Specs extraction tags

### Planning (deplace depuis docs/planning/)
- [architecture/planning/](architecture/planning/) - Plans de phases et roadmaps

### Autres
- [DATA_STORAGE_POLICY.md](architecture/DATA_STORAGE_POLICY.md) - Politique de stockage
- [specification-n-niveaux-complexite.md](architecture/specification-n-niveaux-complexite.md) - Specification complexite

---

## Guides

### Demarrage et Installation
- [ENVIRONMENT-SETUP-SYNTHESIS.md](guides/ENVIRONMENT-SETUP-SYNTHESIS.md) - Configuration d'environnement
- [MCPs-INSTALLATION-GUIDE.md](guides/MCPs-INSTALLATION-GUIDE.md) - Guide d'installation MCPs
- [mcp-deployment.md](guides/mcp-deployment.md) - Deploiement MCP

### Configuration
- [guide-utilisation-mcps.md](guides/guide-utilisation-mcps.md) - Utilisation des MCPs
- [guide-utilisation-mcp-jupyter.md](guides/guide-utilisation-mcp-jupyter.md) - MCP Jupyter
- [guide-complet-modes-roo.md](guides/guide-complet-modes-roo.md) - Guide complet des modes
- [guide-utilisation-profils-modes.md](guides/guide-utilisation-profils-modes.md) - Utilisation des profils

### Encodage
- [guide-encodage.md](guides/guide-encodage.md) - Guide d'encodage
- [RESOLUTION-ENCODAGE-UTF8.md](guides/RESOLUTION-ENCODAGE-UTF8.md) - Resolution UTF-8

### Depannage
- [TROUBLESHOOTING-GUIDE.md](guides/TROUBLESHOOTING-GUIDE.md) - Guide de depannage
- [MCPS-COMMON-ISSUES-GUIDE.md](guides/MCPS-COMMON-ISSUES-GUIDE.md) - Problemes MCP courants
- [GUIDE-URGENCE-MCP.md](guides/GUIDE-URGENCE-MCP.md) - Guide d'urgence MCP

### Guides Utilisateur (deplace depuis docs/user-guide/)
- [guides/user-guide/](guides/user-guide/) - QUICK-START, README, TROUBLESHOOTING

### Autres Guides
- [guide-synchronisation-submodules.md](guides/guide-synchronisation-submodules.md) - Synchronisation des sous-modules
- [procedures-maintenance.md](guides/procedures-maintenance.md) - Procedures de maintenance
- [consolidated-task-management-guide.md](guides/consolidated-task-management-guide.md) - Gestion des taches
- [guide-exploration-prompts-natifs.md](guides/guide-exploration-prompts-natifs.md) - Exploration prompts natifs

---

## Dev (developpement)

### Configuration (ex-configuration/)
- [dev/configuration/](dev/configuration/) - Configuration MCP, guides, resume

### Debugging (ex-debugging/)
- [dev/debugging/](dev/debugging/) - Analyse bugs, corruption settings, hierarchie taches

### Encoding (ex-encoding/)
- [dev/encoding/](dev/encoding/) - 13 documents sur l'encodage UTF-8

### Fixes (ex-fixes/)
- [dev/fixes/](dev/fixes/) - Corrections et reparations
- [PHASE3-PERSISTENCE-FIX-20251024.md](dev/fixes/PHASE3-PERSISTENCE-FIX-20251024.md) - Fix persistence Phase 3

### Indexation (ex-indexation/)
- [dev/indexation/](dev/indexation/) - Reparation detectWorkspaceForTask

### Maintenance (ex-maintenance/)
- [dev/maintenance/](dev/maintenance/) - Guide hooks git

### Refactoring (ex-refactoring/)
- [dev/refactoring/](dev/refactoring/) - 15 documents de refactoring (cleanup, accessibilite, reports)
- [COMPLEXITY-REFACTORING-REPORT.md](dev/refactoring/COMPLEXITY-REFACTORING-REPORT.md) - Rapport refactoring complexite

### Testing (fusionne depuis testing/ + tests/)
- [dev/testing/](dev/testing/) - 16 documents (plans, strategies, rapports)

### Autres
- [dev/precommit-hook.md](dev/precommit-hook.md) - Configuration pre-commit hook
- [dev/WORKTREE-WORKFLOW.md](dev/WORKTREE-WORKFLOW.md) - Workflow worktree

---

## Suivi de Projet

### RooSync Multi-Agent
- [suivi/RooSync/SUIVI_ACTIF.md](suivi/RooSync/SUIVI_ACTIF.md) - Suivi actif
- [suivi/RooSync/BUGS_TRACKING.md](suivi/RooSync/BUGS_TRACKING.md) - Suivi des bugs
- [suivi/RooSync/INDEX.md](suivi/RooSync/INDEX.md) - Index RooSync

### Coordination (deplace depuis docs/coordination/)
- [suivi/coordination/](suivi/coordination/) - Messages diagnostics inter-machines

### Reports (deplace depuis docs/reports/)
- [suivi/reports/](suivi/reports/) - Rapports de missions et analyses

### Sessions (deplace depuis docs/sessions/)
- [suivi/sessions/](suivi/sessions/) - Rapports de sessions

### Project (deplace depuis docs/project/)
- [suivi/project/](suivi/project/) - Status projet, changelog, plans

### Monitoring (deplace depuis docs/monitoring/)
- [suivi/monitoring/](suivi/monitoring/) - Systeme de monitoring quotidien

### Issues (deplace depuis docs/issues/)
- [suivi/issues/](suivi/issues/) - Structure depot propre

### Incidents (deplace depuis docs/incidents/)
- [suivi/incidents/](suivi/incidents/) - Commits a restaurer

### Rapport Bug Critique
- [suivi/RAPPORT-BUG-CRITIQUE-QUICKFILES.md](suivi/RAPPORT-BUG-CRITIQUE-QUICKFILES.md) - Bug critique Quickfiles

---

## MCP (consolide depuis mcp/ + mcps/ + mcp-repairs/)

### Roo State Manager
- [mcp/roo-state-manager/](mcp/roo-state-manager/) - Documentation dediee

### Repairs (ex-mcp-repairs/)
- [mcp/build-skeleton-cache-logs-reduction-20251020.md](mcp/build-skeleton-cache-logs-reduction-20251020.md)
- [mcp/jupyter-papermill-fix-20251017.md](mcp/jupyter-papermill-fix-20251017.md)
- [mcp/roo-state-manager-module-not-found-fix-20251020.md](mcp/roo-state-manager-module-not-found-fix-20251020.md)
- [mcp/roosync-machineid-os-fix-20251020.md](mcp/roosync-machineid-os-fix-20251020.md)

### Troubleshooting (ex-orphelin docs/)
- [mcp/mcp-troubleshooting.md](mcp/mcp-troubleshooting.md) - Guide depannage MCP

### Quickfiles (ex-mcps/)
- [mcp/quickfiles-search-fix.md](mcp/quickfiles-search-fix.md) - Fix recherche Quickfiles

### Documentation MCPs (repertoire racine)
- [../mcps/README.md](../mcps/README.md) - Documentation principale MCPs
- [../mcps/INSTALLATION.md](../mcps/INSTALLATION.md) - Guide d'installation
- [../mcps/TROUBLESHOOTING.md](../mcps/TROUBLESHOOTING.md) - Guide de depannage

---

## Deployment

### Deploiement RooSync v2.1 (legacy)
- [deployment/roosync-v2-1-deployment-guide.md](deployment/roosync-v2-1-deployment-guide.md) - Guide deploiement v2.1
- [deployment/roosync-v2-1-cheatsheet.md](deployment/roosync-v2-1-cheatsheet.md) - Cheatsheet v2.1
- [deployment/roosync-v2-1-commands-reference.md](deployment/roosync-v2-1-commands-reference.md) - Reference commandes
- [deployment/roosync-v2-1-user-guide.md](deployment/roosync-v2-1-user-guide.md) - Guide utilisateur v2.1
- [deployment/roosync-v2-1-developer-guide.md](deployment/roosync-v2-1-developer-guide.md) - Guide developpeur v2.1
- [deployment/DEPLOY-SCHEDULED-ROO.md](deployment/DEPLOY-SCHEDULED-ROO.md) - Deploiement taches planifiees

### Hardware et Infrastructure (fusionnes)
- [deployment/GPU_SPECS_MULTI_MACHINE.md](deployment/GPU_SPECS_MULTI_MACHINE.md) - Specs GPU multi-machine
- [deployment/gpu-specs-myia-po-2023.md](deployment/gpu-specs-myia-po-2023.md) - Specs GPU myia-po-2023

---

## Roo Code

- [roo-code/README.md](roo-code/README.md) - Documentation Roo Code
- [roo-code/pr-tracking/](roo-code/pr-tracking/) - PR tracking (context condensation)
- [roo-code/architecture/](roo-code/architecture/) - Architecture Roo Code
- [roo-code/adr/](roo-code/adr/) - Architecture Decision Records
- [roo-code/contributing/](roo-code/contributing/) - Guides de contribution

---

## Git (historique)

- [git/](git/) - Rapports de merge, stash backups, analyses de sync

---

## Knowledge

- [knowledge/WORKSPACE_KNOWLEDGE.md](knowledge/WORKSPACE_KNOWLEDGE.md) - Base de connaissances (6500+ fichiers)

---

## Archive

- [archive/](archive/) - Contenu historique et obsolete

---

## Liens Externes

- [../roo-config/README.md](../roo-config/README.md) - Configuration Roo
- [../mcps/README.md](../mcps/README.md) - Documentation MCPs
- [../CLAUDE.md](../CLAUDE.md) - Guide agents Claude Code

---

**Consolide par:** myia-po-2025 (Issue #435)
**Date consolidation:** 2026-02-09
**Version:** 4.0
