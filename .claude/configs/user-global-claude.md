# Global Claude Code Instructions (Machine-Level)

**Applies to:** ALL projects on this machine.
**Source:** `.claude/configs/user-global-claude.md` in roo-extensions repo
**Deploy:** `~/.claude/CLAUDE.md` (local, not in git, all workspaces)
**Update:** Edit source in roo-extensions, commit+push, each machine pulls+copies
**Détail déporté:** [`docs/harness/global-rules-detail.md`](../../docs/harness/global-rules-detail.md) — matrices complètes, verbatims, incidents fondateurs.

---

## Terminology — "Consolider" != "Archiver"

**Consolidation = 3 etapes :** (1) ANALYSER chaque fonction de l'ancien script, (2) FUSIONNER chaque feature dans la cible **en citant les numeros de ligne comme preuve**, (3) ARCHIVER seulement apres verification. Deplacer vers `_archives/` sans preuve de preservation n'est **pas** une consolidation (Session 101 : 8+ scripts perdus).

## Fixing Prompts and Rules — No Pendulum

Quand une ligne d'un prompt/regle cause un mauvais comportement : **la supprimer d'abord.** N'ajouter un remplacement que si le retrait laisse un trou reel. Remplacer une ligne par son oppose est l'echec-pendule. L'equilibre s'atteint en soustrayant. Si un mecanisme automatique traite deja la question (auto-condensation, retries, rate limits), ne pas re-encoder son intention dans le prompt.

## Conventions

- **Langue :** User = francais. Code/commits/docs = anglais OK. INTERCOM = francais.
- **Scope workspace :** rester dans SON workspace. Ignorer les dispatchs d'autres workspaces.
- **Securite :** jamais de suppression sans preuve de preservation. Pas de secrets dans les commits. Preferer les actions reversibles.

## Git

- **Conventional commits** : `type(scope): description`. `Co-Authored-By: Claude-Code <noreply@anthropic.com>` si assiste.
- **Conflits** : JAMAIS de resolution aveugle. Lire les marqueurs, comprendre les deux cotes, decider deliberement.
- **Submodules** : commiter DEDANS d'abord, push, puis bump le pointeur parent.
- **Force push** : interdit sur branches partagees. Rejete -> fetch, merge, retry.

## Read Body Before Any Action (HARD, aucune exception)

Avant de **commenter**, **reviewer**, **merger**, **dispatcher**, ou **commencer un fix** sur une issue/PR, lire : (1) le **body complet**, (2) **tous les commentaires** existants, (3) **toutes les reviews** postees (humains ET bots) avec leur `state`, (4) le **diff**.

Le titre seul n'est pas la PR. Le `mergeStateStatus` seul n'est pas une review. **Ne pas merger** si `reviews[].state == "CHANGES_REQUESTED"` non adressee ou commentaires inline non resolus.

