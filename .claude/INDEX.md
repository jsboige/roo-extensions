# Claude Code Workspace - Documentation Index

**Last Updated:** 2026-01-05
**Workspace:** roo-extensions (RooSync Multi-Agent System)

---

## 📚 Navigation Rapide

### Pour Démarrer
- **[README.md](README.md)** - Point d'entrée du workspace
- **[QUICKSTART.md](QUICKSTART.md)** - Guide de démarrage rapide

### Pour les Agents Claude Code
- **[CLAUDE_CODE_GUIDE.md](CLAUDE_CODE_GUIDE.md)** - Guide complet pour les agents (Bootstrap + Phases + Protocole SDDD)
- **[MCP_ANALYSIS.md](MCP_ANALYSIS.md)** - Analyse détaillée des MCPs (Roo vs Claude Code, portabilité)

### Configuration et Déploiement
- **[MCP_SETUP.md](MCP_SETUP.md)** - Guide d'installation et configuration MCP pour les 5 machines
- **[ROO_STATE_MANAGER_GUIDE.md](ROO_STATE_MANAGER_GUIDE.md)** - Guide d'utilisation du MCP roo-state-manager
- **[MCP_BOOTSTRAP_REPORT.md](MCP_BOOTSTRAP_REPORT.md)** - Rapport d'état du bootstrap MCP (myia-ai-01)
- **[MULTI_MACHINE_DEPLOYMENT.md](MULTI_MACHINE_DEPLOYMENT.md)** - Guide de déploiement multi-machine RooSync

### Communication et Coordination
- **[INTERCOM_PROTOCOL.md](INTERCOM_PROTOCOL.md)** - Protocole de communication locale Claude Code ↔ Roo
- **[local/INTERCOM-myia-ai-01.md](local/INTERCOM-myia-ai-01.md)** - Journal de communication local (myia-ai-01)

### Transition et Reprise de Travail
- **[RESUME_WORK.md](RESUME_WORK.md)** - Guide de transition pour reprendre le travail (NOUVELLE CONVERSATION)
- **[START_NEW_CONVERSATION.txt](START_NEW_CONVERSATION.txt)** - Message prêt à copier pour démarrer une nouvelle conversation

### Connaissance du Workspace
- **[docs/knowledge/WORKSPACE_KNOWLEDGE.md](../docs/knowledge/WORKSPACE_KNOWLEDGE.md)** - Base de connaissance complète (6500+ fichiers documentés)

---

## 🗂️ Documentation RooSync

### Guides Principaux
- **[docs/roosync/PROTOCOLE_SDDD.md](../docs/roosync/PROTOCOLE_SDDD.md)** - Protocole SDDD v2.2.0 (Semantic Documentation Driven Design)
- **[docs/roosync/GUIDE-TECHNIQUE-v2.3.md](../docs/roosync/GUIDE-TECHNIQUE-v2.3.md)** - Guide technique RooSync v2.3
- **[docs/roosync/GESTION_MULTI_AGENT.md](../docs/roosync/GESTION_MULTI_AGENT.md)** - Gestion multi-agent

### Documentation Opérationnelle
- **[docs/roosync/GUIDE-OPERATIONNEL-UNIFIE-v2.1.md](../docs/roosync/GUIDE-OPERATIONNEL-UNIFIE-v2.1.md)** - Guide opérationnel unifié
- **[docs/roosync/GUIDE-DEVELOPPEUR-v2.1.md](../docs/roosync/GUIDE-DEVELOPPEUR-v2.1.md)** - Guide développeur

---

## 📊 Suivi et Rapports

### Phase 1 - Diagnostic et Stabilisation
- **[docs/suivi/RooSync/PHASE1_DIAGNOSTIC_ET_STABILISATION.md](../docs/suivi/RooSync/PHASE1_DIAGNOSTIC_ET_STABILISATION.md)** - État actuel Phase 1

### Plans d'Action
- **[docs/suivi/RooSync/PLAN_ACTION_MULTI_AGENT_myia-ai-01_2025-12-31_v2.md](../docs/suivi/RooSync/PLAN_ACTION_MULTI_AGENT_myia-ai-01_2025-12-31_v2.md)** - 58 tâches planifiées

### Rapports de Synthèse
- **[docs/suivi/RooSync/RAPPORT_SYNTHESE_MULTI_AGENT_myia-ai-01_2025-12-31_v2.md](../docs/suivi/RooSync/RAPPORT_SYNTHESE_MULTI_AGENT_myia-ai-01_2025-12-31_v2.md)** - Synthèse multi-agent

---

## 🔧 Outils MCP Disponibles

### MCPs Internes (6 serveurs)

**RooSync (roo-state-manager) - 50+ outils:**
- `search_tasks_by_content` - Recherche sémantique (Qdrant + OpenAI embeddings)
- `view_conversation_tree` - Arborescence des tâches
- `get_conversation_synthesis` - Synthèse LLM
- `roosync_*` - 25 outils de synchronisation multi-machine

**GitHub Projects (github-projects-mcp):**
- `list_projects` - Lister projets
- `get_project_items` - Items du projet
- `convert_draft_to_issue` - Créer issue
- `update_project_item_field` - Mettre à jour

**Autres MCPs internes:**
- `jinavigator-server` - Web → Markdown (Jina API)
- `jupyter-papermill-mcp-server` - Jupyter Papermill
- `quickfiles-server` - Opérations multi-fichiers

### MCPs Externes (12 serveurs)

**Opérations de base:**
- `filesystem` - Opérations fichiers (lecture, écriture, édition)
- `git` - Opérations Git (commit, push, pull, branches)
- `github` - API GitHub (repos, issues, PRs)

