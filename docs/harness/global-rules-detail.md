# Règles globales machine — détail déporté

Détail des règles portées par `.claude/configs/user-global-claude.md` (déployé en `~/.claude/CLAUDE.md`, harnais **machine**, auto-chargé dans tous les workspaces). La règle y reste succincte ; le détail — matrices complètes, verbatims, incidents fondateurs — vit ici et se lit à la demande.

Ce fichier existe parce que le harnais auto-chargé est du contexte payé **à chaque session, dans chaque workspace** : une matrice de 15 lignes lue une fois par mois n'y a pas sa place, un pointeur d'une ligne oui.

---

## Read Body Before Any Action

Règle HARD, aucune exception. Avant de **poster un commentaire**, **reviewer**, **merger**, **dispatcher du travail**, ou **commencer un fix** sur une issue/PR, lire :

1. **Le body complet** (description, scope, décisions, caveats déjà documentés)
2. **Tous les commentaires existants** (`gh pr view N --json comments`, `gh issue view N --comments`)
3. **Toutes les reviews déjà postées** (`gh pr view N --json reviews`) — humains ET bots, avec leur `state` (APPROVED / CHANGES_REQUESTED / COMMENTED)
4. **Le diff** (`gh pr diff N` ou `git diff base..head`) avant review ou merge

Le titre seul n'est pas la PR. Le `mergeStateStatus` seul n'est pas une review. Sauter cette lecture = agir à l'aveugle.

### Matrice action → lecture obligatoire

| Action | Lecture obligatoire avant |
|---|---|
| `gh pr comment N` | body PR + tous comments + toutes reviews existantes |
| `gh pr review N` | idem + diff complet |
| `gh pr merge N` | idem + `mergeStateStatus` + `reviews[].state == "CHANGES_REQUESTED"` **et** comments inline non-résolus → **NE PAS merger** si demandes non-adressées |
| `gh issue comment N` | body issue + tous comments existants |
| Dispatch d'une tâche sur une issue | body issue + comments + linked PRs |
| Fix d'un bug basé sur une issue | body issue + comments + PRs liées + diagnostic existant |
| Audit reassessment | body audit + le code source réel (vérification > mémo) |

### Anti-patterns interdits

- « Le titre dit X, je traite X » → lire le body, X peut être autre chose
- « Le bot a APPROVED, je merge » → lire le body PR + comments humains + CHANGES_REQUESTED
- « Je connais le sujet, je sais quoi dire » → lire ce qui a déjà été dit, ne pas dupliquer/contredire
- « L'issue est ouverte depuis 2 jours, je commence à fix » → lire si un autre agent a déjà commencé/diagnostiqué/abandonné
- « Pas de redite » en reviews : vérifier qu'aucun reviewer n'a déjà soulevé le point
- « J'ai listé les N derniers commentaires » → **l'instrument de lecture tronque** : `--jq '.comments[]'` pipé vers `tail -N` fragmente le JSON multi-lignes (un commentaire = plusieurs lignes) et en cache d'autres. Garde : énumérer les en-têtes d'abord (`--jq '.comments[] | "\(.id) \(.createdAt) \(.author.login)"'`), puis lecture ciblée. Incident #3137 (2026-08-24) : commentaire existant invisible sous `tail`, reposté en double.

### Incident fondateur (2026-05-17, ai-01 sur CoursIA)

6 reviews détaillées postées sur des PRs étudiantes EPITA Contraintes, avec des sections « Questions pour la soutenance » **en duplicate ET en conflit** avec les reviews brèves bienveillantes déjà postées par un autre agent (`jsboigeEpita`) — la veille de la soutenance.

Si les comments existants avaient été lus AVANT, l'incident aurait été détecté : (a) style bref bienveillant déjà adopté, (b) un autre agent était en charge des reviews publiques, (c) fuite jury par-dessus la review de l'autre agent. La règle « lire avant » détecte les incohérences avant le post.

---

## Multi-Machine Ping-Pong — Re-arm

Le cluster ne fonctionne en continu que si chaque agent (coordinateur ET workers) ré-arme son réveil à la fin de chaque turn où il a terminé tout ce qu'il pouvait faire seul. Sans re-arme, l'agent s'endort pendant que le cluster continue à produire du travail (PRs, reviews, dispatches) — ping-pong rompu.

