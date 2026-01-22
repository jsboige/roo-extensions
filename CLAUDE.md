# Roo Extensions - Guide pour Agents Claude Code

**Repository:** [jsboige/roo-extensions](https://github.com/jsboige/roo-extensions)
**Système:** RooSync v2.3 Multi-Agent Coordination (5 machines)
**Dernière mise à jour:** 2026-01-18

---

## 🎯 Vue d'ensemble

Système multi-agent coordonnant **Roo Code** (technique) et **Claude Code** (coordination & documentation) sur 5 machines :

**Machines :** `myia-ai-01`, `myia-po-2023`, `myia-po-2024`, `myia-po-2026`, `myia-web1`

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

## 🤖 Architecture Agents & Skills (NOUVEAU)

### Principe : Conversations Légères

Pour éviter les conversations qui grossissent indéfiniment, utilise des **subagents** pour déléguer les tâches verboses. La conversation principale reste légère et orchestre.

```
┌─────────────────────────────────────────────────────────────┐
│              CONVERSATION PRINCIPALE (légère)                │
│  - Orchestration et décisions                                │
│  - Délègue aux subagents pour les tâches spécialisées       │
└─────────────────┬───────────────────────────────────────────┘
                  │
     ┌────────────┼────────────┬────────────┐
     ▼            ▼            ▼            ▼
┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│ RooSync  │ │  GitHub  │ │ INTERCOM │ │   Code   │
│Coordinator│ │ Tracker │ │ Handler  │ │ Explorer │
└──────────┘ └──────────┘ └──────────┘ └──────────┘
```

### Subagents Disponibles ([.claude/agents/](.claude/agents/))

#### Agents Communs (toutes machines)

| Agent | Description | Modèle | Outils |
|-------|-------------|--------|--------|
| `git-sync` | Pull/merge conservatif, submodules | opus | Bash, Read, Grep |
| `test-runner` | Build TypeScript + tests unitaires | opus | Bash, Read, Edit |
| `github-tracker` | Suivi GitHub Project #67 | opus | MCP GitHub + Bash |
| `intercom-handler` | Communication locale Roo | opus | Read (plan mode) |
| `code-explorer` | Exploration codebase | opus | Read, Grep, Glob |

#### Agents Coordinateur (myia-ai-01 uniquement)

| Agent | Description | Usage |
|-------|-------------|-------|
| `roosync-hub` | Hub central : reçoit rapports, envoie instructions | Tour de sync, coordination |
| `dispatch-manager` | Assignation tâches aux 4 machines × 2 agents | Planification, ventilation |
| `task-planner` | Analyse avancement, équilibrage charge | Fin de phase, réflexion |

#### Agents Exécutants (autres machines)

| Agent | Description | Usage |
|-------|-------------|-------|
| `roosync-reporter` | Envoie rapports au coordinateur, reçoit instructions | Rapport de session |
| `task-worker` | Prend en charge tâches assignées, suit avancement | Exécution tâches |

**Invocation manuelle :**
```
# Sur myia-ai-01 (coordinateur)
Utilise roosync-hub pour traiter les rapports entrants
Utilise dispatch-manager pour assigner les tâches

# Sur autres machines (exécutants)
Utilise roosync-reporter pour envoyer mon rapport
Utilise task-worker pour prendre ma prochaine tâche
```

### Skill Disponible ([.claude/skills/](.claude/skills/))

| Skill | Description | Phases |
|-------|-------------|--------|
| `sync-tour` | Tour de sync complet en 8 phases | INTERCOM → Messages → Git → Tests → GitHub → MAJ → Planning → Réponses |

**Les 8 phases du sync-tour :**
0. **INTERCOM Local** : ⚠️ CRITIQUE - Lire messages de Roo EN PREMIER (merge en cours?, modifs locales?)
1. **Collecte** : Messages RooSync non-lus
2. **Git Sync** : Pull conservatif + résolution conflits automatique + submodules
3. **Validation** : Build + tests unitaires (+ corrections simples)
4. **GitHub Status** : Project #67 + issues récentes + incohérences
5. **MAJ GitHub** : Marquer Done, commentaires (validation utilisateur pour nouvelles issues)
6. **Planification** : Ventilation 5 machines × 2 agents (Roo + Claude)
7. **Réponses** : Messages RooSync personnalisés + gestion machines silencieuses

**Usage :** Demander un "tour de sync" ou "faire le point".

**⚠️ Améliorations récentes (2026-01-18) :**
- Phase 0 ajoutée : Toujours lire INTERCOM avant tout (détecter urgences Roo)
- Phase 2 enrichie : Résolution automatique conflits git (fichiers + submodule)
- Phase 5 renforcée : Validation utilisateur OBLIGATOIRE avant créer issues
- Phase 7 améliorée : Escalade machines silencieuses (48h/72h/96h)

### Slash Commands ([.claude/commands/](.claude/commands/))

| Commande | Machine | Description |
|----------|---------|-------------|
| `/coordinate` | myia-ai-01 | Lance une session de coordination multi-agent (amélioré 2026-01-18) |
| `/executor` | Autres machines | Lance une session d'exécution (workflow multi-itérations ajouté) |
| `/sync-tour` | Toutes | Tour de synchronisation complet (8 phases - Phase 0 ajoutée) |
| `/switch-provider` | Toutes | Basculer entre Anthropic et z.ai |

**Usage :**
- **Coordinateur (myia-ai-01)** : Taper `/coordinate` pour démarrer une session de coordination
- **Exécutants** : Taper `/executor` pour recevoir les instructions et exécuter les tâches

**⚠️ Améliorations coordinate.md (2026-01-18) :**
- Section "Gestion des Urgences" ajoutée (conflits git, machines silencieuses, tests échouants)
- Guide d'usage des sub-agents (quand utiliser, quand gérer directement)
- Workflow démarrage standard en 7 étapes (INTERCOM d'abord, puis sync-tour)

**⚠️ Améliorations executor.md (2026-01-18) :**
- Workflow multi-itérations (Investigation → Action → Validation)
- Collaboration Claude ↔ Roo optimisée (2 cerveaux en parallèle)
- Objectif : 3+ actions majeures par itération minimum

### Workflow Recommandé

1. **Début de session** : Demander un "tour de sync" → active le skill
2. **Pendant le travail** : Les agents s'activent automatiquement selon le contexte
3. **Tâches spécifiques** : Invoquer explicitement l'agent si besoin
4. **Fin de session** : Tour de sync + commit si nécessaire

---

## ✅ État des MCPs (2026-01-22)

### Harmonisation Multi-Machines Complétée

**Harmonisation H2-H7 (issues #331-#336) :**
- ✅ H2 (#331) - jupyter/jupyter-mcp → N/A (myia-web1 sans Jupyter)
- ✅ H4 (#333) - github-projects-mcp → Déjà déployé (configuration validée)
- ✅ H5 (#334) - markitdown MCP → Ajouté à toutes les machines
- 🔄 H6 (#335) - win-cli unbridled → En cours (myia-web1)
- ✅ H7 (#336) - jupyter-mcp-old → N/A (pas de legacy config)

### myia-ai-01 ✅ OPÉRATIONNEL

**MCPs Déployés :**

1. **github-projects-mcp** (57 outils)
   - Configuration : `~/.claude.json` (global)
   - **Statut :** ✅ Vérifié et fonctionnel
   - **Outils testés :** list_projects, get_project, get_project_items
   - **Projet :** "RooSync Multi-Agent Tasks" (#67)
   - **URL :** https://github.com/users/jsboige/projects/67

2. **roo-state-manager** (6 outils RooSync de messagerie)
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
     - 135 messages dans la boîte de réception (1 non-lu)

3. **markitdown** (1 outil)
   - Configuration : `~/.claude.json` (global)
   - **Statut :** ✅ Ajouté lors de H5 (#334)
   - **Outil :** `convert_to_markdown` - Convertir fichiers (PDF, DOCX, etc.) en markdown

### myia-web1 ✅ EN COURS D'HARMONISATION

**MCPs Déployés :**
- ✅ github-projects-mcp (57 outils)
- ✅ roo-state-manager (6 outils RooSync)
- ✅ markitdown (1 outil) - Ajouté le 2026-01-21
- 🔄 win-cli (en cours de déploiement)

**MCPs N/A :**
- N/A jupyter/jupyter-mcp (machine sans Jupyter)
- N/A jupyter-mcp-old (pas de legacy config)

### Autres machines (myia-po-2023, myia-po-2024, myia-po-2026)

**Statut :** ✅ Bootstrap complété, harmonisation en cours

**Action :**
- Harmonisation H2-H7 en cours de déploiement sur toutes les machines

---

## 🤖 Votre Rôle : Agent Claude Code

### Hiérarchie Claude ↔ Roo

**Claude Code est le cerveau principal.** Roo est un assistant polyvalent mais moins puissant.

| Aspect | Claude Code | Roo |
|--------|-------------|-----|
| **Intelligence** | Plus puissant (Opus 4.5) | Moins puissant (modèle variable) |
| **Autonomie** | Décisions critiques | Exécution supervisée |
| **Code** | Tout, y compris critique | Code simple, vérifié par Claude |
| **Orchestration** | Coordination globale | Tâches longues/répétitives |

### ✅ Claude Peut Tout Faire

**Capacités Techniques COMPLÈTES :**
- **Investigation bugs** : Lire le code, tracer les erreurs, identifier les causes racines
- **Analyse de code** : Comprendre l'architecture, comparer implémentations
- **Exécution tests** : `npm test`, diagnostiquer les erreurs, valider les fixes
- **Écriture de code** : Fixes, features, refactoring - TOUT niveau de complexité
- **Build** : Compiler, valider, identifier erreurs TypeScript
- **Modification `mcps/internal/`** : Oui, avec tests de validation

**Coordination :**
- **Documentation** : Consolidation, nettoyage, indexation
- **GitHub** : Issues, Projects #67/#70, traçabilité
- **RooSync** : Messages inter-machines
- **INTERCOM** : Communication locale avec Roo

**Outils :** Read, Grep, Glob, Bash, Edit, Write, Git

### 🔄 Utiliser Roo Comme Assistant

**Roo est utile pour :**
- Orchestrations longues (séquences de commandes)
- Tâches répétitives (bulk operations)
- Explorations préliminaires
- Exécution de scripts préparés par Claude

**⚠️ MAIS le code de Roo doit être vérifié par Claude :**
- Relire les modifications avant commit
- Valider la logique des changements
- Corriger les erreurs subtiles

### ❌ À NE PAS FAIRE

- **Confier les tâches critiques à Roo sans supervision**
- Supposer que le code de Roo est correct sans le vérifier
- Attendre passivement les instructions de Roo (c'est l'inverse)
- Inventer des workflows sans vérifier

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

### 4. Processus de Feedback et Amélioration Continue

**Objectif :** Améliorer les workflows (commands/skills/agents) basé sur l'expérience terrain

**Principe :** Évolution prudente et collective pour éviter le feature creep

**Workflow de proposition :**

1. **Identification** (n'importe quel agent Claude)
   - Repérer un problème/friction dans le workflow actuel
   - Documenter l'expérience concrète qui pose problème
   - Proposer une amélioration spécifique et minimaliste

2. **Consultation collective** (via RooSync)
   - Envoyer message RooSync à `to: "all"` avec:
     - Sujet: `[FEEDBACK] Amélioration proposée: <titre court>`
     - Contexte de l'expérience terrain
     - Proposition concrète
     - Risques de feature creep identifiés
   - Demander avis critique des autres agents (24-48h)

3. **Collecte des retours**
   - Chaque agent peut répondre avec son opinion
   - Focus sur: "Est-ce vraiment nécessaire?" et "Risques?"
   - Les agents servent de garde-fou contre le feature creep

4. **Décision finale** (coordinateur myia-ai-01)
   - Synthétiser les retours
   - Décision: APPROUVER / REJETER / MODIFIER
   - Si approuvé: créer issue GitHub pour traçabilité
   - Documenter la décision dans le thread RooSync

**Critères d'approbation :**
- ✅ Résout un problème réel rencontré (pas théorique)
- ✅ Solution minimale et ciblée
- ✅ Pas de complexité excessive
- ✅ Consensus ou majorité des agents
- ❌ Rejet si: feature creep, complexité, problème théorique

**Exemple de message RooSync :**
```markdown
Subject: [FEEDBACK] Amélioration sync-tour: Phase validation GitHub
Priority: MEDIUM
Tags: feedback, workflow-improvement

Contexte: Lors de mes 3 derniers sync-tours, j'ai dû manuellement vérifier
les issues fermées car la Phase 5 ne détectait pas les items marqués Done.

Proposition: Ajouter un check automatique des incohérences
(item Done sur GitHub mais issue Open).

Risques identifiés:
- Complexité accrue si on essaie de tout détecter
- Peut ralentir la Phase 5

Solution minimale: Ajouter 1 seule vérification pour le cas le plus fréquent.

Qu'en pensez-vous? Est-ce vraiment nécessaire?
```

**Documentation des améliorations :**
- Issue GitHub avec label `workflow-improvement`
- MAJ du fichier concerné (.claude/commands/, skills/, agents/)
- Note dans CLAUDE.md section "Leçons Apprises"

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
├── agents/                # 🆕 Subagents spécialisés
│   ├── coordinator/
│   │   ├── roosync-hub.md           # Messages RooSync (coordinateur)
│   │   └── dispatch-manager.md      # Assignment tâches
│   ├── executor/
│   │   ├── roosync-reporter.md      # Messages RooSync (exécutants)
│   │   └── task-worker.md           # Exécution tâches
│   ├── github-tracker.md       # GitHub Project #67
│   ├── git-sync.md             # Pull/merge conservatif
│   ├── test-runner.md          # Build + tests
│   ├── task-planner.md         # Ventilation 5×2 agents
│   ├── intercom-handler.md     # Communication locale Roo
│   └── code-explorer.md        # Exploration codebase
├── skills/                # 🆕 Skills auto-invoqués
│   └── sync-tour/SKILL.md
├── commands/              # Slash commands
│   └── switch-provider.md
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

## 🎯 Contexte Actuel

**⚠️ IMPORTANT** : L'état actuel du projet change quotidiennement.

**Pour l'état à jour, consulter dans cet ordre :**

1. **Git log** : `git log --oneline -10` - Historique réel des dernières actions
2. **GitHub Project #67** : https://github.com/users/jsboige/projects/67 - Avancement global (% Done)
3. **GitHub Issues** : Issues ouvertes et en cours
4. **INTERCOM local** : `.claude/local/INTERCOM-myia-ai-01.md` - Messages récents de Roo
5. **SUIVI_ACTIF.md** : [`docs/suivi/RooSync/SUIVI_ACTIF.md`](docs/suivi/RooSync/SUIVI_ACTIF.md) - Résumé minimal (peut être obsolète)

**Organisation bicéphale confirmée :**
- **Claude Code (myia-ai-01)** : Git, GitHub Projects, RooSync, Documentation, Coordination
- **Roo (toutes machines)** : Tâches techniques (bugs, features, tests, builds)

### Contraintes Critiques

- **NE PAS supposer que les MCPs sont disponibles** - tester d'abord
- **Utiliser les outils natifs Claude Code** - Read, Grep, Bash, Git
- **NE PAS inventer de workflows** - tester ce qui fonctionne réellement
- **Documenter la réalité** - ce qui est vérifié, pas ce qui est supposé
- **PAS de nouvelles fonctionnalités** - Focus déploiement et stabilisation

### ⚠️ Validation Utilisateur OBLIGATOIRE

**AVANT de créer une nouvelle tâche GitHub (#67 ou #70) :**
1. Présenter la tâche proposée à l'utilisateur
2. Expliquer pourquoi elle est nécessaire
3. Attendre validation explicite
4. Seulement ensuite créer l'issue

**Exception :** Bugs critiques bloquants (informer immédiatement)

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
| **myia-web1** | Agent flexible | ❌ À configurer |

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

1. **Git log** est la source de vérité pour les actions techniques
2. **GitHub Issues** pour le suivi des tâches et bugs
3. **RooSync** pour les messages urgents entre machines
4. **SUIVI_ACTIF.md** contient uniquement un résumé avec références git/github

---

## 📖 Règles de Documentation (NOUVEAU PARADIGME)

### Principes Fondamentaux

**Git/GitHub est la source principale de journalisation.**

| Type | Où | Comment |
|------|-----|---------|
| **Actions techniques** | Git commits | Messages clairs avec issue # |
| **Suivi de tâches** | GitHub Issues | Créer, commenter, fermer |
| **Progression** | GitHub Projects | Mettre à jour statut |
| **Coordination** | RooSync messages | Urgent uniquement |
| **Documentation** | docs/ pérenne | Se consolide, pas éphémère |

### ❌ À NE PLUS CRÉER

- Nouveaux rapports de "synthèse" ou "coordination" quotidiens
- Rapports de mission redondants avec git log
- Fichiers de suivi verbeux sans valeur ajoutée

### ✅ À MAINTENIR

| Fichier | Usage | MAJ |
|---------|-------|-----|
| `docs/suivi/RooSync/SUIVI_ACTIF.md` | Résumé minimal avec refs git | Quotidien |
| `docs/suivi/RooSync/BUGS_TRACKING.md` | Bugs et statuts | Quand bugs |
| `CLAUDE.md` | Ce fichier - Règles principales | Quand règles changent |
| `docs/roosync/*.md` | Documentation technique pérenne | Quand architecture change |

### Format des Commits

```bash
# Format conventionnel
type(scope): description

# Exemples
fix(roosync): Fix #289 - BOM UTF-8 in JSON parsing
docs(coord): Update CLAUDE.md with new governance rules
feat(roosync): Add baseline comparison feature
test(roosync): Add E2E tests for sync workflow

# Avec co-auteur (si Claude Code)
Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```

### Quand créer une GitHub Issue

- Nouveau bug identifié
- Nouvelle fonctionnalité significative
- Tâche de coordination multi-machine
- Documentation manquante critique

**Ne PAS créer d'issue pour:**
- Corrections triviales (directement commit)
- Mises à jour de documentation mineures
- Tests simples

### SUIVI_ACTIF.md - Format Minimal

```markdown
## 2026-01-13

- Bugs #289-291 assignés à Roo (voir #289, #290, #291)
- T1.2 complétée (commit f3e00f3)
- Git synchronisé (3bdb1c7e)

[voir git log --oneline -5]
```

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

**Dernière mise à jour :** 2026-01-18
**Pour questions :** Créer une issue GitHub ou contacter myia-ai-01

**Built with Claude Code (Opus 4.5) 🤖**

---

## 🔧 GitHub Projects MCP - IDs Critiques

**⚠️ IMPORTANT:** Toujours utiliser l'ID complet du projet, pas le numéro !

### Projets

| Projet | Numéro | ID Complet | Usage |
|--------|--------|------------|-------|
| RooSync Multi-Agent Tasks | #67 | `PVT_kwHOADA1Xc4BLw3w` | Tâches techniques Roo |
| RooSync Multi-Agent Coordination | #70 | `PVT_kwHOADA1Xc4BL7qS` | Coordination Claude |

### Field Status

- **Field ID:** `PVTSSF_lAHOADA1Xc4BLw3wzg7PYHY`
- **Options:**
  - `f75ad846` = Todo
  - `47fc9ee4` = In Progress
  - `98236657` = Done

### Exemple d'utilisation

```javascript
// Marquer une tâche Done
update_project_item_field({
  owner: "jsboige",
  project_id: "PVT_kwHOADA1Xc4BLw3w",  // ID complet, PAS "67"
  item_id: "PVTI_lAHOADA1Xc4BLw3wzgjKFOQ",
  field_id: "PVTSSF_lAHOADA1Xc4BLw3wzg7PYHY",
  field_type: "single_select",
  option_id: "98236657"  // Done
})
```

### État Projet #67 (2026-01-13)

- **Total:** 95 items
- **Done:** 12 (12.6%)
- **Todo:** 82
- **In Progress:** 1

---

## 📡 RooSync MCP - Configuration

### Outils Disponibles (après wrapper)

- `roosync_send_message` - Envoyer message
- `roosync_read_inbox` - Lire boîte de réception
- `roosync_reply_message` - Répondre
- `roosync_get_message` - Message complet
- `roosync_mark_message_read` - Marquer comme lu
- `roosync_archive_message` - Archiver

### Fichier Partagé

**Chemin:** `G:/Mon Drive/Synchronisation/RooSync/.shared-state/`
