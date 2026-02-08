# Workspace Knowledge - roo-extensions
**Comprehensive Knowledge Base for Claude Code**

---

## 📋 Metadata

- **Workspace**: roo-extensions
- **Location**: `d:\roo-extensions`
- **Owner**: jsboige
- **Version**: 2.1.0
- **Last Updated**: 2026-01-04
- **Purpose**: Écosystème complet d'extensions pour l'assistant de développement Roo (VS Code)
- **Transition**: Migration progressive vers Claude Code pour simplification

---

## 🗺️ Complete Workspace Map

### Root Level Structure (25 directories)

```
roo-extensions/
├── .claude/                  # Claude Code extensions (NEW, commits a1fe6ec7, 7758302e)
├── .git/                    # Git repository
├── .github/                 # GitHub configuration
├── .roo/                    # Roo runtime configuration
├── .state/                  # Roo state storage
├── .vscode/                 # VSCode settings (workspace-level)
├── archive/                 # Archives multiples (11 dossiers)
├── backups/                 # Backup files
├── config/                  # Configuration files (sync schemas)
├── demo-roo-code/           # 5 demo directories pédagogiques
├── docs/                    # 6505+ markdown files, 101 subdirectories
├── encoding-fix/            # Encoding correction scripts
├── logs/                    # Log files
├── mcps/                    # MCP servers (internal + external)
├── modules/                 # Independent modules (EncodingManager, form-validator)
├── outputs/                 # Generated outputs
├── profiles/                # Configuration profiles
├── results/                 # Test results
├── roo-code/                # Roo VSCode extension (submodule)
├── roo-code-customization/  # Roo customization experiments
├── roo-config/              # Roo configuration & deployment
├── roo-modes/               # Roo mode definitions
├── scheduled-tasks/         # Scheduled task configurations
├── scripts/                 # 547 PowerShell scripts (27 categories)
├── temp/                    # Temporary files
├── test-quickfiles-bug/     # QuickFiles bug reproduction
└── tests/                   # Test suites
```

---

## 🔑 Key Directories Deep Dive

### 1. `.claude/` - Claude Code Integration

**Purpose**: Extensions pour Claude Code (nouveau, en développement)
**Commits**: a1fe6ec7 (Provider Switcher), 7758302e (Workspace Knowledge)

```
.claude/
├── commands/
│   └── switch-provider.md          # Slash command pour changer de provider LLM
├── scripts/
│   ├── Deploy-ProviderSwitcher.ps1 # Déploiement initial
│   └── Switch-Provider.ps1         # Runtime switching
├── configs/
│   ├── provider.anthropic.template.json
│   └── provider.zai.template.json
├── WORKSPACE_KNOWLEDGE.md           # Ce fichier
├── README.md                        # Documentation complète
├── QUICKSTART.md                    # Guide de démarrage
└── settings.local.json              # Permissions PowerShell
```

**Features**:
- Slash command `/switch-provider <anthropic|zai>`
- Multi-level deployment (workspace → global → multi-machine)
- Secure API key management (templates git-ignored)
- Automatic settings backup before switching

---

### 2. `mcps/` - Model Context Protocol Servers

**Purpose**: 15 serveurs MCP (6 internes développés ici + 9 externes + forks)

#### 2.1 Internal MCPs - Analyse Fine (`mcps/internal/servers/`)

##### 1. **roo-state-manager** (⭐ CORE - Version 1.0.14)

**Architecture**:
- **50+ outils MCP** organisés en 15 catégories
- **43 services TypeScript** dans `src/services/`
- **25 outils RooSync** (gestion multi-machines)
- **8 services RooSync** (BaselineService, ConfigSharingService, etc.)

**Technologies**:
- TypeScript 5.9.3, Vitest pour tests
- Qdrant (vector DB), OpenAI API
- PostgreSQL + SQLite + Sequelize ORM
- Winston (logging), WebSocket (notifications)
- LangChain (synthèse LLM)

**Environment Variables Requises**:
```bash
QDRANT_URL, QDRANT_API_KEY, QDRANT_COLLECTION_NAME
OPENAI_API_KEY, ROOSYNC_SHARED_PATH
```

**Catégories d'Outils**:
- RooSync (25): synchronisation, baseline, décisions, messagerie
- Conversation: synthèse LLM, export XML/JSON/CSV, arborescence
- Indexation: indexation sémantique Qdrant, reset collection
- Diagnostic: analyse problèmes RooSync, diagnostic environnement
- Export: multi-formats (XML, JSON, CSV, Markdown)
- Task: arborescence tâches, détails, navigation
- Cache: skeleton cache, rebuild
- Repair: correction BOM UTF-8

##### 2. **quickfiles-server** (Version 1.0.0)

**Purpose**: Manipulation fichiers batch - optimiser opérations multi-fichiers

**Outils (5)**:
- `read_multiple_files` - Lecture multiple avec excerpts optionnels
- `edit_multiple_files` - Édition multi-fichiers avec diffs
- `list_directory_contents` - Exploration récursive
- `search_in_files` - Recherche dans multiples fichiers
- `search_and_replace` - Rechercher-remplacer global

**Cas d'Usage Top 3**:
1. Refactorisation multi-fichiers (remplacer pattern dans N fichiers)
2. Analyse de logs multi-fichiers (extraire excerpts ciblés)
3. Exploration récursive de projet (1 appel vs N appels)

**Technologies**:
- TypeScript 5.8.3, esbuild, Jest
- Zod (validation), glob (patterns)
- Tests: unitaires, anti-régression, performance, e2e
- Scripts: validation, pre-commit, monitoring

**Performance**: 1 appel vs N appels natifs → gain significatif

##### 3. **github-projects-mcp** (Version 0.1.0)

**Purpose**: Intégration GitHub Projects pour tracking issues

**Fonctionnalités**:
- Intégration API GitHub Projects
- Gestion de projet et issues
- Tracking de travail

**Technologies**:
- TypeScript 5.8.3, ts-node
- @octokit/rest (GitHub API v19)
- Winston (logging), eventsource
- Mode E2E disponible pour tests

