# Workspace Knowledge - roo-extensions

**Dernière mise à jour**: 2026-01-04
**Objectif**: Document de connaissance pour grounding Claude Code dans toutes les conversations futures

---

## 📋 Vue d'Ensemble

### Identité du Workspace
- **Nom**: roo-extensions
- **Propriétaire**: jsboige
- **Description**: Écosystème complet d'extensions pour l'assistant de développement Roo (VS Code)
- **Statut**: Production Ready (v2.1.0)
- **Location**: `d:\roo-extensions`

### Architecture Principale

```
roo-extensions/
├── .claude/                 # Extensions Claude Code (NOUVEAU)
│   ├── commands/           # Slash commands Claude Code
│   ├── scripts/            # Scripts PowerShell pour Claude Code
│   └── configs/            # Configurations providers LLM
├── mcps/                   # Serveurs MCP (12 serveurs)
│   ├── internal/           # 6 MCPs internes développés ici
│   │   └── servers/
│   │       ├── roo-state-manager/    # ⭐ Gestion état + RooSync (24 outils)
│   │       ├── quickfiles-server/    # Manipulation fichiers batch
│   │       ├── jinavigator-server/   # Web → Markdown
│   │       ├── jupyter-mcp-server/    # Intégration Jupyter
│   │       ├── github-projects-mcp/  # Gestion GitHub Projects
│   │       └── jupyter-papermill-mcp-server/  # Jupyter avancé
│   └── external/           # 6+ MCPs externes
│       ├── filesystem/     # Accès fichiers
│       ├── git/            # Opérations Git
│       ├── github/         # API GitHub
│       ├── win-cli/        # Commandes Windows
│       ├── mcp-server-ftp/ # FTP
│       └── searxng/        # Recherche web
├── roo-config/             # Configuration & déploiement Roo
│   ├── settings/           # Paramètres globaux
│   ├── deployment-scripts/ # Scripts déploiement modes
│   ├── encoding-scripts/   # Correction UTF-8
│   ├── diagnostic-scripts/ # Scripts diagnostic
│   └── modes/              # Modes standards
├── roo-modes/              # Modes personnalisés Roo
│   ├── configs/            # Configurations standards
│   ├── custom/             # Modes customisés
│   ├── n5/                 # Architecture 5 niveaux (expérimental)
│   └── optimized/          # Modes optimisés
├── docs/                   # Documentation massive (101 dossiers)
│   ├── roosync/            # Documentation RooSync complète
│   ├── suivi/              # Suivi des évolutions (22 rapports)
│   ├── architecture/       # Spécifications techniques
│   ├── guides/             # Guides d'utilisation
│   └── missions/           # Rapports de missions
├── scripts/                # Scripts utilitaires variés
├── tests/                  # Tests automatisés
└── archive/                # Archives multiples (11 dossiers)
```

---

## 🎯 Composant Core: RooSync

### Qu'est-ce que RooSync?

**RooSync** est un système de synchronisation multi-machines baseline-driven qui permet:
- Synchroniser des configurations Roo entre 6 machines Windows
- Gérer des décisions de synchronisation avec validation humaine
- Coordonner des agents multi-machines via messagerie
- Maintenir une baseline unique comme source de vérité

### Architecture RooSync v2.3

**8 Services Principaux**:
1. **NonNominativeBaselineService** - Gestion baseline (v2.3)
2. **ConfigSharingService** - Partage configurations inter-machines
3. **ConfigNormalizationService** - Normalisation multi-environnements
4. **ConfigDiffService** - Comparaison et diff de configs
5. **InventoryService** - Inventaire des machines
6. **MessageManager** - Messagerie inter-agents
7. **DecisionManager** - Gestion décisions de synchronisation
8. **DashboardService** - Monitoring et tableaux de bord

**24 Outils MCP** organisés en:
- Setup (2 outils): `roosync_init`, `roosync_get_status`
- Monitoring (3 outils): `roosync_get_status`, `roosync_read_dashboard`, `roosync_get_machine_inventory`
- Analyse (2 outils): `roosync_compare_config`, `roosync_list_diffs`
- Validation (3 outils): `roosync_approve_decision`, `roosync_reject_decision`, `roosync_get_decision_details`
- Exécution (1 outil): `roosync_apply_decision`
- Recovery (1 outil): `roosync_rollback_decision`
- Communication (5 outils): `roosync_send_message`, `roosync_read_inbox`, `roosync_get_message`, `roosync_reply_message`, `roosync_mark_message_read`, `roosync_archive_message`
- Collecte (3 outils): `roosync_collect_config`, `roosync_publish_config`, `roosync_apply_config`
- Baseline (4 outils): `roosync_update_baseline`, `roosync_version_baseline`, `roosync_restore_baseline`, `roosync_export_baseline`

