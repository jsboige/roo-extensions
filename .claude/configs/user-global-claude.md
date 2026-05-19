# Global Claude Code Instructions (Machine-Level)

**Applies to:** ALL projects on this machine.
**Source:** `.claude/configs/user-global-claude.md` in roo-extensions repo
**Deploy:** `~/.claude/CLAUDE.md` (local, not in git, all workspaces)
**Update:** Edit source in roo-extensions, commit+push, each machine pulls+copies

---

## Terminology — "Consolider" != "Archiver"

**Consolidation = 3 steps:**
1. **ANALYZE** every function in the old script
2. **MERGE** each feature into target (cite exact line numbers as proof)
3. **ARCHIVE** only after verification — header: date, superseded-by, merged features

**NOT consolidation:** Moving to `_archives/` without proof of preservation. Established after Session 101 (8+ scripts lost, pipeline broken).

---

## Fixing Prompts and Rules — No Pendulum

When a line in a prompt/rule causes bad behavior: **delete it first.** Only add a replacement if removal leaves an actual gap the other directives don't cover.

Replacing a line with its opposite (e.g. "viser 50-100 lignes" → "viser 10-14 KB", "ne pas copier-coller" → "préserver l'intégralité") is the pendulum failure — it swings the problem to the other extreme. Equilibrium is reached by subtracting, not by adding a counterweight.

If an automatic mechanism handles the concern elsewhere (auto-condensation, retries, rate limits), don't re-encode its intent in the prompt.

---

## Conventions

- **Language:** User = French. Code/commits/docs = English OK. INTERCOM = French when relevant.
- **Workspace scope:** Stay in YOUR workspace. Ignore dispatches from other workspaces. `roosync_dashboard(type: "workspace")` for YOUR workspace only.
- **Safety:** Never delete without proof of preservation. No secrets in commits. Prefer reversible actions.

---

## Git

- **Conventional commits:** `type(scope): description`. Include `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>` when AI-assisted
- **Conflicts:** NEVER auto-resolve blindly. Read markers, understand both sides, decide deliberately
- **Submodules:** Commit inside FIRST, push, then update pointer in parent
- **Force push:** Forbidden on shared branches. Rejected → fetch, merge, retry

---

## Read Body Before Any Action — review, comment, merge, dispatch, fix (HARD)

**Règle HARD, aucune exception.** Avant de **poster un commentaire**, **reviewer**, **merger**, **dispatcher du travail**, ou **commencer un fix** sur une issue/PR, lire :

1. **Le body complet** (description, scope, decisions, caveats deja documentes)
2. **Tous les commentaires existants** (`gh pr view N --json comments`, `gh issue view N --comments`)
3. **Toutes les reviews deja postees** (`gh pr view N --json reviews`) — humains ET bots, avec leur `state` (APPROVED / CHANGES_REQUESTED / COMMENTED)
4. **Le diff** (`gh pr diff N` ou `git diff base..head`) avant review ou merge

Le titre seul n'est pas la PR. Le `mergeStateStatus` seul n'est pas une review. Sauter cette lecture = agir a l'aveugle.

| Action | Lecture obligatoire avant |
|--------|--------------------------|
| `gh pr comment N` (poster un comment) | body PR + tous comments + toutes reviews existantes |
| `gh pr review N` (poster une review) | idem + diff complet |
| `gh pr merge N` | idem + `mergeStateStatus` + `reviews[].state == "CHANGES_REQUESTED"` ET comments inline non-resolus → NE PAS merger si demandes non-adressees |
| `gh issue comment N` | body issue + tous comments existants |
| Dispatch d'une tache sur une issue a un agent | body issue + comments + linked PRs |
| Fix d'un bug base sur une issue | body issue + comments + PRs liees + diagnostic existant |
| Audit reassessment | body audit + le code source reel (verification > memo) |