**Configuration**:
- GITHUB_TOKEN via .env
- Support HTTP/stdio transports

##### 4. **jinavigator-server** (Version 1.0.0)

**Purpose**: Web → Markdown via API Jina

**Outils**:
- Conversion pages web en Markdown
- Extraction contenu web optimisé LLM

**Technologies**:
- TypeScript, Express 5.0.1
- Axios (HTTP), Jina API
- Dépend de quickfiles-server
- Tests: unitaires, error handling, performance

**Architecture**: Express server pour routing + MCP tools

##### 5. **jupyter-papermill-mcp-server** (Python)

**Purpose**: Remplacement Node.js → Python pour Jupyter, architecture moderne

**17+ Outils Organisés**:

**Notebook** (9 outils):
- `read_cells` - 🆕 Consolidé (4 modes: single/range/list/all)
- `inspect_notebook` - 🆕 Consolidé (4 modes: metadata/outputs/validate/full)
- `read_notebook`, `write_notebook`, `create_notebook`
- `add_cell`, `remove_cell`, `update_cell`
- Outils dépréciés (compatibilité maintenue)

**Kernel** (6 outils):
- `execute_on_kernel` - 🆕 Consolidé (3 modes: code/notebook/notebook_cell)
- `list_kernels`, `start_kernel`, `stop_kernel`
- `interrupt_kernel`, `restart_kernel`

**Papermill** (1 outil):
- `execute_notebook` - 🆕 Consolidé (2 modes: sync/async, 3 report modes)

**Async Management** (1 outil):
- `manage_async_job` - 🆕 Consolidé (5 actions: status/logs/cancel/list/cleanup)

**Utilitaires** (8 outils):
- `list_notebook_files`, `get_notebook_info`
- `get_kernel_status`, `cleanup_all_kernels`
- `start_jupyter_server`, `stop_jupyter_server`
- `debug_list_runtime_dir`

**Architecture Python**:
```
papermill_mcp/
├── main.py              # Point entrée
├── config.py            # Configuration
├── core/
│   ├── papermill_executor.py
│   ├── kernel_manager.py
│   ├── notebook_handler.py
│   └── async_manager.py
└── tools/
    ├── notebook_tools.py
    ├── kernel_tools.py
    └── util_tools.py
```

**Améliorations vs Version Node.js**:
- Consolidation de 15 outils dépréciés en 5 outils multi-modes
- Parité fonctionnelle complète
- Architecture modulaire Python
- Gestion async améliorée

#### 2.2 External MCPs - Synthétique (`mcps/external/`)

##### MCPs Officiels ModelContextProtocol

**Fork**: `mcps/forked/modelcontextprotocol-servers/`
- **Origin**: https://github.com/jsboige/modelcontextprotocol-servers
- **Upstream**: https://github.com/modelcontextprotocol/servers
- **Purpose**: Fork personnalisé pour modifications locales
- **22+ serveurs de référence** dans le repository upstream

**MCPs Utilisés depuis Fork**:
1. **filesystem** - Opérations fichiers sécurisées avec ACLs
2. **git** - Lecture, recherche, manipulation repos Git
3. **github** - Gestion repos, fichiers, API GitHub
4. **docker** - Gestion conteneurs Docker

##### MCPs Externes Additionnels

5. **win-cli** (⭐ Personnalisé)
- **Purpose**: Commandes Windows natives via PowerShell
- **Location**: `mcps/external/win-cli/`
- **Spécificité**: Fork avec personnalisation pour environnement Windows
- **Configuration**: `roo-config/settings/win-cli-config.json`
- **Commits personnalisés** dans le repo

6. **mcp-server-ftp**
- **Purpose**: Opérations FTP/SFTP
- **Technologies**: Node.js, basic-ftp
- **Fonctions**: upload, download, list, delete FTP

7. **markitdown** (⭐ Personnalisé - Fork)
- **Purpose**: Conversion ressources → markdown
- **Location**: `mcps/external/markitdown/`
- **Spécificité**: Fork du projet upstream avec customisations
- **Source**: MarkITdown project

8. **playwright** (MCP officiel)
- **Purpose**: Automatisation web avec navigateur Firefox
- **Command**: `npx -y @playwright/mcp --browser firefox`
- **Fonctions**: navigation, scraping, screenshots

9. **searxng**
- **Purpose**: Recherche web via SearXNG (meta-moteur)
- **Privacy-focused**: Agrégateur de moteurs de recherche

10. **Office-PowerPoint-MCP-Server**
- **Purpose**: Manipulation présentations PowerPoint
- **Technologies**: Python, COM automation
- **PythonPath**: `mcps/external/Office-PowerPoint-MCP-Server`
- **Templates**: `templates/` directory

11. **jupyter** (Python officiel)
- **Purpose**: Intégration Jupyter (Python natif)
- **Command**: `python -m jupyter` ou `python -m papermill_mcp.main`
- **Alternative**: jupyter-papermill-mcp-server (version étendue)

#### 2.3 Configuration Globale

**Fichier**: `roo-config/settings/servers.json` (15 serveurs)

**Paramètres Communs**:
```json
{
  "type": "stdio",
  "enabled": true,
  "autoStart": true,
  "description": "...",
  "workingDirectory": "...",
  "envFile": ".env",
  "env": {...}
}
```

**Environment Variables**:
- `.env` à la racine pour API keys
- Variables spécifiques par MCP dans config

**Documentation**:
- `mcps/README.md` - Guide principal
- `mcps/INSTALLATION.md` - Installation pas-à-pas
- `mcps/TROUBLESHOOTING.md` - Dépannage

#### 2.4 Personnalisations et Forks

**Forks Actifs**:
1. **modelcontextprotocol-servers** (jsboige fork)
   - Commit local possibles pour customisations
   - Upstream tracking pour merges futurs

2. **markitdown** (fork personnalisé)
   - Modifications locales non documentées
   - Source: MarkITdown community project

3. **win-cli** (fork personnalisé)
   - Adaptations environnement Windows spécifiques
   - Configuration custom dans roo-config

**Stratégie de Fork**:
- Maintenir tracking upstream
- Committer customisations localement
- Documenter modifications dans README locaux

