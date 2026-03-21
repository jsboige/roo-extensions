# INDEX CENTRALISE DE LA DOCUMENTATION

**Derniere mise a jour:** 2026-03-21
**Version:** 5.13 (Fix 39 broken archive links + add 24 missing docs: 14 roosync, 4 guides, 6 roo-code)

---

## Structure docs/ (18 repertoires)

```
docs/
├── analysis/         # Analyses de patterns (MCP, etc.)
├── architecture/     # Architecture systeme, designs, analyses
├── archive/          # Contenu historique/obsolete (auto-archive)
├── audit/            # Audits techniques et investigations
├── deployment/       # Deploiement, hardware
├── dev/              # Debugging, encoding, fixes, tests, refactoring
├── evaluation/       # Evaluations modeles (LLM)
├── framework-multi-agent/  # Templates et framework coordination multi-agent
├── guides/           # Guides utilisateur, installation, depannage
├── harness/          # Documentation harnais Roo/Claude (rules-mapping, etc.)
├── knowledge/        # Base de connaissances
├── mcp/              # Documentation MCP roo-state-manager
├── mcps/             # Index MCPs (internal + external)
├── roo-code/         # Documentation Roo Code, PRs, ADR
├── roosync/          # Protocoles RooSync v2.3, guides agents
├── scheduler/        # Scheduler Roo & Claude Code
├── services/         # Documentation services techniques
├── sk-agent/         # sk-agent: inventaire agents, rapports exploitation
├── suivi/            # Suivi projet actif, monitoring
├── testing/          # Rapports tests et audits
├── INDEX.md          # Ce fichier
└── README.md         # Vue d'ensemble
```

---

## Fichiers Racine (docs/)

Documentation importante à la racine de docs/ (hors sous-dossiers).

### Audits & Analyses