Mandat user 2026-05-19 (incident R67/R68 sur ai-01) : « dans le cadre d'une tâche interactive avec messages utilisateurs, ça doit être systématique pour le ping-pong entre le coordinateur et les workers ».

### Quand re-armer, par rôle

| Rôle | Déclencheur | Prompt typique |
|---|---|---|
| **Coordinateur** | Après dispatch à TOUS les workers + complétion de ses tâches individuelles (merges, reviews, bilan), en attente des prochaines PRs/reports | `/coordinate` |
| **Worker** | Après soumission de TOUTES ses PRs (attente review/merge) + complétion des tâches dispatchées, en attente du prochain dispatch | `/executor` ou prompt worker spécifique |

### Cadence — cron porté, pas ScheduleWakeup

`ScheduleWakeup` est clampé runtime à `[60, 3600]s` (max 1 h) : **il ne PEUT PAS porter un cycle multi-heures**. Conséquences :

- **Coordinateur piloté par cron** : `CronCreate("<minute off-:00> */<N> * * *", "/coordinate")` (job session-only, auto-expire 7 j). **NE PAS re-armer un `ScheduleWakeup` par-dessus** — cela ré-introduirait un cycle plus court que la cadence décidée.
- **Sessions interactives coord/worker NON pilotées par cron** : `ScheduleWakeup(delaySeconds: 3540, …)` à chaque fin de turn pour ne pas rompre le ping-pong. C'est le **plafond technique**, pas un mandat de cadence horaire.
- **Jitter** : minute off-`:00` (ex. 3540 s = 59 min) pour éviter que tous les agents frappent l'API à la même seconde.
- **Auto-régulation** via cap 3-IDLE (#2185, par exécutant) + override urgent `[WAKE-CLAUDE]` routé `machine:workspace` (début de ligne sur un append dashboard). **PAS** via timer adaptatif — ne pas faire varier l'intervalle « selon la charge perçue ».

### Scope STRICT — quand la règle s'applique

EXCLUSIVEMENT : sessions Claude Code **interactives** (REPL avec messages utilisateur) où l'agent joue **activement** un rôle **coordinateur** OU **worker** dans un workflow multi-machine.

### Quand elle NE s'applique PAS

| Type d'interaction | Re-arme ? | Pourquoi |
|---|---|---|
| Workers schedulés (Task Scheduler, cron, `start-claude-worker.ps1`) | **NON** | Cadence gérée externalement — re-armer = double-firing |
| Méta-analystes scheduled (cycle 72 h) | **NON** | Cadence externe (`start-meta-audit.ps1`) |
| Sessions interactives informationnelles (Q/R, pas de rôle coord/worker actif) | **NON** | Pas de ping-pong à entretenir |
| Sessions interactives ad-hoc / debugging / one-shot | **NON** | Pas de ping-pong à entretenir |
| Workspace single-machine (pas de cluster) | **NON** | Pas de cluster à animer |
| Handoff documenté (un autre agent assume la suite) | **NON** | Continuité portée par l'autre agent |

**Heuristique** : « Y a-t-il un cluster d'autres machines en train de produire du travail dont je dois m'occuper au tour suivant ? » — si OUI **et** session interactive **et** rôle coord/worker → re-arme. Sinon → pas de re-arme.

Le champ `reason` du `ScheduleWakeup` doit être informatif (visible en télémétrie et par le user).

---

## Git — Checkout Safety

`git checkout -- <fichier>` restaure un fichier depuis l'**INDEX**, pas depuis « avant ma dernière modification ». Sur une branche de travail où un fix n'est jamais commité, ce checkout efface **l'intégralité du fix** — pas seulement la dernière manipulation.

### Le geste de vérification qui efface le fix (incident fondateur 2026-08-24)

c.184, #3205 résiduel write-side (PR #1035) : après vérification par mutations A/B (tests rouges ✓), le revert des mutations via `git checkout -- dashboard.ts` a silencieusement effacé le fix complet non-commité. Les 3 tests « foreign lock » ont échoué en full-file (retour ~3 ms au lieu d'attendre ≥200/500 ms) alors qu'ils passaient en isolation. 4 hypothèses de pollution amont investiguées en vain (clearAllMocks, TTL env, garbage-steal, fail-open catch) — instrumenter n'importe où ne loggait rien parce que le chemin verrouillé **n'existait plus dans le code exécuté**. Les tests étaient CORRECTS : ils détectaient l'absence du fix (comportement exact attendu d'un test de mutation).

### Anti-patterns

- Chasser un pollueur amont sans avoir vérifié que le fix est encore là : `grep -c <symbole-du-fix> <fichier-SUT>` d'abord, toujours.
- Interpréter un SUT qui répond instantanément (3-11 ms) là où un verrou/retry est attendu comme une « optimisation » — c'est la signature d'un chemin lent absent.
- Lire « file state is current in your context » après un revert comme une garantie — l'état disque est le fichier REVERTI.
- Séquencer « Edit réussi » puis verification sans backup — le revert détruit alors le fix.
- Manipuler un fichier porteur d'un fix non-commité : committer d'abord, même en WIP.

### Cousins

- `.claude/rules/submod-pointer-safety.md` — `git checkout --theirs` / `git checkout HEAD --` sur des pointeurs submodule : même famille, mêmes effacements (eux s'appliquent à un gitlink, pas à un fichier de travail).

---

## MCP — Stale host memory

Un hôte MCP (process VS Code / session Claude Code longue durée) charge `build/*.js` **une fois**, au démarrage du process. Après un rebuild ou un bump de submodule, la session vivante continue d'exécuter l'**ancien build en mémoire** — quoi que dise le disque. « Build fresh sur disque ≠ MCP host process servi » (skill executor, #2822 follow-up).

### Discriminant en 3 colonnes

| État source | État `build/` | Symptôme en session | Diagnostic | Fix |
|---|---|---|---|---|
| frais | frais | `-32603 "no export named X"`, compte d'outils ou comportements anciens | **process hôte stale** | restart de la session — dernier recours légitime |
| frais | **stale** | idem | build pas rebuildé | `ensure-build-fresh.ps1`, re-tester, restart ensuite |
| modifié/cassé | — | outil absent, `-32602`, crash au handshake | config ou build cassé | réparer ; le MCP revient DANS la session en cours |

### Relation avec la règle « jamais suggérer un restart »

`.claude/rules/mcp-diagnosis.md` interdit « le MCP reviendra à la prochaine session » quand le problème est de la config ou du build — l'outil revient dans la session **en cours** une fois corrigé. Le stale host est l'exception prouvée : la correction (rebuild) est sur le disque, mais le process ne peut pas la voir sans redémarrer. C'est exactement le « dernier recours » que cette règle réserve déjà. Le prérequis avant de l'invoquer : **vérifier les deux premières colonnes firsthand** (timestamps source/build + grep du symbole du fix dans `build/*.js`) — sinon c'est l'hallucination que la règle interdit.

### Anti-patterns

- Diagnostiquer « timing de démarrage » ou « MCP pas prêt » — règle #1 de mcp-diagnosis : pas de timing fantasy, le MCP répond ou il crash.
- Invoquer stale-host sans preuve que source ET build sont frais (timestamps + grep) — c'est la porte d'entrée de l'hallucination restart.
- Rebuilder à chaud pendant que des process hôtes armés vivent (mèches ESM) — rebuild d'abord, restart ensuite.
- Généraliser l'auto-fresh d'une machine à la flotte : hétérogène (web1 = cron worker 6h qui rebuild ; sessions interactives = non, d'où `ensure-build-fresh.ps1`).

### Incidents

- po-204 (c.14, confirmé firsthand : build stale 48 min après bump → rebuild → 12 422 tests verts ; puis signature `-32603 "no export named"` avec build fresh = couche hôte) · web1 (c.82 : mode hôte mémoire nommé « distinct failure mode ») · po-2026 (c.24 : signal initial du stale build). Promotion T5→T1 #2368 : la leçon survit au changement de machine — elle décrit le harnais (process hôte + build), pas une machine.

---

## Voir aussi

- [`.claude/configs/user-global-claude.md`](../../.claude/configs/user-global-claude.md) — le harnais global lui-même (règles succinctes)
- [`docs/harness/reference/roosync-tools-guide.md`](reference/roosync-tools-guide.md) — inventaire MCP roo-state-manager
- [`docs/harness/reference/conversation-browser-detailed.md`](reference/conversation-browser-detailed.md) · [`docs/harness/reference/sddd-conversational-grounding.md`](reference/sddd-conversational-grounding.md)
- Côté projet, chaque dépôt porte ses propres règles auto-chargées (`.claude/rules/`) : hygiène du harnais à 3 tiers, discipline coordinateur, re-arm des crons expirés.