---

### 3. `roo-state-manager` - Le MCP Central

**Purpose**: Cœur du système, gère RooSync + état conversationnel

#### Structure

```
mcps/internal/servers/roo-state-manager/src/
├── index.ts                    # Point d'entrée (validation env vars)
├── config/                     # Configuration serveur
├── gateway/                    # Passerelle MCP
├── services/                   # 43+ services TypeScript
│   ├── baseline/              # Services baseline
│   ├── roosync/               # Services RooSync
│   ├── synthesis/             # Synthèse LLM
│   ├── task-indexer/          # Indexation Qdrant
│   └── ...
├── tools/                      # 50+ outils MCP organisés par catégorie
│   ├── roosync/               # 25 fichiers RooSync
│   ├── conversation/          # Gestion conversations
│   ├── export/                # Export XML/JSON/CSV
│   ├── indexing/              # Indexation sémantique
│   ├── diagnostic/            # Diagnostics
│   ├── repair/                # Réparation BOM
│   ├── search/                # Recherche
│   ├── summary/               # Synthèse
│   ├── task/                  # Gestion tâches
│   └── registry.ts            # Registre central
├── notifications/              # Système notifications push
├── types/                      # Types TypeScript
├── utils/                      # Utilitaires
└── tests/                      # Tests unitaires
```

#### Environment Variables Requises

```bash
QDRANT_URL=<Qdrant URL>
QDRANT_API_KEY=<API key>
QDRANT_COLLECTION_NAME=<collection>
OPENAI_API_KEY=<OpenAI key>
ROOSYNC_SHARED_PATH=<shared path>
```

#### Tools Principaux

**RooSync (25 outils)**: Voir section RooSync ci-dessous

**Conversation**:
- `list_conversations` - Lister conversations
- `get_conversation_synthesis` - Synthèse LLM
- `view_conversation_tree` - Arborescence
- `get_raw_conversation` - Données brutes

**Export**:
- `export_conversation_xml` - Export XML
- `export_conversation_json` - Export JSON
- `export_conversation_csv` - Export CSV
- `export_tasks_xml` - Export tâches
- `export_project_xml` - Export projet

**Indexation**:
- `index_task_semantic` - Indexer tâche
- `reset_qdrant_collection` - Reset collection
- `rebuild_task_index_fixed` - Rebuild index

**Diagnostic**:
- `analyze_roosync_problems` - Analyser problèmes
- `diagnose_env` - Diagnostic environnement

**Gestion MCP**:
- `manage_mcp_settings` - Gérer settings
- `get_mcp_best_practices` - Best practices
- `rebuild_and_restart` - Rebuild

---

### 4. RooSync - Synchronisation Multi-Machines

**Purpose**: Système baseline-driven pour synchroniser configurations Roo entre 6 machines

#### Architecture v2.3

**8 Services Principaux**:
1. **NonNominativeBaselineService** - Gestion baseline (v2.3)
2. **ConfigSharingService** - Partage configs
3. **ConfigNormalizationService** - Normalisation
4. **ConfigDiffService** - Comparaison configs
5. **InventoryService** - Inventaire machines
6. **MessageManager** - Messagerie inter-agents
7. **DecisionManager** - Gestion décisions
8. **DashboardService** - Monitoring

#### 25 Outils MCP RooSync

**Setup** (2):
- `roosync_init` - Initialiser infrastructure
- `roosync_get_status` - État synchronisation

**Monitoring** (3):
- `roosync_read_dashboard` - Tableau de bord
- `roosync_get_machine_inventory` - Inventaire machine
- `roosync_get_status` - État global

**Analyse** (2):
- `roosync_compare_config` - Comparer configurations
- `roosync_list_diffs` - Lister différences

**Validation** (3):
- `roosync_approve_decision` - Approuver décision
- `roosync_reject_decision` - Rejeter décision
- `roosync_get_decision_details` - Détails décision

**Exécution** (1):
- `roosync_apply_decision` - Appliquer décision

**Recovery** (1):
- `roosync_rollback_decision` - Annuler décision

**Communication** (6):
- `roosync_send_message` - Envoyer message
- `roosync_read_inbox` - Lire boîte réception
- `roosync_get_message` - Obtenir message
- `roosync_reply_message` - Répondre message
- `roosync_mark_message_read` - Marquer comme lu
- `roosync_archive_message` - Archiver message

**Collecte** (3):
- `roosync_collect_config` - Collecter config locale
- `roosync_publish_config` - Publier config
- `roosync_apply_config` - Appliquer config

**Baseline** (4):
- `roosync_update_baseline` - Mettre à jour baseline
- `roosync_version_baseline` - Versionner baseline
- `roosync_restore_baseline` - Restaurer version
- `roosync_export_baseline` - Exporter baseline

#### Machines

| Machine ID | Rôle | Statut |
|------------|------|--------|
| myia-ai-01 | Baseline Master | 🟢 Actif |
| myia-po-2023 | Agent | 🟢 Actif |
| myia-po-2024 | Coordinateur Technique | 🟢 Actif |
| myia-po-2026 | Agent | 🟡 Instabilité MCP |
| myia-web-01 | Testeur | 🟡 Conflit identité (myia-web1) |

#### Fichiers Clés

- **`sync-config.ref.json`** - Baseline référence (source de vérité)
- **`sync-roadmap.md`** - Roadmap validation décisions

#### État Actuel

**Phase 1: Diagnostic & Stabilisation** (13 tâches, 1 complétée)
- Tâche 1.1: Get-MachineInventory.ps1 freeze
- Tâche 1.2: Instabilité MCP myia-po-2026
- Tâche 1.3: Messages non-lus (4 messages)
- Tâche 1.4: Erreurs compilation TypeScript
- Tâche 1.5: Conflit identité myia-web-01 vs myia-web1
- Tâche 1.7: Vulnérabilités npm
- ✅ Tâche 1.12: Synchronisation myia-po-2024 complétée