**Services externes:**
- `searxng` - Recherche web
- `docker` - Conteneurs Docker
- `jupyter` - Notebooks Jupyter
- `markitdown` - Conversion documents

**Sous-modules git:**
- `win-cli/server` - Windows CLI
- `mcp-server-ftp` - Serveur FTP
- `markitdown/source` - Microsoft Markitdown (v0.1.4)
- `playwright/source` - Automatisation navigateur (v0.0.54)
- `Office-PowerPoint-MCP-Server` - PowerPoint (Python)

---

## 🎯 Protocole SDDD Adapté pour Claude Code

### Triple Grounding

#### 1. Grounding Sémantique
**Outils:** `search_tasks_by_content` (Roo MCP) + Grep/Glob
- Recherche sémantique via Qdrant
- Complété par recherche textuelle
- Lecture des documents pertinents

#### 2. Grounding Conversationnel
**Outils:** `view_conversation_tree`, `get_conversation_synthesis` (Roo MCP)
- Arborescence des conversations
- Synthèse LLM
- Lecture des rapports récents

#### 3. Grounding Technique
**Outils:** Read, Grep, Bash, Git
- Lecture code source
- Analyse état Git
- Validation faisabilité

### Traçabilité GitHub

**OBLIGATION CRITIQUE:** Créer une issue GitHub pour toute tâche significative.

**Format:**
```
Titre: [CLAUDE-myia-XX-XX] TITRE_DE_LA_TACHE
Labels: claude-code, phase-X, priority-X
```

---

## 📋 Structure du Dépôt

### Documentation
```
docs/
├── roosync/                     # Documentation RooSync
│   ├── PROTOCOLE_SDDD.md
│   ├── GUIDE-TECHNIQUE-v2.3.md
│   └── GESTION_MULTI_AGENT.md
├── suivi/RooSync/               # Suivi multi-agent
│   ├── PHASE1_DIAGNOSTIC_ET_STABILISATION.md
│   ├── PLAN_ACTION_MULTI_AGENT_*.md
│   └── RAPPORT_SYNTHESE_MULTI_AGENT_*.md
└── ...
```

### Code Source
```
mcps/
├── internal/                    # MCPs internes
│   └── servers/
│       └── roo-state-manager/   # RooSync + outils Roo
└── external/                    # MCPs externes
    ├── github-projects-mcp/     # GitHub Project
    └── playwright/              # Browser automation
```

---

## 🚀 État Actuel (2026-01-05)

### Problèmes Identifiés
- 🔴 **Dualité architecturale v2.1/v2.3** - Cause profonde de l'instabilité
- 🔴 **58 tâches en 4 phases** - Seulement 1 complétée
- 🔴 **Documentation éparpillée** - 6500+ fichiers à consolider
- 🔴 **Multi-agent "poussif"** - Coordination inefficace

### Objectifs Claude Code
1. **Nettoyer le dépôt** - Fusionner doublons, supprimer obsolètes
2. **Consolider la documentation** - Créer index structurés
3. **Coordonner les efforts** - Protocole SDDD + GitHub Project
4. **Assister Roo** - Finaliser outils, tests techniques

---

## 🤝 Contribution Multi-Agent

### Coordination en Cours

**Phase 0: Bootstrap** (Immédiat)
- Démarrer les agents Claude Code sur les 5 machines
- Valider l'accès aux MCPs

**Phase 1: Observation** (Jours 1-2)
- Analyse complète du système RooSync
- Cartographie de la documentation
- Diagnostic technique

**Phase 2: Nettoyage** (Jours 3-7)
- Consolidation documentation
- Nettoyage dépôt
- Validation avec agents Roo

**Phase 3: Coordination** (Jours 8-14)
- Mise en place protocole SDDD
- Rituels de communication
- Outils de coordination

**Phase 4: Extension** (Semaines 3-4)
- Modèle répliquable
- Documentation déploiement
- Tests sur workspaces additionnels

### Comment Participer

1. Lire le [archive/BOOTSTRAP_MESSAGE.md](archive/BOOTSTRAP_MESSAGE.md)
2. Suivre le protocole SDDD adapté
3. Créer des issues GitHub pour traçabilité
4. Communiquer via RooSync

---

## 📞 Support et Ressources

### Documentation
- **RooSync:** `docs/roosync/`
- **Provider Switcher:** [archive/README_PROVIDER_SWITCHER.md](archive/README_PROVIDER_SWITCHER.md)
- **Coordination:** [archive/PROPOSAL.md](archive/PROPOSAL.md)

### Issues et Questions
- **GitHub:** [jsboige/roo-extensions](https://github.com/jsboige/roo-extensions)
- **RooSync:** Via `roosync_send_message`

---

## 📝 Méta-Documentation

### Fichiers .claude/

**Chargés automatiquement au démarrage:**
- `README.md` - Ce fichier, court et avec liens
- `INDEX.md` - Cette table des matières
- `QUICKSTART.md` - Guide rapide

**Documents de référence (archive/):**
- `WORKSPACE_KNOWLEDGE.md` - Base connaissance complète
- `BOOTSTRAP_MESSAGE.md` - Message bootstrap détaillé
- `PROPOSAL.md` - Proposition détaillée
- `ANALYSE_TECHNIQUE.md` - Analyse technique

**Scripts et configurations:**
- `commands/` - Slash commands
- `scripts/` - PowerShell scripts
- `configs/` - Config templates

---

**Version:** 1.0.0
**Last Updated:** 2026-01-05
**Maintainer:** jsboige

---

**Built with Claude Code 🤖**
