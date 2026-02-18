# Roo Extensions - Guide pour Agents Claude Code

**Repository:** [jsboige/roo-extensions](https://github.com/jsboige/roo-extensions)
**Systeme:** RooSync v2.3 Multi-Agent Coordination (6 machines)
**Derniere mise a jour:** 2026-02-19

---

## Vue d'ensemble

Systeme multi-agent coordonnant **Roo Code** (technique) et **Claude Code** (coordination & documentation) sur 6 machines :

**Machines :** `myia-ai-01`, `myia-po-2023`, `myia-po-2024`, `myia-po-2025`, `myia-po-2026`, `myia-web1`

**Architecture :** Coordination bicephale
- **Roo Code** → Taches techniques (scripts, tests, build)
- **Claude Code** → Documentation, coordination, reporting

---

## Demarrage Rapide

### Nouvelle conversation sur cette machine :

1. `git pull`
2. Lire ce fichier (CLAUDE.md)
3. Verifier les MCP disponibles (system-reminders au debut de conversation)

### Autre machine :

1. Identifier la machine : `hostname`
2. Documentation : [`.claude/INDEX.md`](.claude/INDEX.md)
3. MCPs : [`.claude/MCP_SETUP.md`](.claude/MCP_SETUP.md)

---

## Agents, Skills & Commands

**Reference complete :** [`.claude/rules/agents-architecture.md`](.claude/rules/agents-architecture.md)

**Essentiel :**
- 12 subagents (communs + coordinateur + executants + workers)
- 6 skills (sync-tour, validate, git-sync, github-status, redistribute-memory, debrief)
- 4 commands (/coordinate, /executor, /switch-provider, /debrief)

**Workflow :**
1. Debut de session → "tour de sync" (9 phases)
2. Pendant → agents s'activent selon contexte
3. Fin → `/debrief` + commit

---

## Etat des MCPs

### Verification Critique au Demarrage

**OBLIGATION :** Verifier que les outils MCP sont disponibles (system-reminders).
Si ABSENTS : **REGRESSION CRITIQUE** → Reparer AVANT toute autre tache.

**Checklist reparation :**
1. Config : `Read ~/.claude.json` → section `mcpServers`
2. Test : `cd mcps/internal/servers/roo-state-manager && node mcp-wrapper.cjs 2>&1 | head -50`
3. Wrapper : Verifier correspondance avec registry.ts
4. Redemarrer VS Code (MCPs chargent au demarrage uniquement)

### MCPs Deployes (myia-ai-01)

| MCP | Outils | Statut |
|-----|--------|--------|
| **roo-state-manager** | 36 (wrapper v4 pass-through) | Deploye |
| **sk-agent** | 7 + deprecated aliases | Deploye (fix #482) |
| **markitdown** | 1 (convert_to_markdown) | Deploye |
| **win-cli** | 5 (local build 0.2.0) | Deploye |
| **GitHub CLI** (`gh`) | N/A (CLI natif) | Operationnel |

### Configuration Claude Code

| Niveau | Fichier | Portee |
|--------|---------|--------|
| Global utilisateur | `~/.claude/CLAUDE.md` | Tous les projets |
| Projet | `CLAUDE.md` (racine) | Ce projet |
| Auto-memoire | `~/.claude/projects/<hash>/memory/MEMORY.md` | Prive, local |
| Memoire partagee | `.claude/memory/PROJECT_MEMORY.md` | Via git |
| Rules | `.claude/rules/*.md` | Projet, auto-chargees |

### Configuration Roo

- **MCP Settings global :** `%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json`
- **MCP Settings projet :** `.roo\mcp.json` (overrides)
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

### Contrainte cle

Pas d'acces a l'historique de conversation. Utiliser :
- **GitHub Issues** comme memoire externe
- **RooSync** pour la coordination inter-machine
- **INTERCOM** pour la coordination locale

---

## Canaux de Communication

### 1. RooSync (Inter-Machine) - CLAUDE CODE UNIQUEMENT

**REGLE ABSOLUE : Roo n'utilise JAMAIS RooSync.**

Outils MCP (CONS-1) :
- `roosync_send` - Envoyer/repondre/amender (action: send|reply|amend)
- `roosync_read` - Lire inbox/message (mode: inbox|message)
- `roosync_manage` - Gerer messages (action: mark_read|archive)

Fichier partage : `G:/Mon Drive/Synchronisation/RooSync/.shared-state/`

### 2. INTERCOM (Locale Claude Code <-> Roo)

Fichier : `.claude/local/INTERCOM-{MACHINE_NAME}.md`
Documentation : [`.claude/INTERCOM_PROTOCOL.md`](.claude/INTERCOM_PROTOCOL.md)
Types : `INFO`, `TASK`, `DONE`, `WARN`, `ERROR`, `ASK`, `REPLY`

### 3. GitHub Issues

Projet : "RooSync Multi-Agent Tasks" (#67)
URL : https://github.com/users/jsboige/projects/67
Format : `[CLAUDE-MACHINE] Titre` + labels

### 4. Scheduler Roo

**Reference complete :** [`.claude/rules/scheduler-system.md`](.claude/rules/scheduler-system.md)

Essentiel : Extension `kylehoskins.roo-scheduler`, intervalle 3h, 10 modes (5 familles x 2 niveaux), escalade automatique.

### 5. Feedback

**Reference :** [`.claude/rules/feedback-process.md`](.claude/rules/feedback-process.md)

---

## Structure du Depot

```
.claude/
  rules/              # Regles auto-chargees (testing, github-cli, scheduler, agents, etc.)
  agents/             # Subagents specialises (coordinator/, executor/, workers/)
  skills/             # Skills auto-invoques (sync-tour, validate, git-sync, etc.)
  commands/           # Slash commands (coordinate, executor, switch-provider, debrief)
  memory/             # Memoire partagee (PROJECT_MEMORY.md)
  local/              # Communication locale gitignored (INTERCOM)

docs/                 # Documentation technique perenne (10 repertoires actifs)

mcps/
  internal/servers/   # roo-state-manager (TS) + sk-agent (Python)
  external/           # MCPs externes (12 serveurs)
```

---

## Pour Demarrer une Nouvelle Tache

1. **Verifier MCP** : Outils disponibles dans system-reminders
2. **Lire doc** : INDEX.md, MCP_SETUP.md, CLAUDE_CODE_GUIDE.md
3. **Communications** : RooSync inbox + INTERCOM local + GitHub issues
4. **Annoncer** : INTERCOM local + RooSync `[WORK]` + commentaire GitHub
5. **Issue GitHub** : Obligatoire pour toute tache significative
6. **Travailler** : Tester les MCPs, documenter la realite

---

## Contexte Actuel

**L'etat change quotidiennement. Consulter dans cet ordre :**
1. `git log --oneline -10`
2. GitHub Project #67
3. GitHub Issues ouvertes
4. INTERCOM local
5. SUIVI_ACTIF.md (peut etre obsolete)

### Contraintes

- NE PAS supposer que les MCPs sont disponibles - tester
- NE PAS inventer de workflows - tester ce qui marche
- Documenter la realite, pas les hypotheses
- Validation utilisateur OBLIGATOIRE avant creer issues GitHub

### Checklist de Validation Technique

**Reference complete :** [`.claude/rules/validation-checklist.md`](.claude/rules/validation-checklist.md)

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
| **myia-web1** | Agent flexible | GitHub + RooSync (2GB RAM) |

### Communication Quotidienne

1. **Git log** = source de verite technique
2. **GitHub Issues** = suivi taches et bugs
3. **RooSync** = messages urgents inter-machines
4. **SUIVI_ACTIF.md** = resume minimal

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

**Reference complete :** [`.claude/rules/sddd-conversational-grounding.md`](.claude/rules/sddd-conversational-grounding.md) et [`.claude/CLAUDE_CODE_GUIDE.md`](.claude/CLAUDE_CODE_GUIDE.md)

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

## Regles Absolues

1. **Etat partage RooSync = GDrive UNIQUEMENT** (jamais dans le depot Git)
2. **Roo n'utilise JAMAIS RooSync** (seulement Claude Code inter-machine)
3. **Ne JAMAIS modifier `.roomodes` ou `.roo/schedules.json` directement** (modifier sources + regenerer)
4. **Validation checklist OBLIGATOIRE** pour consolidation/refactoring
5. **Annoncer son travail** avant de commencer (anti-conflit)

---

**Derniere mise a jour :** 2026-02-19
**Pour questions :** Creer une issue GitHub ou contacter myia-ai-01
