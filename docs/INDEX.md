# INDEX CENTRALISE DE LA DOCUMENTATION

**Derniere mise a jour:** 2026-02-09
**Version:** 5.0 (Post-consolidation contenu)

---

## Structure docs/ (10 repertoires)

```
docs/
├── architecture/     # Architecture systeme, designs, analyses
├── archive/          # Contenu historique/obsolete (auto-archive)
├── deployment/       # Deploiement, hardware
├── dev/              # Debugging, encoding, fixes, tests, refactoring
├── guides/           # Guides utilisateur, installation, depannage
├── knowledge/        # Base de connaissances
├── mcp/              # Documentation MCP roo-state-manager
├── roo-code/         # Documentation Roo Code, PRs, ADR
├── roosync/          # Protocoles RooSync v2.3, guides agents
├── suivi/            # Suivi projet actif, monitoring
├── INDEX.md          # Ce fichier
└── README.md         # Vue d'ensemble
```

---

## Documentation RooSync

### Guides Principaux
- [README.md](roosync/README.md) - Documentation principale RooSync
- [GUIDE-TECHNIQUE-v2.3.md](roosync/GUIDE-TECHNIQUE-v2.3.md) - Guide technique v2.3 (actuel)
- [ARCHITECTURE_ROOSYNC.md](roosync/ARCHITECTURE_ROOSYNC.md) - Architecture technique
- [GESTION_MULTI_AGENT.md](roosync/GESTION_MULTI_AGENT.md) - Gestion multi-agent
- [QUICKSTART.md](roosync/QUICKSTART.md) - Demarrage rapide

### Guides Agents
- [roosync/guides/](roosync/guides/) - Checklists, glossaire, onboarding, troubleshooting

### Reference
- [ERROR_CODES_REFERENCE.md](roosync/ERROR_CODES_REFERENCE.md) - Codes d'erreur
- [SUBMODULE_WORKFLOW.md](roosync/SUBMODULE_WORKFLOW.md) - Workflow submodules
- [PROTOCOLE_SDDD.md](roosync/PROTOCOLE_SDDD.md) - Protocole SDDD

### Archive
- [roosync/archive/](roosync/archive/) - v2.1 legacy, migration plans, integration historique (20+ docs)

---

## Architecture

### Architecture Systeme
- [repository-map.md](architecture/repository-map.md) - Carte du depot
- [ARCHITECTURE_2_NIVEAUX.md](architecture/ARCHITECTURE_2_NIVEAUX.md) - Architecture 2 niveaux
- [DATA_STORAGE_POLICY.md](architecture/DATA_STORAGE_POLICY.md) - Politique de stockage
- [scheduling-claude-code.md](architecture/scheduling-claude-code.md) - Planification Claude Code

### Roo State Manager
- [roo-state-manager-architecture.md](architecture/roo-state-manager-architecture.md) - Architecture
- [roo-state-manager-parsing-refactoring.md](architecture/roo-state-manager-parsing-refactoring.md) - Refactoring parsing
- [message-to-skeleton-transformer.md](architecture/message-to-skeleton-transformer.md) - Transformeur messages

### RooSync Architecture
- [roosync-real-diff-detection-design.md](architecture/roosync-real-diff-detection-design.md) - Detection de differences
- [roosync-temporal-messages-architecture.md](architecture/roosync-temporal-messages-architecture.md) - Messages temporels
- [roosync-v1-vs-v2-gap-analysis.md](architecture/roosync-v1-vs-v2-gap-analysis.md) - Gap analysis v1 vs v2

### Analyses Recentes
- [ROO_TASK_FORENSICS_2026-02-08.md](architecture/ROO_TASK_FORENSICS_2026-02-08.md) - Forensics taches
- [task-hierarchy-analysis-20251203.md](architecture/task-hierarchy-analysis-20251203.md) - Analyse hierarchie taches

### Archive
- [architecture/archive/](architecture/archive/) - Syntheses, planning, investigations historiques

---

## Guides

### Installation et Configuration
- [MCPs-INSTALLATION-GUIDE.md](guides/MCPs-INSTALLATION-GUIDE.md) - Guide d'installation MCPs
- [ENVIRONMENT-SETUP-SYNTHESIS.md](guides/ENVIRONMENT-SETUP-SYNTHESIS.md) - Configuration d'environnement
- [guide-utilisation-mcps.md](guides/guide-utilisation-mcps.md) - Utilisation des MCPs
- [guide-utilisation-mcp-jupyter.md](guides/guide-utilisation-mcp-jupyter.md) - MCP Jupyter

### Modes et Profils Roo
- [guide-complet-modes-roo.md](guides/guide-complet-modes-roo.md) - Guide complet des modes
- [guide-utilisation-profils-modes.md](guides/guide-utilisation-profils-modes.md) - Utilisation des profils

### Depannage
- [TROUBLESHOOTING-GUIDE.md](guides/TROUBLESHOOTING-GUIDE.md) - Guide de depannage general
- [MCP-TROUBLESHOOTING-UNIFIED.md](guides/MCP-TROUBLESHOOTING-UNIFIED.md) - Depannage MCP unifie (consolide 3 guides)

### Guides Utilisateur
- [guides/user-guide/](guides/user-guide/) - QUICK-START, README, TROUBLESHOOTING

### Autres Guides
- [guide-synchronisation-submodules.md](guides/guide-synchronisation-submodules.md) - Synchronisation des sous-modules
- [procedures-maintenance.md](guides/procedures-maintenance.md) - Procedures de maintenance
- [consolidated-task-management-guide.md](guides/consolidated-task-management-guide.md) - Gestion des taches
- [guide-exploration-prompts-natifs.md](guides/guide-exploration-prompts-natifs.md) - Exploration prompts natifs
- [vscode-extension-debug-powershell-configuration.md](guides/vscode-extension-debug-powershell-configuration.md) - Debug VS Code PowerShell