**Anti-patterns interdits** :
- "Le titre dit X, je traite X" → lire le body, X peut etre autre chose
- "Le bot a APPROVED, je merge" → lire le body PR + comments humains + CHANGES_REQUESTED
- "Je connais le sujet, je sais quoi dire" → lire ce qui a deja ete dit, ne pas duplicate/conflict
- "L'issue est ouverte depuis 2 jours, je commence a fix" → lire si un autre agent a deja commence/diagnostique/abandonne
- "Pas de redite" en reviews : verifier qu'aucun reviewer n'a deja souleve le point que tu vas mentionner

**Why** : incident 2026-05-17 (ai-01 sur CoursIA). 6 reviews detaillees postees sur PRs etudiantes EPITA Contraintes avec sections "Questions pour la soutenance" en duplicate ET en conflit avec les reviews breves bienveillantes deja postees par un autre agent (`jsboigeEpita`) la veille de la soutenance. Si les comments existants avaient ete lus AVANT, l'incident aurait ete detecte : (a) style bref bienveillant deja adopte, (b) un autre agent reviewer en charge des reviews publiques, (c) leak jury par-dessus la review de l'autre agent. La regle "lire avant" detecte les incoherences avant le post.

---

## Tool Discipline

- **Read before Edit** — Edit fails without prior Read. Always.
- **Test commands:** `npx vitest run` / `npx jest --ci` (never `npm test` — watch mode blocks)
- **Build + test** after code changes. Never commit broken code.
- **Large persisted outputs (#1340):** When a tool returns `<persisted-output>` with "Output too large (N MB/KB)", adapt your read strategy based on size:
  - **< 50KB:** `Read` the full file is acceptable
  - **50KB - 500KB:** Use `Read` with `offset`/`limit` to read sections
  - **> 500KB:** Use `Bash` with `head`/`tail`/`grep`/`jq` to extract relevant parts
  - **Always:** If a preview is shown, analyze it first before deciding if more data is needed. Never blindly `Read` the full persisted file — context explosion kills the task.

---

## Windows / PowerShell Gotchas

- **UTF-8 BOM:** `Set-Content`/`Out-File` add BOM → breaks parsers. Use `[System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))` or PS7+ `-Encoding utf8NoBOM`
- **Join-Path PS 5.1:** Only 2 args. Use `"$a/b/c/d"` instead of `Join-Path $a "b" "c" "d"`
- **Line endings:** `core.autocrlf = true` or `.gitattributes`. CRLF-sensitive: Bash, Docker

---

## MCP Tools (Global)

### roo-state-manager (15 tools — post all CONS consolidation rounds)

MCP serveur pour la coordination multi-agents, conversations Roo/Claude, dashboards, et indexation.
**Config:** `~/.claude.json` section `mcpServers.roo-state-manager`.

#### Dashboard (canal principal de coordination)

3 types de dashboards : `global`, `machine`, `workspace`. Pas d'autre type.

| Action | Usage | Exemple |
|--------|-------|---------|
| `read` | Lire un dashboard | `roosync_dashboard(action: "read", type: "workspace")` |
| `append` | Poster un message intercom | `roosync_dashboard(action: "append", type: "workspace", tags: ["INFO"], content: "...")` |
| `write` | Remplacer le statut | `roosync_dashboard(action: "write", type: "workspace", content: "...")` |
| `condense` | Condenser messages anciens | `roosync_dashboard(action: "condense", type: "workspace", keepMessages: 20)` |
| `list` | Lister tous les dashboards | `roosync_dashboard(action: "list")` |
| `read_overview` | Vue 3 niveaux en 1 appel | `roosync_dashboard(action: "read_overview")` |

**Debut de session :** `roosync_dashboard(action: "read", type: "workspace")` pour lire les messages recents.
**Fin de session :** `roosync_dashboard(action: "append", type: "workspace", tags: ["DONE"], content: "resume...")` pour rapporter.
**Tags standards :** `INFO`, `DONE`, `WARN`, `ERROR`, `ASK`, `REPLY`, `ACK`, `PROPOSAL`, `TASK`, `BLOCKED`.
**Auto-condensation :** Préemptive à **92% d'utilisation** (≈46 KB) avant `append`, filet de sécurité à 50 KB après. Condensation manuelle via `condense`.

#### Conversation Browser

**TOUJOURS commencer par `list`** pour obtenir les IDs de taches :

| Action | Usage |
|--------|-------|
| `list` | Lister les taches recentes (**OBLIGATOIRE en premier**) |
| `view` | Voir le contenu d'une tache (avec `task_id`, `smart_truncation: true`) |
| `tree` | Arbre parent-enfant |
| `current` | Tache active du workspace |
| `summarize` | Resume (`summarize_type: "trace"` recommande) |

**Sans `list` d'abord, les autres actions echouent** — pas d'IDs a deviner.
**Bug connu :** `summarize_type: "synthesis"` peut echouer. Preferer `"trace"`.

#### Recherche

| Outil | Usage |
|-------|-------|
| `roosync_search(action: "text", search_query: "...")` | Recherche textuelle dans les taches |
| `roosync_search(action: "semantic", search_query: "...")` | Recherche par concept (Qdrant) |
| `codebase_search(query: "...", workspace: "C:/dev/...")` | Recherche dans le code (TOUJOURS passer `workspace`) |

#### RooSync (inter-machines)

| Outil | Usage |
|-------|-------|
| `roosync_read(mode: "inbox")` | Lire les messages entrants |
| `roosync_send(to: "machine-id", content: "...")` | Envoyer un message |
| `roosync_manage(action: "cleanup")` | Nettoyer les vieux messages |
| `roosync_get_status()` | Etat de la machine locale |

**Dashboard = canal PRINCIPAL. RooSync messages = fallback ou urgences.**

#### Autres outils utiles

| Outil | Usage |
|-------|-------|
| `roosync_mcp_management(action: "manage", subAction: "read")` | Lire config MCP |
| `read_vscode_logs(filter: "error", lines: 50)` | Diagnostiquer erreurs MCP/VS Code |
| `export_data(format: "json", taskId: "...")` | Exporter conversations |

#### Bugs connus et precautions

- **Dashboard redirect (#984) :** Si la reponse contient "written to file:", lire ce fichier avec `Read`.
- **`codebase_search` :** Toujours passer `workspace` explicitement (auto-detection pointe vers le serveur MCP). Requetes en anglais, vocabulaire du code.
- **Condensation LLM :** Utilise un LLM local (Qwen3.5). Si le LLM est indisponible, la condensation est annulee (pas de perte de donnees).

### playwright (22 outils) / markitdown (1 outil)

- **playwright :** Automatisation web, screenshots, navigation
- **markitdown :** PDF/DOCX/XLSX → Markdown

---

## SDDD — Investigation Methodology

**Triple grounding (obligatoire pour travail significatif):**
1. **Technique** — Code source = verite (Read, Grep, Glob, Git)
2. **Conversationnel** — `conversation_browser` pour historique Roo/Claude
3. **Semantique** — `codebase_search` + `roosync_search(semantic)` pour recherche par concept

**Regle:** Ne jamais se contenter d'une seule source. Croiser les 3 groundings.

### Pattern Bookend (obligatoire)

`codebase_search` en DEBUT et FIN de chaque tache significative.
- **Debut :** Eviter de refaire un travail deja fait, comprendre le contexte.
  - Trouver la documentation existante (README, CLAUDE.md, docs/, ADRs)
  - Identifier le contexte : qui a travaille dessus, quelles decisions ont ete prises
- **Fin :** Confirmer que le travail est indexe et retrouvable.
  - S'assurer que le travail est coherent avec le reste du projet
  - Mettre a jour la documentation afferente si le travail la rend obsolète

### Wiki Karpathy / SDDD Documentaire

Apres chaque tache significative, si `codebase_search` en debut a trouve de la documentation existante :
- **Verifier** qu'elle est toujours a jour
- **Mettre a jour** si le travail l'a rendue obsolète
- **Documenter** les decisions prises et les approches rejetées

Ce pattern est analogue au "wiki Karpathy" : documenter comprehensivement ce qu'on apprend en construisant.

### Complémentarité Grep vs codebase_search

| Besoin | Outil |
|--------|-------|
| Symbole exact, nom de fonction | `Grep` |
| Fichier par pattern | `Glob` |
| Concept, documentation, contexte | `codebase_search` |
| Historique conversations | `roosync_search(semantic)` |

`Grep` trouve des strings exacts mais pas les concepts. `codebase_search` decouvre la documentation meme sans connaitre les mots exacts.

### codebase_search — Protocole Multi-Pass

**TOUJOURS passer `workspace` explicitement** (auto-detection pointe vers le serveur MCP, pas votre projet).

| Pass | But | Methode |
|------|-----|---------|
| 1 | Identifier le module | Requete conceptuelle large (anglais) |
| 2 | Zoom dans le module | `directory_prefix` + vocabulaire du code |
| 3 | Confirmer | Grep exact (noms de fonctions, types) |
| 4 | Variante | Reformuler avec synonymes si Pass 2 insuffisant |

**Conseils :** Vocabulaire du code > langage naturel. 5-10 mots cles. `directory_prefix` divise l'espace par ~10. **Requetes en francais = mauvais resultats.**

### Session Pattern (tout workspace) — OBLIGATOIRE

1. **Debut :**
   - `roosync_dashboard(action: "read", type: "workspace")` — lire les messages recents, identifier les demandes
   - **`memory-inject`** — auto-injecter les leçons pertinentes depuis MEMORY.md (pattern Reddit #1369)
2. **Pendant :** Travailler. Si question/blocage → `roosync_dashboard(action: "append", tags: ["ASK"], ...)`
3. **Fin :** `roosync_dashboard(action: "append", tags: ["DONE"], content: "resume du travail")` — **OBLIGATOIRE, aucune exception**

**Regle :** TOUT agent (interactif ou scheduled) DOIT rapporter son travail sur le dashboard workspace en fin de session. Les rapports de méta-analystes vont sur le dashboard, PAS dans des fichiers du dépôt.

**Ordre OBLIGATOIRE :** Commit + PR AVANT de poster le rapport [DONE] sur le dashboard. Ne jamais annoncer un travail qui n'est pas commité.

### Scepticisme

**Ne JAMAIS propager une affirmation non verifiee.** Qualifier : VERIFIE / RAPPORTE PAR [source] / SUPPOSE.
Si ca te surprend → verifie avant de repeter ou d'agir dessus.

---

## Knowledge Preservation

- **No memory between sessions.** Always write learnings to files before session ends.
- **Memory hierarchy:**
  - `~/.claude/CLAUDE.md` — Global (THIS FILE)
  - `CLAUDE.md` (repo root) — Project instructions
  - `~/.claude/projects/<hash>/memory/MEMORY.md` — Per-machine session learnings
  - `.claude/memory/PROJECT_MEMORY.md` — Cross-machine shared (via git)
  - `.claude/rules/*.md` — Auto-loaded project rules

- **Memory auto-injection (#1377):** Le skill `memory-inject` auto-charge les leçons pertinentes au debut de chaque tache pour prevenir les erreurs recurrentes. Pattern valide par l'analyse Reddit 3-agent (#1369).

**After each significant task:** Update project CLAUDE.md + MEMORY.md. Record rejected approaches.

---

## Self-Maintenance

**After each significant task:**
1. Update project CLAUDE.md if technical sections changed
2. Update MEMORY.md with current state + lessons learned
3. Record tested-and-rejected approaches (avoid repeating experiments)
4. Verify coherence before ending session