**Documentation**:
- `docs/roosync/README.md` - Point d'entrée
- `docs/roosync/ARCHITECTURE_ROOSYNC.md` - Architecture complète
- `docs/roosync/GESTION_MULTI_AGENT.md` - Protocoles multi-agents
- `docs/roosync/GUIDE_UTILISATION_ROOSYNC.md` - Guide utilisateur
- `docs/suivi/RooSync/PHASE1_DIAGNOSTIC_ET_STABILISATION.md` - État actuel

---

### 5. `roo-modes/` - Modes Personnalisés Roo

**Purpose**: Définitions des modes Roo avec architecture 2-niveaux (simple/complex)

#### Architecture des Modes

**Chaque type de mode existe en version simple ET complexe**:

| Type | Simple (Qwen) | Complex (Claude) |
|------|---------------|-----------------|
| **Code** | `code-simple` | `code-complex` |
| **Debug** | `debug-simple` | `debug-complex` |
| **Architect** | `architect-simple` | `architect-complex` |
| **Ask** | `ask-simple` | `ask-complex` |
| **Orchestrator** | `orchestrator-simple` | `orchestrator-complex` |
| **Manager** | `manager` (uniquement) | - |

#### Configuration

**File**: `roo-config/settings/modes.json` (13 modes)

**Exemples**:
- `code-simple`: Claude 3.5, modifications mineures
- `code-complex`: Claude 3.7, refactorings majeurs
- `debug-simple`: Qwen 1.7B, problèmes simples
- `debug-complex`: Claude 3.7, problèmes complexes
- `architect-simple`: Qwen 32B, documentation simple
- `architect-complex`: Claude 3.7, architecture système
- `ask-simple`: Qwen 8B, questions factuelles
- `ask-complex`: Claude 3.7, analyses approfondies
- `orchestrator-simple`: Qwen 30B, tâches simples
- `orchestrator-complex`: Claude 3.7, workflows complexes
- `manager`: Claude 3.7, décomposition tâches haut-niveau

#### Déploiement

**Script principal**: `roo-config/settings/deploy-settings.ps1`
- Initialise submodules Git
- Déploie `servers.json` (config MCP)
- Déploie `settings.json` (config Roo globale)
- Prépare l'environnement

**Emplacements**:
- Définitions: `roo-modes/modes/`, `roo-modes/configs/`
- Templates: `roo-modes/modes/templates/`
- Custom: `roo-modes/custom/`
- N5 experimental: `roo-modes/modes/n5/`

---

### 6. `roo-config/` - Configuration & Déploiement

**Purpose**: Scripts et configurations pour déploiement Roo

#### Structure

```
roo-config/
├── settings/                   # Configuration principale
│   ├── deploy-settings.ps1     # Script déploiement principal
│   ├── settings.json           # Config Roo globale
│   ├── servers.json            # Config 15 MCPs
│   ├── modes.json              # Config 13 modes
│   ├── modes-base.json         # Modes de base
│   └── win-cli-config.json     # Config Windows CLI
├── modes/                      # Fichiers modes
│   ├── standard-modes.json
│   ├── standard-modes-updated.json
│   ├── generated-profile-modes.json
│   └── templates/              # Templates modes
├── config-templates/           # Templates configuration
├── docs/                       # Documentation
├── guides/                     # Guides utilisation
├── backups/                    # Backups automatiques
└── config-backups/             # Backups config
```

#### Scripts Clés

1. **deploy-settings.ps1** (`roo-config/settings/`)
   - Initialise submodules Git
   - Déploie settings.json et servers.json
   - Fusionne avec config existante
   - Crée backups automatiques

2. **12 scripts PowerShell** dans `roo-config/`
   - Correction encodage UTF-8
   - Diagnostic
   - Déploiement modes

---

### 7. `scripts/` - 547 Scripts PowerShell

**Purpose**: Scripts utilitaires organisés en 27 catégories

#### Catégories de Scripts

```
scripts/
├── analysis/           # Analyse code
├── audit/              # Audits
├── benchmarks/         # Benchmarks performance
├── build/              # Build
├── cleanup/            # Nettoyage
├── demo-scripts/       # Scripts démo
├── deployment/         # Déploiement (7 scripts)
├── diagnostic/         # Diagnostics
├── docs/               # Documentation
├── encoding/           # Correction encodage
├── git/                # Opérations Git
├── git-workflow/       # Workflows Git
├── install/            # Installation
├── inventory/          # Inventaire
├── maintenance/        # Maintenance
├── mcp/                # Gestion MCPs
├── messaging/          # Messagerie
├── monitoring/         # Monitoring
├── repair/             # Réparation
├── roosync/            # 23 scripts RooSync
├── setup/              # Setup initial
├── stash-recovery/     # Récupération stash
├── testing/            # Tests
├── transients/         # Scripts temporaires
├── utf8/               # UTF-8 handling
└── validation/         # Validation
```

#### Scripts Notables

**RooSync** (23 scripts dans `scripts/roosync/`):
- `roosync_update_baseline.ps1`
- `roosync_export_baseline.ps1`
- `roosync_compare_baseline.ps1`
- `roosync_validate_diff.ps1`
- Scripts de tests de production

**Déploiement**:
- `deploy-modes-simple-complex.ps1`
- `install-mcps.ps1`
- `force-deploy-with-encoding-fix.ps1`

**Encodage**:
- `fix-emoji-encoding-issues.ps1`
- `diagnostic-encoding-consolide.ps1`

---

### 8. `docs/` - Documentation Massive

**Purpose**: 6505+ fichiers markdown, 101 sous-dossiers

#### Structure Principale

```
docs/
├── roosync/            # Documentation RooSync complète
├── suivi/              # Suivi évolutions (22 rapports)
│   └── RooSync/        # 22 rapports de suivi RooSync
├── architecture/       # Spécifications techniques
├── guides/             # Guides d'utilisation
├── missions/           # Rapports de missions
├── mcp/                # Documentation MCPs
├── mcps/               # Documentation MCPs (alternative)
├── configuration/      # Documentation configuration
├── analysis/           # Analyses diverses
├── diagnostics/        # Diagnostics système
├── debugging/          # Guides debugging
├── deployment/         # Guides déploiement
├── testing/            # Documentation tests
├── troubleshooting/    # Dépannage
└── [90+ autres dossiers]
```