Anti-patterns : « le titre dit X » · « le bot a APPROVED, je merge » · « je connais le sujet » · « l'issue est ouverte depuis 2 jours, je fix ». Matrice action->lecture + incident fondateur (2026-05-17, reviews en double et en conflit sur PRs etudiantes la veille d'une soutenance) : [detail](../../docs/harness/global-rules-detail.md#read-body-before-any-action).

## Tool Discipline

- **Read avant Edit** — Edit echoue sans Read prealable. Toujours.
- **Tests** : `npx vitest run` / `npx jest --ci` (jamais `npm test` — le watch mode bloque).
- **Build + test** apres tout changement de code. Ne jamais commiter du code casse.
- **Large persisted outputs (#1340)** : `<50 KB` -> `Read` complet OK ; `50-500 KB` -> `Read` avec `offset`/`limit` ; `>500 KB` -> `Bash` + `head`/`grep`/`jq`. Ne JAMAIS `Read` un fichier persiste enorme : l'explosion de contexte tue la tache.

## Windows / PowerShell Gotchas

- **UTF-8 BOM** : `Set-Content`/`Out-File` ajoutent un BOM -> casse les parsers. Utiliser `[System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))` ou PS7+ `-Encoding utf8NoBOM`.
- **Join-Path PS 5.1** : 2 args seulement. Preferer `"$a/b/c/d"`.
- **Line endings** : `core.autocrlf = true` ou `.gitattributes`. Sensibles au CRLF : Bash, Docker.

## MCP Tools

**roo-state-manager** = MCP critique (coordination, conversations, dashboards, indexation). Config : `~/.claude.json` section `mcpServers.roo-state-manager`.

- **Dashboard (canal PRINCIPAL)** : 3 types — `global`, `machine`, `workspace`. Debut de session -> `roosync_dashboard(action:"read", type:"workspace", section:"all")` (JAMAIS `section:"status"` seul, #2306). Fin -> `append` avec tag `DONE`. Auto-condensation preemptive a 92 %. Tags : `INFO`, `TASK`, `DONE`, `WARN`, `ERROR`, `ASK`, `REPLY`, `ACK`, `PROPOSAL`, `BLOCKED`, `CLAIMED`.
- **conversation_browser** : `list` OBLIGATOIRE en premier (sinon pas d'IDs) -> `view`/`tree`/`summarize`. `smart_truncation:true`, `summarize_type:"trace"` (pas `synthesis`).
- **Recherche** : `roosync_search(action:"semantic"|"text")` ; `codebase_search(query, workspace)` — TOUJOURS passer `workspace`, requetes en anglais.
- **RooSync inter-machines** : `roosync_messages(action:"inbox"|"send")`. Dashboard = principal, DM = decision/urgence.

Inventaire complet : [`docs/harness/reference/roosync-tools-guide.md`](../../docs/harness/reference/roosync-tools-guide.md), [`conversation-browser-detailed.md`](../../docs/harness/reference/conversation-browser-detailed.md). Autres MCP : playwright (automation web), markitdown (PDF/DOCX->MD), searxng (web), sk-agent (vision/multi-agent).

## SDDD — Triple grounding

Croiser **Technique** (code = verite : Read/Grep/Glob/Git), **Conversationnel** (`conversation_browser`), **Semantique** (`codebase_search` + `roosync_search`). Jamais une seule source.

**Pattern Bookend** : `codebase_search` en DEBUT (eviter de refaire, trouver la doc existante) et en FIN (confirmer l'indexation, mettre a jour la doc afferente). Detail : `~/.claude/rules/sddd-protocol.md` + [`docs/harness/reference/sddd-conversational-grounding.md`](../../docs/harness/reference/sddd-conversational-grounding.md).

### Session Pattern (tout workspace) — OBLIGATOIRE

1. **Debut** : `roosync_dashboard(action:"read", type:"workspace", section:"all")` + skill `memory-inject`.
2. **Pendant** : travailler. Blocage -> `append` tag `ASK`.
3. **Fin** : `append` tag `DONE` — **aucune exception**. Les rapports vont sur le dashboard, PAS dans des fichiers du depot.

**Ordre OBLIGATOIRE** : commit + PR AVANT le rapport `[DONE]`. Ne jamais annoncer un travail non commite.

## Knowledge Preservation

Pas de memoire entre sessions : ecrire les apprentissages dans des fichiers avant la fin. Hierarchie : `~/.claude/CLAUDE.md` (global) · `CLAUDE.md` repo (projet) · `~/.claude/projects/<hash>/memory/MEMORY.md` (par machine) · `.claude/rules/*.md` (auto-loaded). Apres chaque tache significative : MAJ CLAUDE.md projet + MEMORY.md, consigner les approches **testees-et-rejetees**.

## Multi-Machine Ping-Pong — Re-arm

**Scope STRICT** : sessions Claude Code **interactives** ou l'agent joue **activement** un role coordinateur OU worker dans un workflow multi-machine. **Ne s'applique PAS** aux workers/meta-analystes schedules (cadence externe -> double-firing), aux sessions informationnelles, ad-hoc/debug, workspace single-machine, ou apres handoff documente.

Heuristique : « un cluster produit-il du travail dont je dois m'occuper au tour suivant ? » — si OUI **et** session interactive **et** role coord/worker -> re-armer.

```
# coordinateur — cadence portee par cron (economie tokens) :
CronCreate(cron: "<minute off-:00> */<N> * * *", prompt: "/coordinate", recurring: true)
# session interactive NON-cron (fallback, plafond technique 1 h) :
ScheduleWakeup(delaySeconds: 3540, prompt: "/coordinate", reason: "<informatif>")
```

`ScheduleWakeup` est clampe a `[60, 3600]s` : il ne PEUT PAS porter un cycle multi-heures — quand la cadence depasse 1 h, c'est `CronCreate` qui la porte, **sans** `ScheduleWakeup` par-dessus. Jitter (minute off-`:00`) pour ne pas frapper l'API a la meme seconde. Auto-regulation par cap 3-IDLE (#2185) + override `[WAKE-CLAUDE]`, pas par timer adaptatif.

Matrice de scope complete + verbatims du mandat : [detail](../../docs/harness/global-rules-detail.md#multi-machine-ping-pong--re-arm).
