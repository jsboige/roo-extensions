# INDEX CENTRALISE DE LA DOCUMENTATION

**Derniere mise a jour:** 2026-04-30
**Version:** 6.0 (Phase 2 consolidation #1844 Task 5: index exhaustif 385 fichiers)
**Stats:** 385 fichiers | 240 actifs | 145 archives

---

## Structure docs/ (28 repertoires)

```
docs/
├── analysis/              # Analyses de patterns (MCP, Reddit)
├── architecture/          # Architecture systeme, designs, ADR
│   ├── archive/           #   Syntheses, planning historiques
│   │   └── planning/      #     Plans consolidation, refactoring
│   │       └── roosync-refactor/  # Plans RooSync v2.3
│   ├── investigations/    #   Investigations specifiques
│   └── proposals/         #   Propositions d'implementation
├── archive/               # Contenu historique/obsolete
│   ├── harness-reports/   #   Rapports analyse croisee harnais
│   └── reports/           #   Rapports anciens (diagnostics, audits)
│       └── 2026-03-03-issue553-phase2/  # Dossier issue 553
├── audit/                 # Audits techniques et remediation
│   └── archive/           #   Audits archives
├── deployment/            # Deploiement, hardware GPU
├── dev/                   # Debugging, encoding, fixes, tests, refactoring
│   ├── archive-configuration/  # Configs MCP archivees
│   ├── debugging/         #   Analyse bugs
│   ├── encoding/          #   Documentation encodage UTF-8
│   │   └── archive/       #     Docs encodage archivees
│   ├── fixes/             #   Rapports de corrections
│   ├── indexation/        #   Fix detectWorkspaceForTask
│   ├── maintenance/       #   Guide hooks git
│   ├── refactoring/       #   Rapports refactoring
│   │   └── archive/       #     Archives refactoring
│   └── testing/           #   Strategies et plans de test
│       └── archive/       #     Archives testing
│           └── reports/   #       Rapports de tests archives
├── evaluation/            # Evaluations modeles (LLM)
├── framework-multi-agent/ # Templates coordination
├── github/                # Processus GitHub
├── guides/                # Guides utilisateur, installation
│   └── user-guide/        #   Guide utilisateur Phase 3D
├── harness/               # Documentation harnais Roo/Claude
│   ├── coordinator-specific/  # Docs coordinateur ai-01
│   ├── investigations/    #   Investigations harnais
│   ├── machine-specific/  #   Contraintes par machine
│   ├── reference/         #   Reference on-demand (33 docs)
│   ├── reports/           #   Rapports harnais
│   └── research/          #   Recherche outils
├── history/               # Historique worker-reports
│   └── worker-reports/    #   Rapports workers par machine
│       └── myia-po-2023/  #     Rapports po-2023
├── knowledge/             # Base de connaissances
├── mcp/                   # Documentation MCP roo-state-manager
│   ├── archive/           #   Fix reports historiques
│   └── roo-state-manager/ #   Docs RSM
│       ├── features/      #     Features design
│       └── technical-audit/  #  Audits techniques
├── mcps/                  # Index MCPs
├── meta-analysis/         # Meta-analyses par machine
│   ├── myia-po-2023/      #   (vide)
│   ├── myia-po-2024/      #   (vide)
│   ├── myia-po-2025/      #   (vide)
│   ├── myia-po-2026/      #   Rapports actifs
│   │   └── archives/2026-03/  # Archives mars 2026
│   └── myia-web1/         #   (vide)
├── nanoclaw/              # NanoClaw bridge
├── ops/                   # Operations, Docker/WSL
├── roo-code/              # Documentation Roo Code, PRs, ADR
│   ├── adr/               #   Architecture Decision Records
│   ├── architecture/      #   Architecture condensation
│   └── contributing/      #   Guides contribution
├── roosync/               # Protocoles RooSync v2.3
│   ├── archive/           #   Archives integration
│   │   └── integration/   #     Phase 8 integration (22 docs)
│   └── guides/            #   Checklists, glossaire, onboarding
├── scheduler/             # Scheduler Roo & Claude Code
├── scheduling/            # Guide deploiement scheduler
├── services/              # Documentation services techniques
├── sk-agent/              # sk-agent: inventaire, rapports
├── suivi/                 # Suivi projet actif
│   ├── archive/           #   Archives suivi
│   │   ├── coordination/  #     Messages inter-machine
│   │   ├── issues/        #     Issues archives
│   │   ├── reports/       #     Rapports archives
│   │   └── sessions/      #     Sessions archives
│   ├── monitoring/        #   Systeme monitoring
│   │   └── scheduled-tasks/  # Taches planifiees
│   ├── project/           #   Changelog, statut
│   └── RooSync/           #   Suivi RooSync actif
├── testing/               # Rapports tests et audits
└── validation/            # Validation indexation semantique
```

---

## 1. Harness & Configuration (56 fichiers)

### docs/ (racine) — 6 fichiers

| Fichier | Description | Statut |
|---------|-------------|--------|
| `INDEX.md` | Ce fichier — index centralise | active |
| `README.md` | Hub documentation, pointe vers INDEX.md | active |
| `mcp-configuration.md` | Configuration MCP par machine (issue #688) | active |
| `mcp-audit-report-1401.md` | Audit outils MCP et corrections (issue #1401) | active |
| `git-notification-maintenance.md` | Workflow Git et notifications (issue #741) | active |
| `scheduler-workflow.md` | Workflows scheduler unifies (issue #689) | active |

### docs/harness/ — 1 fichier

| Fichier | Description | Statut |
|---------|-------------|--------|
| `README.md` | Hub documentation harnais, guide consultation on-demand | active |

### docs/harness/coordinator-specific/ — 4 fichiers

| Fichier | Description | Statut |
|---------|-------------|--------|
| `meta-analyst-detailed.md` | Workflow meta-analyste detaille (v1.3) | active |
| `pr-review-policy.md` | Politique review PR multi-agents (issue #461) | active |
| `scheduled-coordinator.md` | Protocole coordinateur schedule ai-01 (issue #540) | active |
| `skeptical-posture.md` | Protocole posture ferme coordinateur | active |

### docs/harness/reference/ — 33 fichiers

| Fichier | Description | Statut |
|---------|-------------|--------|
| `INDEX.md` | Index reference on-demand | active |
| `agent-claim-discipline-detailed.md` | Discipline claim agents (issues #1605/#1666) | active |
| `bash-fallback.md` | Regle bash-fallback (issue #488) | active |
| `condensation-thresholds.md` | Seuils condensation contexte (issues #502/#555/#736) | active |
| `conversation-browser-detailed.md` | Reference conversation_browser (issue #1063) | active |
| `delegation.md` | Regles delegation sub-agents (issue #566) | active |
| `escalation-protocol.md` | Protocole escalation Claude Code (issue #842) | active |
| `feedback-process.md` | Processus feedback et amelioration | active |
| `friction-protocol.md` | Protocole friction (issue #712) | active |
| `friction-protocol-detailed.md` | Friction detaille (issue #1033) | active |
| `github-checklists.md` | Regles checklists GitHub (issue #516) | active |
| `github-cli.md` | Regles GitHub CLI, migration MCP vers gh | active |
| `github-reviewer-bot-feasibility.md` | Etude faisabilite bot review (issue #1184) | active |
| `harness-reduction-plan.md` | Plan reduction empreinte harnais (issue #1026) | active |
| `incident-history.md` | Journal incidents (issue #713) | active |
| `intercom-v3-mentions.md` | Mentions structurees et cross-post v3.2 (issue #1363) | active |
| `issue-closure-detailed.md` | Fermeture issues detaille (incidents #829/#850/#855) | active |
| `mcp-discoverability.md` | Test decouvrabilite MCP (issue #486) | active |
| `mcp-proxy-architecture.md` | Architecture proxy MCP (issue #1354) | active |
| `mcp-proxy-host.md` | Exposition HTTP streamable proxy (issue #1354) | active |
| `meta-analysis.md` | Protocole meta-analyse architecture 3x2 (issues #551/#981) | active |
| `pr-trivial-merge-policy.md` | Politique merge trivial (issue #1582) | active |
| `roo-schedulable-criteria.md` | Criteres label roo-schedulable (issue #605) | active |
| `rules-footprint.md` | Snapshot empreinte rules (issue #1606, 2026-04-24) | active |
| `scheduler-densification.md` | Regle densification scheduler | active |
| `scheduler-system.md` | Reference technique scheduler Roo | active |
| `sddd-conversational-grounding.md` | Protocole SDDD triple grounding v2.2 (issue #984) | active |
| `sddd-grounding-detailed.md` | SDDD multi-pass et filtres (issue #1063) | active |
| `stub-detection.md` | Protocol detection stubs (crise #767-#786) | active |
| `test-success-rates.md` | Taux succes tests (issues #720/#827) | active |
| `tool-availability-detailed.md` | Inventaire outils detaille | active |
| `worktree-cleanup-protocol.md` | Protocol cleanup worktrees (issue #856) | active |
| `worktree-cleanup.md` | Protocol cleanup worktrees v2.0 (issues #856/#895) | active |
| `wsl-docker-cascade-protocol.md` | Protocol cascade kill WSL/Docker (issue #1379) | active |

### docs/harness/investigations/ — 1 fichier

| Fichier | Description | Statut |
|---------|-------------|--------|
| `ISSUE-1264-reboot-investigation.md` | Investigation reboot inattendu ai-01/po-2023 | active |

### docs/harness/machine-specific/ — 1 fichier

| Fichier | Description | Statut |
|---------|-------------|--------|
| `myia-web1-constraints.md` | Contraintes web1 (16GB RAM, Win Server 2019) | active |

### docs/harness/reports/ — 1 fichier

| Fichier | Description | Statut |
|---------|-------------|--------|
| `cross-harness-analysis-2026-04-05.md` | Analyse croisee harnais etape 2 | active |

### docs/harness/research/ — 1 fichier

| Fichier | Description | Statut |
|---------|-------------|--------|
| `native-pr-review-tools.md` | Recherche outils review PR natifs (issue #1522) | active |

### docs/deployment/ — 4 fichiers

| Fichier | Description | Statut |
|---------|-------------|--------|
| `DEPLOY-SCHEDULED-ROO.md` | Guide deploiement 10 modes Roo + scheduler | active |
| `GPU_SPECS_MULTI_MACHINE.md` | Specs GPU multi-machines (v1.1) | active |
| `scheduler-issues-fixes.md` | Fixes scheduler (2026-02-09) | active |
| `scheduler-modes-deployment-guide.md` | Guide deploiement modes scheduler (issue #487) | active |

### docs/roo-code/ — 15 fichiers + sous-dossiers

| Fichier | Description | Statut |
|---------|-------------|--------|
| `INDEXING_ARCHITECTURE.md` | Architecture indexation semantique (issue #452) | active |
| `PARSING_XML_ASSISTANT_MESSAGES.md` | Notes parsing XML assistant | active |
| `PLAN-IMPLEMENTATION-MIGRATION-UI.md` | Plan migration UI taches orphelines (Sept 2025) | archived |
| `PROPOSITION-SOLUTION-UI.md` | Solution interface taches orphelines (Sept 2025) | archived |
| `SCHEDULED_COORDINATOR.md` | Protocol coordinateur (doublon harness/) | active |
| `SCHEDULER_DENSIFICATION.md` | Regle densification (doublon harness/) | active |
| `SCHEDULER_SYSTEM.md` | Reference scheduler (doublon harness/) | active |
| `message-editor-fix-summary.md` | Resume fix autosave draft PR | active |
| `message-editor-pr-description.md` | Description PR message editor | active |
| `message-editor-pr-guide.md` | Guide soumission PR message editor | active |
| `race-condition-manual-verification.md` | Verification manuelle race condition | active |
| `roo-scheduler-analysis.md` | Analyse extension kyle-apex/roo-scheduler | active |
| `roo-scheduler-direct-config-guide.md` | Guide config directe scheduler | active |
| `roo-scheduler-installation-guide.md` | Guide installation scheduler | active |
| `send-message-flow-analysis.md` | Analyse flux envoi messages | active |

**adr/** (3 fichiers) : `001-registry-pattern`, `002-singleton-pattern`, `004-template-method` — tous actifs

**architecture/** (1 fichier) : `context-condensation-system.md` — actif

**contributing/** (1 fichier) : `add-condensation-provider.md` — actif

---

## 2. RooSync (53 fichiers)

### docs/roosync/ — 24 fichiers actifs

| Fichier | Description | Statut |
|---------|-------------|--------|
| `AGENTS_ARCHITECTURE.md` | Architecture agents, skills, commandes | active |
| `ARCHITECTURE_ROOSYNC.md` | Architecture technique RooSync v2.3.0 | active |
| `BASELINE_GHOST_MCPS.md` | Investigation MCPs fantomes (issue #460) | active |
| `CROSS_WORKSPACE_SETUP.md` | Guide setup cross-workspace (issue #526) | active |
| `DASHBOARD_AUTO_REFRESH.md` | Automatisation refresh dashboards (issue #460) | active |
| `ERROR_CODES_REFERENCE.md` | Reference codes erreur v1.0 | active |
| `ESCALATION_MECHANISM.md` | Mecanisme escalation Roo (issues #462/#464) | active |
| `FEEDBACK_PROCESS.md` | Processus feedback continu | active |
| `GESTION_MULTI_AGENT.md` | Guide gestion multi-agent v1.0 | active |
| `GUIDE-TECHNIQUE-v2.3.md` | Guide technique unifie v2.3.1 (production) | active |
| `HARNESS-CORRESPONDENCE.md` | Mapping harnais Roo/Claude (issue #874) | active |
| `HEARTBEAT_REGISTRATION_PROCEDURE.md` | Procedure enregistrement heartbeat (issue #460) | active |
| `INTERCOM_PROTOCOL.md` | Protocol communication inter-agents v1.1 | active |
| `MCP_AVAILABILITY.md` | Inventaire outils et STOP & REPAIR v1.2 | active |
| `META_ANALYSIS.md` | Protocol meta-analyse architecture 3x2 | active |
| `PROTOCOLE_SDDD.md` | Protocol SDDD v2.7 | active |
| `PR_REVIEW_POLICY.md` | Politique review PR multi-agents (issue #461) | active |
| `QUALITY-PIPELINE.md` | Pipeline qualite automatique (issue #544) | active |
| `QUICKSTART.md` | Guide demarrage rapide (30 lignes) | active |
| `README.md` | Entree principale RooSync v2.3 | active |
| `ROOSYNC_DASHBOARDS.md` | Documentation dashboards (issue #675) | active |
| `SKEPTICISM_PROTOCOL.md` | Protocol scepticisme raisonnable | active |
| `SUBMODULE_WORKFLOW.md` | Guide workflow submodules | active |
| `worktree-best-practices.md` | Bonnes pratiques worktrees (issue #627) | active |

### docs/roosync/guides/ — 5 fichiers

| Fichier | Description | Statut |
|---------|-------------|--------|
| `CHECKLISTS.md` | Checklists operationnelles | active |
| `GLOSSAIRE.md` | Glossaire RooSync v1.1 | active |
| `ONBOARDING_AGENT.md` | Guide onboarding nouvel agent | active |
| `README.md` | Index guides operationnels | active |
| `TROUBLESHOOTING.md` | Guide depannage RooSync | active |

### docs/roosync/archive/ — 2 fichiers + integration/ (23 fichiers)

Tous archives. Integration Phase 8 (Oct-Dec 2025) : 22 docs dans `archive/integration/` + `ROOSYNC-INTEGRATION-CONSOLIDATED.md`.

---

## 3. MCPs & Services (27 fichiers)

### docs/mcp/ — 1 fichier

| Fichier | Description | Statut |
|---------|-------------|--------|
| `TIMEOUT_AUDIT.md` | Audit timeout MCP po-2023 (issue #853) | active |

### docs/mcp/roo-state-manager/ — 6 fichiers

| Fichier | Description | Statut |
|---------|-------------|--------|
| `README.md` | Hub documentation RSM | active |
| `project-plan.md` | Plan projet recherche semantique | active |
| `features/granular-indexing-strategy.md` | Strategie indexation granulaire | active |
| `features/optimized-task-navigation.md` | Navigation optimisee taches | active |
| `features/semantic-task-search.md` | Recherche semantique taches | active |
| `features/task-tree-navigation.md` | Navigation arbre taches (Juillet 2025) | active |

**technical-audit/** (3 fichiers) : `e2e-qdrant-connection-issue`, `e2e-testing-architecture`, `jest-module-resolution` — tous actifs

**archive/** (5 fichiers) : Fix reports Oct 2025 (jupyter, quickfiles, MODULE_NOT_FOUND, machineId) — tous archives

### docs/mcps/ — 2 fichiers

| Fichier | Description | Statut |
|---------|-------------|--------|
| `INDEX.md` | Index serveurs MCP (v1.0, Mars 2026) | active |
| `mcp-timeouts-recommended.md` | Timeouts MCP recommandes (issue #853) | active |

### docs/services/ — 6 fichiers

| Fichier | Description | Statut |
|---------|-------------|--------|
| `README.md` | Index documentation services | active |
| `ConfigSharingService.md` | Doc technique (921 lignes) | active |
| `GranularDiffDetector.md` | Doc technique (952 lignes) | active |
| `HierarchyReconstructionEngine.md` | Doc technique (1281 lignes) | active |
| `NarrativeContextBuilderService.md` | Doc technique (1360 lignes) | active |
| `sk-agent-deployment.md` | Guide deploiement sk-agent avec OWUI | active |

### docs/sk-agent/ — 7 fichiers

| Fichier | Description | Statut |
|---------|-------------|--------|
| `AGENT_INVENTORY.md` | Inventaire complet agents (issue #645) | active |
| `EXPLOITATION_REPORT_2026-03-01.md` | Rapport exploitation Mars 2026 (issue #485) | active |
| `EXPLOITATION_REPORT_485.md` | Rapport complet phases 1-4 (issue #485) | active |
| `EXPLOITATION_REPORT_PHASE1-3.md` | Rapport phases 1-3 (issue #485) | active |
| `PHASE_4_IMPLEMENTATION_REPORT.md` | Rapport implementation Phase 4 (issue #485) | active |
| `VALIDATION_SUMMARY_#645.md` | Resume validation Phase 5 (issue #645, tout OK) | active |
| `validation-report-2026-03-19.md` | Rapport validation (issue #645) | active |

---

## 4. Scheduling & Automation (9 fichiers)

### docs/scheduler/ — 4 fichiers

| Fichier | Description | Statut |
|---------|-------------|--------|
| `README.md` | Hub documentation scheduler | active |
| `copilot-roostate-v3-plan.md` | Plan integration Copilot + RSM v3 | active |
| `issue-copilot-v3-connectors.md` | Design connecteurs Copilot v3 | active |
| `scheduler-pilot-test-plan.md` | Plan test pilote scheduler (issue #487) | active |

### docs/scheduling/ — 1 fichier

| Fichier | Description | Statut |
|---------|-------------|--------|
| `DEPLOYMENT_GUIDE.md` | Guide deploiement scheduler Claude Code | active |

### docs/suivi/monitoring/ — 3 fichiers + scheduled-tasks/ (2 fichiers)

| Fichier | Description | Statut |
|---------|-------------|--------|
| `daily-monitoring-implementation-report.md` | Rapport implementation monitoring | active |
| `daily-monitoring-system.md` | Architecture systeme monitoring | active |
| `mcp-debug-logging-system.md` | Systeme logging MCP avec Winston | active |
| `scheduled-tasks/README.md` | Vue d'ensemble taches planifiees | active |
| `scheduled-tasks/settings_sync_procedure.md` | Procedure sync settings | active |

---

## 5. Analysis & Audit (46 fichiers)

### docs/analysis/ — 2 fichiers

| Fichier | Description | Statut |
|---------|-------------|--------|
| `mcp-usage-patterns-2026-02.md` | Analyse patterns utilisation MCP (issue #545) | active |
| `reddit-3-agent-vs-roosync-cluster.md` | Comparaison Reddit 3-agent vs RooSync (issue #1369) | active |

### docs/audit/ — 6 fichiers + archive/ (3 fichiers)

| Fichier | Description | Statut |
|---------|-------------|--------|
| `REMEDIATION_STEPS_572.md` | Etapes remediation issue #572 | active |
| `issue-603-baseline-2026-03-29.md` | Baseline technique issue #603 | active |
| `issue-603-lot-b-candidates-2026-03-29.md` | Candidats simplification Lot B | active |
| `issue-603-lot-b-legacy-mapping.md` | Matrice mapping legacy (Avril 2026) | active |
| `issue-603-tool-inventory-2026-03-29.md` | Inventaire outils issue #603 | active |
| `protected-path-migration-2026-04-07.md` | Migration chemins proteges | active |

**archive/** (3 fichiers) : `INVESTIGATION_SUMMARY_572`, `README`, `VSCODE_LOGS_AUDIT_2026-03-06` — archives

### docs/investigation/ — 3 fichiers

| Fichier | Description | Statut |
|---------|-------------|--------|
| `claw-ecosystem-comparison.md` | Analyse comparative ecosysteme Claw (issue #1073) | active |
| `openclaw-containerized-deployment-ai01.md` | Investigation deploiement containerise (issue #921) | active |
| `unified-model-router.md` | Analyse comparative routeur modeles (issue #1730) | active |

### docs/meta-analysis/ — Rapports po-2026 (4 actifs + 13 archives)

Actifs : `README`, `rapport-2026-04-22`, `report-2026-04-21`, `report-2026-04-22`

Archives (2026-03/) : `INDEX`, `META-ANALYSIS-SYNTHESIS`, `harnais-analysis`, 6 rapports `roo-analysis-*`, `sessions-claude-analysis`, `traces-roo-analysis`

Repertoires vides (.gitkeep) : `myia-po-2023/`, `myia-po-2024/`, `myia-po-2025/`, `myia-web1/`

### docs/testing/ — 2 fichiers

| Fichier | Description | Statut |
|---------|-------------|--------|
| `issue-564-phase1-audit-report.md` | Rapport audit Phase 1 (issue #564) | active |
| `issue-564-phase1-inventory.md` | Inventaire et couverture tests (issue #564) | active |

### docs/validation/ — 1 fichier

| Fichier | Description | Statut |
|---------|-------------|--------|
| `semantic-search-validation-myia-ai-01.md` | Validation indexation semantique ai-01 (issue #655) | active |

---

## 6. Guides & Reference (68 fichiers)

### docs/guides/ — 17 fichiers + user-guide/ (3 fichiers)

| Fichier | Description | Statut |
|---------|-------------|--------|
| `BASH_FALLBACK.md` | Regle bash-fallback (issue #488) | active |
| `CODEBASE_SEARCH_GUIDE.md` | Guide recherche semantique codebase | active |
| `GITHUB_CLI.md` | Regles GitHub CLI | active |
| `MCP-TROUBLESHOOTING-UNIFIED.md` | Guide depannage MCP unifie v2.0 | active |
| `MCPs-INSTALLATION-GUIDE.md` | Guide installation MCPs v2.0 | active |
| `README.md` | Index documentation synthese | active |
| `TROUBLESHOOTING-GUIDE.md` | Guide depannage general v1.1 | active |
| `consolidated-task-management-guide.md` | Guide gestion taches Roo (Aout 2025) | active |
| `guide-complet-modes-roo.md` | Guide complet modes Roo | active |
| `guide-exploration-prompts-natifs.md` | Guide exploration prompts natifs | active |
| `guide-synchronisation-submodules.md` | Guide synchronisation submodules | active |
| `guide-utilisation-mcp-jupyter.md` | Guide MCP Jupyter | active |
| `guide-utilisation-mcps.md` | Guide utilisation MCPs dans modes | active |
| `guide-utilisation-profils-modes.md` | Guide profils modes | active |
| `jupyter-papermill-execution.md` | Guide execution Jupyter Papermill (issue #600) | active |
| `procedures-maintenance.md` | Procedures maintenance depot | active |
| `vscode-extension-debug-powershell-configuration.md` | Config debug VS Code PowerShell | active |

**user-guide/** : `QUICK-START.md`, `README.md`, `TROUBLESHOOTING.md` — tous actifs

### docs/dev/encoding/ — 4 actifs + 9 archives

Actifs : `README.md`, `maintenance-procedures.md`, `quick-start-encoding.md`, `troubleshooting-guide.md`

Archives : documentation-monitoring, profiles-powershell, technique-encodingmanager, variables-environnement, vscode-utf8, guide-rollback-phase1, matrice-tracabilite, roadmap-evolution, spec-roosync-integration

### docs/dev/testing/ — 3 actifs + 10 archives + 5 rapports archives

Actifs : `TEST_STRATEGY.md` (issue #380), `roosync-e2e-test-plan.md`, `strategies-de-test.md`

---

## 7. Architecture (30 fichiers)

### docs/architecture/ — 14 fichiers actifs

| Fichier | Description | Statut |
|---------|-------------|--------|
| `ARCHITECTURE_2_NIVEAUX.md` | Architecture SDDD 2 niveaux (Jan 2026) | active |
| `DATA_STORAGE_POLICY.md` | Politique stockage : code Git, donnees GDrive | active |
| `ROO_TASK_FORENSICS_2026-02-08.md` | Forensics taches Roo rationing LLM (issue #424) | active |
| `message-to-skeleton-transformer.md` | Architecture transformer Phase 2 | active |
| `repository-map.md` | Cartographie structure depot | active |
| `roo-state-manager-architecture.md` | Architecture detaillee RSM | active |
| `roo-state-manager-parsing-refactoring.md` | Analyse refactoring parsing (SUSPENDED) | active |
| `roosync-real-diff-detection-design.md` | Design detection differences v2.0 | active |
| `scheduler-claude-code-design.md` | Architecture scheduler Claude Code (issue #487) | active |
| `scheduler-optimization-proposals.md` | Propositions optimisation scheduler (issue #487) | active |
| `scheduler-pilot-deployment-guide.md` | Guide deploiement pilote (issue #487) | active |
| `scheduling-claude-code.md` | Investigation scheduling (issue #403) | active |
| `task-hierarchy-analysis-20251203.md` | Analyse hierarchie cycle 4 (Dec 2025) | active |
| `unified-task-extraction-architecture.md` | Architecture extraction unifiee (issue #1360) | active |

**investigations/** (1 fichier) : `investigation-461-phase1.md` — actif

**proposals/** (1 fichier) : `todo1-get-nexttask-impl.md` — actif

**archive/** (12 fichiers + planning/ 4 fichiers + roosync-refactor/ 4 fichiers) — tous archives

---

## 8. Archive & History (50 fichiers)

### docs/archive/ — 2 fichiers

| Fichier | Description | Statut |
|---------|-------------|--------|
| `git-merge-commits-analysis-20251016.md` | Analyse merge commits (Oct 2025) | archived |
| `gpu-specs-myia-po-2023.md` | Specs GPU po-2023 (Jan 2026) | archived |

**harness-reports/** (4 fichiers) : cross-analysis 2026-03-13 a 15 — archives

**reports/** (8 fichiers + 2026-03-03-issue553-phase2/ 12 fichiers) — tous archives

### docs/history/worker-reports/ — 4 fichiers + myia-po-2023/ (4 fichiers)

Actifs : `DELEGATION.md`, `EXTRACTOR.md`, `INDEX.md`, `README.md` (issue #1429)

myia-po-2023/ : `2026-04-16-idle-worker-veille`, `2026-04-16-test-coverage-analysis`, `2026-04-16-test-coverage-improvement`, `2026-04-17-scheduler-health-metrics-1442`

### docs/suivi/archive/ — 17 fichiers (tous archives)

coordination/ (3), issues/ (1), reports/ (9), sessions/ (1), plus 3 fichiers racine

---

## 9. Other (46 fichiers)

### docs/dev/ (hors encoding/testing) — 8 fichiers

| Fichier | Description | Statut |
|---------|-------------|--------|
| `WORKTREE-WORKFLOW.md` | Workflow worktree isole multi-machines | active |
| `precommit-hook.md` | Documentation hook pre-commit | active |
| `sk-agent-enhancement-485.md` | Rapport enhancement sk-agent (issue #485) | active |

**archive-configuration/** (4 fichiers) : configs MCP archivees — archives

**debugging/** (3 fichiers) : `get_task_tree_bug_analysis`, `mcp_settings_corruption_bug`, `task_hierarchy_complete` — actifs

**fixes/** (1 fichier) : `PHASE3-PERSISTENCE-FIX-20251024` — actif

**indexation/** (1 fichier) : `repair-detectWorkspaceForTask-20251020` — actif

**maintenance/** (1 fichier) : `GUIDE_HOOKS_GIT_RESOLUTION` — actif

**refactoring/** (3 actifs + 9 archives) : cleanup plan, phase 1 completion, complexity report

### docs/evaluation/ — 1 fichier

| Fichier | Description | Statut |
|---------|-------------|--------|
| `qwen-3.5-35b-a3b-evaluation-536.md` | Evaluation Qwen 3.5 35B (issue #536) | active |

### docs/framework-multi-agent/ — 1 fichier

| Fichier | Description | Statut |
|---------|-------------|--------|
| `TEMPLATE_WORKSPACE.md` | Template workspace multi-agent (Fev 2026) | active |

### docs/github/ — 1 fichier

| Fichier | Description | Statut |
|---------|-------------|--------|
| `pr-review-enforcement-implementation.md` | Implementation enforcement review (issue #958) | active |

### docs/nanoclaw/ — 2 fichiers

| Fichier | Description | Statut |
|---------|-------------|--------|
| `IMPLEMENTATION_CHECKLIST.md` | Checklist implementation bridge (issue #1319) | active |
| `NANOCLAW_ROOSYNC_BRIDGE.md` | Design document bridge (issue #1319) | active |

### docs/ops/ — 1 fichier

| Fichier | Description | Statut |
|---------|-------------|--------|
| `docker-wsl-watchdog.md` | Watchdog Docker/WSL monitoring (issue #1380) | active |

### docs/suivi/ (hors monitoring/archive) — 5 fichiers

| Fichier | Description | Statut |
|---------|-------------|--------|
| `ISSUE-543-SESSION-SUMMARY.md` | Resume session issue #543 | active |
| `RAPPORT-BUG-CRITIQUE-QUICKFILES.md` | Investigation bug critique QuickFiles | active |
| `audit-disque-web1-2026-04-28.md` | Audit pression disque web1 (issue #1807) | active |
| `issue-543-final-report.md` | Rapport final harmonisation (issue #543) | active |
| `issue-572-audit-summary.md` | Resume investigation issue #572 | active |

**RooSync/** (3 fichiers) : `ANALYSE-#486-skills-agents`, `INDEX`, `web1-jupyter-fix-instructions` — actifs

### docs/knowledge/ — 2 fichiers

| Fichier | Description | Statut |
|---------|-------------|--------|
| `MEMORY-AUTO-INJECTION.md` | Doc feature auto-injection memoire (issue #1377) | active |
| `WORKSPACE_KNOWLEDGE.md` | Base de connaissances workspace | active |

---

## Resume par Statut

| Statut | Fichiers | Pourcentage |
|--------|----------|-------------|
| Active | ~240 | 62% |
| Archived | ~145 | 38% |
| **Total** | **385** | 100% |

## Doublons connus

- `roo-code/SCHEDULED_COORDINATOR.md` ↔ `harness/reference/scheduler-system.md`
- `roo-code/SCHEDULER_DENSIFICATION.md` ↔ `harness/reference/scheduler-densification.md`
- `roo-code/SCHEDULER_SYSTEM.md` ↔ `harness/reference/scheduler-system.md`
- `roosync/FEEDBACK_PROCESS.md` ↔ `harness/reference/feedback-process.md`
- `roosync/META_ANALYSIS.md` ↔ `harness/reference/meta-analysis.md`
- `roosync/PR_REVIEW_POLICY.md` ↔ `harness/coordinator-specific/pr-review-policy.md`
- `roosync/SKEPTICISM_PROTOCOL.md` ↔ `rules/skepticism-protocol.md`

---

**Genere par:** myia-web1 (executor session)
**Source:** Issue #1844 Task 5 (consolidation Phase 2)
**Precedent:** v5.14 (2026-03-26, structure repertoires uniquement)
