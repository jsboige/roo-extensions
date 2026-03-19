# INDEX CENTRALISE DE LA DOCUMENTATION

**Derniere mise a jour:** 2026-03-18
**Version:** 5.8 (Indexation complète Archive - 45 fichiers documentés)

---

## Structure docs/ (16 repertoires)

```
docs/
├── analysis/         # Analyses de patterns (MCP, etc.) - NOUVEAU
├── architecture/     # Architecture systeme, designs, analyses
├── archive/          # Contenu historique/obsolete (auto-archive)
├── audit/            # Audits techniques et investigations - NOUVEAU
├── deployment/       # Deploiement, hardware
├── dev/              # Debugging, encoding, fixes, tests, refactoring
├── evaluation/       # Evaluations modeles (LLM) - NOUVEAU
├── framework-multi-agent/  # Templates et framework coordination multi-agent
├── guides/           # Guides utilisateur, installation, depannage
├── harness/          # Documentation harnais Roo/Claude (rules-mapping, etc.)
├── knowledge/        # Base de connaissances
├── mcp/              # Documentation MCP roo-state-manager
├── roo-code/         # Documentation Roo Code, PRs, ADR
├── roosync/          # Protocoles RooSync v2.3, guides agents
├── scheduler/        # Scheduler Roo & Claude Code
├── services/         # Documentation services techniques - NOUVEAU
├── suivi/            # Suivi projet actif, monitoring
├── testing/          # Rapports tests et audits - NOUVEAU
├── INDEX.md          # Ce fichier
└── README.md         # Vue d'ensemble
```

---

## Fichiers Racine (docs/)

Documentation importante à la racine de docs/ (hors sous-dossiers).

### Audits & Analyses

