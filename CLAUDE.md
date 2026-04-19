# Roo Extensions - Guide Agent Claude Code

**Repo:** [jsboige/roo-extensions](https://github.com/jsboige/roo-extensions)
**Systeme:** RooSync v2.3 — 6 machines
**MAJ:** 2026-04-05

---

## Vue d'ensemble

Multi-agent coordonnant **Roo Code** (technique, scheduler) et **Claude Code** (implementation, coordination, docs) sur 6 machines : `myia-ai-01` (coordinateur), `myia-po-2023/24/25/26`, `myia-web1`.

**Claude DIRIGE, Roo ASSISTE.** Claude = code critique + architecture + decisions. Roo = tests, build, taches repetitives (validees par Claude). Ne JAMAIS deleguer du code critique a Roo.

---

## Demarrage

1. `git pull`
2. **Verifier MCPs** (system-reminders). roo-state-manager absent → [STOP & REPAIR](.claude/rules/tool-availability.md)
3. **Lire inbox RooSync** (`roosync_read(mode: "inbox")`) — OBLIGATOIRE
4. Annoncer via dashboard/RooSync avant de travailler

---

## Canaux Communication

| Canal | Portee | Outil |
|-------|--------|-------|
| **RooSync** | **Inter-machines** | `roosync_send/read/manage` via MCP |
| **Dashboard workspace** | **Cross-machine (PRINCIPAL)** | `roosync_dashboard(type: "workspace")` |
| **INTERCOM local** | Intra-workspace (fallback) | `.claude/local/INTERCOM-{MACHINE}.md` |

**RooSync = inter-machine. INTERCOM = local. Ne jamais confondre.**
Les deux agents (Roo ET Claude) utilisent RooSync pour communiquer entre machines.

**Detail :** [.claude/rules/intercom-protocol.md](.claude/rules/intercom-protocol.md)

---

## MCPs

| Critique pour | MCP | Outils |
|---------------|-----|--------|
| **Claude Code** | roo-state-manager | 34 |
| **Roo Scheduler** | win-cli (fork local 0.2.0) | 9 |

**Config Claude Code :** `C:\Users\{user}\.claude.json` section `mcpServers`
**Config Roo (GLOBAL, pas projet) :** `%APPDATA%\...\mcp_settings.json`
**MCPs retires (ne doivent pas exister) :** desktop-commander, quickfiles, github-projects-mcp

**Inventaire complet :** [.claude/rules/tool-availability.md](.claude/rules/tool-availability.md)

---

## Config Hierarchy

| Niveau | Fichier | Portee |
|--------|---------|--------|
| Global | `~/.claude/CLAUDE.md` | Tous projets |
| Projet | `CLAUDE.md` (racine) | Ce projet |
| Local | `CLAUDE.local.md` | Machine (gitignored) |
| Harness (per-machine) | `~/.claude/settings.json` | Provider tuning + permissions (JAMAIS dans le repo) |
| Rules | `.claude/rules/*.md` | Auto-chargees chaque conversation |
| Auto-memoire | `~/.claude/projects/<hash>/memory/` | Prive, local |
| Memoire partagee | `.claude/memory/PROJECT_MEMORY.md` | Via git |

**Harness par machine :** Chaque machine définit ses paramètres Claude Code (fenêtre de contexte, seuil de condensation, permissions auto-approve) dans `~/.claude/settings.json`. Ce fichier est **machine-specific** et dépend du provider :
- **ai-01 (Anthropic Opus)** : `CLAUDE_CODE_AUTO_COMPACT_WINDOW=1000000`, `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=20`
- **Autres machines (z.ai GLM)** : `CLAUDE_CODE_AUTO_COMPACT_WINDOW=200000`, `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=75`

**`.claude/settings.json` (niveau projet) : INTERDIT.** Ce fichier écrase silencieusement le machine-level et a cassé 2 semaines de tuning condensation (2026-04-07). Il n'est **pas gitignoré** volontairement : s'il réapparaît, `git status` doit le crier pour qu'on le détruise immédiatement.

**`.claude/settings.local.json` : toléré** (gitignoré) UNIQUEMENT pour des permissions locales ponctuelles. JAMAIS d'env vars ni de tuning provider — ça doit rester dans `~/.claude/settings.json`.

---

## Agents, Skills & Commands

**18 subagents** (5 communs + 2 coordinateur + 11 workers) + 6 globaux.
**6 skills :** sync-tour, validate, git-sync, github-status, redistribute-memory, debrief.
**4 commands :** /coordinate, /executor, /switch-provider, /debrief.

**Detail :** [.claude/rules/agents-architecture.md](.claude/rules/agents-architecture.md)

---

## Structure

```
.claude/rules/     # 10 regles auto-chargees (operationnelles)
.claude/agents/    # Subagents (coordinator/, executor/, workers/)
.claude/skills/    # Skills auto-invoques
.claude/commands/  # Slash commands
docs/harness/      # Docs on-demand (anciennement .claude/docs/)
mcps/internal/     # roo-state-manager (TS) + sk-agent (Python)
roo-code/          # Submodule git (REFERENCE SEULEMENT)
roo-config/        # Modes Roo (modes-config.json + scripts)
```

**Submodule `roo-code/` :** Reference pour lire le code source Roo. PAS un env de build, PAS de `npm install`, PAS de `node_modules` utilisables. Pipeline modes : `modes-config.json` → `generate-modes.js` → `.roomodes`.

---

## Modes Roo

| Type | Groupes | Terminal | Exemples |
|------|---------|----------|----------|
| Orchestrateurs | `[]` | NON | orchestrator-simple/complex |
| -simple | read,edit,browser,mcp | **NON** (win-cli MCP) | code-simple, debug-simple |
| -complex | read,edit,browser,mcp | **NON** (win-cli MCP) | code-complex, debug-complex |

**Orchestrateurs = delegation pure** (aucun outil, `new_task` uniquement).
**AUCUN mode n'a le groupe `command` natif** (#1482). Tous utilisent win-cli MCP pour le terminal.

---

## GitHub

**Project #67 :** [GitHub Projects](https://github.com/users/jsboige/projects/67)
**Format issues :** `[CLAUDE-MACHINE] Titre` + labels.
**Labels :** Verifier avec `gh label list`. **N'EXISTENT PAS :** maintenance, scheduler, memory.
**Obligatoires :** bug/enhancement/documentation + attribution (claude-only ou roo-schedulable).
**Detail :** [docs/harness/reference/github-cli.md](docs/harness/reference/github-cli.md)

---

## Rules Auto-chargees

**Critiques :** [Tool Availability](.claude/rules/tool-availability.md) | [Validation](.claude/rules/validation.md) | [No Deletion](.claude/rules/no-deletion-without-proof.md) | [PR Mandatory](.claude/rules/pr-mandatory.md) | [CI Guardrails](.claude/rules/ci-guardrails.md) | [Issue Closure](.claude/rules/issue-closure.md)
**Ops :** [File Writing](.claude/rules/file-writing.md)
**Communication :** [INTERCOM](.claude/rules/intercom-protocol.md) | [Skepticism](.claude/rules/skepticism-protocol.md)
**Contexte :** [Context Window](.claude/rules/context-window.md) | [Agents](.claude/rules/agents-architecture.md)

**Index docs on-demand :** [docs/harness/reference/INDEX.md](docs/harness/reference/INDEX.md)

---

## Ressources

- [`docs/knowledge/WORKSPACE_KNOWLEDGE.md`](docs/knowledge/WORKSPACE_KNOWLEDGE.md) - Base connaissance
- [`docs/roosync/GUIDE-TECHNIQUE-v2.3.md`](docs/roosync/GUIDE-TECHNIQUE-v2.3.md) - Guide RooSync
- [`scripts/claude/`](scripts/claude/) - Scripts Claude Code (init, provider switch, worktree cleanup)
- [`scripts/README.md`](scripts/README.md) - Index des scripts du projet
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
| **Issue Closure** | Jamais fermer sans preuve de completion. Wontfix = utilisateur seulement. | `.claude/rules/issue-closure.md` |

### Règles Opérationnelles

| Règle | Description | Fichier |
|-------|-------------|---------|
| **SDDD Grounding** | Triple grounding (sémantique + conversationnel + technique). Bookend obligatoire. | `.claude/rules/sddd-grounding.md` |
| **conversation_browser Guide** | Usage conversation_browser + fix #881 (NoTools → Compact). | `.claude/rules/conversation-browser-guide.md` |
| **File Writing** | Edit > Write. Read obligatoire avant. Encodage UTF-8 no-BOM. | `.claude/rules/file-writing.md` |
| **Meta-Analyste** | Workflow 5 étapes pour analyse meta (miroir Roo `.roo/scheduler-workflow-meta-analyst.md`). | `.claude/rules/meta-analyst.md` |

### Règles Communication

| Règle | Description | Fichier |
|-------|-------------|---------|
| **INTERCOM Protocol** | Dashboard workspace = canal principal. Fichier local = DEPRECATED. | `.claude/rules/intercom-protocol.md` |
| **Skepticism Protocol** | Vérifier les affirmations surprenantes avant de propager. | `.claude/rules/skepticism-protocol.md` |

### Règles Contexte

| Règle | Description | Fichier |
|-------|-------------|---------|
| **Context Window** | Seuil condensation 75% pour GLM (131K réels). | `.claude/rules/context-window.md` |
| **Agents Architecture** | 18 subagents, 6 skills, 4 commands. | `.claude/rules/agents-architecture.md` |

---

## Documents de Reference (on-demand)

Les documents ci-dessous sont dans `docs/harness/` (PAS auto-charges). Les consulter quand le sujet est pertinent.

### Protocoles et Processus

| Document | Essentiel a retenir | Chemin |
|----------|-------------------|--------|
| **Condensation GLM** | Seuil **75%** pour z.ai (contexte reel 131K, pas 200K). `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=75` | `docs/harness/reference/condensation-thresholds.md` |
| **Checklists GitHub** | Ne JAMAIS fermer une issue avec tableau vide. Cocher AU FUR ET A MESURE. | `docs/harness/reference/github-checklists.md` |
| **Feedback/Friction** | Signaler via RooSync `[FRICTION]` to:all. Evolution prudente. | `docs/harness/reference/feedback-process.md`, `docs/harness/reference/friction-protocol.md` |
| **Escalade Claude Code** | 5 niveaux (outils → sub-agent → sk-agent → SDDD → utilisateur). Claude EST deja Opus 4.6 (pas d'escalade CLI/API). | `docs/harness/reference/escalation-protocol.md` |
| **Context Window** | Seuil de condensation 75% OBLIGATOIRE pour GLM (z.ai). | `.claude/rules/context-window.md` |

### Quality & CI

| Document | Essentiel a retenir | Chemin |
|----------|-------------------|--------|
| **CI Guardrails** | Validation OBLIGATOIRE avant push du submodule. Build + tests CI doivent passer. | `.claude/rules/ci-guardrails.md` |
| **PR Mandatory** | Zero push direct sur main. Tout changement passe par worktree → PR → review → merge. | `.claude/rules/pr-mandatory.md` |
| **No Deletion Without Proof** | Interdiction de supprimer du code sans preuve que la fonctionnalité est preservee. | `.claude/rules/no-deletion-without-proof.md` |
| **Test Success Rates** | Taux de succes attendu : 99.8% (ai-01), 99.6% (autres). Toujours `npx vitest run`. Tronquer output scheduler. | `docs/harness/reference/test-success-rates.md` |

### Coding Standards

| Document | Essentiel a retenir | Chemin |
|----------|-------------------|--------|
| **File Writing Patterns** | Edit pour modifications, Write pour nouveaux fichiers. Jamais ecraser sans lecture prealable. | `.claude/rules/file-writing.md` |
| **Validation Checklist** | Pour toute consolidation/refactoring : compter avant/apres, verifier ecart. | `.claude/rules/validation.md` |
| **SDDD Grounding** | Triple grounding (sémantique + conversationnel + technique). Bookend obligatoire. Protocole multi-pass. | `docs/harness/reference/sddd-conversational-grounding.md` |
| **Delegation** | Déléguer aux sub-agents si autonome, parallélisable. Contexte isolé. Statuts DONE/BLOCKED/NEEDS_CONTEXT. | `docs/harness/reference/delegation.md` |
| **GitHub CLI** | `gh` CLI, scope `project` requis. IDs fields Project #67. Ne pas créer de fichiers temporaires GraphQL. | `docs/harness/reference/github-cli.md` |
| **Worktree Cleanup** | Script cleanup orphelins + branches stale. Lifecycle complet : create→work→PR→merge→CLEANUP. | `docs/harness/reference/worktree-cleanup.md` |

### Scheduler & Coordination

| Document | Essentiel a retenir | Chemin |
|----------|-------------------|--------|
| **Scheduler system** | 10 modes (5 familles x 2 niveaux). Orchestrateurs = 0 outils. Pipeline: modes-config.json → generate-modes.js → .roomodes | `docs/harness/reference/scheduler-system.md` |
| **Scheduler densification** | Seuil escalade : 1 echec en -simple → escalade IMMEDIATE vers -complex (#1233) | `docs/harness/reference/scheduler-densification.md` |
| **Coordinator protocol** | Cycle 6-12h sur ai-01. Analyse RooSync + git + Project #67. | `docs/harness/coordinator-specific/scheduled-coordinator.md` |
| **Meta-analysis** | Cycle 72h. Triple grounding. Dashboard workspace (META-INTERCOM DEPRECATED). Guard rails: lecture seule. | `docs/harness/reference/meta-analysis.md` |

### Reference Technique

| Document | Essentiel a retenir | Chemin |
|----------|-------------------|--------|
| **PR review policy** | Agents → PR → Review coordinateur → Merge. Jamais push direct sur main. | `docs/harness/coordinator-specific/pr-review-policy.md` |
| **Incidents** | Lecons cles : cross-machine check apres config, STOP & REPAIR, CI avant push | `docs/harness/reference/incident-history.md` |
| **roo-schedulable** | Seulement taches subalternes (tests, validation, docs, cleanup) | `docs/harness/reference/roo-schedulable-criteria.md` |
| **Bash fallback** | Si Bash echoue : outils natifs > MCP win-cli > degradation gracieuse | `docs/harness/reference/bash-fallback.md` |
| **MCP discoverability** | Tests decouverte en 3 phases : visibilite, fonctionnalite, integration | `docs/harness/reference/mcp-discoverability.md` |
| **Web1 contraintes** | 16GB RAM, `--maxWorkers=1`, path GDrive different, fork win-cli local | `docs/harness/machine-specific/myia-web1-constraints.md` |
| **Stub Detection** | CI gate pour detecter les exports stub (return null, TODO non implementes). | `docs/harness/reference/stub-detection.md` |
| **Worktree Cleanup** | Protocol de gestion des worktrees git (auto-cleanup + garbage collection). | `docs/harness/reference/worktree-cleanup.md` |
| **MCP Proxy Architecture** | `mcp-tools.myia.io` = 2 etages : Windows sparfenyuk (PR #187) + container TBXark (PR mcp-go #796). roo-state-manager + searxng + sk_agent, bearer commun. | `docs/harness/reference/mcp-proxy-architecture.md` |

---

## Regles Absolues

1. RooSync = GDrive UNIQUEMENT (jamais dans git)
2. INTERCOM = local, RooSync = inter-machine
3. JAMAIS modifier `.roomodes`/`.roo/schedules.json` directement (sources + regenerer)
4. Validation checklist OBLIGATOIRE pour consolidation/refactoring
5. Annoncer avant de travailler
6. STOP & REPAIR si MCP critique absent
7. Verification cross-machine apres changement config
8. Scepticisme : ne JAMAIS propager affirmation non verifiee
9. VS Code restart requis apres modification schedules
10. Worktree cleanup apres PR merge/close
11. JAMAIS de cles API dans GitHub (RooSync pour partage)
12. `.claude/` = PROTEGE (harnais uniquement, pas de temporaires)
13. **Dashboard = canal de COMMANDEMENT** : le coordinateur repond a chaque rapport [DONE] avec des instructions claires (qui fait quoi, priorite, deadline). Ne JAMAIS laisser un rapport sans reponse.
14. **Dashboard = canal de RAPPORT** : tout agent (executor ou coordinateur) rapporte ses observations et actions notables en fin de session sur le dashboard. Inclure : ce qui a ete fait, PRs creees, issues commentees, prochaine action prevue.
15. **Agents proactifs** : tous les agents sont invites a creer/alimenter des issues, mettre a jour la documentation, ou effectuer des corrections directes si elles ne necessitent pas de planification git prealable. Pour eviter le double-claiming, notamment si ces actions réagissent à des des messages sur le Dashboard, poster sur le dashboard l'action envisagee AVANT de l'entreprendre.
16. **Reviews exigeantes AVANT merge** : verifier les faits, decompter les lignes, detecter les regressions de condensation. Un PR approuve par un scheduled coordinator ne vaut PAS validation — le coordinateur interactif re-review. **IMPORTANT:** Pour les PRs >50 LOC, utiliser le template d'integration tracing (context tracing) dans [`docs/harness/coordinator-specific/pr-review-policy.md`](docs/harness/coordinator-specific/pr-review-policy.md) section 2, pas juste la validation du diff. Cf. issue #1471 (BLOCKER-3 manqué par review générique).
17. **Presomption de regression** (issue #1463) : si un outil / une config / un service "ne marche plus" alors qu'il a fonctionne en prod pendant >7 jours, la cause probable est une **regression par un agent rogue**, pas un bug a reecrire from scratch. AVANT de proposer une refonte : `git log --oneline --all -20 -- <path>`, `git blame`, audit config drift. Ne JAMAIS proposer "recreer depuis zero" sans avoir d'abord prouve que le commit rogue n'existe pas.
18. **Coordinateur = gardien de la raison** : les agents du cluster sont comme des enfants qui cassent regulierement des choses. Le coordinateur doit resister a la derive entropique en exigeant preuve de panne (sortie complete, commande exacte, timestamp avant/apres) avant d'agir sur tout rapport critique. Traiter la naivete comme un risque majeur.

---

## Posture Coordinateur Ferme (depuis #1463)

Le coordinateur interactif (ai-01) applique le **Protocole de Scepticisme Raisonnable v3.1** :

### Avant d'agir sur un rapport critique (audit 4 questions)

| Question | Reponse requise |
|---|---|
| Qui a touche ce code dans les 30 derniers jours ? | `git log` + liste commits |
| La doc/MEMORY dit-elle deja quelque chose ? | Grep explicite |
| Est-ce une issue deja ouverte/fermee ? | `gh issue list --search` |
| Y a-t-il un test qui aurait du detecter ? | Si oui, pourquoi n'a-t-il pas tourne ? |

**Sans ces 4 reponses : pas de dispatch, pas de PR, pas de refonte.**

### Signaux entropiques a reconnaitre

- Une issue "documentee ad nauseam" (>=3 fois) qui revient → **ne pas investiguer, fermer avec contexte**
- Un rapport "outil X cassé" qui propose une reecriture → **exiger d'abord le commit rogue**
- Un meta-analyste qui rapporte "harmonisation theorique" → **rejeter, scope real problems only**
- Un PR qui touche `.env` / `mcp_settings.json` / `.claude/rules/` mergé par un scheduled agent → **re-review obligatoire 24h**

### Paradoxe 7000+ tests

Le repo a 7000+ tests unitaires mais la plupart des outils fonctionnent a peine. C'est la signature de la **vibecoding** : les agents modifient des fichiers critiques sans lire l'historique ni faire tourner les tests. **Le coordinateur ne doit jamais normaliser cette derive.**

### Scepticisme PR Review (issue #1471)

**PROBLEME :** sk-agent PR reviews se contentent de valider le diff sans tracer l'integration end-to-end. Resultat : BLOCKER-3 (bug workspace-loss dans dispatch) passé au travers de PR #124 review.

**PROTOCOL :** Pour toute PR >50 LOC, le coordinateur DOIT exiger le template d'integration tracing (context tracing) :

1. **Context tracing obligatoire** : Entry point → Validation → Consumers → Side effects → Context preservation
2. **Chasse aux patterns silencieux** : `.catch(() => {})`, fire-and-forget sans log, defaults qui masquent des bugs
3. **Verification E2E** : "Est-ce qu'un test exerce ce flow complet ?"
4. **Detection dual-definition** : meme schema/type duplique (tool-definitions vs handler source)
5. **Questions sceptiques** : "Ce schema accepte ces fields, est-ce que le dispatch en aval les traite correctement ?"

**Template complet** : [`docs/harness/coordinator-specific/pr-review-policy.md`](docs/harness/coordinator-specific/pr-review-policy.md) section 2.

**Impact attendu** : Reviews plus longues (5-10 min vs 1-2 min) mais **beaucoup** plus utiles. Catch de bugs d'integration AVANT merge, pas apres.

---

**Derniere MAJ :** 2026-04-18