#### Documents Clés

**Point d'entrée**:
- `README.md` (racine) - Vue d'ensemble complète

**RooSync**:
- `docs/roosync/README.md`
- `docs/roosync/ARCHITECTURE_ROOSYNC.md`
- `docs/roosync/GESTION_MULTI_AGENT.md`

**MCPs**:
- `mcps/README.md`
- `mcps/INSTALLATION.md`
- `mcps/TROUBLESHOOTING.md`

**Configuration**:
- `roo-config/README.md`

#### Anti-Pattern Documentation

**Problème**: Documentation générée par agents sans consolidation
- Multiples versions des mêmes documents
- Rapports non consolidés
- Archives jamais nettoyées

**Exemple**: `sync-roadmap.md` existe dans 9 emplacements!

---

### 9. `demo-roo-code/` - Démos Pédagogiques

**Purpose**: 5 répertoires thématiques avec démos Roo

#### Structure

```
demo-roo-code/
├── 01-decouverte/              # Premiers pas
│   ├── demo-1-conversation/    # Demo conversation basique
│   ├── demo-2-vision/          # Demo vision
│   └── workspace/              # Workspace interactions
├── 02-orchestration-taches/    # Orchestration
│   ├── demo-1-planification/   # Planification
│   └── demo-2-recherche/       # Recherche
├── 03-assistant-pro/           # Assistant professionnel
│   ├── demo-1-analyse/         # Analyse données
│   ├── demo-2-presentation/    # Présentations
│   └── demo-3-communication/   # Communication
├── 04-creation-contenu/        # Création contenu
└── 05-projets-avances/         # Projets avancés
```

#### Chaque Demo Contient

- `README.md` - Instructions détaillées
- `docs/` - Guides pour agents
- `ressources/` - Fichiers nécessaires
- `workspace/` - Espace de travail

---

### 10. `modules/` - Modules Indépendants

**Purpose**: Modules TypeScript réutilisables

#### Modules

1. **EncodingManager** (`modules/EncodingManager/`)
   - Version: 1.0.0
   - Purpose: Gestion centralisée encodage UTF-8
   - Main: `dist/core/EncodingManager.js`
   - Scripts: `build`, `test`

2. **form-validator** (`modules/form-validator/`)
   - Purpose: Validation formulaires HTML
   - Files: `form-validator.html`, `form-validator.js`
   - Tests: `tests/` directory

---

### 11. `roo-code-customization/` - Expérimentations Roo

**Purpose**: Investigations et expérimentations sur Roo

#### Contenu

```
roo-code-customization/
├── investigations/     # 12+ rapports d'investigation
│   ├── 06-incident-loss-assessment.md
│   ├── 07-file-search-analysis.md
│   ├── 08-ui-crash-deep-dive.md
│   ├── 09-context-condensation-analysis.md
│   ├── 10-condensation-poc-design.md
│   ├── 11-sddd-process-post-mortem.md
│   ├── 12-vhp-condensation-analysis.md
│   └── ...
├── deployment-script-design.md
├── deployment-script-testing-plan.md
└── deployment-script-tests-design.md
```

#### Thèmes

- Condensation du contexte
- Compression VHP (Virtual Heuristics Provider)
- SDDD (Semantic-Documentation-Driven Design)
- Architecture grappes
- File search analysis

---

### 12. `tests/` - Suites de Tests

**Purpose**: Tests automatisés multiples

#### Structure

```
tests/
├── e2e/                        # Tests end-to-end
│   └── run-e2e-tests.ps1
├── encoding/                   # Tests encodage
│   └── multi-language-encoding-tests/
├── mcp/                        # Tests MCP
│   ├── quickfiles-bug-demo.js
│   ├── test-jupyter-*.js       # 10+ tests Jupyter
│   └── quickfiles-validation.js
├── mcp-structure/              # Tests structure MCP
├── mcp-win-cli/                # Tests Windows CLI
├── integration-assets/         # Assets tests intégration
├── manual/                     # Tests manuels
├── data/                       # Données de test
├── functional/                 # Tests fonctionnels
└── scripts/                    # Scripts de test
```

---

### 13. Autres Répertoires Notables

#### `archive/` (11 dossiers)
- `architecture-ecommerce/`
- `backups/`
- `cleanup_20251208/`
- `docs-20251022/`
- `optimized-agents/`
- `roosync-v1-2025-12-27/`
- `scripts-repair-2025-11-04/`
- Et 4 autres...

#### `scheduled-tasks/`
- Documentation pour tâches planifiées
- Procédures de sync settings

#### `backups/`
- `mcp-cleanup-20251024/`
- `profiles/`
- `terminal-config/`
- `vscode-config/`

#### `config/`
- `sync-config.unified.work.json`
- `sync-config.json` (baseline RooSync)
- `sync-config.schema.json`
- `sync-dashboard.schema.json`

#### `.roo/` (Roo Runtime)
- `mcp.json` (vide, configuration MCP)
- `schedules.json`
- `rules-orchestrator/` (règles orchestration)

#### `.state/`
- `sync-config.ref.json` (baseline référence)

#### `.vscode/` (Workspace Settings)
- `settings.json` (avec backups automatiques)

---

## 🔄 Git Submodules

### Sous-Modules Actifs