### Machines RooSync

| Machine ID | Rôle | Statut Actuel |
|------------|------|---------------|
| myia-ai-01 | Baseline Master | 🟢 Actif |
| myia-po-2023 | Agent | 🟢 Actif |
| myia-po-2024 | Coordinateur Technique | 🟢 Actif |
| myia-po-2026 | Agent | 🟡 Problèmes (instabilité MCP) |
| myia-web-01 | Testeur | 🟡 Conflit identité (myia-web1) |

### Fichiers Clés RooSync

- **`sync-config.ref.json`** - Baseline de référence (source de vérité)
- **`sync-roadmap.md`** - Roadmap de validation des décisions
- **`.shared-state/`** - NE PAS UTILISER (était un mirage, supprimé)

### État Actuel RooSync (Phase 1: Diagnostic & Stabilisation)

**Tâches**: 13 tâches, 1 complétée (CP1.12: synchronisation myia-po-2024 ✅)

**Problèmes identifiés**:
- Get-MachineInventory.ps1 freeze (tâche 1.1)
- Instabilité MCP myia-po-2026 (tâche 1.2)
- Messages non-lus à traiter (tâche 1.3)
- Erreurs compilation TypeScript (tâche 1.4)
- Conflit identité myia-web-01 vs myia-web1 (tâche 1.5)
- Vulnérabilités npm (tâche 1.7)

**Documentation RooSync**:
- [`docs/roosync/README.md`](docs/roosync/README.md) - Point d'entrée principal
- [`docs/roosync/ARCHITECTURE_ROOSYNC.md`](docs/roosync/ARCHITECTURE_ROOSYNC.md) - Architecture v2.3 complète
- [`docs/roosync/GESTION_MULTI_AGENT.md`](docs/roosync/GESTION_MULTI_AGENT.md) - Protocoles multi-agents
- [`docs/roosync/GUIDE_UTILISATION_ROOSYNC.md`](docs/roosync/GUIDE_UTILISATION_ROOSYNC.md) - Guide utilisateur
- [`docs/suivi/RooSync/PHASE1_DIAGNOSTIC_ET_STABILISATION.md`](docs/suivi/RooSync/PHASE1_DIAGNOSTIC_ET_STABILISATION.md) - État actuel

---

## 🤖 Composant Core: roo-state-manager MCP

### Rôle

**roo-state-manager** est LE MCP central qui implémente:
- **RooSync**: Tous les 24 outils de synchronisation
- **Gestion de l'état**: Tracking des conversations Roo
- **SDDD Enhanced Export**: Système de génération de rapports multi-niveaux
- **Synthèse LLM**: Synthèse automatique de conversations
- **Notifications Push**: Système event-driven

### Outils Principaux (42 au total)

**Catégorie RooSync (24 outils)**: voir section RooSync ci-dessus

**Catégorie État Conversationnel**:
- `get_conversation_synthesis` - Synthèse LLM d'une conversation
- `list_conversations` - Lister toutes les conversations
- `get_conversation_details` - Détails d'une conversation
- `export_conversations` - Exporter conversations

**Catégorie SDDD Export**:
- `export_sddd_report` - Générer rapport SDDD multi-niveaux
- `list_sddd_templates` - Lister templates disponibles
- Niveaux: MINIMAL, STANDARD, DETAILED, COMPREHENSIVE, DEBUG, FULL

**Catégorie Notifications**:
- Système automatique d'indexation temps réel
- Notifications inter-machines RooSync
- Filtrage par priorité et règles

### Emplacement Code

- **Code source**: `mcps/internal/servers/roo-state-manager/src/`
- **Outils**: `src/tools/` (organisés par catégorie)
- **Services**: `src/services/` (8 services RooSync + autres)
- **Documentation**: `mcps/internal/servers/roo-state-manager/docs/`

---

## 🎭 Modes Roo

### Architecture 2 Niveaux (Recommandée)

**Modes Simples** (Qwen 3 32B - Tâches courantes):
- `code` - Développement standard
- `ask` - Questions simples
- `debug` - Diagnostic basique

**Modes Complexes** (Claude 3.5/3.7 - Tâches avancées):
- `architect` - Architecture et conception
- `orchestrator` - Coordination workflows
- `manager` - Décomposition tâches complexes

