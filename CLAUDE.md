# Roo Extensions - Guide pour Agents Claude Code

**Repository:** [jsboige/roo-extensions](https://github.com/jsboige/roo-extensions)
**Systeme:** RooSync v2.3 Multi-Agent Coordination (6 machines)
**Derniere mise a jour:** 2026-03-19

---

## Vue d'ensemble

Systeme multi-agent coordonnant **Roo Code** (technique) et **Claude Code** (coordination & documentation) sur 6 machines :

**Machines :** `myia-ai-01`, `myia-po-2023`, `myia-po-2024`, `myia-po-2025`, `myia-po-2026`, `myia-web1`

**Architecture :** Coordination bicephale
- **Roo Code** → Taches techniques subalternes (scripts, tests, build, cleanup) + scheduler autonome
- **Claude Code** → Implementation, coordination, code critique, documentation

---

## Demarrage Rapide

### Nouvelle conversation sur cette machine :

1. `git pull`
2. Lire ce fichier (CLAUDE.md)
3. **CRITIQUE : Verifier les MCP disponibles** (system-reminders au debut de conversation). Si roo-state-manager absent → STOP & REPAIR immediatement (voir [`.claude/rules/tool-availability.md`](.claude/rules/tool-availability.md)). Note: win-cli est pour Roo Scheduler uniquement, pas Claude Code.

### Autre machine :

1. Identifier la machine : `hostname`
2. Documentation : [`.claude/INDEX.md`](.claude/INDEX.md)
3. MCPs : [`.claude/MCP_SETUP.md`](.claude/MCP_SETUP.md)

---

## Agents, Skills & Commands

**Reference complete :** [`.claude/rules/agents-architecture.md`](.claude/rules/agents-architecture.md)

**Essentiel :**
- 18 subagents projet (5 communs + 2 coordinateur + 11 workers) + 6 globaux (`~/.claude/agents/`)
- 6 skills (sync-tour, validate, git-sync, github-status, redistribute-memory, debrief)
- 4 commands (/coordinate, /executor, /switch-provider, /debrief)
- 10 rules auto-chargées (`.claude/rules/`) + 14 docs de référence on-demand (`.claude/docs/`)

**Workflow :**
1. Debut de session → "tour de sync" (9 phases)
2. Pendant → agents s'activent selon contexte
3. Fin → `/debrief` + commit

---

## Etat des MCPs

### Verification Critique au Demarrage (STOP & REPAIR)

**OBLIGATION :** Verifier que les outils MCP critiques sont disponibles.
Si ABSENTS : **STOP IMMEDIAT** → Entrer en mode reparation. AUCUN autre travail tant que les outils ne sont pas restaures.

**Protocole complet :** [`.claude/rules/tool-availability.md`](.claude/rules/tool-availability.md)

**MCPs CRITIQUES :**

**Pour Claude Code :**

| MCP | Outils attendus | Verification | Note |
|-----|-----------------|-------------|------|
| **roo-state-manager** | 34 | `conversation_browser(action: "current")` | Coordination, grounding conversationnel |

**Pour Roo Scheduler (bloque sans eux) :**

| MCP | Outils attendus | Verification | Note |
|-----|-----------------|-------------|------|
| **win-cli** | 9 (fork local 0.2.0) | `execute_command(shell="powershell", command="echo OK")` | Terminal shell (modes -simple n'ont plus le groupe `command` depuis b91a841c) |

**Note importante :** win-cli est critique pour **Roo Scheduler uniquement** (depuis cleanup #658, 2026-03-13). Claude Code utilise l'outil `Bash` natif pour les commandes shell.

**MCPs Standards :**

| MCP | Outils | Statut |
|-----|--------|--------|
| **sk-agent** | 7 + deprecated aliases | Deploye (fix #482) |
| **markitdown** | 1 (convert_to_markdown) | Deploye |
| **playwright** | 22 | Deploye |
| **GitHub CLI** (`gh`) | N/A (CLI natif) | Operationnel |

**MCPs RETIRES (NE DOIVENT PAS etre presents) :** desktop-commander, quickfiles, github-projects-mcp

### Configuration Claude Code

| Niveau | Fichier | Portee |
|--------|---------|--------|
| Global utilisateur | `~/.claude/CLAUDE.md` | Tous les projets |
| **Config MCP** | **`C:\Users\{user}\.claude.json`** | **MCP servers (playwright, win-cli, roo-state-manager, etc.)** |
| Projet | `CLAUDE.md` (racine) | Ce projet |
| **Permissions partagees** | **`.claude/settings.json`** | **Permissions auto-approve, git-tracked (#746)** |
| Permissions locales | `.claude/settings.local.json` | Overrides machine (gitignored) |
| Auto-memoire | `~/.claude/projects/<hash>/memory/MEMORY.md` | Prive, local |
| Memoire partagee | `.claude/memory/PROJECT_MEMORY.md` | Via git |
| Rules | `.claude/rules/*.md` | Projet, auto-chargees |

**⚠️ CRITIQUE :** Si un MCP est indisponible pour Claude Code, verifier `C:\Users\{user}\.claude.json` section `mcpServers`. Exemple :

```json
"mcpServers": {
  "roo-state-manager": {
    "command": "node",
    "args": ["D:\\Dev\\roo-extensions\\mcps\\internal\\servers\\roo-state-manager\\mcp-wrapper.cjs"],
    "cwd": "D:\\Dev\\roo-extensions\\mcps\\internal\\servers\\roo-state-manager\\"
  }
}
```

### Configuration Roo

**⚠️ CRITIQUE : Les MCPs Roo sont definis dans un fichier GLOBAL, pas dans .roo/mcp.json !**

**Fichier GLOBAL Roo (VERITE) :**
```
%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json
```
**CECI est le fichier qui contient jupyter-mcp, jinavigator, etc.**

**Fichier PROJET (.roo/mcp.json) :**
```
.roo/mcp.json
```
Ceci est un fichier de OVERRIDES pour les MCPs du PROJET roo-extensions uniquement.

**NE PAS CONFONDRE :**
- jupyter-mcp → Verifier dans `mcp_settings.json` (GLOBAL) PAS dans `.roo/mcp.json`
- jinavigator → Verifier dans `mcp_settings.json` (GLOBAL) PAS dans `.roo/mcp.json`

**MCPs actuels dans mcp_settings.json (myia-web1, 2026-03-02) :**
- jupyter-mcp (ACTIF, 20 outils)
- jinavigator (ACTIF, 2 outils)
- playwright (ACTIF, 22 outils)
- searxng (ACTIF, 2 outils)
- win-cli (ACTIF, fork local 0.2.0)
- roo-state-manager (ACTIF, 34 outils)

- **MAJ alwaysAllow :** `roosync_mcp_management(subAction: "sync_always_allow")`
- **MAJ unitaire :** `roosync_mcp_management(subAction: "update_server_field")`
- **Settings generaux :** Template `roo-config/settings/settings.json`, deploy via `deploy-settings.ps1`

---

## Votre Role : Agent Claude Code

### Hierarchie Claude <-> Roo

**REGLE FONDAMENTALE : Claude Code DIRIGE, Roo ASSISTE.**

| Aspect | Claude Code | Roo |
|--------|-------------|-----|
| Intelligence | Plus puissant (Opus 4.6) | Moins puissant (variable) |
| Fiabilite | Elevee | Moyenne |
| Code | Tout, y compris critique | Simple, VALIDE par Claude |
| Orchestration | Coordination globale | Taches longues/repetitives |

### Claude fait :
- Implementation de code (features, fixes, refactoring)
- Investigation de bugs et analyse de code
- Decisions d'architecture
- Resolution de conflits git
- Validation et correction du travail de Roo

### Roo fait (sous supervision) :
- Tests (`npx vitest run`), build (`npm run build`)
- Scripts prepares par Claude
- Taches repetitives, documentation simple

### Regles critiques

- **TOUJOURS** relire les modifications de Roo avant commit
- **JAMAIS** faire confiance aveuglement au code de Roo
- **JAMAIS** rester inactif en attente de travail (consulter GitHub #67, RooSync, INTERCOM)
- **JAMAIS** deleguer l'implementation de code critique a Roo

### Verification des rapports (CRITIQUE)

**Reference :** [`.claude/rules/skepticism-protocol.md`](.claude/rules/skepticism-protocol.md)

Quand un agent rapporte un fait surprenant (GPU insuffisante, outil casse, "impossible"), le verifier AVANT de le propager dans les dispatches. Le cout d'une verification est negligeable compare au cout d'une erreur amplifiee sur 6 machines. Qualifier chaque affirmation : VERIFIE / RAPPORTE PAR [source] / SUPPOSE.

### Contrainte cle

Pas d'acces a l'historique de conversation. Utiliser :
- **GitHub Issues** comme memoire externe
- **RooSync** pour la coordination inter-machine
- **INTERCOM** pour la coordination locale

---

## Canaux de Communication

### REGLE ABSOLUE - NE JAMAIS CONFONDRE

| Canal | Portee | Usage | Outil |
|-------|--------|-------|-------|
| **RooSync** | **INTER-MACHINES et INTER-WORKSPACES** | Messages entre machines differentes OU entre workspaces differents sur la meme machine | MCP `roosync_send/read/manage` via roo-state-manager |
| **INTERCOM** | **INTRA-WORKSPACE UNIQUEMENT** | Communication locale entre Roo et Claude Code dans le MEME workspace sur la MEME machine | Fichier `.claude/local/INTERCOM-{MACHINE}.md` |

**"Verifie tes messages" = verifie RooSync inbox (`roosync_read`), PAS l'INTERCOM.**
**L'INTERCOM n'est PAS un canal de messagerie inter-machines.**

**Les deux agents (Roo ET Claude Code) utilisent RooSync pour communiquer entre machines.** Chaque agent peut envoyer et recevoir des messages RooSync independamment.

**Exceptions (cas particuliers) :**

- Si RooSync est indisponible (GDrive offline) → utiliser GitHub Issues ou INTERCOM local comme fallback temporaire
- Si l'utilisateur donne une instruction explicite de canal different → suivre l'instruction
- En dehors de ces exceptions : toujours RooSync pour inter-machine, toujours INTERCOM pour local

### 1. RooSync (Inter-Machine / Inter-Workspace)

Outils MCP (CONS-1) :
- `roosync_send` - Envoyer/repondre/amender (action: send|reply|amend)
- `roosync_read` - Lire inbox/message (mode: inbox|message)
- `roosync_manage` - Gerer messages (action: mark_read|archive)

Fichier partage : `G:/Mon Drive/Synchronisation/RooSync/.shared-state/`

### 2. Dashboards RooSync (3 niveaux)

Les dashboards sont geres via `roosync_dashboard` (MCP). Stockes sur GDrive, partages cross-machine. **PAS de fichier local improvise.**

**REGLE CRITIQUE : Le dashboard `workspace` est le PRINCIPAL canal de coordination. C'est la que le coordinateur poste les taches, les executeurs rapportent leur avancement, et tout le monde se synchronise.**

| Type | Portee | Usage | Commande |
|------|--------|-------|----------|
| **`global`** | Cluster entier | Sommaire global, references vers les autres dashboards | `roosync_dashboard(action: "read", type: "global")` |
| **`workspace`** | **CROSS-MACHINE** | **DASHBOARD PRINCIPAL** — Coordination entre machines pour ce workspace. Dispatches, progression, alertes. | `roosync_dashboard(action: "read", type: "workspace")` |
| **`machine`** | Par machine | Hardware, MCPs, services, sante de la machine | `roosync_dashboard(action: "read", type: "machine")` |

**Actions disponibles :** `read`, `write` (remplace le status), `append` (ajoute un message intercom), `condense`, `list`, `delete`, `read_archive`

**Protocole de session :**
1. `roosync_dashboard(action: "read", type: "workspace")` — Lire le dashboard PRINCIPAL (taches, dispatches, alertes)
2. Prendre une tache, travailler
3. Rapporter via `roosync_dashboard(action: "append", type: "workspace", tags: ["DONE", "claude-interactive"], content: "...")`

**Fallback fichier local (si MCP echoue) :** `.claude/local/INTERCOM-{MACHINE_NAME}.md`
Types de tags : `INFO`, `TASK`, `DONE`, `WARN`, `ERROR`, `ASK`, `REPLY`

### 3. GitHub Issues

Projet : "RooSync Multi-Agent Tasks" (#67)
URL : https://github.com/users/jsboige/projects/67
Format : `[CLAUDE-MACHINE] Titre` + labels

#### Labels GitHub

Labels disponibles pour catégoriser les issues. Utiliser `gh label list` pour voir la liste complète.

**⚠️ IMPORTANT :** Toujours vérifier qu'un label existe avant de l'utiliser. Les labels suivants **N'EXISTENT PAS** et ne doivent PAS être utilisés : `maintenance`, `scheduler`, `memory`.

**Labels de type (obligatoire pour chaque issue):**

| Label | Description | Quand l'utiliser |
|-------|-------------|------------------|
| `bug` | Something isn't working | Comportement incorrect, erreur, crash |
| `enhancement` | New feature or request | Feature request, amélioration |
| `documentation` | Improvements or additions to documentation | MAJ docs, README, guides |

**Labels techniques (optionnels):**

| Label | Description |
|-------|-------------|
| `critical` | Issues critiques bloquantes |
| `regression` | Regression bugs |
| `harness-change` | Modifies agent infrastructure (rules, workflows, modes) |
| `harness-inconsistency` | Incohérence entre les harnais Roo et Claude |
| `quality` | Code quality and reliability |
| `testing` | Test coverage and infrastructure |
| `test` | Test coverage (alias de testing) |
| `investigation` | Investigation and audit tasks |
| `friction` | Problème ou friction découverte |
| `harness-inconsistency` | Incohérence entre les harnais Roo et Claude |

**Labels d'attribution (un seul par issue):**

| Label | Agent concerné |
|-------|----------------|
| `claude-only` | Réservé Claude Code (opus/sonnet) - NOT for Roo schedulers |
| `roo-schedulable` | Peut être exécuté par scheduler Roo autonomously |

**Labels de validation (gérés automatiquement):**

| Label | Description |
|-------|-------------|
| `needs-approval` | Requires user approval before execution |
| `needs-deployment-checklist` | Requires deployment checklist validation before closing |
| `good first issue` | Good for newcomers |
| `help wanted` | Extra attention is needed |

**Labels de statut (gérés automatiquement):**

| Label | Description |
|-------|-------------|
| `wontfix` | This will not be worked on |
| `duplicate` | This issue or pull request already exists |
| `invalid` | This doesn't seem right |
| `question` | Further information is requested |

**⚠️ LABELS INEXISTANTS (NE JAMAIS UTILISER) :**

- `maintenance` → N'existe pas (utiliser `documentation` ou `quality`)
- `scheduler` → N'existe pas (utiliser `roo-schedulable` ou `harness-change`)
- `memory` → N'existe pas (utiliser `documentation` ou `harness-change`)

**Verifier les labels disponibles :** `gh label list --repo jsboige/roo-extensions`

### 4. Scheduler Roo

**Reference complete :** [`docs/roo-code/SCHEDULER_SYSTEM.md`](docs/roo-code/SCHEDULER_SYSTEM.md)

Essentiel : Extension `kylehoskins.roo-scheduler`, intervalle 3h, 10 modes (5 familles x 2 niveaux), escalade automatique.

### 5. Feedback

**Reference :** [`.claude/docs/feedback-process.md`](.claude/docs/feedback-process.md)

---

## Structure du Depot

```
.claude/
  rules/              # 10 regles auto-chargees (operationnelles, chaque conversation)
  docs/               # 14 docs de reference on-demand (lues quand pertinent)
  agents/             # Subagents specialises (coordinator/, executor/, workers/)
  skills/             # Skills auto-invoques (sync-tour, validate, git-sync, etc.)
  commands/           # Slash commands (coordinate, executor, switch-provider, debrief)
  memory/             # Memoire partagee (PROJECT_MEMORY.md)
  local/              # Communication locale gitignored (INTERCOM)

docs/                 # Documentation technique perenne (10 repertoires actifs)

mcps/
  internal/servers/   # roo-state-manager (TS) + sk-agent (Python)
  external/           # MCPs externes (12 serveurs)

roo-code/             # Submodule git (DOCUMENTATION ONLY - voir ci-dessous)

roo-config/
  modes/              # Source des modes Roo (modes-config.json + templates)
  scripts/            # generate-modes.js, Deploy-Modes.ps1
  settings/           # Templates settings Roo
```

### ⚠️ Submodule `roo-code/` = REFERENCE UNIQUEMENT

Le repertoire `roo-code/` est un **submodule git** pointant vers le code source de Roo Code.

**Ce qu'il EST :**
- Une reference pour lire et comprendre le code source de Roo (schemas Zod, types, logique interne)
- Synchronise avec upstream via `git fetch upstream && git merge upstream/main`

**Ce qu'il N'EST PAS :**
- PAS l'environnement d'execution (Roo tourne via l'extension VS Code installee separement)
- PAS un environnement de build (pas de `npm install`, pas de `node_modules` utilisables)
- PAS la version de Roo qui tourne sur les machines (celle-ci est dans les extensions VS Code)
- PAS une source de dependances npm (ne JAMAIS chercher des packages dans `roo-code/node_modules/`)

**Pipeline des modes Roo :**
```
roo-config/modes/modes-config.json     →  generate-modes.js  →  .roomodes (JSON, local)
                                       →  generate-modes.js --format yaml  →  custom_modes.yaml (YAML, global)
                                       →  Deploy-Modes.ps1 -DeploymentType global  →  %APPDATA%/.../custom_modes.yaml
```

### Architecture des Modes Roo (CRITIQUE - NE PAS CONFONDRE)

**3 types de modes avec des droits differents :**

| Type | Exemples | Groupes | Terminal | MCPs |
|------|----------|---------|----------|------|
| **Orchestrateurs** | `orchestrator-simple`, `orchestrator-complex` | `[]` (aucun) | NON | NON |
| **Modes -simple** | `code-simple`, `debug-simple`, `ask-simple` | `["read","edit","browser","mcp"]` | **NON** (pas de groupe `command`) | **OUI** (dont win-cli) |
| **Modes -complex** | `code-complex`, `debug-complex` | `["read","edit","browser","command","mcp"]` | **OUI** (natif) | **OUI** |

**Regles fondamentales :**

1. **Orchestrateurs = delegation pure.** Ils n'ont AUCUN outil. Ils utilisent uniquement `new_task` pour deleguer aux modes de travail. S'ils tentent d'utiliser un outil, c'est un bug de harnais.

2. **Modes -simple = win-cli comme terminal.** Ils n'ont PAS le groupe `command` (terminal natif Roo). Leur unique acces shell est via le MCP win-cli (`execute_command`). C'est un outil MCP (groupe `mcp`), PAS le terminal natif (groupe `command`). **Si une trace montre `"Tool execute_command is not allowed in code-simple mode"`, ca signifie que le modele a tente d'utiliser le terminal natif au lieu de win-cli MCP** — c'est un probleme de confusion du modele, pas un probleme de configuration.

3. **Modes -complex = tout.** Ils ont le terminal natif ET les MCPs.

**Erreur recurrente des agents :** Confondre `execute_command` natif (groupe `command`, bloque en `-simple`) avec `execute_command` via win-cli MCP (groupe `mcp`, autorise en `-simple`). Meme nom d'outil, deux sources differentes.

**Config dans `modes-config.json` :**
- `"groups": ["read","edit","browser","mcp"]` = mode -simple (pas de `command`)
- `"useWinCli": true` = flag indiquant que le template doit inclure les instructions win-cli dans customInstructions

---

## Pour Demarrer une Nouvelle Tache

1. **Verifier MCP** : Outils disponibles dans system-reminders
2. **Lire doc** : INDEX.md, MCP_SETUP.md, rules/ (auto-chargées)
3. **Communications (OBLIGATOIRE)** : **RooSync inbox en PREMIER** (`roosync_read(mode: "inbox", status: "unread")`) + INTERCOM local + GitHub issues. **Ne JAMAIS declarer une machine "silencieuse" sans avoir verifie l'inbox RooSync.**
4. **Annoncer** : INTERCOM local + RooSync `[WORK]` + commentaire GitHub
5. **Issue GitHub** : Obligatoire pour toute tache significative
6. **Travailler** : Tester les MCPs, documenter la realite

---

## Contexte Actuel

**L'etat change quotidiennement. Consulter dans cet ordre :**
1. **RooSync inbox** : `roosync_read(mode: "inbox", status: "unread")` — Messages des autres machines (OBLIGATOIRE, ne jamais sauter)
2. `git log --oneline -10` — Historique reel des dernieres actions
3. GitHub Project #67
4. GitHub Issues ouvertes
5. INTERCOM local
6. SUIVI_ACTIF.md (peut etre obsolete)

### Contraintes

- NE PAS supposer que les MCPs sont disponibles - tester
- NE PAS inventer de workflows - tester ce qui marche
- Documenter la realite, pas les hypotheses
- Validation utilisateur OBLIGATOIRE avant creer issues GitHub

### Checklist de Validation Technique

**Reference complete :** [`.claude/rules/validation.md`](.claude/rules/validation.md)

---

## Coordination Multi-Agent

### Repartition des Machines

| Machine | Role | Statut |
|---------|------|--------|
| **myia-ai-01** | Coordinateur Principal | GitHub + RooSync + Jupyter |
| **myia-po-2023** | Agent flexible | GitHub + RooSync + Jupyter |
| **myia-po-2024** | Agent flexible | GitHub + RooSync + Jupyter |
| **myia-po-2025** | Agent flexible | GitHub + RooSync + Jupyter |
| **myia-po-2026** | Agent flexible | GitHub + RooSync + Jupyter |
| **myia-web1** | Agent flexible | GitHub + RooSync (16GB RAM) |

### Communication Quotidienne

1. **RooSync inbox** = messages des autres machines (TOUJOURS verifier en PREMIER — ne jamais declarer une machine inactive sans avoir lu l'inbox)
2. **Git log** = source de verite technique
3. **GitHub Issues** = suivi taches et bugs
4. **INTERCOM local** = communication Roo <-> Claude Code (meme machine)
5. **DASHBOARD.md** = dashboard hiérarchique (remplace SUIVI_ACTIF.md depuis #546)

---

## Regles de Documentation

**Git/GitHub est la source principale de journalisation.**

### A ne plus creer
- Rapports de synthese/coordination quotidiens
- Rapports de mission redondants avec git log
- Fichiers de suivi verbeux

### A maintenir

| Fichier | Usage |
|---------|-------|
| `docs/suivi/RooSync/SUIVI_ACTIF.md` | Resume minimal |
| `CLAUDE.md` | Regles principales |
| `docs/roosync/*.md` | Documentation technique perenne |

### Methodologie SDDD

**Reference complete :** [`.claude/rules/sddd-conversational-grounding.md`](.claude/rules/sddd-conversational-grounding.md)

Triple grounding : Semantique + Conversationnel + Technique. Ne jamais se contenter d'une seule source.

---

## GitHub CLI

**Reference complete :** [`.claude/rules/github-cli.md`](.claude/rules/github-cli.md)

Essentiel : `gh issue`, `gh pr`, `gh api graphql`. Scope `project` requis. Project #67 = `PVT_kwHOADA1Xc4BLw3w`.

---

## Ressources

- [`docs/knowledge/WORKSPACE_KNOWLEDGE.md`](docs/knowledge/WORKSPACE_KNOWLEDGE.md) - Base connaissance
- [`docs/roosync/GUIDE-TECHNIQUE-v2.3.md`](docs/roosync/GUIDE-TECHNIQUE-v2.3.md) - Guide RooSync
- [`.claude/scripts/init-claude-code.ps1`](.claude/scripts/init-claude-code.ps1) - Initialisation MCP
- **GitHub :** https://github.com/users/jsboige/projects/67

---

## Règles Auto-chargées (`.claude/rules/`)

Les règles ci-dessous sont automatiquement chargées dans chaque conversation. Elles s'appliquent sans action explicite.

### Règles Critiques (sécurité & qualité)

| Règle | Description | Fichier |
|-------|-------------|---------|
| **Tool Availability** | STOP & REPAIR si MCP critique absent. Non-négociable. | `.claude/rules/tool-availability.md` |
| **Validation** | Checklist validation consolidation (comptage avant/après). | `.claude/rules/validation.md` |
| **No Deletion Without Proof** | Jamais supprimer sans preuve de préservation. | `.claude/rules/no-deletion-without-proof.md` |
| **PR Mandatory** | Zéro push direct sur main. PR obligatoire. | `.claude/rules/pr-mandatory.md` |
| **CI Guardrails** | Valider build + tests CI avant push submodule. | `.claude/rules/ci-guardrails.md` |

### Règles Opérationnelles

| Règle | Description | Fichier |
|-------|-------------|---------|
| **SDDD Grounding** | Triple grounding (sémantique + conversationnel + technique). Bookend obligatoire. | `.claude/rules/sddd-conversational-grounding.md` |
| **Delegation** | Déléguer aux sub-agents si autonome, parallélisable. Contexte isolé. | `.claude/rules/delegation.md` |
| **File Writing** | Edit > Write. Read obligatoire avant. Encodage UTF-8 no-BOM. | `.claude/rules/file-writing.md` |
| **GitHub CLI** | `gh` CLI au lieu de MCP github-projects. Scope `project` requis. | `.claude/rules/github-cli.md` |
| **Test Success Rates** | `npx vitest run` (JAMAIS `npm test`). web1: `--maxWorkers=1`. | `.claude/rules/test-success-rates.md` |

### Règles Communication

| Règle | Description | Fichier |
|-------|-------------|---------|
| **INTERCOM Protocol** | Dashboard workspace = canal principal. Fichier local = DEPRECATED. | `.claude/rules/intercom-protocol.md` |
| **Skepticism Protocol** | Vérifier les affirmations surprenantes avant de propager. | `.claude/rules/skepticism-protocol.md` |

### Règles Contexte

| Règle | Description | Fichier |
|-------|-------------|---------|
| **Context Window** | Seuil condensation 80% pour GLM (131K réels). | `.claude/rules/context-window.md` |
| **Worktree Cleanup** | Script cleanup orphelins + branches stale. | `.claude/rules/worktree-cleanup.md` |
| **Agents Architecture** | 18 subagents, 6 skills, 4 commands. | `.claude/rules/agents-architecture.md` |

---

## Documents de Reference (on-demand)

Les documents ci-dessous sont dans `.claude/docs/` (PAS auto-charges). Les consulter quand le sujet est pertinent.

### Protocoles et Processus

| Document | Essentiel a retenir | Chemin |
|----------|-------------------|--------|
| **Condensation GLM** | Seuil **80%** pour z.ai (contexte reel 131K, pas 200K). `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=80` | `.claude/docs/condensation-thresholds.md` |
| **Checklists GitHub** | Ne JAMAIS fermer une issue avec tableau vide. Cocher AU FUR ET A MESURE. | `.claude/docs/github-checklists.md` |
| **Feedback/Friction** | Signaler via RooSync `[FRICTION]` to:all. Evolution prudente. | `.claude/docs/feedback-process.md`, `.claude/docs/friction-protocol.md` |
| **Escalade Claude Code** | 5 niveaux (outils → sub-agent → sk-agent → SDDD → utilisateur). Claude EST deja Opus 4.6 (pas d'escalade CLI/API). | `.claude/docs/escalation-protocol.md` |
| **Context Window** | Seuil de condensation 80% OBLIGATOIRE pour GLM (z.ai). | `.claude/rules/context-window.md` |

### Quality & CI

| Document | Essentiel a retenir | Chemin |
|----------|-------------------|--------|
| **CI Guardrails** | Validation OBLIGATOIRE avant push du submodule. Build + tests CI doivent passer. | `.claude/rules/ci-guardrails.md` |
| **PR Mandatory** | Zero push direct sur main. Tout changement passe par worktree → PR → review → merge. | `.claude/rules/pr-mandatory.md` |
| **No Deletion Without Proof** | Interdiction de supprimer du code sans preuve que la fonctionnalité est preservee. | `.claude/rules/no-deletion-without-proof.md` |
| **Test Success Rates** | Taux de succes attendu : 99.8% (ai-01), 99.6% (autres). Toujours `npx vitest run`. | `.claude/rules/test-success-rates.md` |

### Coding Standards

| Document | Essentiel a retenir | Chemin |
|----------|-------------------|--------|
| **File Writing Patterns** | Edit pour modifications, Write pour nouveaux fichiers. Jamais ecraser sans lecture prealable. | `.claude/rules/file-writing.md` |
| **Validation Checklist** | Pour toute consolidation/refactoring : compter avant/apres, verifier ecart. | `.claude/rules/validation.md` |

### Scheduler & Coordination

| Document | Essentiel a retenir | Chemin |
|----------|-------------------|--------|
| **Scheduler system** | 10 modes (5 familles x 2 niveaux). Orchestrateurs = 0 outils. Pipeline: modes-config.json → generate-modes.js → .roomodes | `.claude/docs/reference/scheduler-system.md` |
| **Scheduler densification** | Sweet spot escalade : 2 echecs en -simple → escalader vers -complex | `.claude/docs/reference/scheduler-densification.md` |
| **Coordinator protocol** | Cycle 6-12h sur ai-01. Analyse RooSync + git + Project #67. | `.claude/docs/coordinator-specific/scheduled-coordinator.md` |
| **Meta-analysis** | Cycle 72h. Triple grounding. META-INTERCOM separe. Guard rails: lecture seule. | `.claude/docs/reference/meta-analysis.md` |

### Reference Technique

| Document | Essentiel a retenir | Chemin |
|----------|-------------------|--------|
| **PR review policy** | Agents → PR → Review coordinateur → Merge. Jamais push direct sur main. | `.claude/docs/coordinator-specific/pr-review-policy.md` |
| **Incidents** | Lecons cles : cross-machine check apres config, STOP & REPAIR, CI avant push | `.claude/docs/reference/incident-history.md` |
| **roo-schedulable** | Seulement taches subalternes (tests, validation, docs, cleanup) | `.claude/docs/reference/roo-schedulable-criteria.md` |
| **Bash fallback** | Si Bash echoue : outils natifs > MCP win-cli > degradation gracieuse | `.claude/docs/reference/bash-fallback.md` |
| **MCP discoverability** | Tests decouverte en 3 phases : visibilite, fonctionnalite, integration | `.claude/docs/reference/mcp-discoverability.md` |
| **Web1 contraintes** | 16GB RAM, `--maxWorkers=1`, path GDrive different, fork win-cli local | `.claude/docs/machine-specific/myia-web1-constraints.md` |
| **Stub Detection** | CI gate pour detecter les exports stub (return null, TODO non implementes). | `.claude/docs/reference/stub-detection.md` |
| **Worktree Cleanup** | Protocol de gestion des worktrees git (auto-cleanup + garbage collection). | `.claude/rules/worktree-cleanup.md` (auto-chargé) |

---

## Regles Absolues

1. **Etat partage RooSync = GDrive UNIQUEMENT** (jamais dans le depot Git)
2. **INTERCOM pour communication locale** (Roo <-> Claude Code meme machine), **RooSync pour inter-machine** (les deux agents peuvent l'utiliser)
3. **Ne JAMAIS modifier `.roomodes` ou `.roo/schedules.json` directement** (modifier sources + regenerer)
4. **Validation checklist OBLIGATOIRE** pour consolidation/refactoring
5. **Annoncer son travail** avant de commencer (anti-conflit)
6. **STOP & REPAIR si outil critique absent** : Verifier roo-state-manager (Claude Code) ou win-cli (Roo) au demarrage. Si absent → arreter, reparer, escalader. Voir [`.claude/rules/tool-availability.md`](.claude/rules/tool-availability.md)
7. **Verification cross-machine OBLIGATOIRE** apres tout changement de config (modes, MCPs, workflows)
8. **Scepticisme raisonnable** : Ne JAMAIS propager une affirmation non verifiee. Croiser les rapports d'agents avec les faits connus (git log, tables infra, tests). Voir [`.claude/rules/skepticism-protocol.md`](.claude/rules/skepticism-protocol.md)
9. **VS Code restart requis** : Apres modification de `.roo/schedules.json` (ou schedules.template.json), demander a l'utilisateur de redemarrer VS Code pour que le Roo scheduler prenne en compte les nouvelles instructions.
10. **Worktree cleanup** : Utiliser les worktrees git pour les branches temporaires. Nettoyer apres usage. Voir [`.claude/rules/worktree-cleanup.md`](.claude/rules/worktree-cleanup.md)
11. **🚨 JAMAIS DE CLÉS API DANS GITHUB** : Les clés API, tokens, secrets ne doivent JAMAIS apparaître dans issues, PRs, commentaires, commits. **Si une clé doit être partagée → RooSync message (GDrive privé)**. Voir [`.claude/rules/no-api-keys-in-git.md`](.claude/rules/no-api-keys-in-git.md)

---

**Communication locale (fallback) :**

Voir [`.claude/rules/intercom-protocol.md`](.claude/rules/intercom-protocol.md) pour le protocole de communication locale Claude Code ↔ Roo (INTERCOM fichier, deprecated au profit du dashboard RooSync).

---

**Derniere mise a jour :** 2026-03-26
**Pour questions :** Creer une issue GitHub ou contacter myia-ai-01