- [coverage-audit-492.md](coverage-audit-492.md) - **Audit de Couverture de Tests** (Issue #492) - Analyse couverture roo-state-manager MCP (25.33% vs 80% objectif)
- [archive/harness-reports/](archive/harness-reports/) - **Rapports d'Analyse Croisée des Harnais** (2026-03-13 à 15) - Archivés 2026-03-20 : 4 rapports meta-analyste (cross-analysis-harnesses-2026-03-13.md, harness-cross-analysis-report*.md)

### Référence Technique

- [mcp-configuration.md](mcp-configuration.md) - **Configuration MCP par Machine** - Référence complète (Issue #688) : configs séparées Claude Code vs Roo, win-cli fork local 0.2.0, tableau de vérification
- [scheduler-workflow.md](scheduler-workflow.md) - **Unified Scheduler Workflows** - Référence technique (Issue #689) : 3 types workflows (Executor/Coordinator/Meta-Analyst), modules PowerShell partagés, protocole INTERCOM
- [git-notification-maintenance.md](git-notification-maintenance.md) - **Git Notification & Maintenance Workflow** (Issue #741) - Workflow Git et notifications pour maintenance cross-machine
- [sk-agent-phase5-validation-report.md](sk-agent-phase5-validation-report.md) - **sk-agent Phase 5 Validation Report** (myia-ai-01, 2026-03-20, Issue #645) - Rapport validation sk-agent configuration complète

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

### Protocoles et Processus
- [AGENTS_ARCHITECTURE.md](roosync/AGENTS_ARCHITECTURE.md) - Architecture agents multi-machine
- [DASHBOARD-HIERARCHIQUE-v1.0.md](roosync/DASHBOARD-HIERARCHIQUE-v1.0.md) - Dashboards hierarchiques (4 types)
- [DASHBOARD_AUTO_REFRESH.md](roosync/DASHBOARD_AUTO_REFRESH.md) - Auto-refresh dashboards
- [ESCALATION_MECHANISM.md](roosync/ESCALATION_MECHANISM.md) - Mecanisme d'escalade
- [FEEDBACK_PROCESS.md](roosync/FEEDBACK_PROCESS.md) - Processus feedback/friction
- [HEARTBEAT_REGISTRATION_PROCEDURE.md](roosync/HEARTBEAT_REGISTRATION_PROCEDURE.md) - Procedure enregistrement heartbeat
- [INTERCOM_PROTOCOL.md](roosync/INTERCOM_PROTOCOL.md) - Protocole INTERCOM (local Roo-Claude)
- [META_ANALYSIS.md](roosync/META_ANALYSIS.md) - Protocole meta-analyse
- [PR_REVIEW_POLICY.md](roosync/PR_REVIEW_POLICY.md) - Politique review PR
- [PROTOCOLE_SDDD.md](roosync/PROTOCOLE_SDDD.md) - Protocole SDDD
- [QUALITY-PIPELINE.md](roosync/QUALITY-PIPELINE.md) - Pipeline qualite
- [SKEPTICISM_PROTOCOL.md](roosync/SKEPTICISM_PROTOCOL.md) - Protocole scepticisme raisonnable

### Reference Technique
- [ERROR_CODES_REFERENCE.md](roosync/ERROR_CODES_REFERENCE.md) - Codes d'erreur
- [SUBMODULE_WORKFLOW.md](roosync/SUBMODULE_WORKFLOW.md) - Workflow submodules
- [ROOSYNC_DASHBOARDS.md](roosync/ROOSYNC_DASHBOARDS.md) - **Shared Markdown Dashboards** - Cross-machine collaboration via GDrive (#675)
- [worktree-best-practices.md](roosync/worktree-best-practices.md) - **Worktree Best Practices** - Infrastructure, decision tree, adoption guide (#627)
- [MCP_AVAILABILITY.md](roosync/MCP_AVAILABILITY.md) - Disponibilite et inventaire MCPs
- [BASELINE_GHOST_MCPS.md](roosync/BASELINE_GHOST_MCPS.md) - Baseline et MCPs fantomes
- [CROSS_WORKSPACE_SETUP.md](roosync/CROSS_WORKSPACE_SETUP.md) - Configuration cross-workspace

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
- [BASH_FALLBACK.md](guides/BASH_FALLBACK.md) - Guide fallback Bash (si outil natif echoue)
- [CODEBASE_SEARCH_GUIDE.md](guides/CODEBASE_SEARCH_GUIDE.md) - Guide recherche semantique codebase
- [GITHUB_CLI.md](guides/GITHUB_CLI.md) - Guide GitHub CLI (gh)
- [jupyter-papermill-execution.md](guides/jupyter-papermill-execution.md) - Execution Jupyter via Papermill

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

## sk-agent

- [AGENT_INVENTORY.md](sk-agent/AGENT_INVENTORY.md) - **Inventaire des agents sk-agent** - Agents disponibles, configs, modeles LLM
- [EXPLOITATION_REPORT_2026-03-01.md](sk-agent/EXPLOITATION_REPORT_2026-03-01.md) - Rapport exploitation (2026-03-01)
- [EXPLOITATION_REPORT_485.md](sk-agent/EXPLOITATION_REPORT_485.md) - Rapport exploitation #485
- [EXPLOITATION_REPORT_PHASE1-3.md](sk-agent/EXPLOITATION_REPORT_PHASE1-3.md) - Rapport exploitation Phases 1-3
- [PHASE_4_IMPLEMENTATION_REPORT.md](sk-agent/PHASE_4_IMPLEMENTATION_REPORT.md) - Rapport implementation Phase 4
- [agents-configuration-template.yaml](sk-agent/agents-configuration-template.yaml) - Template configuration agents

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

### Architecture et Design
- [roo-code/architecture/](roo-code/architecture/) - Architecture Roo Code
- [roo-code/adr/](roo-code/adr/) - Architecture Decision Records
- [roo-code/contributing/](roo-code/contributing/) - Guides de contribution
- [INDEXING_ARCHITECTURE.md](roo-code/INDEXING_ARCHITECTURE.md) - Architecture indexation taches
- [PARSING_XML_ASSISTANT_MESSAGES.md](roo-code/PARSING_XML_ASSISTANT_MESSAGES.md) - Parsing messages XML assistant

### Scheduler Roo
- [SCHEDULER_SYSTEM.md](roo-code/SCHEDULER_SYSTEM.md) - Systeme scheduler (10 modes, 5 familles)
- [SCHEDULER_DENSIFICATION.md](roo-code/SCHEDULER_DENSIFICATION.md) - Densification scheduler (sweet spot escalade)
- [SCHEDULED_COORDINATOR.md](roo-code/SCHEDULED_COORDINATOR.md) - Coordinateur schedule
- [roo-scheduler-analysis.md](roo-code/roo-scheduler-analysis.md) - Analyse scheduler Roo
- [roo-scheduler-direct-config-guide.md](roo-code/roo-scheduler-direct-config-guide.md) - Guide config directe scheduler
- [roo-scheduler-installation-guide.md](roo-code/roo-scheduler-installation-guide.md) - Guide installation scheduler

---

## Knowledge

- [knowledge/WORKSPACE_KNOWLEDGE.md](knowledge/WORKSPACE_KNOWLEDGE.md) - Base de connaissances (6500+ fichiers)

---

## Archive

### Harness Reports (4 fichiers)

- [archive/harness-reports/](archive/harness-reports/) - Rapports d'analyse croisee des harnais (2026-03-13 a 15)

### Git History (4 fichiers actifs + sous-repertoires)

- [archive/git-history/GIT-OPERATIONS-SYNTHESIS-2025-10.md](archive/git-history/GIT-OPERATIONS-SYNTHESIS-2025-10.md) - Synthese Q4 2025 (15 stashs, merges)
- [archive/git-history/GIT-OPERATIONS-SYNTHESIS-2025-Q4-Q1.md](archive/git-history/GIT-OPERATIONS-SYNTHESIS-2025-Q4-Q1.md) - Synthese complete Q4 2025 + Q1 2026 (2094 commits, 40+ conflits)
- [archive/git-history/detailed-reports/](archive/git-history/detailed-reports/) - Rapports detailles (reconciliation, merge, stash investigation)
- [archive/git-history/phase2-analysis/](archive/git-history/phase2-analysis/) - Analyse phase 2 (checksums, patches, sync diffs)
- [archive/git-history/stash-details/](archive/git-history/stash-details/) - Details stashs (analyses, patches)

### Obsolete (7 fichiers)

- [archive/obsolete/roosync-v1-vs-v2-gap-analysis.md](archive/obsolete/roosync-v1-vs-v2-gap-analysis.md) - Gap analysis v1 vs v2
- [archive/obsolete/DEPLOY-ALWAYSALLOW.md](archive/obsolete/DEPLOY-ALWAYSALLOW.md) - Deploiement alwaysAllow (superseded)
- [archive/obsolete/ENVIRONMENT-SETUP-SYNTHESIS.md](archive/obsolete/ENVIRONMENT-SETUP-SYNTHESIS.md) - Synthese setup environnement
- [archive/obsolete/003-backward-compatibility-strategy.md](archive/obsolete/003-backward-compatibility-strategy.md) - Strategie compatibilite ascendante
- [archive/obsolete/roo-state-manager-indexing-checkpoints.md](archive/obsolete/roo-state-manager-indexing-checkpoints.md) - Checkpoints indexation
- [archive/obsolete/roosync-temporal-messages-architecture.md](archive/obsolete/roosync-temporal-messages-architecture.md) - Architecture messages temporels
- [archive/obsolete/README.md](archive/obsolete/README.md) - Index fichiers obsoletes

### Reports (10 fichiers actifs)

- [archive/reports/diagnostic-systeme-2026-02-02.md](archive/reports/diagnostic-systeme-2026-02-02.md) - Diagnostic systeme
- [archive/reports/mcp-analysis-report.md](archive/reports/mcp-analysis-report.md) - Rapport analyse MCP
- [archive/reports/project-67-myia-po-2026-report.md](archive/reports/project-67-myia-po-2026-report.md) - Rapport Project #67 po-2026
- [archive/reports/scheduler-audit-myia-po-2023.md](archive/reports/scheduler-audit-myia-po-2023.md) - Audit scheduler po-2023
- [archive/reports/scheduler-audit-myia-po-2026.md](archive/reports/scheduler-audit-myia-po-2026.md) - Audit scheduler po-2026
- [archive/reports/scheduler-claude-code-design.md](archive/reports/scheduler-claude-code-design.md) - Design scheduler Claude Code
- [archive/reports/scheduler-workflow-adjustments.md](archive/reports/scheduler-workflow-adjustments.md) - Ajustements workflow scheduler
- [archive/reports/task-440-exploration-architecture.md](archive/reports/task-440-exploration-architecture.md) - Exploration architecture tache 440
- [archive/reports/2026-03-03-issue553-phase2/](archive/reports/2026-03-03-issue553-phase2/) - Analyse phase 2 issue 553 (12 fichiers)

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
