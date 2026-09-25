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
- « J'ai listé les N derniers commentaires » → **l'instrument de lecture tronque** : seuls `| jq '.comments[]'` (binaire externe, pretty-print) et `--jq '.comments[].body'` fragmentent — mesuré sur 26 commentaires (`#2368`, 2026-09-04) :

  | Forme | Lignes rendues | `tail -N` ? |
  |---|---|---|
  | `gh … --jq '.comments[]'` | **26** | sûr — 1 ligne = 1 commentaire |
  | `gh … \| jq '.comments[]'` (externe) | **390** | fragmente (~15 l./commentaire) |
  | `gh … --jq '.comments[].body'` | **1020** | fragmente (~39 l./commentaire) |

  Garde : énumérer les en-têtes (`--jq '.comments[] | "\(.id) \(.createdAt) \(.author.login)"'`), ou rendre 1 ligne = 1 enregistrement avec `@tsv` (échappe les newlines nativement). Piège distinct mais même symptôme apparent : `@chemin` dans un body `gh` part tel quel (non interprété) — cf. incident `@FILE:` 2026-08-24 15:17Z.

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

## Harness Amplification Control

Le harnais doit terminer des obligations, pas maximiser le nombre d'actions. Le contrat #3647 garde
l'obligation de continuer tout en retirant les quotas numériques qui transformaient chaque résultat
en prétexte pour ouvrir une nouvelle tâche.

### Ledger turn-local

Le ledger est une vue de travail du tour, jamais un fichier, une base ou un service supplémentaire :

| Champ | Rôle |
|---|---|
| `candidate` | issue, PR ou condition suivie |
| `state` | `active`, `done`, `blocked`, `handed-off` |
| `WAIT_FOR` | condition qui bloque réellement |
| `RESUME_WHEN` | événement nommé qui justifie un réexamen |
| `observer` | unique mécanisme chargé de signaler la fin |
| `evidence` | résultat ou preuve déjà lu dans ce tour |

Avant tout sweep spéculatif, chaque obligation est terminée, bloquée avec reprise nommée, ou remise
explicitement à un destinataire. Une candidate bloquée sort temporairement de la file ;
`always-pick-next` impose alors de prendre une autre issue en souffrance. Un événement de reprise
permet seulement de réexaminer la candidate : il ne vaut ni autorisation humaine ni preuve que la
condition est satisfaite.

### Fraîcheur et observation

Une lecture faite dans le tour est réutilisable. La rafraîchir seulement après une mutation pouvant
changer l'état, l'intervention pertinente d'un acteur indépendant, ou une frontière de sécurité.
Une condition asynchrone n'a qu'un observateur : si une tâche de fond, `Monitor` ou `gh run watch`
notifiera, aucun second poll ne la surveille. L'observateur doit rendre tous les états terminaux :
succès, échec, annulation, timeout et terminaison inattendue.

### Attribution et communication

Attribuer une mesure par `session_id` avant toute agrégation machine ; distinguer
`parent_session_id` et `subagent_id` quand ils existent. Une variation machine-wide ne prouve pas
quelle session, quel parent ou quel sous-agent l'a produite. Les messages font 3-5 lignes par défaut ;
les décisions, blocages et preuves discriminantes peuvent dépasser cette borne.

---

## User Arbitration — Registre des questions

