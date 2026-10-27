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

**Cadence d'un observateur GitHub (Maintenance#196, 27/10).** `gh pr checks --watch` interroge l'API
toutes les 10 s par défaut, et chaque appel `gh` est un processus neuf qui refait sa résolution DNS.
Le journal DNS client d'ai-01 a désigné une session Claude Code (`--watch --interval 30`) parmi les
sources du fond continu vers `api.github.com`, à côté des runners CI et des scripts de merge. Un
cycle CI dure de 10 à 40 min : une boucle `sleep 180` bornée (par exemple 15 itérations), qui sort
dès qu'aucun check n'est `pending`, rend le même verdict avec 6 fois moins d'appels qu'un intervalle
de 30 s, et 18 fois moins que le défaut.

### Attribution et communication

Attribuer une mesure par `session_id` avant toute agrégation machine ; distinguer
`parent_session_id` et `subagent_id` quand ils existent. Une variation machine-wide ne prouve pas
quelle session, quel parent ou quel sous-agent l'a produite. Les messages font 3-5 lignes par défaut ;
les décisions, blocages et preuves discriminantes peuvent dépasser cette borne.

### La limite du harnais

Retirer l'amplification du harnais ne promet pas de supprimer la verbosité côté modèle : la
croissance de sortie par requête et de *thinking* observée à l'été 2026 est un effet modèle, que le
harnais ne peut ni expliquer ni corriger. Le succès de #3647 se mesure donc en **observations
dupliquées, compactions et sortie par obligation terminée** — pas en nombre d'appels d'outils — et
une verbosité modèle résiduelle n'invalide pas le travail fait ici. Le versant télémétrique
avant/après appartient à l'issue claudish, pas à ce dépôt.

---

## User Arbitration — Registre des questions