---

## Dev (developpement)

### Debugging
- [dev/debugging/](dev/debugging/) - Analyse bugs, corruption settings, hierarchie taches

### Encoding (4 docs actifs + archives)
- [dev/encoding/README.md](dev/encoding/README.md) - Index encodage
- [dev/encoding/quick-start-encoding.md](dev/encoding/quick-start-encoding.md) - Reference rapide
- [dev/encoding/troubleshooting-guide.md](dev/encoding/troubleshooting-guide.md) - Depannage encodage
- [dev/encoding/maintenance-procedures.md](dev/encoding/maintenance-procedures.md) - Procedures maintenance

### Fixes
- [dev/fixes/](dev/fixes/) - Corrections et reparations

### Indexation
- [dev/indexation/](dev/indexation/) - Reparation detectWorkspaceForTask

### Maintenance
- [dev/maintenance/](dev/maintenance/) - Guide hooks git

### Refactoring (4 docs actifs + archives)
- [dev/refactoring/01-cleanup-plan.md](dev/refactoring/01-cleanup-plan.md) - Plan cleanup
- [dev/refactoring/02-phase1-completion-report.md](dev/refactoring/02-phase1-completion-report.md) - Rapport phase 1
- [dev/refactoring/04-mission-final-report.md](dev/refactoring/04-mission-final-report.md) - Rapport final
- [dev/refactoring/COMPLEXITY-REFACTORING-REPORT.md](dev/refactoring/COMPLEXITY-REFACTORING-REPORT.md) - Rapport complexite

### Testing (3 docs actifs + archives)
- [dev/testing/TEST_STRATEGY.md](dev/testing/TEST_STRATEGY.md) - Strategie de tests
- [dev/testing/strategies-de-test.md](dev/testing/strategies-de-test.md) - Strategies alternatives
- [dev/testing/roosync-e2e-test-plan.md](dev/testing/roosync-e2e-test-plan.md) - Plan E2E RooSync

### Autres
- [dev/precommit-hook.md](dev/precommit-hook.md) - Configuration pre-commit hook
- [dev/WORKTREE-WORKFLOW.md](dev/WORKTREE-WORKFLOW.md) - Workflow worktree

---

## Suivi de Projet

### RooSync Multi-Agent (actif)
- [suivi/RooSync/SUIVI_ACTIF.md](suivi/RooSync/SUIVI_ACTIF.md) - Suivi actif
- [suivi/RooSync/BUGS_TRACKING.md](suivi/RooSync/BUGS_TRACKING.md) - Suivi des bugs
- [suivi/RooSync/INDEX.md](suivi/RooSync/INDEX.md) - Index RooSync

### Project
- [suivi/project/project-status.md](suivi/project/project-status.md) - Statut projet
- [suivi/project/project-changelog.md](suivi/project/project-changelog.md) - Changelog

### Monitoring
- [suivi/monitoring/](suivi/monitoring/) - Systeme de monitoring quotidien

### Rapport Bug Critique
- [suivi/RAPPORT-BUG-CRITIQUE-QUICKFILES.md](suivi/RAPPORT-BUG-CRITIQUE-QUICKFILES.md) - Bug critique Quickfiles

### Archive
- [suivi/archive/](suivi/archive/) - Coordination, reports, sessions, incidents historiques

---

## MCP

### Roo State Manager
- [mcp/roo-state-manager/](mcp/roo-state-manager/) - Documentation dediee (features, audit technique)

### Archive
- [mcp/archive/](mcp/archive/) - Fix reports historiques (Oct 2025)

---

## Deployment

- [deployment/DEPLOY-SCHEDULED-ROO.md](deployment/DEPLOY-SCHEDULED-ROO.md) - Deploiement taches planifiees
- [deployment/GPU_SPECS_MULTI_MACHINE.md](deployment/GPU_SPECS_MULTI_MACHINE.md) - Specs GPU multi-machine

---

## Roo Code

- [roo-code/README.md](roo-code/README.md) - Documentation Roo Code
- [roo-code/pr-tracking/](roo-code/pr-tracking/) - PR tracking (context condensation)
- [roo-code/architecture/](roo-code/architecture/) - Architecture Roo Code
- [roo-code/adr/](roo-code/adr/) - Architecture Decision Records
- [roo-code/contributing/](roo-code/contributing/) - Guides de contribution

---

## Knowledge

- [knowledge/WORKSPACE_KNOWLEDGE.md](knowledge/WORKSPACE_KNOWLEDGE.md) - Base de connaissances (6500+ fichiers)

---

## Archive

- [archive/](archive/) - Contenu historique et obsolete
  - Guides MCP consolides (MCPS-COMMON-ISSUES, GUIDE-URGENCE-MCP, mcp-troubleshooting)
  - Guides encodage (guide-encodage, RESOLUTION-ENCODAGE-UTF8)
  - Deploiement v2.1 legacy (5 guides)
  - GPU specs myia-po-2023 (contenu dans multi-machine)
  - MCP deployment (couvert par MCP-TROUBLESHOOTING-UNIFIED)
  - Historique git (merge reports, stash analyses)

---

## Liens Externes

- [../roo-config/README.md](../roo-config/README.md) - Configuration Roo
- [../mcps/README.md](../mcps/README.md) - Documentation MCPs
- [../CLAUDE.md](../CLAUDE.md) - Guide agents Claude Code

---

**Consolide par:** myia-po-2025
**Date consolidation:** 2026-02-09
**Version:** 5.0 - Consolidation contenu (fusions, archives par sous-repertoire)
**Precedent:** v4.0 (consolidation structure #435)
