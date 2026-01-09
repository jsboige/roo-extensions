# Roo Extensions - Guide pour Agents Claude Code

**Repository:** [jsboige/roo-extensions](https://github.com/jsboige/roo-extensions)
**Système:** RooSync v2.3 Multi-Agent Coordination (5 machines)
**Dernière mise à jour:** 2026-01-09

---

## 🎯 Vue d'ensemble

Système multi-agent coordonnant **Roo Code** (technique) et **Claude Code** (coordination & documentation) sur 5 machines :

**Machines :** `myia-ai-01`, `myia-po-2023`, `myia-po-2024`, `myia-po-2026`, `myia-web-01`

**Architecture :** Coordination bicéphale
- **Roo Code** → Tâches techniques (scripts, tests, build)
- **Claude Code** → Documentation, coordination, reporting

---

## 📚 Démarrage Rapide

### Pour une NOUVELLE conversation sur cette machine :

```powershell
# 1. Mettre à jour le dépôt
git pull

# 2. Lire ce fichier (CLAUDE.md) complètement

# 3. Vérifier les MCP disponibles
# Les MCPs sont chargés au démarrage de VS Code
```

### Pour une AUTRE machine :

1. **Identifier la machine** : `$env:COMPUTERNAME` ou `hostname`
2. **Lire la documentation** : [`.claude/INDEX.md`](.claude/INDEX.md)
3. **Configurer les MCPs** : Suivre [`.claude/MCP_SETUP.md`](.claude/MCP_SETUP.md)

---

## ✅ État des MCPs (2026-01-09)

### myia-ai-01 ✅ OPÉRATIONNEL

**github-projects-mcp** (57 outils)
- Configuration : `~/.claude.json` (global)
- **Statut :** ✅ Vérifié et fonctionnel
- **Outils testés :** list_projects, get_project, get_project_items
- **Projet :** "RooSync Multi-Agent Tasks" (#67, 60 items)
- **URL :** https://github.com/users/jsboige/projects/67

**roo-state-manager** (6 outils RooSync de messagerie)
- Configuration : `~/.claude.json` avec wrapper [mcp-wrapper.cjs](mcps/internal/servers/roo-state-manager/mcp-wrapper.cjs)
- **Statut :** ✅ DÉPLOYÉ ET FONCTIONNEL (2026-01-09)
- **Solution :** Wrapper intelligent qui filtre 57+ outils → 6 outils RooSync
- **Outils disponibles :**
  - `roosync_send_message` - Envoyer un message
  - `roosync_read_inbox` - Lire la boîte de réception
  - `roosync_reply_message` - Répondre à un message
  - `roosync_get_message` - Obtenir un message complet
  - `roosync_mark_message_read` - Marquer comme lu
  - `roosync_archive_message` - Archiver un message
- **Capacités :**
  - Messagerie inter-machine via RooSync
  - Synchronisation multi-agent
  - 65 messages dans la boîte de réception (4 non-lus)

### Autres machines ❌ À CONFIGURER

- myia-po-2023
- myia-po-2024
- myia-po-2026
- myia-web-01

**Action requise :**
1. Lancer : `.\.claude\scripts\init-claude-code.ps1`
2. Redémarrer VS Code complètement
3. Créer issue GitHub : `[CLAUDE-MACHINE] Bootstrap Complete`

---

## 🤖 Votre Rôle : Agent Claude Code

### ✅ À FAIRE

- **Documentation** : Consolidation, nettoyage, indexation
- **Coordination** : Via GitHub Issues et RooSync
- **Analyse** : Rapports, diagnostics, audits
- **Outils natifs** : Read, Grep, Bash, Git

### ❌ À NE PAS FAIRE

- Modifier le code technique de Roo (scripts, tests, build)
- Supposer que les MCPs fonctionnent sans tester
- Inventer des workflows sans vérifier
- Utiliser des outils non vérifiés

### ⚠️ CONTRAINTE CLÉ

**Vous n'avez PAS accès à votre historique de conversation.**

Utilisez :
- **GitHub Issues** comme "mémoire externe"
- **RooSync** pour la coordination inter-machine
- **INTERCOM** pour la coordination locale (même machine)

---

## 🔄 Canaux de Communication

### 1. RooSync (Inter-Machine)

**Objectif :** Coordination entre les 5 machines

**Outils MCP :**
- `roosync_send_message` - Envoyer message
- `roosync_read_inbox` - Lire boîte de réception
- `roosync_reply_message` - Répondre

**Fichier :** `G:/Mon Drive/Synchronisation/RooSync/.shared-state/`

**Documentation :** [`docs/roosync/GUIDE-TECHNIQUE-v2.3.md`](docs/roosync/GUIDE-TECHNIQUE-v2.3.md)

### 2. INTERCOM (Locale Claude Code ↔ Roo)

**Objectif :** Coordination locale sur la même machine

**Fichier :** `.claude/local/INTERCOM-{MACHINE_NAME}.md`

**Documentation :** [`.claude/INTERCOM_PROTOCOL.md`](.claude/INTERCOM_PROTOCOL.md)

**Protocole :**
1. Vérifier les messages de l'autre agent au démarrage
2. Envoyer message : Ouvrir fichier → Ajouter message → Sauvegarder
3. Format : Markdown avec horodatage

```markdown
## [2026-01-09 10:00:00] claude-code → roo [TASK]
Merci de tester le module X.

---
```

**Types de messages :** `INFO`, `TASK`, `DONE`, `WARN`, `ERROR`, `ASK`, `REPLY`

### 3. GitHub Issues (Traçabilité)

**Objectif :** Suivi des tâches multi-agent

**Projet :** "RooSync Multi-Agent Tasks"
- URL : https://github.com/users/jsboige/projects/67
- 60 items en cours

**Format des issues :**
```
Titre: [CLAUDE-MACHINE] Titre de la tâche
Labels: claude-code, priority-X
```

---

## 📋 Structure du Dépôt

### Documentation Principale
```
.claude/
├── README.md              # Point d'entrée (court)
├── INDEX.md               # Table des matières détaillée
├── CLAUDE.md              # Ce fichier
├── CLAUDE_CODE_GUIDE.md   # Méthodologie SDDD complète
├── MCP_SETUP.md           # Guide configuration MCP
├── INTERCOM_PROTOCOL.md   # Protocole communication locale
├── scripts/               # Scripts d'initialisation
│   └── init-claude-code.ps1
└── local/                 # Communication locale
    └── INTERCOM-myia-ai-01.md
```

### Documentation Technique
```
docs/
├── roosync/                              # Protocoles RooSync
│   ├── PROTOCOLE_SDDD.md                 # Méthodologie SDDD v2.2
│   ├── GUIDE-TECHNIQUE-v2.3.md           # Guide technique complet
│   └── GESTION_MULTI_AGENT.md            # Gestion multi-agent
├── suivi/RooSync/                        # Suivi multi-agent
│   ├── PHASE1_DIAGNOSTIC_ET_STABILISATION.md
│   └── RAPPORT_SYNTHESE_MULTI_AGENT_*.md
└── knowledge/
    └── WORKSPACE_KNOWLEDGE.md             # Base connaissance (6500+ fichiers)
```

### Code Source
```
mcps/
├── internal/servers/
│   ├── roo-state-manager/               # ✅ DÉPLOYÉ (avec wrapper)
│   └── github-projects-mcp/             # ✅ DÉPLOYÉ
└── external/                             # MCPs externes (12 serveurs)
```

---

## 🚀 Pour Démarrer une Nouvelle Tâche

### 1. Vérifier l'environnement

```powershell
# Identifier la machine
$env:COMPUTERNAME

# Vérifier les MCP disponibles
# (Les outils MCP sont listés au démarrage de la conversation)
```

### 2. Lire la documentation

- [`.claude/INDEX.md`](.claude/INDEX.md) - Carte complète
- [`.claude/MCP_SETUP.md`](.claude/MCP_SETUP.md) - Configuration MCP
- [`.claude/CLAUDE_CODE_GUIDE.md`](.claude/CLAUDE_CODE_GUIDE.md) - Méthodologie SDDD

### 3. Vérifier les communications

**RooSync :**
```bash
roosync_read_inbox  # Vérifier les messages inter-machines
```

**INTERCOM :**
```bash
# Ouvrir .claude/local/INTERCOM-{MACHINE}.md
# Chercher messages récents de Roo
```

**GitHub :**
```bash
# Vérifier les issues récentes avec label "claude-code"
```

### 4. Créer une issue de traçabilité

**OBLIGATOIRE pour toute tâche significative.**

Format :
```
Titre: [CLAUDE-MACHINE] Description de la tâche
Labels: claude-code, priority-<HIGH|MEDIUM|LOW>
Body:
- Contexte: ...
- Objectifs: ...
- Livrables: ...
```

### 5. Travailler et documenter

- **Attendez-vous** à ce qui est réellement disponible, pas à ce qui devrait l'être
- **Testez** les MCPs avant de les utiliser
- **Documentez** la réalité, pas les hypothèses
- **Communiquez** via RooSync, INTERCOM et GitHub

---

## 🎯 Contexte Actuel (2026-01-09)

### Phase : Coordination Multi-Agent

**Accomplissements récents :**
- ✅ GitHub Projects MCP déployé et vérifié (myia-ai-01)
- ✅ RooSync MCP déployé avec wrapper intelligent (myia-ai-01)
  - Résolution du problème de logs verbeux
  - Filtrage de 57+ outils → 6 outils RooSync de messagerie
  - Communication inter-machine fonctionnelle

**Problèmes résolus :**
- ✅ Plantage de Claude Code au démarrage avec roo-state-manager
- ✅ Trop de logs stdout interférant avec le protocole MCP
- Solution : Wrapper [mcp-wrapper.cjs](mcps/internal/servers/roo-state-manager/mcp-wrapper.cjs)

**Objectifs immédiats :**
- 🔄 Déployer les MCPs sur les 4 autres machines
- 📋 Créer un plan de distribution de tâches clair
- 🎯 Reprendre la coordination bicéphale Claude Code + Roo

### Contraintes Critiques

- **NE PAS supposer que les MCPs sont disponibles** - tester d'abord
- **Utiliser les outils natifs Claude Code** - Read, Grep, Bash, Git
- **NE PAS inventer de workflows** - tester ce qui fonctionne réellement
- **Documenter la réalité** - ce qui est vérifié, pas ce qui est supposé

---

## 📝 Méthodologie SDDD pour Claude Code

### Triple Grounding

**1. Grounding Sémantique**
- Outils : `search_tasks_by_content` (Roo MCP) + Grep/Glob
- Recherche sémantique + recherche textuelle
- Lecture des documents pertinents

**2. Grounding Conversationnel**
- Outils : `view_conversation_tree`, `get_conversation_synthesis` (Roo MCP)
- Arborescence des conversations
- Synthèse LLM

**3. Grounding Technique**
- Outils : Read, Grep, Bash, Git
- Lecture code source
- Validation faisabilité

### Traçabilité GitHub

**OBLIGATION CRITIQUE :** Créer une issue GitHub pour toute tâche significative.

**Documentation complète :** [`.claude/CLAUDE_CODE_GUIDE.md`](.claude/CLAUDE_CODE_GUIDE.md)

---

## 🤝 Coordination Multi-Agent

### Répartition des Machines

| Machine | Rôle | Statut MCP |
|---------|------|------------|
| **myia-ai-01** | Coordinateur Principal | ✅ GitHub + RooSync |
| **myia-po-2023** | Agent flexible | ❌ À configurer |
| **myia-po-2024** | Agent flexible | ❌ À configurer |
| **myia-po-2026** | Agent flexible | ❌ À configurer |
| **myia-web-01** | Agent flexible | ❌ À configurer |

**Toutes les machines ont des capacités égales** - pas de spécialisation rigide.

### Responsabilités

**myia-ai-01 (Coordinateur) :**
- Créer les issues GitHub pour les catégories de tâches
- Maintenir le suivi global
- Coordonner la distribution du travail
- Consolider et intégrer les résultats

**Tous les agents :**
- Choisir les tâches disponibles dans les issues GitHub
- S'auto-assigner via les commentaires GitHub
- Reporter les progrès quotidiennement
- Coordonner via les commentaires
- Demander de l'aide si bloqué

### Communication Quotidienne

1. **Chaque agent** poste un rapport quotidien : `[CLAUDE-MACHINE] Daily Report - DATE`
2. **Vérifier** les nouvelles tâches avec label `claude-code` et `help-wanted`
3. **Commenter** sur les tâches en cours pour éviter les duplications
4. **Signaler** les bloquants tôt pour que les autres puissent aider

---

## 📚 Ressources Supplémentaires

### Documentation Technique
- [`docs/knowledge/WORKSPACE_KNOWLEDGE.md`](docs/knowledge/WORKSPACE_KNOWLEDGE.md) - Base connaissance complète
- [`docs/roosync/GUIDE-TECHNIQUE-v2.3.md`](docs/roosync/GUIDE-TECHNIQUE-v2.3.md) - Guide RooSync

### Scripts et Outils
- [`.claude/scripts/init-claude-code.ps1`](.claude/scripts/init-claude-code.ps1) - Initialisation MCP
- [`mcps/internal/servers/roo-state-manager/mcp-wrapper.cjs`](mcps/internal/servers/roo-state-manager/mcp-wrapper.cjs) - Wrapper MCP

### GitHub
- **Projet :** https://github.com/users/jsboige/projects/67
- **Issues :** https://github.com/jsboige/roo-extensions/issues

---

**Dernière mise à jour :** 2026-01-09
**Pour questions :** Créer une issue GitHub ou contacter myia-ai-01

**Built with Claude Code 🤖**