Mandat user 2026-09-15 (issue #3656), donné en session directe (myia-ai-01, workspace CoursIA) — portée **machine-globale**, la règle vit dans le harnais global :

> « Je prefere que tu gardes tes questions pour la fin de session, et si jamais le cron reprend, que tu les gardes tant qu'elles sont pas repondues dans une memoire que tu dois restituer en fin de session. Ca va demander une MAJ du harnais global en coordination avec roo-extensions »

> « Pour le mode plan utilisez un scratchpad et si une validation utilisateur est necessaire, donner le chemin du scratchpad en fin de session »

### Pourquoi le registre (le mécanisme rend la règle auto-applicable)

Le user arbitre **par pull, pas par push**. Une question posée en plein cycle le force à arbitrer au rythme de la session de l'agent plutôt qu'au sien. Sous cron c'est pire : la question part dans un tour qu'il ne lira peut-être jamais — et l'agent la perd au cycle suivant. Le registre remplace une **interruption** par une **restitution**.

### Vue mutualisée fin de session (#4196, forme (a) — arbitrage user 14/10)

Demande user du 09/10 (relayée po-2024:CoursIA) : les registres étant morcelés par lane, **personne ne voit l'ensemble des questions ouvertes**. Forme (a) arbitrée (dispatch c.22bis, doc + règle, pas de code) : chaque lane, **en fin de session**, append **une entrée consolidée** taguée `ASK-USER` sur le dashboard **`global`** — questions ouvertes uniquement, format 5 points ci-dessous, **une seule vue par lane** (pas une entrée par question). Le registre local reste la **source de vérité** ; l'entrée globale est une vue reconstruite à chaque fin de session, jamais un second état qui dériverait (même principe que « une seule liste » ci-dessus). **Zéro question ouverte = pas d'entrée** — le canal reste silencieux quand il n'y a rien à arbitrer.

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

### Réponses intermédiaires quand le user engage (mandat 26/09, #3879)

Le registre couvre les questions **de l'agent vers le user**. Quand c'est **le user** qui ouvre un échange en cours de session (question, remarque, concern), il faut lui donner de quoi partir ou réagir : la **conclusion vérifiée** reste réservée au **message final**. La règle opérationnelle (tôt une poignée de messages avec niveau de croyance initial, sans insister, conclusion au dernier message puis réitérée au cycle suivant) vit dans le porteur, section « Quand le user engage la conversation » — portée depuis `jsboige/CoursIA#17955` et gardée par `user-arbitration-registry.Tests.ps1` (#3879) pour qu'une passe de slimming ne la laisse pas tomber en silence.

**Mesure fondatrice (26/09)** : **trois réponses d'étape restées dans le raisonnement** — le user a cru à un silence et a dû relancer pour obtenir la tendance. Une réponse d'étape qui ne passe pas par un bloc de **texte visible** placé avant l'appel d'outil suivant, dans le même message, ne parvient pas au user : c'est la forme, pas seulement le contenu, qui fait arriver la réponse.

**Sans réponse, rien ne change** pour la lane : la boucle agentique reprend, la conclusion se réitère au cycle suivant portée par la mémoire de reprise, puis sort dès que le user a réagi.

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

## Escalade cross-workspace — le point de rendez-vous unique

**Règle (arbitrage user 06/09/2026, promue depuis `jsboige/Maintenance@b704b52`).** Le dashboard **workspace** est le canal par défaut : tant qu'un sujet reste dans une lane, il y reste. **Dès qu'un problème devient cross-workspace, c'est l'opportunité de le remonter** — sur le dashboard `global`, et potentiellement sur le dashboard `machine` s'il est spécifique à une machine.

**Le mécanisme est le cross-post, et sa fonction est de désigner un point de rendez-vous unique.** Escalader ne veut pas dire recopier le sujet partout : cela veut dire poster **une fois** à l'échelon supérieur, en disant explicitement où la suite se passe, puis n'utiliser les DM que pour pointer vers cet endroit.

| Portée du sujet | Canal | Geste |
|---|---|---|
| Une seule lane | dashboard `workspace` | `append` normal |
| Plusieurs workspaces / plusieurs machines | dashboard **`global`** | `append` + `crossPost` vers les workspaces concernés |
| Spécifique à une machine mais traversant ses lanes | dashboard **`machine`** | `append`/`update` + `crossPost` |

```
roosync_dashboard(action:"append", type:"global", content:"...",
                  crossPost:[{type:"workspace", workspace:"roo-extensions"},
                             {type:"workspace", workspace:"claudish"}])
```

**Pourquoi.** Un sujet cross-workspace traité en messages point-à-point produit autant de fils qu'il y a de destinataires : personne ne voit l'état consolidé, les réponses atterrissent dans des inbox disjointes, et le premier qui agit ignore ce que les autres ont déjà fait. Le cross-post inverse la charge — **un seul endroit fait foi, les DM ne font plus qu'y renvoyer.**

**À écrire dans le message d'escalade**, sinon le rendez-vous ne tient pas :
1. **Qui porte quel volet** (tableau de répartition explicite).
2. **Ce qui est en cours à l'instant**, pour que personne ne le refasse en double.
3. **Ce qui est attendu en retour** de chaque lane.
4. **Les effets de bord annoncés** (ex. « un redémarrage de conteneur va couper les connexions dans les minutes qui viennent ») — un effet de bord non annoncé se lit comme une panne chez le voisin.

**Précédent fondateur** — chantier « pression de ressources » du 06/09/2026 : PostgreSQL saturé côté serveur (Maintenance), pools clients (roo-extensions), mesure fleet-wide (6 lanes Maintenance), trafic proxy (claudish). Quatre porteurs, un seul dashboard `global`.

---

## Harnais serré (15/09, #3657) — compléments relocalisés (#2368 round 2)

**Mesure de référence (#99 du 13/09)** : ~105 k tokens/requête dont ~64 % de **définitions MCP inline pour 0,4 % d'appels**. Le différé `ENABLE_TOOL_SEARCH` est ce qui rend les définitions **non payées** tant qu'elles ne sont pas effectivement appelées — et débloque ce qui était impossible avec un `ANTHROPIC_BASE_URL` custom (les définitions inline étaient figées au démarrage).

**Observation ai-01** : ~70 outils passés en différé. Chaque lane mesure son propre delta (taille de harnais avant/après activation du drapeau) et le consigne — le gain dépend des MCPs effectivement chargés.

**Mesure lane po-2028 (R2 #3647, 22/10)** — siège proxied, `ENABLE_TOOL_SEARCH=true`, 5 serveurs MCP configurés :

- **Définitions totales** : 104 795 octets / 80 outils, mesurés par handshake `initialize`→`tools/list` sur chaque serveur configuré (aucun appel d'outil) : RSM 44 163/17 · papermill 24 527/25 · playwright 20 296/25 · sk-agent 8 817/9 · searxng 6 992/4. **Octets ≠ tokens** (≈3–4 car./tok) — à réconcilier en unités avec les « ~105 k » de #99 avant d'en faire un canon.
- **Appels réels sur 7 j** (comptage seul sur les transcripts, #1785) : 236 au total ; **papermill et searxng : 0 appel** — 31 519 octets de définitions servis pour rien sur cette lane.
- **Levier `disabledMcpServers`** : entrée `projects[<chemin workspace>].disabledMcpServers` de `~/.claude.json` retire un serveur jamais appelé ; réversible ; **effet au spawn de session suivant seulement** (pas relu à chaud — les cycles d'un même processus ne peuvent pas la mesurer). Piège #4195 : la clé est indexée par chemin, un déménagement de workspace réactive le serveur en silence.
- Ce que le levier achète : sur une lane à déferrance active, les définitions déjà ne sont pas payées inline — il retire le serveur du harnais (lancement, inventaire différé, rechargements à la demande) ; sur une chaîne où la déferrance est inerte, c'est la pleine charge inline qui part. Mesure avant/après po-2028 (`["jupyter-papermill"]`, attendu −25 outils/−24 527 octets) : au premier vrai respawn de la lane.

**Armement claudish du registre** (jsboige/claudish#111) : Phase 5 consigne, Phase 6 représente. Les autres workspaces suivent le même réflexe (append `[ASK]` sur le dashboard workspace + fichier `open-questions.md` si la question concerne plusieurs sessions).

**Détails de drapeaux** : `disableClaudeAiConnectors` — voir aussi `~/.claude.json` → `claudeAiMcpEverConnected` ; `disableBundledSkills` — skills bundled non présents dans ce projet, proposés en doublon des skills projet sans le drapeau.

**Tableau de drapeaux complet** (déplacé depuis `rules/harnais-tightening.md`, coupe A-suite #445, 17/10/2026) :

| Drapeau | Effet |
|---|---|
| `ENABLE_TOOL_SEARCH: "true"` | Outils MCP chargés **en différé** : les schémas ne sont pas payés inline à chaque requête. Débloque ce qui était impossible avec un `ANTHROPIC_BASE_URL` custom (les définitions inline étaient figées au démarrage). |
| `disableBundledSkills` | Désactive les skills bundled par défaut (non présents dans ce projet) ; évite qu'ils soient proposés en doublon des skills projet. |
| `disableClaudeAiConnectors` | Coupe les connecteurs Claude.ai distants injectés automatiquement (voir aussi `~/.claude.json` → `claudeAiMcpEverConnected`). |
| `disableRemoteControl` | Bloque l'ouverture automatique du navigateur à chaque nouvel artefact. |

---

## Scratch d'agent — emplacement et nettoyage

**Origine** : proposition po-2024:claudish (09/10 15:43Z), discutée par ai-01, CoursIA-3 et web2, synthèse v2 à 19:04Z (dashboard `global`). Le user avait demandé qu'elle soit inscrite dans le harnais global.

**Incident fondateur (po-2024, 09/10)** : une commande qui n'écrivait que dans le scratchpad (extraire des archives du GDrive) est restée **1 h 24 min 28 s** en attente de confirmation. Les horodatages viennent du transcript (`14:09:31.982Z` → `15:33:59.916Z`) et le user a dû débloquer à la main. On a comparé deux commandes presque identiques, lancées à quelques minutes d'intervalle :

| Commande | Issue |
|---|---|
| `mkdir -p` + extraction 7z vers `%TEMP%\claude\…` | passe (~4 min) |
| **`rm -rf`** + `mkdir` + même extraction | **bloquée 84 min** |

La seule différence est le `rm -rf`. **L'emplacement n'était pas la cause**, puisque la même écriture dans `%TEMP%\claude\…` a réussi. D'où le texte de la règle : le scratchpad de session que le harnais désigne lui-même (Claude Code l'annonce dans son prompt système et l'isole par session) reste un emplacement légitime. Ce qui est interdit, c'est d'écrire du scratch **ailleurs** sous `~/.claude/` (configuration, mémoire, règles) ou sous `%TEMP%\claude\`. La règle de nettoyage vise donc le geste : on supprime ses fichiers nommés, sans `rm -rf`, quelle que soit la cible (sauf l'exception Q27 ci-dessous).

**Exception Q27 — un dossier nommé, preuve d'abord (décision user 25/10)** : réponse verbatim « OK pour a » (24/10 23:24Z, journal des paroles de la lane Maintenance ai-01), à l'option (a) telle qu'elle a été posée. La règle stricte contredisait la politique Maintenance du 23/10, selon laquelle les worktrees livrés sont nettoyables d'office, et laissait sur le disque deux restes que seule une suppression récursive retire :
- le dossier qu'un `git worktree remove` laisse derrière lui sous Windows (« Directory not empty », à cause de `node_modules` ; ~10 Go chez claudish sur D: d'ai-01) ;
- le dossier `<git-dir>/modules` d'un worktree à sous-modules, qui bloque `git worktree remove` sans `--force` (Maintenance#127).

Ce qui est autorisé : la suppression récursive d'**un seul dossier nommé** par **commande isolée**, jamais un joker ni un parent, et seulement quand la **preuve de préservation est écrite avant** le geste :
1. arbre propre (`git status` vide) ;
2. HEAD présent sur origin ;
3. aucun lien qui sort du dossier : énumérer les reparse points et délier les jonctions sans les traverser, voir [`worktree-lifecycle`](../../.claude/rules/worktree-lifecycle.md) ;
4. pour un orphelin, archive 7z d'abord de ce qui n'est pas régénérable ;
5. pour `<git-dir>/modules`, chaque dépôt de sous-module a 0 commit absent de son remote, mesuré après un fetch **complet** (piège *single-branch*).

Après le geste, on **mesure** l'absence (`Test-Path` faux).

Deux bornes restent entières :
- **pas de licence pour `git worktree remove --force`**, qui reste un invariant du protocole de recyclage ;
- **pas de contournement de la garde intégrée de Claude Code** sur les dossiers à la racine d'un disque : ce geste reste au user.

La règle shell #4214 est inchangée. Pour ce seul geste, l'exception Q27 déroge à deux de ses clauses, « suppression sur fichiers nommés » et « jamais `rm -rf` sur un chemin absolu » : un dossier hors du répertoire courant a nécessairement un chemin absolu. L'interdiction de `rm` dans une commande composée reste entière. Les suppressions elles-mêmes appartiennent aux lanes propriétaires des dossiers.

**Archive de préservation ≠ scratch** (pré-review 10/10) : l'étape 3 de la [postcondition de fin de cycle](reference/clean-cycle-exit.md) range une archive hors dépôt (manifeste NUL + SHA-256) sous `~/.claude/scratch/…`. Elle doit survivre à la session, elle n'est pas jetable : elle garde son emplacement documenté.

**Amendement web2 (19:26Z)** : la règle porte sur l'**écriture**. Les sorties que le harnais range sous `%TEMP%\claude\<projet>\<session>\tasks\*.output` (tâches en arrière-plan) se lisent normalement. Un agent qui interpréterait la règle trop largement refuserait de les lire, et perdrait ainsi son propre observateur asynchrone.

**Filet `.gitignore` (amendement CoursIA-3)** : les règles gouvernent l'**intention**. Les accidents de **résolution de chemin**, eux, ne déclenchent ni commande destructive ni demande de confirmation, donc aucune règle ne les voit :
- famille A : un chemin absolu dont les séparateurs ont été avalés devient un nom de fichier (`C:Users…`, 28,9 Mo chez CoursIA-3) ;
- famille B : `scratchpad_*` résolu contre le répertoire courant.

Les motifs `.tmp/`, `scratchpad_*` et `C:Users*` attrapent les deux familles, y compris celles qu'on n'a pas encore vues. Ils sont posés dans claudish (`a5a7ce54`) et dans roo-extensions ; chaque dépôt les ajoute de son côté. Réserve mesurée par po-2024 : sous Windows, on ne peut pas tester `C:Users*` avec `git check-ignore`, car le CLI lit `C:` comme une lettre de lecteur. Le motif reste valide : le matching gitignore est purement textuel.

**Révision v3 (décision user, 11/10)** : « "Bypass permissions" est globalement bien mis en oeuvre de partout, mais certaines commandes nécessitent quand même mon autorisation, je crois qu'il s'agit des création de répertoires ou supressons de fichier en dehors du workspace. Donc il faut surtout privilégier l'utilisation de répertoires locaux gitignored pour les scritps temporaires, et puis ne pas oublier de nettoyer de temps à autre les différentes surfaces de fichiers temporaires. » D'où deux changements : `<repo>/.tmp/` passe **en premier**, devant le scratchpad du harnais, et le nettoyage périodique des surfaces temporaires devient une consigne.

Ce que dit la documentation de Claude Code sur le mode bypass (pages *permission-modes* et *permissions*, lues le 11/10 par un sous-agent : RAPPORTÉ, pas mesuré sur la flotte) :

- **Écritures et créations de répertoires hors du workspace** : aucune demande.
- **Suppressions** : `rm`/`rmdir` sur un **chemin critique** demande toujours une autorisation. Sont critiques la racine, un dossier de premier niveau, le dossier utilisateur, une racine de lecteur Windows, **le workspace et ses parents**. `Remove-Item` sur un chemin système ou sur un joker nu est refusé dans tous les modes.
- **Autres sources** : une règle `permissions.ask`, ou `blockReadsOutsideWorkingDirectories` (lectures hors workspace et commandes non traçables). Les règles `allow` sont **sans effet** en bypass : mettre le scratchpad en allowlist ne sert à rien dans ce mode.

Sur ai-01 (vérifié le 11/10) : pas de `permissions.ask`, pas de `blockReadsOutsideWorkingDirectories`, un seul hook (compteur de boucles, sans `ask`). Cas typique de chemin critique : supprimer le worktree dans lequel la session tourne. Il faut d'abord revenir au checkout principal.

---

## Split-Brain — un cron double dans la meme instance

**Correction owner du 2026-10-20**, dite en interactif à `ai-01:Argumentum` et escaladée par cette lane (dashboard workspace roo-extensions, 20/10 00:37Z). Verbatim :

> « Ca ne marche pas comme ça (mémorise et escalade pour que tous comprennnent). Je ne démarre jamais plus d'une instance d'une lane sur chaque machine. Quand vous avez 2 sessions actives, c'est qu'un double cron s'est mis en place dans la même instance et l'une des 2 sessions est cachée et non interactive »

### Ce qui était faux

La règle du 08/10 supposait **deux instances** (deux fenêtres) d'une même lane. Elle faisait demander à l'owner, en clôture, `[SPLIT-BRAIN?] … redémarre l'instance en trop`. Il n'y a **pas d'instance en trop** : ce geste était impossible, et la question se reposait à chaque clôture pour rien (cas ai-01:Argumentum, registre du 19/10 : « fermer l'une des deux fenêtres VS Code »).

### Ce qui reste vrai

- Deux sessions d'une même lane voient le même dépôt, les mêmes dashboards, et chacune se croit légitime.
- Les crons sont propres à chaque session : **une session ne voit pas le cron de l'autre**. C'est pour cela que chaque session publie l'ID de son cron (`CronList`) sur son dashboard : le doublon s'y repère.
- La session **visible** est celle où l'owner peut écrire. Une session qui n'a jamais reçu de message direct de l'owner est **présumée cachée**. C'est un indice, pas une preuve.
- Le doublon se supprime (`CronDelete`) **dans la session qui le porte**, annoncé avant le geste. Aucune session n'agit sur le cron d'une autre.
- Jamais de cron ni de tâche planifiée pour « reprendre » une lane douteuse : deux tireurs refont le même cycle (escalade CoursIA-2, 07/10).

**Mécanisme non établi** : on ne sait pas comment le second cron et la session cachée apparaissent. Cas connus : ai-01:Argumentum le 10/10, po-2023:Argumentum le 19/10 (crons aux minutes :53 et :23).

*Historique : la modalité « demander au user en clôture » (mandat 08/10, rapporté par `po-2025:Maintenance`) est retirée par cette correction.*

---

## UAC & Dry-run — cas fondateur 2026-10-07

**(Déplacé depuis `rules/uac-dryrun-discipline.md`, coupe A-suite #445, 17/10/2026 — les règles 1-3 + 2a restent dans le fichier de règle.)**

**Cas fondateur 2026-10-07 (myia-po-2025, #1171).** `Register-ScheduledTask` pour `Docker-Auto-Start` : la cible `install-docker-autostart.ps1` avait été dry-runnée par assemblage `New-ScheduledTask*` (objet complet, sans écrire) et était saine — mais le **lanceur** écrit pour l'occasion portait `-Encoding utf8NoBOM`, PS7 seulement. Le run élevé a produit 4 erreurs `ValidateSet` sur `Out-File`, zéro installation, fenêtre user consommée. Réécrit en 5.1-safe, puis **rejoué entier en non-élevé** : il est allé jusqu'à `Accès refusé` sur `Register-ScheduledTask` seul — c'est ce run qui manquait. Relancé élevé -> `State=Ready`. La vérification suivante a rendu « tâche absente », refusé après contrôle : `Test-Path` et `schtasks /query` rendent `Accès refusé` (règle 3), la tâche existe bien.

---

## SDDD — protocole complet

**(Déplacé depuis `rules/sddd-protocol.md`, supprimé coupe A-suite #445, 17/10/2026 — la section SDDD du `~/.claude/CLAUDE.md` global porte désormais la règle en 4 lignes.)**

### `codebase_search` — 4 passes

1. Requête **large** sur le thème (vocabulaire du domaine).
2. `directory_prefix` pour cibler le sous-arbre pertinent.
3. Grep **exact** sur le symbole/chemin identifié.
4. **Reformuler** si les trois passes précédentes n'ont rien donné — le vocabulaire du code n'était pas celui de la requête.

### Scepticisme — qualificateurs

Ne JAMAIS propager une affirmation non vérifiée. Toute affirmation sortant d'une session porte son qualificateur : **VERIFIE** (lu dans le code/la sortie, ce cycle) · **RAPPORTE** (lu chez un tiers, non re-vérifié ici) · **SUPPOSE** (inférence, à tester avant d'agir dessus).

### `conversation_browser`

- **`list` est OBLIGATOIRE en premier** — sans IDs, les autres actions échouent.
- `summarize_type: "trace"` recommandé (pas `synthesis` — la trace garde l'ordre des gestes, la synthèse le perd).

---

## File Writing — matrice de sélection

**(Déplacé depuis `rules/file-writing.md`, supprimé coupe A-suite #445, 17/10/2026 — §Tool Discipline du global porte la règle en une ligne.)**

| Situation | Outil | Note |
|-----------|-------|------|
| Modifier existant | `Edit` | `Read` d'abord. Préféré. |
| Créer nouveau | `Write` | `Read` d'abord si existe déjà. |
| Ajouter contenu | `Edit` (remplacer dernier bloc) | Jamais `Write` (écrase tout). |

- **Edit nécessite Read préalable** — échoue sinon.
- **Edit old_string doit être unique** — ajouter du contexte si ambigu.
- **Encodage** : UTF-8 no-BOM. PowerShell : `[System.IO.File]::WriteAllText()` avec `UTF8Encoding($false)`.
- **Backup** : si remplacement >50% du contenu, préférer `Write` (plus sûr que `Edit` partiel). Vérifier après écriture.

---

## Voir aussi

- [`.claude/configs/user-global-claude.md`](../../.claude/configs/user-global-claude.md) — le harnais global lui-même (règles succinctes)
- [`docs/harness/reference/roosync-tools-guide.md`](reference/roosync-tools-guide.md) — inventaire MCP roo-state-manager
- [`docs/harness/reference/conversation-browser-detailed.md`](reference/conversation-browser-detailed.md) · [`docs/harness/reference/sddd-conversational-grounding.md`](reference/sddd-conversational-grounding.md)
- Côté projet, chaque dépôt porte ses propres règles auto-chargées (`.claude/rules/`) : hygiène du harnais à 3 tiers, discipline coordinateur, re-arm des crons expirés.