### Architecture 5 Niveaux (Expérimentale)

**N5** - MICRO → MINI → MEDIUM → LARGE → ORACLE
- Optimisation coûts par complexité
- Réservé à usage expérimental

### Déploiement des Modes

**Script principal**: `roo-config/settings/deploy-settings.ps1`
- Initialise les submodules Git
- Déploie `servers.json` (config MCP)
- Prépare l'environnement

**Script modes**: `roo-config/deployment-scripts/deploy-modes-simple-complex.ps1`
- Déploie les modes simples
- Déploie les modes complexes

### Emplacement Fichiers

- **Définitions**: `roo-modes/configs/` et `roo-modes/custom/`
- **Documentation**: `roo-modes/docs/`
- **Scripts déploiement**: `roo-config/deployment-scripts/`

---

## 🔧 Scripts et Outils

### Scripts PowerShell Principaux

**Dans `roo-config/`**:
- `settings/deploy-settings.ps1` - Déploiement paramètres globaux
- `deployment-scripts/deploy-modes-simple-complex.ps1` - Déploiement modes
- `encoding-scripts/fix-encoding-complete.ps1` - Correction UTF-8
- `diagnostic-scripts/diagnostic-rapide-encodage.ps1` - Diagnostic encodage

**Dans `scripts/`**:
- Plus de 30 sous-dossiers de scripts spécialisés
- Diagnostic, deployment, testing, validation, etc.

### Gestion Encodage UTF-8

**Problème récurrent**: Caractères accentués et emojis mal encodés dans les fichiers JSON

**Solution**: Scripts dans `roo-config/encoding-scripts/`
- Détection automatique
- Correction séquences mal encodées
- Réenregistrement UTF-8 sans BOM

---

## 📚 Documentation

### Structure Massive

**6505+ fichiers markdown** au total (incluant node_modules)
**101 sous-dossiers** dans `docs/`
**189 rapports/synthèses** avec "rapport", "report" ou "synthesis"

### Documentation Clé

**Point d'entrée principal**:
- [`README.md`](README.md) - Vue d'ensemble complète

**RooSync**:
- [`docs/roosync/README.md`](docs/roosync/README.md) - Guide principal RooSync
- [`docs/roosync/ARCHITECTURE_ROOSYNC.md`](docs/roosync/ARCHITECTURE_ROOSYNC.md) - Architecture technique
- [`docs/roosync/GESTION_MULTI_AGENT.md`](docs/roosync/GESTION_MULTI_AGENT.md) - Multi-agents

**Suivi**:
- [`docs/suivi/RooSync/`](docs/suivi/RooSync/) - 22 rapports de suivi
- [`docs/suivi/RooSync/PHASE1_DIAGNOSTIC_ET_STABILISATION.md`](docs/suivi/RooSync/PHASE1_DIAGNOSTIC_ET_STABILISATION.md) - État actuel

**MCPs**:
- [`mcps/README.md`](mcps/README.md) - Guide MCPs
- [`mcps/INSTALLATION.md`](mcps/INSTALLATION.md) - Installation MCPs
- [`mcps/TROUBLESHOOTING.md`](mcps/TROUBLESHOOTING.md) - Dépannage MCPs

**Configuration**:
- [`roo-config/README.md`](roo-config/README.md) - Guide configuration
- [`roo-config/docs/`](roo-config/docs/) - Documentation détaillée

### Anti-Pattern Documentation

**Problème**: Documentation générée par agents sans consolidation
- Multiples versions des mêmes documents
- Rapports de missions non consolidés
- Archives créées mais jamais nettoyées

**Exemple**: `sync-roadmap.md` existe dans 9 emplacements différents!

---

## 🔄 Sous-Modules Git

### Sous-Modules Actifs