| Sous-module | Path | Commit Actuel | Rôle |
|-------------|------|---------------|------|
| roo-code | roo-code/ | ca2a491ee | Extension Roo VSCode |
| mcps/internal | mcps/internal/ | 125d038134 | MCPs internes |
| mcps/external/* | mcps/external/ | Variable | MCPs externes |
| mcps/forked | mcps/forked/ | 6619522da | MCPs forkés |

### Gestion

**Initialisation**:
```bash
git submodule update --init --recursive
```

**Mise à jour**:
```bash
git submodule update --remote mcps/internal
```

---

## 🎯 Contexte et Objectifs

### Objectif Principal

Développer un **système agentique de vibe coding** multi-machines et multi-workspaces avec fiabilité maximale.

### Contexte Actuel

- **6 mois de développement** avec Roo
- **5 agents Roo** sur 5 machines tentent de consolider RooSync
- **Multiplication des rapports** mais problèmes persistants
- **Roo complexe** → Personnaliser Roo avec Roo s'est avéré difficile

### Transition Vers Claude Code

**Pourquoi**:
- Roo s'est avéré complexe et instable
- Claude Code offre une approche plus simple
- Besoin de consolider et nettoyer l'existant

**Approche**:
- NE PAS perturber les agents Roo existants
- Analyser en profondeur avant toute action
- Préserver ce qui fonctionne
- Identifier les points de cohabitation possibles

---

## 🚨 Points d'Attention

### ⚠️ À Éviter

1. **Modifier RooSync** sans comprendre les 25 outils MCP
2. **Toucher aux configs Roo** sans consultation
3. **Supprimer de la documentation** sans analyse approfondie
4. **Modifier les sous-modules** sans comprendre les dépendances
5. **Supprimer .shared-state/** (n'existe pas, était un mirage)

### ⚠️ Problèmes Connus

1. **Dérive documentaire massive** - 6505+ fichiers MD
2. **RooSync instable** - Phase 1 stabilisation (1/13 tâches)
3. **Multi-agent difficile** - 5 agents en conflit
4. **Documentation éparpillée** - 101 dossiers dans `docs/`
5. **Encodage UTF-8** - Problèmes récurrents avec accents/emojis

### ✅ Principe de Prudence

**Toujours**:
1. Lire la documentation existante avant toute action
2. Consulter les rapports de suivi récents
3. Vérifier l'état actuel via les outils appropriés
4. Documenter toute modification
5. Committer avec messages clairs

---

## 📊 Métriques Clés

### Taille et Complexité

- **547 scripts PowerShell** (27 catégories)
- **15 serveurs MCP** configurés
- **13 modes Roo** (simple/complex pour 5 types + manager)
- **50+ outils MCP** dans roo-state-manager
- **6505+ fichiers markdown** documentation
- **101 sous-dossiers** dans `docs/`
- **25 fichiers tools** RooSync
- **6 machines** dans système multi-agent

### Scripts PowerShell

- **547 scripts** au total
- **27 catégories** différentes
- **23 scripts** RooSync
- **7 scripts** déploiement
- **Multiple scripts** encodage, diagnostic, testing

### Documentation

- **22 rapports** suivi RooSync
- **12 investigations** roo-code-customization
- **11 dossiers** archive
- **50+ documents** techniques dans `docs/`

---

## 🔍 Navigation Rapide

### Trouver de l'Information

**RooSync**:
- `docs/roosync/README.md` (entrée principale)
- `docs/roosync/ARCHITECTURE_ROOSYNC.md` (architecture)
- `docs/suivi/RooSync/PHASE1_*.md` (état actuel)

**MCPs**:
- `mcps/README.md` (guide)
- `mcps/INSTALLATION.md` (installation)
- `roo-config/settings/servers.json` (configuration)

**Configuration Roo**:
- `roo-config/README.md` (guide)
- `roo-config/settings/deploy-settings.ps1` (déploiement)
- `roo-config/settings/modes.json` (modes)

**Modes**:
- `roo-modes/docs/` (documentation)
- `roo-config/settings/modes.json` (définitions)

**Scripts**:
- `scripts/` (547 scripts organisés par catégorie)

**Tests**:
- `tests/` (suites de tests)

**Démos**:
- `demo-roo-code/` (5 démos thématiques)

---

## 🆕 Intégration Claude Code

### Composants Existants

**Fork**: `.claude/` (commits a1fe6ec7, 7758302e)
- Provider Switcher: Multi-LLM (Anthropic/z.ai)
- Slash command: `/switch-provider`
- Scripts PowerShell: Déploiement et switching
- Workspace Knowledge: Ce fichier

### Objectifs Futurs

1. **Approfondir compréhension** RooSync et 25 outils
2. **Identifier précisément** ce qui fonctionne vs à nettoyer
3. **Proposer plan** consolidation documentation
4. **Explorer cohabitation** Roo ↔ Claude Code
5. **Établir ponts** entre les deux systèmes

---

## Context Condensation - Decisions Architecturales (Archive)

**Projet** : Refactoring du systeme de condensation de contexte pour Roo Code (PR #8743)
**Periode** : Octobre 2025 (planning, implementation, validation, soumission PR)
**Statut** : Projet termine. 155 fichiers de documentation archives dans `archive/context-condensation-pr-tracking/`.

### Architecture Provider-Based

Le systeme de condensation de contexte a ete concu autour d'un **pattern Strategy** avec 4 providers interchangeables orchestres par un `CondensationProviderManager`. L'interface commune `ICondensationProvider` definit les methodes `condense()`, `estimateCost()`, `estimateReduction()` et `getCapabilities()`. Les 4 providers implementes sont : **Native** (backward-compatible, wrapping du systeme LLM-based existant), **Lossless** (deduplication de lectures fichiers, consolidation de resultats d'outils, zero perte d'information), **Truncation** (reduction mecanique rapide par age, cout zero), et **Smart** (architecture pass-based ultra-configurable avec 3 presets : Conservative, Balanced, Aggressive).

### Decisions Cles et Patterns Reutilisables

L'architecture a suivi une approche incrementale en phases distinctes plutot qu'un PR monolithique, suite a une revue architecturale critique identifiant un risque de sur-engineering. La separation Manager/Provider est stricte : le Manager gere l'orchestration, les profils API, les seuils et les fallbacks, tandis que les Providers gerent l'implementation technique. Le systeme de profils API permet une optimisation des couts de 95% en utilisant des modeles moins chers pour la condensation (ex: GPT-4o-mini au lieu de Claude Sonnet). Le Smart Provider introduit une architecture pass-based ou toute strategie de condensation est exprimable via configuration (3 types de contenu x 4 operations x 2 modes d'execution).

### Patterns Techniques Identifies

Parmi les patterns reutilisables documentes : (1) **Optimistic UI avec Temporal Guard** pour synchroniser frontend/backend sans race conditions (timestamp + ignore backend 500ms), (2) **Loop-guard anti-boucles** avec MAX_ATTEMPTS et cooldown pour les retries, (3) **Registry Reset** pour la stabilite des tests unitaires dans les singletons. Le projet a aussi produit 4 corrections critiques suite a une analyse externe : loop-guard, registry reset, context detection amelioree dans BaseProvider, et telemetrie enrichie.

### Metriques Finales

Le projet a produit 31 commits conventionnels, 95 fichiers modifies (~8300 lignes ajoutees), 155+ tests (110 backend + 45 UI, 100% passing), 0 warnings ESLint, et 18 documents de checkpoint couvrant toutes les phases. La documentation technique totale depasse 8000 lignes. Les fichiers detailles sont consultables dans `archive/context-condensation-pr-tracking/`, avec l'index principal dans `000-documentation-index.md`.

---

## Lecons Apprises : Taches Orphelines

### Probleme identifie (Septembre 2025)

Sur 3598 taches Roo, 3075 (85.5%) etaient invisibles dans l'UI car leur fichier `task_metadata.json` etait manquant. Ce fichier lie une tache a son workspace et lui donne un titre visible. Sans lui, la tache existe dans `globalState.taskHistory` et dans les fichiers `api_conversation_history` mais n'apparait pas dans l'interface.

### Architecture de persistance Roo Code

Roo utilise une persistance a 2 niveaux :
1. **Fichiers individuels** par tache dans `globalStorage/tasks/{id}/` : `api_conversation_history.json` (messages API), `ui_messages.json` (messages UI), `task_metadata.json` (titre, workspace, timestamps)
2. **Index global** dans `globalState.taskHistory` (SQLite via VS Code) : liste ordonnee de toutes les taches avec metadonnees minimales

Le bug : lors de crashes ou interruptions, `globalState` est mis a jour mais `task_metadata.json` n'est pas ecrit, rendant la tache orpheline.

### Tentatives de reparation echouees (5 tentatives, 0 succes)

Cinq approches testees sans succes (34.8 MB d'echanges, 5954 messages) :
- Script PowerShell de reconstruction, analyse fichiers + regeneration, approche TypeScript directe, reconstruction inversee depuis globalState, approche hybride.
- **Anti-pattern cle** : "code-first" au lieu de "system-first" -- les agents codaient des solutions avant de comprendre l'architecture de persistance.

### Solutions architecturales retenues

1. **Corrective** : `rebuild_task_index` -- reconstruit l'index en scannant les fichiers tasks existants
2. **Proactive** : Auto-reparation au demarrage de Roo -- detecte et repare les taches orphelines
3. **Fallback** : Implementation autonome sans modification du code source Roo

---

## Procedures de Recovery et Post-Mortems

### Disaster Recovery mcps/internal (6 septembre 2025)

Le sous-module `mcps/internal` avait 375 modifications non commitees suite a un `git reset --hard` mal execute. Recovery : sauvegarde temporaire, `git submodule update --init --recursive --force`, reapplication selective. **Lecon** : Toujours sauvegarder l'etat du sous-module avant toute operation git destructive.

### Restauration Git critique (21 septembre 2025)

Plus de 100 commits effaces suite a un `push --force` accidentel sur main. Recovery par cherry-pick de 6 commits critiques, resolution manuelle des conflits sous-modules. **Lecon** : Ne JAMAIS utiliser `push --force` sur main.

### Recovery Git apres second push --force (25 septembre 2025)

Deuxieme incident similaire. Recovery via `git reflog` + `git reset --hard <bon-commit>` + `git push --force-with-lease`.

### Reparation roo-state-manager : build path

Le build generait `build/src/index.js` au lieu de `build/index.js` car `rootDir` dans `tsconfig.json` pointait vers `.` au lieu de `./src`.

### Synthese reparations MCP (janvier 2025)

3 serveurs repares en une session : roo-state-manager (build path + validation env vars), office-powerpoint (chemin Python), jupyter-papermill (migration Node.js vers Python).

### Recovery MCP post-resync (25 septembre 2025)

Apres resync Git, tous les MCP casses (node_modules/builds supprimes). Resolution : `npm install && npm run build` dans chaque serveur, regeneration token GitHub, verification markitdown+ffmpeg.

---

## Troubleshooting : Fixes Documentes

### Fix timeout jupyter-papermill-mcp

Champ `"timeout": 120` invalide dans `mcp_settings.json` (non supporte par MCP stdio). Fix : retirer le champ.

### Fix problemes residuels MCP

Rate limiting 10->100 ops/s, nettoyage 23828 entrees orphelines DB, correction BOM UTF-8 sur `mcp_settings.json`.

### Fix fuite reseau 220GB roo-state-manager

Verifications Qdrant excessives (30s intervalle). Fix Version 2 : cache anti-fuite Map, intervalle coherence 30s->24h, reindexation minimum 4h, background 30s->5min.

### __dirname en module ES

Remplacer `__dirname` par `path.dirname(fileURLToPath(import.meta.url))`.

### Regression SearXNG : import.meta.url sur Windows

`import.meta.url` retourne `file:///C:/...` vs `process.argv[1]` retourne `C:\...`. Fix : normaliser avec `fileURLToPath()`. Verifier aussi absence BOM UTF-8 dans configs.

---

## Getting Started et Installation

### Prerequis

Node.js >= 18.x, Python >= 3.10, Git avec sous-modules, VS Code avec Roo/Claude Code, PowerShell 7+, API keys (Anthropic, OpenAI, Qdrant optionnel, GitHub token).

### Parcours d'apprentissage (5 niveaux)

1. **Decouvrant** : demos `demo-roo-code/01-decouverte/`
2. **Utilisateur** : modes simple/complex, MCPs de base
3. **Power User** : personnalisation modes, scripts PowerShell
4. **Developpeur** : contribution MCPs internes, tests
5. **Architecte** : architecture RooSync, nouveaux services

### Installation rapide

```bash
git clone --recursive https://github.com/jsboige/roo-extensions.git
cd mcps/internal/servers/roo-state-manager && npm install && npm run build
cp .env.example .env  # Remplir API keys
cd roo-config/settings && powershell ./deploy-settings.ps1
```

---

## Conventions Git et Strategie Multi-Profils

### Format de commit conventionnel

`type(scope): description` avec types fix/feat/docs/test/chore/refactor et scopes roosync/mcp/modes/scripts/coord.

### Profils Git multi-machines

Utiliser `includeIf` dans `.gitconfig` pour gerer les identites par machine/repertoire.

---

## Troubleshooting Encodage UTF-8 sur Windows

Windows utilise Windows-1252 par defaut. Les fichiers PowerShell peuvent ajouter un BOM UTF-8 (`EF BB BF`) qui corrompt les parseurs JSON.

- **Diagnostic** : `[System.IO.File]::ReadAllBytes()` pour verifier les 3 premiers octets
- **Reparation** : `[System.IO.File]::WriteAllText(path, content, [System.Text.UTF8Encoding]::new($false))`
- **Prevention** : VS Code `"files.encoding": "utf8"`, eviter `Set-Content` en PowerShell

---

## Demos Pedagogiques

5 repertoires thematiques dans `demo-roo-code/` (decouverte, orchestration, assistant pro, creation contenu, projets avances). Chaque demo est autonome avec README, ressources et workspace. Maintenir la compatibilite avec la version courante de Roo lors des mises a jour.

---

## Architecture Globale du Projet

### Couches principales

1. **Extension Roo Code** (`roo-code/`) : sous-module VS Code
2. **MCPs** (`mcps/`) : 15 serveurs (6 internes + 9 externes/forks)
3. **Configuration** (`roo-config/`) : modes, parametres, deploiement
4. **RooSync** : synchronisation multi-machines via Google Drive
5. **Claude Code** (`.claude/`) : agents, skills, commands

### Architecture des modes

- **2 niveaux** (initial) : simple (modeles legers) vs complex (Claude/GPT)
- **5 niveaux** (N5, experimental) : mini, light, standard, plus, max

### Strategie de tests

ESM-First : migration CommonJS vers ESM, configuration centralisee vitest/jest, `tsconfig.base.json` partage.

---

## MCO : Maintien en Conditions Operationnelles

### Pannes MCP typiques

Apres inactivite/resync/MAJ OS : `node_modules/` ou `build/` manquants. Resolution : `npm install && npm run build` dans chaque serveur affecte.

### Jupyter mode offline

Sans serveur Jupyter actif, les operations fichier notebook fonctionnent mais les operations kernel sont indisponibles. Verifier `jupyter server list` avant utilisation.

### Degradation gracieuse

Chaque MCP doit demarrer meme si ses dependances externes sont indisponibles, avec erreurs explicites plutot que blocage.

---

## Containerisation et Dev Containers

4 approches evaluees : VS Code Remote Containers, GitHub Codespaces, Gitpod, Self-hosted Docker Compose. Recommandation : image de base `mcr.microsoft.com/devcontainers/typescript-node:18`, Docker volumes pour `node_modules`, WSL2 pour performance I/O sur Windows, inclusion MCPs dans le container avec lifecycle hooks (`postCreateCommand: npm install`).

---

## VS Code : Chemins globalStorage

- **Windows** : `%APPDATA%\Code\User\globalStorage\<publisher>.<extension>/`
- **macOS** : `~/Library/Application Support/Code/User/globalStorage/<publisher>.<extension>/`
- **Linux** : `~/.config/Code/User/globalStorage/<publisher>.<extension>/`

Pour Roo Code : `rooveterinaryinc.roo-cline`. Acces programmatique via `context.globalStorageUri`.

---

## Actions RooSync

- **Compare-Config** : Detection ecarts configuration locale vs baseline de reference (modes, MCPs, config globale)
- **Initialize-Workspace** : Initialisation environnement partage Google Drive (repertoires, baseline, permissions)

---

## Historique Projet

### v3.19.0 (Septembre 2025)

jupyter-papermill refactore Node.js vers Python, roo-state-manager avec 50+ outils MCP et architecture 2 niveaux, RooSync baseline-driven, modes simple/complex deployes sur 5 machines.

---

## Roo Code Extension : Connaissances Techniques

### Composants principaux

ClineProvider (point d'entree webview), Cline (logique conversationnelle), TaskManager (cycle de vie taches), systeme de modes avec permissions differenciees.

### Persistance et affichage

`globalState.taskHistory` comme index, verification `task_metadata.json` par tache, chargement metadonnees, filtrage par workspace. Messages UI deserialises avec JSON.parse + validation Zod, fallback sur valeurs par defaut.

### Hierarchies de taches

Relations parent-enfant supportees en memoire mais NON persistees sur disque -- perdues au redemarrage VS Code.

### Bug race condition message editor

Dans `ChatView.tsx`, si une reponse d'outil arrive pendant la saisie utilisateur, `sendingDisabled` passe a `true` avant le re-rendu UI. Le click Send met le message en file d'attente ET vide l'input via `clearDraft()`. Le hook `useAutosaveDraft` (debounce 300ms) ne protege que partiellement (messages tapes en <300ms perdus).

### Indexation semantique

tree-sitter pour analyse code source, embeddings stockes dans Qdrant, recherche semantique dans l'historique conversationnel multi-workspace.

---

## Troubleshooting MCP : Erreur "Tool names must be unique"

Bug dans Claude Code VS Code dupliquant les outils MCP lors de l'initialisation des sous-agents. Procedure de debug : desactiver tous les MCPs, tester chaque serveur individuellement (jupyter, github, roo), tester par paires, restaurer. Le wrapper `mcp-wrapper.cjs` de roo-state-manager est suspect (filtrage potentiellement incomplet). Toujours redemarrer VS Code completement apres changement de config MCP.

---

**Document genere par**: Claude Sonnet 4.5, enrichi par Claude Opus 4.6
**Pour**: Toutes les conversations futures dans ce workspace
**Objectif**: Grounding rapide, contexte fiable et vision complete
**Version**: 3.0 (Consolidee -- integration P4 documentation diverse)
**Derniere mise a jour**: 2026-02-08