- [coverage-audit-492.md](coverage-audit-492.md) - **Audit de Couverture de Tests** (Issue #492) - Analyse couverture roo-state-manager MCP (25.33% vs 80% objectif)
- [cross-analysis-harnesses-2026-03-13.md](cross-analysis-harnesses-2026-03-13.md) - **Analyse Croisée des Harnais META-ANALYST** (2026-03-13, Roo vs Claude) - 10 incohérences, 12 lacunes identifiées, 5 recommandations priorisées
- [harness-cross-analysis-report.md](harness-cross-analysis-report.md) - **Rapport d'Analyse Croisée des Harnais** (Roo vs Claude) - Comparaison couverture fichiers Roo/Claude + gaps analysés
- [harness-cross-analysis-report-2026-03-14.md](harness-cross-analysis-report-2026-03-14.md) - **Rapport d'Analyse Croisée des Harnais** (2026-03-14) - Rapport meta-analyste session 32
- [harness-cross-analysis-report-2026-03-15.md](harness-cross-analysis-report-2026-03-15.md) - **Rapport d'Analyse Croisée des Harnais** (2026-03-15) - Rapport meta-analyste session 32 (cont-6)

### Référence Technique

- [mcp-configuration.md](mcp-configuration.md) - **Configuration MCP par Machine** - Référence complète (Issue #688) : configs séparées Claude Code vs Roo, win-cli fork local 0.2.0, tableau de vérification
- [scheduler-workflow.md](scheduler-workflow.md) - **Unified Scheduler Workflows** - Référence technique (Issue #689) : 3 types workflows (Executor/Coordinator/Meta-Analyst), modules PowerShell partagés, protocole INTERCOM

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
- [scheduling-claude-code.md](architecture/scheduling-claude-code.md) - Investigation scheduling (fév 2026)
- [scheduler-claude-code-design.md](architecture/scheduler-claude-code-design.md) - **NOUVEAU** Architecture scheduler implémenté (fév 2026)

### Roo State Manager
- [roo-state-manager-architecture.md](architecture/roo-state-manager-architecture.md) - Architecture
- [roo-state-manager-parsing-refactoring.md](architecture/roo-state-manager-parsing-refactoring.md) - Refactoring parsing
- [message-to-skeleton-transformer.md](architecture/message-to-skeleton-transformer.md) - Transformeur messages

### RooSync Architecture
- [roosync-real-diff-detection-design.md](architecture/roosync-real-diff-detection-design.md) - Detection de differences
- [roosync-v1-vs-v2-gap-analysis.md](archive/obsolete/roosync-v1-vs-v2-gap-analysis.md) - Gap analysis v1 vs v2 (archivé)

### Analyses Recentes
- [ROO_TASK_FORENSICS_2026-02-08.md](architecture/ROO_TASK_FORENSICS_2026-02-08.md) - Forensics taches
- [task-hierarchy-analysis-20251203.md](architecture/task-hierarchy-analysis-20251203.md) - Analyse hierarchie taches

### Archive
- [architecture/archive/](architecture/archive/) - Syntheses, planning, investigations historiques

---

## Analysis

- [mcp-usage-patterns-2026-02.md](analysis/mcp-usage-patterns-2026-02.md) - Patterns d'utilisation MCP

---

## Audit

- [REMEDIATION_STEPS_572.md](audit/REMEDIATION_STEPS_572.md) - Etapes remediation #572

---

## Evaluation

- [qwen-3.5-35b-a3b-evaluation-536.md](evaluation/qwen-3.5-35b-a3b-evaluation-536.md) - Evaluation modele Qwen 3.5

---

## Guides

### Installation et Configuration
- [MCPs-INSTALLATION-GUIDE.md](guides/MCPs-INSTALLATION-GUIDE.md) - Guide d'installation MCPs
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

### Refactoring (3 docs actifs + archives)
- [dev/refactoring/01-cleanup-plan.md](dev/refactoring/01-cleanup-plan.md) - Plan cleanup
- [dev/refactoring/02-phase1-completion-report.md](dev/refactoring/02-phase1-completion-report.md) - Rapport phase 1
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
- **$ROOSYNC_SHARED_PATH/DASHBOARD.md** - Dashboard hiérarchique (nouveau format #546)
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

## MCP

### Documentation

- [mcp/roo-state-manager/README.md](mcp/roo-state-manager/README.md) - Index documentation Roo State Manager
- [mcp/roo-state-manager/features/](mcp/roo-state-manager/features/) - Recherche sémantique, navigation, indexation
- [mcp/roo-state-manager/technical-audit/](mcp/roo-state-manager/technical-audit/) - Audits techniques (E2E, Qdrant, Jest)
- [mcp/roo-state-manager/project-plan.md](mcp/roo-state-manager/project-plan.md) - Plan de projet

### Archive
- [mcp/archive/](mcp/archive/) - Fix reports historiques (Oct 2025)

---

## Deployment

- [deployment/GPU_SPECS_MULTI_MACHINE.md](deployment/GPU_SPECS_MULTI_MACHINE.md) - Specs GPU multi-machine
- [deployment/DEPLOY-SCHEDULED-ROO.md](deployment/DEPLOY-SCHEDULED-ROO.md) - Deploiement taches planifiees Roo
- [deployment/scheduler-issues-fixes.md](deployment/scheduler-issues-fixes.md) - Fixes scheduler
- [deployment/scheduler-modes-deployment-guide.md](deployment/scheduler-modes-deployment-guide.md) - Guide deploiement modes scheduler

---

## Services

- [ConfigSharingService.md](services/ConfigSharingService.md) - Service partage configuration
- [GranularDiffDetector.md](services/GranularDiffDetector.md) - Detection differences granulaire
- [HierarchyReconstructionEngine.md](services/HierarchyReconstructionEngine.md) - Reconstruction hierarchie
- [NarrativeContextBuilderService.md](services/NarrativeContextBuilderService.md) - Construction contexte narratif
- [sk-agent-deployment.md](services/sk-agent-deployment.md) - Deploiement sk-agent

---

## Testing

- [issue-564-phase1-audit-report.md](testing/issue-564-phase1-audit-report.md) - Rapport audit tests #564
- [issue-564-phase1-inventory.md](testing/issue-564-phase1-inventory.md) - Inventaire tests #564

---

## Scheduler

### Claude Code Scheduler (OPERATIONAL - 2026-02-26)
- [scheduler/scheduler-pilot-test-plan.md](scheduler/scheduler-pilot-test-plan.md) - Plan de test pilote scheduler
- [../scripts/scheduling/README.md](../scripts/scheduling/README.md) - Scripts scheduling (worker, setup, tests)
- [../scripts/scheduling/start-claude-worker.ps1](../scripts/scheduling/start-claude-worker.ps1) - Worker avec escalade + sub-agents
- [../scripts/scheduling/setup-scheduler.ps1](../scripts/scheduling/setup-scheduler.ps1) - Windows Task Scheduler installer

### Roo Scheduler
- [deployment/DEPLOY-SCHEDULED-ROO.md](deployment/DEPLOY-SCHEDULED-ROO.md) - Deploiement taches planifiees Roo

---

## Framework Multi-Agent

- [framework-multi-agent/TEMPLATE_WORKSPACE.md](framework-multi-agent/TEMPLATE_WORKSPACE.md) - Template workspace coordination

---

## Harness (Roo/Claude)

Documentation sur les harnais d'agents (règles, workflows, mappings).

- [harness/rules-mapping.md](harness/rules-mapping.md) - **Mapping Règles Roo ↔ Claude** (Issue #721 v1.1.0) - Table d'équivalence des règles entre les deux harnais, alignements et gaps

---

## Roo Code

- [roo-code/architecture/](roo-code/architecture/) - Architecture Roo Code
- [roo-code/adr/](roo-code/adr/) - Architecture Decision Records
- [roo-code/contributing/](roo-code/contributing/) - Guides de contribution

---

## Knowledge

- [knowledge/WORKSPACE_KNOWLEDGE.md](knowledge/WORKSPACE_KNOWLEDGE.md) - Base de connaissances (6500+ fichiers)

---

## Archive

### Git History (16 fichiers)

- [archive/git-history/GIT-OPERATIONS-SYNTHESIS-2025-10.md](archive/git-history/GIT-OPERATIONS-SYNTHESIS-2025-10.md) - Synthese Q4 2025 (15 stashs, merges)
- [archive/git-history/GIT-OPERATIONS-SYNTHESIS-2025-Q4-Q1.md](archive/git-history/GIT-OPERATIONS-SYNTHESIS-2025-Q4-Q1.md) - Synthese complete Q4 2025 + Q1 2026 (2094 commits, 40+ conflits)
- [archive/git-history/README.md](archive/git-history/README.md) - Index operations Git
- [archive/git-history/phase2-analysis/STASH_ANALYSIS.md](archive/git-history/phase2-analysis/STASH_ANALYSIS.md) - Analyse stashes phase 2
- [archive/git-history/phase2-analysis/WORKTREE_ANALYSIS.md](archive/git-history/phase2-analysis/WORKTREE_ANALYSIS.md) - Analyse worktrees phase 2
- [archive/git-history/stash-details/STASH-001.md](archive/git-history/stash-details/STASH-001.md) - Stash "fix-encoding"
- [archive/git-history/stash-details/STASH-002.md](archive/git-history/stash-details/STASH-002.md) - Stash "test-indexing"
- [archive/git-history/stash-details/STASH-003.md](archive/git-history/stash-details/STASH-003.md) - Stash "worktree-cleanup"
- [archive/git-history/stash-details/STASH-004.md](archive/git-history/stash-details/STASH-004.md) - Stash "docs-reorg"
- [archive/git-history/stash-details/STASH-005.md](archive/git-history/stash-details/STASH-005.md) - Stash "test-fix-569"
- [archive/git-history/stash-details/STASH-006.md](archive/git-history/stash-details/STASH-006.md) - Stash "consolidation-merge"
- [archive/git-history/stash-details/STASH-007.md](archive/git-history/stash-details/STASH-007.md) - Stash "roosync-fix"
- [archive/git-history/stash-details/STASH-008.md](archive/git-history/stash-details/STASH-008.md) - Stash "cleanup-088"
- [archive/git-history/stash-details/STASH-009.md](archive/git-history/stash-details/STASH-009.md) - Stash "pre-sync"
- [archive/git-history/stash-details/STASH-010.md](archive/git-history/stash-details/STASH-010.md) - Stash "emergency-fix"
- [archive/git-history/detailed-reports/](archive/git-history/detailed-reports/) - Rapports detailles par operation

### Obsolete (7 fichiers)

- [archive/obsolete/roosync-v1-vs-v2-gap-analysis.md](archive/obsolete/roosync-v1-vs-v2-gap-analysis.md) - Gap analysis v1 vs v2
- [archive/obsolete/MCP-TROUBLESHOOTING-ARCHIVE.md](archive/obsolete/MCP-TROUBLESHOOTING-ARCHIVE.md) - Archive depannage MCP
- [archive/obsolete/mcp-usage-2024-12.md](archive/obsolete/mcp-usage-2024-12.md) - Usage MCP decembre 2024
- [archive/obsolete/mcp-usage-2025-01.md](archive/obsolete/mcp-usage-2025-01.md) - Usage MCP janvier 2025
- [archive/obsolete/scheduler-investigation.md](archive/obsolete/scheduler-investigation.md) - Investigation scheduler
- [archive/obsolete/GUIDE-TECHNIQUE-v2.1.md](archive/obsolete/GUIDE-TECHNIQUE-v2.1.md) - Guide technique v2.1 legacy
- [archive/obsolete/QUICKSTART-v2.1.md](archive/obsolete/QUICKSTART-v2.1.md) - Quickstart v2.1 legacy

### Reports (19 fichiers)

- [archive/reports/context-condensation-audit-report-issue-633.md](archive/reports/context-condensation-audit-report-issue-633.md) - Audit condensation contexte
- [archive/reports/session-consolidation-report-2025-10-26.md](archive/reports/session-consolidation-report-2025-10-26.md) - Rapport consolidation session
- [archive/reports/task-analysis-report-2025-10-27.md](archive/reports/task-analysis-report-2025-10-27.md) - Analyse taches
- [archive/reports/workspace-inventory-2025-10-28.md](archive/reports/workspace-inventory-2025-10-28.md) - Inventaire workspace
- [archive/reports/scheduler-audit-2025-10-29.md](archive/reports/scheduler-audit-2025-10-29.md) - Audit scheduler
- [archive/reports/git-history-synthesis-2025-11-02.md](archive/reports/git-history-synthesis-2025-11-02.md) - Synthese historique Git
- [archive/reports/roosync-indexing-diagnostics-2025-11-03.md](archive/reports/roosync-indexing-diagnostics-2025-11-03.md) - Diagnostics indexation RooSync
- [archive/reports/mcp-compatibility-matrix-2025-11-04.md](archive/reports/mcp-compatibility-matrix-2025-11-04.md) - Matrice compatibilite MCP
- [archive/reports/context-condensation-audit-2025-11-05.md](archive/reports/context-condensation-audit-2025-11-05.md) - Audit condensation contexte
- [archive/reports/semantic-search-validation-2025-11-06.md](archive/reports/semantic-search-validation-2025-11-06.md) - Validation recherche semantique
- [archive/reports/roosync-message-flow-analysis-2025-11-07.md](archive/reports/roosync-message-flow-analysis-2025-11-07.md) - Analyse flux messages RooSync
- [archive/reports/tool-usage-patterns-2025-11-08.md](archive/reports/tool-usage-patterns-2025-11-08.md) - Patterns usage outils
- [archive/reports/task-completion-report-2025-11-09.md](archive/reports/task-completion-report-2025-11-09.md) - Rapport completion taches
- [archive/reports/issue-553-phase2-analysis/](archive/reports/issue-553-phase2-analysis/) - Analyse phase 2 issue 553
  - [README.md](archive/reports/issue-553-phase2-analysis/README.md) - Index analyse phase 2
  - [CONSOLIDATION-STATUS.md](archive/reports/issue-553-phase2-analysis/CONSOLIDATION-STATUS.md) - Statut consolidation
  - [FILE-MOVEMENT-LOG.md](archive/reports/issue-553-phase2-analysis/FILE-MOVEMENT-LOG.md) - Log mouvements fichiers
  - [OLD-STRUCTURE.md](archive/reports/issue-553-phase2-analysis/OLD-STRUCTURE.md) - Ancienne structure
  - [NEW-STRUCTURE.md](archive/reports/issue-553-phase2-analysis/NEW-STRUCTURE.md) - Nouvelle structure
  - [BREAKING-CHANGES.md](archive/reports/issue-553-phase2-analysis/BREAKING-CHANGES.md) - Changements cassants

---

## Liens Externes

- [../roo-config/README.md](../roo-config/README.md) - Configuration Roo
- [../mcps/README.md](../mcps/README.md) - Documentation MCPs
- [../CLAUDE.md](../CLAUDE.md) - Guide agents Claude Code

---

**Consolide par:** myia-po-2024
**Date consolidation:** 2026-02-09
**Derniere MAJ:** 2026-03-18 (v5.8 - Indexation complete Archive - 45 fichiers documentes)
**Precedent:** v5.7 (Ajout synthese git Q4-Q1 + docs/harness/ + Fix 11 liens casses)