| Sous-module | Path | Commit actuel | Rôle |
|-------------|------|---------------|------|
| roo-code | roo-code/ | ca2a491ee | Extension Roo VS Code |
| mcps/internal | mcps/internal/ | 125d038134 | MCPs internes |
| mcps/external/* | mcps/external/ | Variable | MCPs externes |
| mcps/forked | mcps/forked/ | 6619522da | MCPs forkés |

### Gestion Sous-Modules

**Initialisation**:
```bash
git submodule update --init --recursive
```

**Mise à jour**:
```bash
git submodule update --remote mcps/internal
```

---

## 🆕 Intégration Claude Code

### Composants Existants

**Fork: `.claude/`** (commit a1fe6ec7)
- **Provider Switcher**: Système multi-LLM (Anthropic/z.ai)
- **Slash command**: `/switch-provider <anthropic|zai>`
- **Scripts PowerShell**: Déploiement et switching
- **Sécurité**: Templates sans API keys, configs git-ignored

### Fichiers Claude Code

```
.claude/
├── commands/
│   └── switch-provider.md          # Slash command definition
├── scripts/
│   ├── Deploy-ProviderSwitcher.ps1 # One-time deployment
│   └── Switch-Provider.ps1         # Runtime switching
├── configs/
│   ├── provider.anthropic.template.json
│   └── provider.zai.template.json
├── settings.local.json             # Workspace permissions
├── README.md                        # Documentation complète
└── QUICKSTART.md                    # Quick start guide
```

### .gitignore Configuré

```gitignore
# Claude Code Provider Switcher - Real API keys (NEVER commit these!)
.claude/configs/provider.*.json
!.claude/configs/provider.*.template.json

# Claude Code settings backups
.claude/settings.json.backup-*
```

---

## 🎯 Objectifs et Contexte

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

**Approche prudente**:
- NE PAS perturber les agents Roo existants
- Analyser en profondeur avant toute action
- Préserver ce qui fonctionne
- Identifier les points de cohabitation possibles

---

## 🚨 Points d'Attention

### ⚠️ À Éviter

1. **Supprimer .shared-state/** - C'était un mirage, déjà supprimé
2. **Modifier RooSync** sans comprendre les 24 outils MCP
3. **Toucher aux configs Roo** sans consultation
4. **Supprimer de la documentation** sans analyse approfondie
5. **Modifier les sous-modules** sans comprendre les dépendances

### ⚠️ Problèmes Connus

1. **Dérive documentaire massive** - 6505+ fichiers MD, beaucoup en double
2. **RooSync instable** - Phase 1 de stabilisation en cours (1/13 tâches)
3. **Multi-agent difficile** - 5 agents qui se marchent sur les pieds
4. **Documentation éparpillée** - 101 dossiers dans `docs/`, difficile à naviguer

### ✅ Principe de Prudence

**Toujours**:
1. Lire la documentation existante avant toute action
2. Consulter les rapports de suivi récents
3. Vérifier l'état actuel via les outils appropriés
4. Documenter toute modification
5. Commiter avec messages clairs

---

## 🔍 Recherche et Navigation

### Comment Trouver de l'Information

**Pour RooSync**:
- Commencer par: `docs/roosync/README.md`
- Architecture: `docs/roosync/ARCHITECTURE_ROOSYNC.md`
- État actuel: `docs/suivi/RooSync/PHASE1_*.md`

**Pour les MCPs**:
- Guide principal: `mcps/README.md`
- Installation: `mcps/INSTALLATION.md`
- Problèmes: `mcps/TROUBLESHOOTING.md`

**Pour la configuration**:
- Guide: `roo-config/README.md`
- Déploiement: `roo-config/settings/deploy-settings.ps1`

**Pour les modes Roo**:
- Documentation: `roo-modes/docs/`
- Scripts: `roo-config/deployment-scripts/`

**Pour le suivi**:
- Rapports récents: `docs/suivi/RooSync/`
- Missions: `docs/missions/`

---

## 📊 Métriques Clés

### Taille et Complexité

- **6505+ fichiers markdown** (documentation massive)
- **101 sous-dossiers** dans `docs/` seul
- **189 rapports** avec "rapport"/"report"/"synthesis"
- **299 fichiers JSON** de configuration
- **12 MCPs** (6 internes + 6 externes)
- **24 outils RooSync** MCP
- **6 machines** dans le système multi-agent

### Documentation

- **3 guides unifiés RooSync** (opérationnel, développeur, technique)
- **22 rapports de suivi** dans `docs/suivi/RooSync/`
- **11+ documents d'archive** (nettoyage nécessaire)
- **50+ documents techniques** dans `docs/`

---

## 🎯 Prochaines Étapes Suggérées

Pour Claude Code dans ce workspace:

1. **Approfondir la compréhension** de RooSync et des 24 outils MCP
2. **Identifier précisément** ce qui fonctionne vs ce qui doit être nettoyé
3. **Proposer un plan** de consolidation documentation
4. **Explorer la cohabitation** Roo ↔ Claude Code
5. **Établir des ponts** entre les deux systèmes

---

**Document généré par**: Claude Sonnet 4.5
**Pour**: Toutes les conversations futures dans ce workspace
**Objectif**: Grounding rapide et contexte fiable
