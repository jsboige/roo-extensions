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
- **Infra d'un autre workspace : se demande, ne s'applique pas** (decision user 23/09) — `.env`, `docker-compose` ou conteneur d'infra partagee : modifiable uniquement depuis le workspace qui le porte ; une autre lane **demande** sur le dashboard du proprietaire, meme quand le geste parait evident. **Exception urgence** (flotte a l'arret) : agir, puis excuse + explication sur le dashboard proprietaire **dans le meme cycle**. [Detail](../../docs/harness/global-rules-detail.md#infra-dun-autre-workspace--demander-pas-appliquer)
- **Securite :** jamais de suppression sans preuve de preservation. Pas de secrets dans les commits. Preferer les actions reversibles.

## Git

- **Conventional commits** : `type(scope): description`. `Co-Authored-By: Claude-Code <noreply@anthropic.com>` si assiste.
- **Conflits** : JAMAIS de resolution aveugle. Lire les marqueurs, comprendre les deux cotes, decider deliberement.
- **Submodules** : commiter DEDANS d'abord, push, puis bump le pointeur parent.
- **Force push** : interdit sur branches partagees. Rejete -> fetch, merge, retry.
- **Checkout safety** : `git checkout -- <fichier>` restaure depuis l'INDEX — il efface TOUT le non-commite du fichier. Revert d'une mutation de verification : `cp` backup/restore, JAMAIS `git checkout --`. [Detail](../../docs/harness/global-rules-detail.md#git--checkout-safety)
- **Postcondition Git de fin de cycle** : une session ayant travaille dans un depot ne termine pas tant que son clone principal n'est pas revenu sur la branche par defaut, fast-forward avec son upstream, index/worktree propres, sous-modules aux gitlinks epingles ; contenu utile commite+pousse avec PR, ou sauvegarde hors depot (manifeste + empreintes) ; jamais de suppression sans preuve de preservation. Organe : `python scripts/check_clean_cycle_exit.py` **depuis un checkout roo-extensions** (`--path <depot>` pour tout autre depot). [Detail](../../docs/harness/reference/clean-cycle-exit.md)

## Read Body Before Any Action (HARD, aucune exception)

Avant de **commenter**, **reviewer**, **merger**, **dispatcher** ou **commencer un fix** sur une issue/PR : lire (1) le **body complet**, (2) **tous les commentaires**, (3) **toutes les reviews** (humains ET bots, avec leur `state`), (4) le **diff**. **Ne pas merger** si `reviews[].state == "CHANGES_REQUESTED"` non adressee ou commentaires inline non resolus. L'instrument peut mentir : `| jq` et `--jq '.comments[].body'` fragmentent — `tail -N` masque des commentaires entiers ; `gh --jq '.comments[]'` = 1 ligne = 1 commentaire, enumerer les en-tetes avant de poster. Matrice action->lecture, anti-patterns, incident fondateur (2026-05-17) : [detail](../../docs/harness/global-rules-detail.md#read-body-before-any-action).

## Tool Discipline

- **Read avant Edit** — Edit echoue sans Read prealable. Toujours. Creer = `Write` (Read d'abord si le fichier existe) ; ajouter = `Edit` sur le dernier bloc (jamais `Write`, qui ecrase tout) ; remplacement >50% = preferer `Write` + verification. `old_string` doit etre unique. Matrice complete : [detail](../../docs/harness/global-rules-detail.md#file-writing--matrice-de-selection).
- **Tests** : `npx vitest run` / `npx jest --ci` (jamais `npm test` — le watch mode bloque).
- **Bash sans attente d'approbation** : dans une commande composée, ni `cd` vers un autre dossier ni `rm` sur un chemin. Utiliser `git -C <chemin>` ou des chemins absolus en argument, `git worktree remove` pour un worktree, et des appels séparés. En bypass, ces formes déclenchent une attente d'approbation silencieuse (#4243).
- **Build + test** apres tout changement de code. Ne jamais commiter du code casse.
- **Large persisted outputs (#1340)** : `<50 KB` -> `Read` complet ; `50-500 KB` -> `Read` avec `offset`/`limit` ; `>500 KB` -> `Bash` + `head`/`grep`/`jq`. Ne JAMAIS `Read` un fichier persiste enorme : l'explosion de contexte tue la tache.
- **Scratch d'agent (v3, 11/10)** : artefacts jetables **d'abord** dans un repertoire local gitignore du workspace (`<repo>/.tmp/`), sinon le scratchpad de session du harnais, sinon `%TEMP%`/`/tmp` hors `claude/`. Jamais ailleurs sous `~/.claude/` ou `%TEMP%\claude\`. Les sorties du harnais (`…\tasks\*.output`) se **lisent** normalement ; une archive de preservation n'est pas du scratch et garde son emplacement. Nettoyage : fichiers **nommes**, sans `rm -rf` — **exception Q27 (user 25/10)** : suppression recursive d'**un** dossier nomme par commande isolee, preuve ecrite **avant** (arbre propre, HEAD sur origin, aucun lien sortant ; orphelin : archive 7z du non-regenerable d'abord), puis absence mesuree ; jamais une licence pour `git worktree remove --force` ni pour contourner la garde racine-de-disque de Claude Code ; nettoyer de temps a autre `.tmp/` + scratchpad + `%TEMP%` ; jamais supprimer le workspace ni un parent. Chaque depot ignore `.tmp/`, `scratchpad_*`, `C:Users*`. [Detail](../../docs/harness/global-rules-detail.md#scratch-dagent--emplacement-et-nettoyage)

## Harnais serré (15/09, #3657)

`settings.json` : deny `AskUserQuestion`/`EnterPlanMode`/`ExitPlanMode`/`DesignSync`, `mode: auto-approve`, `outputStyle: Proactive`, `ENABLE_TOOL_SEARCH: "true"`, `disableBundledSkills`, `disableClaudeAiConnectors`, `disableRemoteControl`. Conséquences :
- **Zéro question bloquante** — question non bloquante = registre persistant (`memory/open-questions-ledger.md` par workspace), représenté à chaque fin de cycle, sorti **que sur réponse user**. Détail : [`harnais-tightening.md`](../../.claude/rules/harnais-tightening.md).
- **Notebooks** via MCP `jupyter-papermill` (activé au besoin) ; `NotebookEdit` est deny, pas de fallback.
- **Harnais maigre** — schémas MCP en différé ; effet à mesurer par lane.

## Harness Amplification Control

- Tenir un **ledger turn-local** des obligations ; avant un sweep, chacune est `done`, `blocked` avec `WAIT_FOR` + `RESUME_WHEN`, ou `handed-off` explicitement. Pas de nouveau registre persistant.
- **`always-pick-next` reste obligatoire** : exclure la candidate bloquee jusqu'a son evenement de reprise et prendre une autre tache actionnable. L'evenement autorise le reexamen, pas l'action bloquee.
- Une condition asynchrone a **un seul observateur** ; ne jamais poller en parallele d'une notification existante, et couvrir succes, echec, annulation, timeout et terminaison inattendue.
- Reutiliser les lectures du tour sauf mutation pertinente, acteur independant pertinent ou frontiere de securite. Attribuer par `session_id` avant machine, puis parent/sous-agent quand disponible.
- Communication : **3-5 lignes par defaut** ; decision, blocage et preuve peuvent depasser ce format. [Detail](../../docs/harness/global-rules-detail.md#harness-amplification-control)

## User Arbitration — Questions au registre, pas au fil

Mandat user 2026-09-15 (#3656) : **aucune question a l'arbitrage user n'est posee en cours de session.** Le user arbitre **par pull, pas par push** — le registre remplace une **interruption** par une **restitution**.

1. Question -> **immediatement** le registre per-machine `user-question-registry.md` (memoire du workspace `~/.claude/projects/<hash>/memory/`, indexe dans `MEMORY.md`). Jamais dans le fil.
2. **Fin de session** : restitution **en bloc** des ouvertes dans le rapport final, **+ une entrée consolidée sur le dashboard `global`** (tag `ASK-USER`, une seule par lane et par fin de session, questions ouvertes uniquement — #4196, demande user 09/10 : le registre local reste la source de vérité, l'entrée globale est la vue mutualisée ; **zéro question ouverte = pas d'entrée**).
3. Sans reponse, la question **survit aux reprises de cron** : represee au **cycle suivant** via `MEMORY.md`, sans se re-poster dans le fil.
4. Champs obligatoires par entree : **ce qui est attendu du user** et **comment verifier qu'elle est morte** — sans retrait, une question repondue se re-pose indefiniment.
5. Entree repondue -> **sort des ouvertes** (section courte « repondues »).
6. Plan demandant validation : **scratchpad** (`$TEMP`) ; on rend le **chemin** du scratchpad, jamais le plan recopie dans le fil.

**Format d'ecriture (escalade user 25/09/2026)** : phrases simples, sans jargon non explique — (1) **ce qui se passe** ; (2) **ce qui est demande** (oui/non, ou un choix a/b/c) ; (3) **ce qui arrive sans reponse** ; (4) **ce que la lane recommande** ; (5) **l'echeance** s'il y en a une. Des chiffres seulement s'ils aident a decider. **Jamais un mot plus fort que ce qui a ete mesure.**

Cablage : le tag signale (`ASK` dashboard, `[ASK USER]`, `ASK-USER` sur le global en fin de session, « Actions user en attente »), **le registre porte l'etat entre deux sessions** — une seule liste, jamais deux qui derivent (l'entree globale est une VUE du registre, reconstruite a chaque fin de session, jamais un second etat). [Detail](../../docs/harness/global-rules-detail.md#user-arbitration--registre-des-questions)

### Quand le user engage la conversation — réponses intermédiaires (mandat user 26/09)

Le registre porte les questions **agent -> user**. Quand **le user** ouvre un echange, lui donner de quoi réagir — la **conclusion vérifiée** reste pour le **message final**. **Tôt, une poignée de messages** : tendance + **niveau de croyance initial** (mesuré / supposé / à vérifier), en **texte visible** avant l'appel d'outil suivant, dans la langue du user, **sans clore le tour** — restée dans le raisonnement, elle ne lui parvient pas. **Sans insister** : jamais relancer un user silencieux ; un résultat intermédiaire significatif (mesure qui renverse l'hypothèse, décision prise) mérite un court message. Conclusion non vue avant la session suivante : **réitérée** au cycle suivant, portée par la mémoire de reprise, puis sortie dès qu'il a réagi. **Anti-patterns** : tout garder pour le message final ; présenter une croyance initiale comme une conclusion vérifiée. [Detail](../../docs/harness/global-rules-detail.md#user-arbitration--registre-des-questions)

## Windows / PowerShell Gotchas

- **UTF-8 BOM** : `Set-Content`/`Out-File` ajoutent un BOM -> casse les parsers. Utiliser `[System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))` ou PS7+ `-Encoding utf8NoBOM`.
- **Join-Path PS 5.1** : 2 args seulement. Preferer `"$a/b/c/d"`.
- **`Get-Date -Format u`** : heure LOCALE + suffixe « Z » — PAS une conversion UTC (faux skew cross-clock). UTC : `[DateTimeOffset]::UtcNow` ou `(Get-Date).ToUniversalTime()`.
- **`[Environment]::TickCount64`** : absente sous PS 5.1 → `$null` silencieux (0 en arithmétique ; a figé une garde Docker, Maintenance#72). Durée : `[Diagnostics.Stopwatch]::StartNew()` ; boot : `(Get-CimInstance Win32_OperatingSystem).LastBootUpTime`. PAS `[Environment]::TickCount` (Int32, négatif après ~24,9 j).
- **Line endings** : `core.autocrlf = true` ou `.gitattributes`. Sensibles au CRLF : Bash, Docker.

## MCP Tools

**roo-state-manager** = MCP critique (coordination, conversations, dashboards, indexation). Config : `~/.claude.json` section `mcpServers.roo-state-manager`.

- **Dashboard (canal PRINCIPAL)** : 3 types — `global`, `machine`, `workspace`. Debut de session -> `roosync_dashboard(action:"read", type:"workspace", section:"all")` (JAMAIS `section:"status"` seul, #2306). Fin -> `append` avec tag `DONE`. Tags : `INFO`, `TASK`, `DONE`, `WARN`, `ERROR`, `ASK`, `REPLY`, `ACK`, `PROPOSAL`, `BLOCKED`, `CLAIMED`.
- **conversation_browser** : `list` OBLIGATOIRE en premier (sinon pas d'IDs) -> `view`/`tree`/`summarize`. `smart_truncation:true`, `summarize_type:"trace"` (pas `synthesis`).
- **Recherche** : `roosync_search(action:"semantic"|"text")` ; `codebase_search(query, workspace)` — TOUJOURS passer `workspace`, requetes en anglais.
- **RooSync inter-machines** : `roosync_messages(action:"inbox"|"send")`. Dashboard = principal, DM = decision/urgence.
- **Stale MCP host** : une session vivante sert le build charge au demarrage du process hote — `-32603 "no export named X"` ou comportements anciens alors que source ET `build/` sont frais = hote memoire stale. Restart de session = fix legitime (dernier recours) a DEMANDER a l'utilisateur, jamais suggere d'office. [Detail](../../docs/harness/global-rules-detail.md#mcp--stale-host-memory)

Inventaire : [`roosync-tools-guide.md`](../../docs/harness/reference/roosync-tools-guide.md) · [`conversation-browser-detailed.md`](../../docs/harness/reference/conversation-browser-detailed.md). Autres MCP : playwright (automation web), markitdown (PDF/DOCX->MD), searxng (web), sk-agent (vision/multi-agent).

### Escalade cross-workspace — le cross-post donne le point de rendez-vous

**Règle (arbitrage user 06/09/2026)** : sujet dans une seule lane -> dashboard `workspace` ; cross-workspace -> **poster une fois à l'échelon supérieur** — dashboard **`global`**, et **`machine`** si spécifique à une machine — avec `crossPost` vers les workspaces concernés, en disant où la suite se passe. Escaler ≠ recopier partout : les DM ne font plus que renvoyer vers ce point de rendez-vous unique. Le message d'escalade porte : **qui porte quel volet** · **ce qui est en cours à l'instant** (anti-doublon) · **ce qui est attendu de chaque lane** · **les effets de bord annoncés** — non annoncé = lu comme une panne chez le voisin. Pourquoi, table portée->canal, forme du `crossPost`, précédent fondateur : [detail](../../docs/harness/global-rules-detail.md#escalade-cross-workspace--le-point-de-rendez-vous-unique).

## SDDD — Triple grounding

Croiser **Technique** (code = verite : Read/Grep/Glob/Git), **Conversationnel** (`conversation_browser`), **Semantique** (`codebase_search` + `roosync_search`). Jamais une seule source. **Pattern Bookend** : `codebase_search` en DEBUT (doc existante, ne pas refaire) et en FIN (indexation, MAJ doc afferente). `codebase_search` : **TOUJOURS** `workspace` explicite, requetes en anglais, **4 passes** (large → `directory_prefix` → grep exact → reformuler) ; `conversation_browser` : `list` OBLIGATOIRE en premier, `summarize_type: "trace"`. Ne JAMAIS propager une affirmation non verifiee — qualifier **VERIFIE / RAPPORTE / SUPPOSE**. Detail : [`global-rules-detail.md`](../../docs/harness/global-rules-detail.md) §SDDD + [`sddd-conversational-grounding.md`](../../docs/harness/reference/sddd-conversational-grounding.md).

### Session Pattern (tout workspace) — OBLIGATOIRE

1. **Debut** : `roosync_dashboard(action:"read", type:"workspace", section:"all")` + skill `memory-inject`.
2. **Pendant** : travailler. Blocage -> `append` tag `ASK`.
3. **Fin** : `append` tag `DONE` — **aucune exception**. Les rapports vont sur le dashboard, PAS dans des fichiers du depot.

**Ordre OBLIGATOIRE** : commit + PR AVANT le rapport `[DONE]`. Ne jamais annoncer un travail non commite.

## Knowledge Preservation

Pas de memoire entre sessions : ecrire les apprentissages dans des fichiers avant la fin. Hierarchie : `~/.claude/CLAUDE.md` (global) · `CLAUDE.md` repo (projet) · `~/.claude/projects/<hash>/memory/MEMORY.md` (par machine) · `.claude/rules/*.md` (auto-loaded). Le CLAUDE.md projet recoit les **decisions** ; detail, mesures et incidents vont dans `docs/` avec un pointeur d'une ligne. Apres chaque tache significative : MAJ CLAUDE.md projet + MEMORY.md, consigner les approches **testees-et-rejetees**.

**Les paroles du user survivent a la session (mandat user 20/10, « amnesie systemique »)** : le hook `user-words-journal` copie chaque message humain (tape ou envoye en cours de tour) dans `memory/user-words-journal.jsonl` et le reinjecte au demarrage et apres chaque compaction (7 jours). Le journal n'est pas la memoire : une consigne qui doit durer au-dela de 7 jours est **promue en fiche, citation verbatim**, avant la fin du cycle ; une consigne deja donnee ne se redemande jamais. [Detail](../../docs/harness/reference/user-words-journal.md)

## Multi-Machine Ping-Pong — Re-arm

**Scope STRICT** : sessions Claude Code **interactives** avec role actif coordinateur OU worker dans un workflow multi-machine — PAS les workers/meta-analystes schedules (double-firing), sessions informationnelles, ad-hoc/debug, workspace single-machine, ou post-handoff documente. Heuristique : « un cluster produit-il du travail dont je dois m'occuper au tour suivant ? » — si OUI **et** session interactive **et** role coord/worker -> re-armer.

- **Armement et verification des crons/wakeups : par l'agent PRINCIPAL, jamais delegues** — un sub-agent n'a pas les tools de scheduling, et un timer cree dans sa session mourrait avec lui (#3722). Un sub-agent a qui il manque un tool s'arrete apres une ou deux tentatives et **rapporte**, il ne cherche pas de substituts (#3722).
- **Cadence** : `ScheduleWakeup` est clampe a `[60, 3600]s` — une cadence > 1 h est portee par `CronCreate`, **sans** `ScheduleWakeup` par-dessus ; session interactive NON-cron : `ScheduleWakeup(delaySeconds: 3540)` en repli. Jitter : minute off-`:00`. Auto-regulation par cap 3-IDLE (#2185) + override `[WAKE-CLAUDE]`, pas par timer adaptatif. [Detail](../../docs/harness/global-rules-detail.md#multi-machine-ping-pong--re-arm)
- **Le cron d'une session interactive se ré-arme DANS la session (`CronCreate`), jamais par une tâche planifiée Windows qui relance `claude` sur la même lane** : les deux tirent au même cycle et la lane tourne en double (escalade CoursIA-2, 07/10). Les workers planifiés gardent leur tâche, sans cron de session par-dessus.

## Split-Brain — un cron double dans la meme instance (correction owner 20/10)

L'owner ne demarre **jamais plus d'une instance d'une lane par machine**. Deux sessions actives d'une meme lane = un **cron double dans la meme instance** : l'une des deux est **cachee et non interactive**. Ne jamais demander a l'owner de fermer une fenetre ou de redemarrer une instance. Remede cote agents : chaque session publie l'ID de son cron (`CronList`) sur son dashboard, et le doublon se supprime (`CronDelete`) **dans la session qui le porte**. Mecanisme d'apparition **non etabli** : ne pas inventer de cause.

Corollaire : **aucun cron ni tache planifiee pour « reprendre » une lane douteuse** — deux tireurs refont le meme cycle (escalade CoursIA-2, 07/10). [Detail](../../docs/harness/global-rules-detail.md#split-brain--un-cron-double-dans-la-meme-instance)