Mandat user 2026-09-15 (issue #3656), donné en session directe (myia-ai-01, workspace CoursIA) — portée **machine-globale**, la règle vit dans le harnais global :

> « Je prefere que tu gardes tes questions pour la fin de session, et si jamais le cron reprend, que tu les gardes tant qu'elles sont pas repondues dans une memoire que tu dois restituer en fin de session. Ca va demander une MAJ du harnais global en coordination avec roo-extensions »

> « Pour le mode plan utilisez un scratchpad et si une validation utilisateur est necessaire, donner le chemin du scratchpad en fin de session »

### Pourquoi le registre (le mécanisme rend la règle auto-applicable)

Le user arbitre **par pull, pas par push**. Une question posée en plein cycle le force à arbitrer au rythme de la session de l'agent plutôt qu'au sien. Sous cron c'est pire : la question part dans un tour qu'il ne lira peut-être jamais — et l'agent la perd au cycle suivant. Le registre remplace une **interruption** par une **restitution**.

### Emplacement canonique et format

| Élément | Valeur |
|---|---|
| Fichier | `user-question-registry.md` |
| Répertoire | la mémoire auto-chargée du workspace : `~/.claude/projects/<hash>/memory/` (per-machine, jamais commité) |
| Index | une ligne dans `MEMORY.md` (toujours chargée en contexte) portant le **nombre de questions ouvertes** |
| Frontmatter | `type: project` |

La ligne d'index dans `MEMORY.md` est le mécanisme du point 3 (survie aux reprises de cron) : la question ouverte se ré-presente au cycle suivant **sans se re-poster dans le fil**, parce que `MEMORY.md` est injectée à chaque session.

Format d'une entrée — les deux champs marqués OBLIGATOIRES sont le seul anti-pourrissement : sans mécanisme de retrait, une question répondue se re-pose indéfiniment (défaut mesuré des anciennes listes de bloqueurs, qui re-postaient des items morts de cycle en cycle) :

    ## Ouvertes

    | # | Question | Attendu du user (OBLIGATOIRE) | Comment vérifier qu'elle est morte (OBLIGATOIRE) | Depuis |
    |---|---|---|---|---|
    | 1 | Faut-il révoquer la clé X avant le 20/09 ? | oui/non + date | `gh api` retourne `revoked:true`, ou commentaire user du 19/09 | 2026-09-15 |

    ## Répondues

    - 2026-09-16 #1 — répondue (commentaire user) : oui, révoquée. Sortie des ouvertes.

### Câblage au signalement existant (une seule liste, jamais deux)

Le signalement de fin de session reste : tag `ASK` sur le dashboard (Session Pattern), `[ASK USER]` côté workers, section « Actions user en attente » côté coordinateur (`user-blocker-signaling.md`, règle qui vit côté CoursIA, pas dans ce dépôt). **Le tag signale, le registre porte l'état entre deux sessions.** Les deux gestes sont câblés : la restitution de fin de session EST le contenu pointé par le tag — poster le tag sans lire le registre, ou tenir une seconde liste de questions dans le fil, recrée exactement la dérive que le champ « comment vérifier qu'elle est morte » existe pour éteindre.

Où la règle `user-blocker-signaling.md` existe, elle doit renvoyer vers ce registre (convergence à traiter côté CoursIA).

### Plans : scratchpad, pas le fil

Un plan demandant validation s'écrit dans un scratchpad sous `$TEMP` (jamais dans `.claude/` — sanctuaire, fichiers temporaires → `$TEMP`). Seul le **chemin** est rendu en fin de session. Si la validation est toujours en attente au cycle suivant, l'entrée de registre porte le chemin — le plan n'est jamais recopié dans le fil.

### Clarté — le format d'écriture d'une question (escalade user 25/09/2026)

Le user a rejeté les questions rendues en une ligne de jargon — les 5 de `po-2025:claudish`, prises comme exemple pour toute la flotte :

> « Q6 ça veut dire quoi ? Stp escalade sur le dashboard global. J'en ai marre de vous faire préciser ce qui n'est pas clair. Le reste est aussi obscur. »

Deux conséquences, et c'est la seconde qui coûte le plus cher :

- le user doit relancer pour comprendre : la question n'arrive pas du premier coup ;
- **un mot plus fort que les faits fait arbitrer un problème inexistant.** « Rotation de la clé du proxy, qui a été exposée » s'est lu comme une fuite publique. Mesure du 25/09 : 0 occurrence dans le dépôt GitHub public (historique de toutes les branches, issues et commentaires). Le mot « exposée » ne portait rien de mesuré ; il a produit une inquiétude, pas une information.

Le format — **ce qui se passe / ce qui est demandé (oui-non ou a-b-c) / ce qui arrive sans réponse / ce que la lane recommande / l'échéance** — vit dans le porteur [`.claude/configs/user-global-claude.md`](../../.claude/configs/user-global-claude.md), section « User Arbitration ». Il s'applique aux **trois** canaux : fil de session, entrée de registre, message de dashboard. Des chiffres seulement s'ils aident à décider.

### Outils d'interactivité retirés par le user (déjà fait, côté user)

| Outil retiré | Substitut |
|---|---|
| `AskUserQuestion` | registre mémoire + restitution en fin de session |
| `Plan` / `ExitPlanMode` | plan écrit dans le **scratchpad**, seul le **chemin** est rendu en fin de session |
| `NotebookEdit` | MCP `jupyter-papermill` (qui exécute en outre) |
| bundledSkills | skills du projet et de l'utilisateur uniquement |
| remote control, connecteurs ClaudeAI | MCP locaux |

Ce n'est plus une préférence contournable : c'est une **impossibilité** outillage.

### Point vérifié — `disableBundledSkills` (évite une fausse alerte)

`"disableBundledSkills": true` dans `settings.json` ne coupe **que** les skills livrés par Anthropic. Les skills **de projet** (`.claude/skills/`) et utilisateur restent chargés — vérifié empiriquement (2026-09-15) : le cron a invoqué `/coordinate` (skill de projet) normalement avec ce réglage déjà actif. Aucune action requise ; noté parce qu'une mauvaise réponse aurait cassé la cadence de coordination de toute la flotte.

### Garde

`scripts/testing/unit/user-arbitration-registry.Tests.ps1` — garde statique Pester (#3656) : les 6 points, la justification pull/push, le câblage au signalement et le nom canonique du fichier doivent rester présents dans le porteur `.claude/configs/user-global-claude.md`, et l'escalade niveau 5 (`escalation-protocol.md`) ne doit plus instruire d'utiliser `AskUserQuestion`.

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

- po-2024 (c.14, confirmé firsthand : build stale 48 min après bump → rebuild → 12 422 tests verts ; puis signature `-32603 "no export named"` avec build fresh = couche hôte) · web1 (c.82 : mode hôte mémoire nommé « distinct failure mode ») · po-2026 (c.24 : signal initial du stale build). Promotion T5→T1 #2368 : la leçon survit au changement de machine — elle décrit le harnais (process hôte + build), pas une machine.

---

## Infra d'un autre workspace — demander, pas appliquer

**Décision user (23/09/2026), verbatim :** « OK pour la règle (sauf exception urgence avec message d'excuse dans le dashboard cible) ». Règle proposée et portée par le coordinateur claudish (dashboard `global`, 22/09 22:18Z) ; déjà en vigueur côté claudish (SKILL coordinateur Phase 5b, PR claudish #221).

1. Un `.env`, un `docker-compose` ou un conteneur d'**infra partagée** ne se modifie que depuis le **workspace qui le porte**.
2. Une autre lane **demande** sur le dashboard du propriétaire. Elle ne fait pas le geste elle-même, même quand il paraît évident.
3. **Exception urgence** (flotte à l'arrêt, tours perdus) : on agit, puis on poste **un message d'excuse et d'explication sur le dashboard du workspace propriétaire, dans le même cycle**.

### Pourquoi

Le propriétaire sait ce que la lane de passage ignore : qui consomme le service, ce qui est en vol, quel état est voulu. Un geste de bonne foi sur l'infra d'autrui coupe les flux de toute la flotte sans que personne ne l'ait annoncé — et un effet de bord non annoncé se lit comme une panne chez le voisin.

### Incidents fondateurs (RAPPORTÉS par le coordinateur claudish, hub po-2025)

- **17/09** — une session CoursIA-2 lance `compose up -d` ×4 sur le hub en déboguant un vrai défaut.
- **19/09** — une session worker roo-extensions réécrit le `.env` du hub sur le modèle sidecar puis recrée le conteneur : le hub se relaie sur lui-même pendant **4 h 40** (193 bascules AUTONOMOUS).

### Ce que la règle ne change pas

- Dans **son** workspace, le geste reste libre — mais ses effets de bord sur les consommateurs des autres lanes s'**annoncent** (cf. « Escalade cross-workspace » : les effets de bord annoncés font partie du message).
- Qui porte quoi : la table de propriété d'infra vit dans la mémoire de chaque machine et sur les dashboards ; en cas de doute sur le porteur, demander sur le dashboard `global`.

---

## Voir aussi

- [`.claude/configs/user-global-claude.md`](../../.claude/configs/user-global-claude.md) — le harnais global lui-même (règles succinctes)
- [`docs/harness/reference/roosync-tools-guide.md`](reference/roosync-tools-guide.md) — inventaire MCP roo-state-manager
- [`docs/harness/reference/conversation-browser-detailed.md`](reference/conversation-browser-detailed.md) · [`docs/harness/reference/sddd-conversational-grounding.md`](reference/sddd-conversational-grounding.md)
- Côté projet, chaque dépôt porte ses propres règles auto-chargées (`.claude/rules/`) : hygiène du harnais à 3 tiers, discipline coordinateur, re-arm des crons expirés.
