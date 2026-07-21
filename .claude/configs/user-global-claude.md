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

- **Conventional commits:** `type(scope): description`. Include `Co-Authored-By: Claude-Code <noreply@anthropic.com>` when AI-assisted.
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

**roo-state-manager (15 outils — post all CONS)** = MCP critique Claude Code (coordination, conversations, dashboards, indexation). Config : `~/.claude.json` section `mcpServers.roo-state-manager`.

- **Dashboard** (canal PRINCIPAL) : 3 types seulement — `global`, `machine`, `workspace`. Début de session → `roosync_dashboard(action: "read", type: "workspace", section: "all")` (JAMAIS `section: "status"` seul, #2306). Fin → `roosync_dashboard(action: "append", type: "workspace", tags: ["DONE"], content: "...")`. Auto-condensation préemptive à 92% (~46 KB). Tags : `INFO`, `TASK`, `DONE`, `WARN`, `ERROR`, `ASK`, `REPLY`, `ACK`, `PROPOSAL`, `BLOCKED`, `CLAIMED`.
- **conversation_browser** : `list` OBLIGATOIRE en premier (sinon pas d'IDs) → `view`/`tree`/`summarize`. `smart_truncation: true`, `summarize_type: "trace"` (pas `synthesis`).
- **Recherche** : `roosync_search(action: "semantic"|"text")` ; `codebase_search(query, workspace)` — TOUJOURS passer `workspace` explicitement, requêtes en anglais.
- **RooSync (inter-machines)** : `roosync_messages(action: "inbox")`, `roosync_messages(action: "send", to: "machine:workspace")`, `roosync_messages(action: "cleanup")`, `roosync_inventory(type: "status")`. Dashboard = principal, messages = fallback/urgences.

**Inventaire complet + paramètres + scénarios :** [`docs/harness/reference/roosync-tools-guide.md`](../../docs/harness/reference/roosync-tools-guide.md), [`docs/harness/reference/conversation-browser-detailed.md`](../../docs/harness/reference/conversation-browser-detailed.md). Autres MCP : playwright (automation web), markitdown (Roo seul, PDF/DOCX→MD), searxng (web canonique), sk-agent (vision/multi-agent).

---

## SDDD — Investigation Methodology

**Triple grounding** (toute tâche significative) : croiser **Technique** (code = vérité : Read/Grep/Glob/Git), **Conversationnel** (`conversation_browser`), **Sémantique** (`codebase_search` + `roosync_search(semantic)`). Ne jamais se contenter d'une seule source.

**Pattern Bookend** : `codebase_search` en DÉBUT (éviter de refaire, trouver la doc existante) et FIN (confirmer indexation, mettre à jour la doc afférente) de chaque tâche significative.

**Détail complet (multi-pass, Wiki Karpathy, filtres roosync_search, complémentarité Grep) :** `~/.claude/rules/sddd-protocol.md` + [`docs/harness/reference/sddd-conversational-grounding.md`](../../docs/harness/reference/sddd-conversational-grounding.md).

### Session Pattern (tout workspace) — OBLIGATOIRE

1. **Début :** `roosync_dashboard(action: "read", type: "workspace", section: "all")` (lire messages récents, identifier demandes) + **`memory-inject`** (auto-injecter les leçons MEMORY.md, #1369/#1377).
2. **Pendant :** Travailler. Question/blocage → `roosync_dashboard(action: "append", tags: ["ASK"], ...)`.
3. **Fin :** `roosync_dashboard(action: "append", tags: ["DONE"], content: "résumé")` — **OBLIGATOIRE, aucune exception**.

**Règle :** TOUT agent (interactif ou scheduled) DOIT rapporter son travail sur le dashboard workspace en fin de session. Les rapports de méta-analystes vont sur le dashboard, PAS dans des fichiers du dépôt.

**Ordre OBLIGATOIRE :** Commit + PR AVANT de poster le rapport [DONE]. Ne jamais annoncer un travail qui n'est pas commité.

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

---

## Multi-Machine Ping-Pong — Re-arm OBLIGATOIRE (sessions interactives coord/worker)

**Workspaces concernés :** `roo-extensions`, `CoursIA`, `2025-Epita-Intelligence-Symbolique`, `Argumentum`, et tout workspace engagé dans un workflow multi-machine coordinateur/workers.

**Règle absolue.** Le cluster ne fonctionne en continu que si chaque agent (coordinateur ET workers) ré-arme son réveil à la fin de chaque turn où il a "terminé tout ce qu'il pouvait faire seul". Sans re-arme, l'agent s'endort pendant que le cluster continue à produire du travail (PRs, reviews, dispatches) — ping-pong rompu. Mandate user 2026-05-19 (incident R67/R68 sur ai-01) : « dans le cadre d'une tâche interactive avec messages utilisateurs, ça doit être systématique pour le ping-pong entre le coordinateur et les workers ».

### Quand re-armer (chaque rôle)

| Rôle | Déclencheur de re-arme | Prompt typique |
|------|------------------------|----------------|
| **Coordinateur** | Après dispatch à TOUS les workers + complétion de ses tâches individuelles (merges, reviews, bilan), en attente des prochaines PRs/reports | `/coordinate` |
| **Worker** | Après soumission de TOUTES ses PRs (attente review/merge) + complétion des tâches dispatchées, en attente du prochain dispatch | `/executor` ou prompt worker spécifique |

### Cadence — cron 2h (économie tokens), pas ScheduleWakeup 1h

**Cadence fleet-wide actuelle : 2h, portée par `CronCreate`** (économie tokens, mandate user 2026-05-25 — RALENTIR ; le cycle 1h de #2203 est superseded). `ScheduleWakeup` est clampé runtime à `[60, 3600]s` (max 1h) → il ne PEUT PAS porter un cycle multi-heures. Donc :

- **ai-01 (coordinateur) = cron-driven.** `CronCreate("41 */2 * * *", "/coordinate")` (job session-only, auto-expire 7j). **NE PAS re-armer un `ScheduleWakeup` 1h par-dessus** — cela ré-introduirait le cycle 1h superseded.
- **Sessions interactives coord/worker NON pilotées par cron** : `ScheduleWakeup(delaySeconds: 3540, ...)` (≤1h, fallback) à chaque fin de turn pour ne pas rompre le ping-pong. C'est le plafond technique, pas un mandat de cadence 1h.
- **Petit jitter** (3540s = 59 min, ou minute off-`:00`) pour éviter que tous les agents frappent l'API à la même seconde.
- **Auto-régulation** via cap 3-IDLE (#2185, par exécutant) + override urgent `[WAKE-CLAUDE]` routé `machine:workspace` (début de ligne sur dashboard append). PAS via timer adaptatif — ne PAS varier l'intervalle « selon charge perçue ».

### Scope STRICT — Quand la règle de re-arme s'applique

EXCLUSIVEMENT : sessions Claude Code **interactives** (REPL avec messages utilisateur) où l'agent joue **activement** un rôle **coordinateur** OU **worker** dans un workflow multi-machine.

### Cadrage — Quand la règle NE s'applique PAS

| Type d'interaction | Re-arme ? | Pourquoi |
|--------------------|-----------|----------|
| **Workers schedulés** (Task Scheduler, cron, `start-claude-worker.ps1`) | **NON** | Cadence gérée externalement par le scheduler. Re-armer = double-firing. |
| **Méta-analystes scheduled** (cycle 72h) | **NON** | Cadence externe (`start-meta-audit.ps1`). |
| **Sessions interactives informationnelles** (question/réponse, pas de rôle coord/worker actif) | **NON** | Pas de ping-pong à entretenir. |
| **Sessions interactives ad-hoc / debugging / one-shot** | **NON** | Pas de ping-pong à entretenir. |
| **Workspace single-machine** (pas de cluster) | **NON** | Pas de cluster à animer. |
| **Handoff documenté** (un autre agent assume la suite) | **NON** | Continuité portée par l'autre agent. |

**Heuristique :** « Y a-t-il un cluster d'autres machines en train de produire du travail dont je dois m'occuper au tour suivant ? » — si OUI **et** session interactive **et** rôle coord/worker → re-arme. Sinon → pas de re-arme.

### Pattern technique

```
# ai-01 coordinateur (cadence 2h, économie tokens) :
CronCreate(cron: "41 */2 * * *", prompt: "/coordinate", recurring: true)
# → job session-only, auto-expire 7j. PAS de ScheduleWakeup 1h en plus.

# Session interactive coord/worker NON-cron (fallback ≤1h, plafond technique) :
ScheduleWakeup(
  delaySeconds: 3540,                 # 59 min — clamp runtime [60,3600]
  prompt: "/coordinate",              # ou "/executor", ou prompt rôle-spécifique
  reason: "Re-arme ping-pong coord/workers, attente PRs/dispatches"
)
```

Le `reason` doit être informatif (vu en telemetry + par l'user).
