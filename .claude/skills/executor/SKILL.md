---
name: executor
description: Lance une session d'execution multi-agent RooSync pour les machines executantes (myia-po-* et myia-web1). Phrase declencheur : "/executor", "mode executor", "lance executor".
triggers:
  keywords:
    - "lance executor"
    - "mode executor"
    - "session executor"
  exact:
    - "executor"
  context:
    - "executor"
  priority: normal
metadata:
  author: "Roo Extensions Team"
  version: "3.9.1"
  compatibility:
    surfaces: ["claude-code"]
    restrictions: "Requiert acces aux MCPs roo-state-manager"
---

# Skill: Executor - Session d'Execution RooSync

**Version:** 3.9.1 (cadence coordinateur ai-01 4h→5h — #3660, directive user 2026-09-15 ; exécuteurs inchangés à 4h)
**Cree:** 2026-03-28
**MAJ:** 2026-09-15 (cadence coordinateur ai-01 4h→5h, #3660 — directive user « Réarme un cron 5h stp » ; minute `:23` conservée, exécuteurs **inchangés** à `41 */4`) — 2026-09-14 (escalade après N=3 formes absorbantes exit-10, #3605 — spec user 13/09 : `[ESCALATE]`/`[SHORT-CYCLE]`/`[RESTART-REQUIRED]`, ni kill ni retry auto, streak par signature) — 2026-09-13 (cadence coordinateur ai-01 6h→4h, #3629 — directive user « Réarme un cron 4h stp » ; minute `:23` conservée, exécuteurs **inchangés** à `41 */4`) — 2026-09-12 (cadence coordinateur ai-01 4h→6h, #3610 — mandat user ; **portée asymétrique** : les exécuteurs restent à `41 */4`, ne pas uniformiser dans un sens ni dans l'autre) — 2026-09-11 (cadence coordinateur ai-01 3h→4h — flotte réalignée à 4h) — 2026-09-09 (cadence coordinateur ai-01 8h→3h, #3547) — 2026-09-05 (anti-double-claim étendu aux 2 dépôts, #3407) — 2026-09-04 (pre-flight : pwsh -> powershell 5.1, #2368) (arbitrage user revert #3141 : `CronCreate` INTERACTIF = primaire, schtask `Claude-Executor-Cron` = interdite — Phase 0 étape 6 + section cadence inversées ; relay web1 c.283, appliqué web1/po-2025/po-204 le 18/08)
**Usage:** `/executor`
**Methodologie:** SDDD triple grounding (voir `docs/harness/reference/sddd-conversational-grounding.md`)

---

## Objectif

Executer une session de travail autonome sur les machines executantes (myia-po-2023, myia-po-2024, myia-po-2025, myia-po-2026, myia-web1).

**Canal de coordination PRINCIPAL :** Dashboard workspace (`roosync_dashboard`).
**Pas de fichier d'etat local.** La progression est rapportee via le dashboard workspace, pas via un fichier local.

---

## Workflow

### Phase 0 : Pre-flight Check

**Verifier les outils critiques AVANT toute autre action :**

1. MCP roo-state-manager disponible (17 outils) → Si absent, STOP & REPAIR
2. **[INBOX-GATE] Lecture inbox obligatoire en première action effective** (#3554) :
   - Appeler `roosync_messages(action:"inbox", status:"unread")` **avant toute commande shell, synchronisation git ou parallélisation**.
   - Traiter les HIGH/URGENT adressés à cette machine, puis appeler `roosync_messages(action:"mark_read", message_id:"<id>")` pour chacun effectivement traité.
   - Ne pas scanner `messages/inbox` directement : l'énumération DriveFS peut prendre plusieurs minutes à froid. Le MCP préserve le backend fichier/PG et constitue la source de vérité.
   - Si l'appel inbox échoue, appliquer STOP & REPAIR ; ne pas poursuivre le cycle en prétendant l'inbox vide.
3. **Pré-vol transactionnel obligatoire** (#2822/#3489, incident po-2025 08/09) :
   - Exécuter **une seule commande**, sans séparer le pull du build :
     `powershell.exe -ExecutionPolicy Bypass -File scripts/claude/executor-preflight.ps1`
   - Le script enchaîne `fetch` → `pull origin main` → `submodule update --init mcps/internal` → vérification identité/gitlink → `ensure-build-fresh.ps1 -RequireFresh` dans un **nouveau processus** qui charge la version fraîchement tirée.
   - Exit `0` = parent, submodule et build prêts. Exit `1` = fraîcheur non garantie : **STOP & REPAIR**, aucune autre phase. Exit `10` = des hôtes RSM vivants précèdent le build frais sur disque (rebuild courant ou dette persistante) : **STOP et restart VS Code immédiatement** ; le cycle ne reprend qu'après le restart, où le même pré-vol doit rendre `0`.
   - **Interdit** : exécuter le pull et le helper comme deux étapes indépendantes. C'est ce qui a permis au cycle po-2025 de tirer #3525, poursuivre sans build, puis gaspiller le reboot suivant sur l'ancien binaire.
   - **Deploy-lag nudge (#2591)** : si le pré-vol rend `10`, fusionner au rapport `[INFO]` le gitlink activé ; build frais sur disque ≠ hôte MCP qui le sert en mémoire.
   - **Escalade après N=3 formes absorbantes (#3605, spec user 13/09)** : sur exit `10`, le pré-vol émet une de trois banderoles. `[RESTART-REQUIRED]` (répétitions 1-2) : poster **UN** `[ASK]` user (restart full-quit VS Code) et stopper le cycle. `[ESCALATE]` (3ᵉ répétition de la forme absorbante — hôtes vivants précèdent un build que CE run n'a **pas** rebuildé) : poster **UN seul** `[ASK]`, puis stop — ni kill, ni retry automatique. `[SHORT-CYCLE]` (escalade déjà émise) : rapport **1 ligne** — pas de collecte Phase 1, pas de nouveau `[ASK]`. Dès que le pré-vol rend `0` (signature disparue), les cycles reprennent normalement.
3. **Win-cli timeout guard** (anti-régression #2333) :
   - `powershell.exe -ExecutionPolicy Bypass -File scripts/infra/harmonize-win-cli-timeouts.ps1`
   - Script idempotent vérifie les 2 niveaux (interne `~/.win-cli-mcp/config.json` + transport `mcp_settings.json`)
   - Ajouter `-Fix` pour corriger automatiquement si `commandTimeout < 600`
   - Poster `[WARN]` sur dashboard si corrections appliquées
6. **Cron re-arm verification — PROVIDER-AWARE** (#2539 ; cadence unifiée 4h mandates user 2026-08-15/17 ; **arbitrage user 2026-08-18 : cron INTERACTIF primaire, schtask executor-cron interdite**) :
   - `CronList` — vérifier qu'un job récurrent pour `/executor` existe à la cadence **de VOTRE provider** :
     - **Executors z.ai** (po-2023/24/25/26, web1) : `*/4` → `CronCreate(cron: "41 */4 * * *", prompt: "/executor", recurring: true)` — cadence unifiée 4h (mandates user 2026-08-15/17 ; l'AUTO-STOP cap #2185 gère les cycles IDLE, pas de timer adaptatif)
     - **ai-01 (Anthropic, coordinateur)** : `5h` — `23 */5` (directive user **2026-09-15**, #3660 ; supersede le 4h de #3629 (13/09), le 6h de #3610 (12/09), le 4h du 09-11, le 3h #3547). Le coord tire à `:23`, les exécuteurs à `:41` : aux **heures communes**, ces **18 min** sont la protection contre un tir groupé sur l'API, **ne pas « corriger » `:23` vers `:41`**.
   - **Le cron doit vivre dans la session INTERACTIVE** (arbitrage user 2026-08-18, revert #3141, relay web1 c.283 : « je préfère un cron avec lequel je peux interagir quand je passe sur la machine… j'ai besoin de trouver la dernière conversation interactive dans VS Code quand je débarque sur la machine »). Les cycles atterrissent dans LA conversation que l'utilisateur rouvre — jamais dans des sessions headless séparées. Le trade-off « pas de cycles si VS Code fermé » est accepté par le user.
   - **Schtask résiduelle à SUPPRIMER — mais ARMER D'ABORD, RETIRER ENSUITE** (le rollout #3141/#3161 est rendu interdit par l'arbitrage). Une schtask executor-cron spawn des sessions headless invisibles/indépendantes de la conversation interactive, donc elle doit partir. **L'ordre n'est pas cosmétique** :
     1. `CronCreate(...)` — armer le cron interactif ;
     2. `CronList` — **vérifier que le job existe réellement** ;
     3. seulement alors `Unregister-ScheduledTask -TaskName "Claude-Executor-Cron" -Confirm:$false`.

     **Si `CronCreate` est indisponible ou échoue → retirer la schtask QUAND MÊME**, et poster `[INFO] cadence absente` pour que le trou soit visible. **Zéro cadence est l'état accepté par le user ; une cadence headless est celle qu'il a interdite** — entre les deux, l'arbitrage a déjà tranché. Ne jamais garder `Claude-Executor-Cron` en vie au motif qu'elle vaudrait mieux que rien.

     *Pourquoi cet ordre (2026-08-19)* : la version précédente disait « Unregister **PUIS** `CronCreate` ». En session **interactive**, un `CronCreate` qui échoue après le retrait laisse la machine sans la cadence interactive qu'elle pouvait avoir — perte évitable, et silencieuse. L'inversion supprime ce cas. En session headless, `CronCreate` n'est pas exposé (constat po-2026 le 19/08) et un cron session-only mourrait de toute façon à l'exit : la machine retire sa schtask et reste sans cadence — **c'est conforme à l'arbitrage, pas un incident**.

     La précondition qui compte n'est pas « suis-je interactive ? » mais **« le cron est-il armé et vérifié ? »**. La garde protège la cadence *atteignable* ; elle ne protège jamais la schtask, dont le retrait est inconditionnel.
   - Si absent à VOTRE cadence → réarmer. **Vérifier la bonne cadence** (`*/4` pour executors z.ai) — un re-arm `*/2`/`*/3` résiduel = cadence superseded.
   - **Cleanup stale job (anti-double-fire)** : si un job `/executor` existe à la MAUVAISE cadence (ex: `*/2` résiduel de l'ère 2h-conditionnel), `CronDelete`-le **AVANT** de `CronCreate` le bon — sinon les deux firent (`:41` à 2h + 4h = overlap 0,4,8,12… = double-fire 4×/jour). `CronList` pour lister les IDs, `CronDelete <id>` sur le stale.
   - Session-only, auto-expire 7j — doit être vérifié/réarmé à chaque session
   - Poster `[INFO]` si réarmé ou schtask retirée (pour traçabilité)

Si un outil critique manque : signaler via dashboard workspace `[CRITICAL]` et STOP.

**Reference :** `.claude/rules/tool-availability.md`

---

### Phase 1 : Collecte + Grounding SDDD (5 min max)

Executer en parallele quand possible :

1. **RooSync inbox (OBLIGATOIRE, EN PREMIER)** : `roosync_messages(action: "inbox", status: "unread")`
2. **Dashboard workspace** : `roosync_dashboard(action: "read", type: "workspace", section: "intercom", intercomLimit: 20)`
3. **GitHub Issues ouvertes** : `gh issue list --repo jsboige/roo-extensions --state open --limit 100 --json number,title,labels`
   - **PIEGE `--limit` (bug #2509)** : `gh issue list --limit 15` retourne les **15 issues les PLUS RECENTES**, PAS un echantillon representatif. Si les 15 dernieres sont toutes `needs-approval`/meta, l'agent conclut faussement « pool draine, 0 tache » alors que des dizaines d'issues actionnables existent plus bas dans la liste. **TOUJOURS `--limit 100`** (le backlog reel tourne autour de 80-90 issues ouvertes).
   - **Filtrage actionnable (cote agent, apres recuperation)** : ne retenir que les issues portant un label actionnable — `approved`, `bug`, `investigation` — et **exclure** `needs-approval`, `deferred`, `blocked-on-gate`, `epic`. Compter ce sous-ensemble filtre, pas la liste brute.
   - **Conclusion « pool draine » INTERDITE** sans avoir verifie le backlog filtre complet (priorites Phase 2 ci-dessous). Un cycle IDLE ne se justifie que si le sous-ensemble actionnable est reellement vide.
4. **PRs ouvertes (ANTI-DOUBLE-CLAIM)** : les DEUX depots (#3407) — `gh pr list --state open --limit 50 --json number,title,headRefName --repo jsboige/roo-extensions` puis idem `--repo jsboige/jsboige-mcp-servers`
5. **Git state** : `git log --oneline -5`

**Resume concis (10 lignes max) :**
```
Machine: {name} | Git: {hash} | MCPs: {OK/KO}
RooSync: {Y non-lus} | Dashboard: {X messages recents}
Issues ouvertes: {Z} | PRs ouvertes: {P} ({branches})
Taches assignees: {liste courte}
```

---

### Phase 2 : Selection de Tache (automatique)

**Algorithme par priorite decroissante :**

1. Instructions directes RooSync du coordinateur
2. Issue GitHub avec Machine={MA_MACHINE} dans Project #67
3. Issue GitHub avec Machine=Any non reclamee
4. Issue GitHub avec TODO detaille sans Machine assignee
5. Bug ouvert reproductible
6. Issue "In Progress" sans activite recente
7. **Catalogue idle tasks** (voir ci-dessous — #1417)
8. **PR review (fallback #1713)** : Lancer `/pr-review` pour reviser les PRs ouvertes en attente

**ANTI-DOUBLE-CLAIM (OBLIGATOIRE avant chaque tache) :**

Avant de travailler sur une issue, verifier qu'aucune PR ouverte ne la couvre deja :

```bash
# Les DEUX depots — une PR submodule vit dans jsboige/jsboige-mcp-servers,
# invisible au check single-repo (trou #3407 : #1091 ouverte 26 h, non vue).
# Frontiere de mot sur le numero : --search GitHub est flou (mesure 05/09 :
# "#34" ramene des PRs sans rapport) et "#109" matche "#1091" sans elle.
for R in jsboige/roo-extensions jsboige/jsboige-mcp-servers; do
  gh pr list --repo "$R" --state open --json number,author,title \
    --jq '.[] | select(.title | test("#<issue-number>([^0-9]|$)"))'
done
```

Si une PR existe deja (dans l'un des deux) → **SKIP l'issue** + rapporter `[INFO] Issue #X deja couverte par PR #Y, skip`.

Cross-checker aussi avec les branches wt/ actives : si une branche `wt/*-{issue-keyword}` existe avec une PR ouverte, ne pas dupliquer.

**Si AUCUNE tache disponible (priorites 1-6)** : Executer les idle tasks ci-dessous puis fallback PR review.

> **Garde-fou anti-faux-drain (#2509)** : avant de declarer « aucune tache disponible », confirmer que le **backlog filtre complet** (`--limit 100` + labels actionnables, Phase 1 etape 3) a bien ete examine — pas seulement les 15 issues les plus recentes. Les priorites 3-5 (Machine=Any, TODO detaille, bug reproductible) sont quasi toujours servies par ce backlog. Passer aux idle tasks UNIQUEMENT si ce sous-ensemble est genuinement vide.

#### Picker 3 urnes — option avancee (#3675, ADR 015)

Pour les cycles ou le pool est suspecte etire (notamment en executeur isole sans coordinateur frais), preferer le **picker 3 urnes** au bare `gh issue list` :

```bash
# Tirage deterministe, verdict IDLE-REAL strict
python scripts/scheduling/pick_idle_grain.py --dry-run --json

# Re-tirage si le 1er candidat est deja CLAIMED ailleurs
python scripts/scheduling/pick_idle_grain.py --reroll --json
```

Le picker scanne **les 2 depots** (anti-double-claim #3407) avec `--limit 300` (corrige #2509), repartit
dans 3 urnes ponderees (`grain` 7 / `umbrella` 2 / `delivered` 1), et declare `IDLE-REAL` UNIQUEMENT
si toutes les urnes sont vides. **Fail-closed :** toute panne gh (exit non-nul, timeout, JSON invalide)
rend un verdict `ERROR` avec **exit 2** — un instrument muet ne declare jamais le pool vide ; reparer
gh puis relancer. Sans filtre machine : le champ Machine vit dans le Project #67, pas en labels —
l'attribution par lane passe par la discipline `[CLAIMED]` dashboard. **Detail et rationale :** ADR 015.

#### Catalogue Idle Tasks (#1417)

Quand aucune issue GitHub n'est assignable, executer ces taches productives dans l'ordre :

| # | Tâche | Type | Description | Contraintes |
|---|-------|------|-------------|-------------|
| I1 | Worktree/Branch cleanup | ACTIF | Detecter branches `wt/` orphelines >48h (PR merged/closed), nettoyer worktrees | `git worktree list` + `gh pr list` |
| I2 | Submodule drift check | READ-ONLY | Verifier `mcps/internal` vs dernier commit merged upstream. Signaler si >1 commit behind | Rapport dashboard `[WARN]` si drift |
| I3 | Heartbeat health patrol | READ-ONLY | `roosync_inventory(type: "machines")` — verifier heartbeats <6h pour chaque machine | Signaler silencieuses `[WARN]` |
| I4 | Config drift patrol | READ-ONLY | `roosync_compare_config()` entre machines, signaler divergences MCP/modes | Claude only |
| I5 | Doc freshness check | READ-ONLY | Verifier TOUTE la doc — `docs/`, `.claude/rules/`, `.claude/skills/`, `.roo/`, `roo-config/` — chemins references existent encore | Poster `[FRICTION]` si cassé |
| I6 | TODO/FIXME audit | READ-ONLY | Scanner `TODO`, `FIXME`, `HACK` dans le code. Recouper avec issues existantes | Creer issue pour non-trackés |
| I7 | Memory freshness audit | READ-ONLY | Verifier entrées MEMORY.md >30j sans MAJ | Signaler potentiellement obsoletes |
| I8 | Stale build artifacts | ACTIF | Scanner `build/` pour .js/.d.ts sans .ts source | Sous submodule seulement |

**Regle :** Max 2 idle tasks par cycle. Poster resultat sur dashboard (`[DONE]` ou `[INFO]`). Issue staleness patrol INTERDIT sans arbitrage utilisateur (priorite 6 couvre si issue genuinely stale). Fermeture d'issue INTERDITE sans arbitrage utilisateur (voir `.claude/rules/issue-closure.md`).

#### Test de fin de cycle — verifier AVANT de basculer en idle (#3675, ADR 015)

Le vocabulaire d'idle (« backlog draine », « idle honnete ») peut etre contournable par label.
Avant de basculer sur le catalogue I1-I8, executer le **test de fin de cycle** base sur le RESULTAT :

```bash
python scripts/scheduling/test_cycle_end.py --since-hours 24 --json
```

- **PASS + backlog_grain=0** : urne grain REELLEMENT vide (0 issue approved/bug/investigation), I1-I8 legitimes.
- **PASS + prs_delivered_fleet>0** : au moins une PR livree par la flotte dans la fenetre, grain transforme.
- **FAIL** (exit 1) : backlog grain >0 MAIS 0 livraison. **Echec de methode** — reprendre Phase 2 (relire
  le picker, prendre un grain reel), NE PAS basculer en I1-I8.
- **ERROR** (exit 2) : panne instrument gh (fail-closed). Aucun verdict de fond — reparer gh puis relancer.

**Portee FLOTTE assumee :** les PRs comptees sont celles de toute la flotte (l'auteur gh est un
compte partage, le champ Machine vit dans le Project #67). La conformite de TA lane passe par la
discipline `[CLAIMED]`/`[DONE]` dashboard, pas par cet instrument. En cas de divergence avec le
picker, c'est ce test qui fait foi.

Ce test remplace le controle par vocabulaire par un controle par sortie. Il ne supprime pas le cap IDLE 3
(#2185), il le double d'un garde-fou resultat.

**Qui / Type / Contraintes (legende #1417) :** ce catalogue est le **versant Claude** (ce skill `executor` = agent Claude Code). Toutes les taches I1-I8 sont executables par Claude sauf restriction explicite en colonne *Contraintes* (ex. I4 = `Claude only`). Le **versant Roo** equivalent (patrouilles idle du scheduler) vit dans [`.roo/scheduler-workflow-executor.md`](../../../.roo/scheduler-workflow-executor.md) Option 2 — I2 (submodule drift) et I6 (TODO/FIXME) y sont desormais mirror. *Type* = `ACTIF` (modifie l'etat : commit/cleanup) ou `READ-ONLY` (diagnostic + rapport dashboard seulement).

---

### Phase 3 : Execution Autonome

Pour chaque tache selectionnee, executer le cycle complet :

1. **Investigation** : Lire le code, comprendre l'architecture
2. **Implementation** : Ecrire le code, tester incrementalement
3. **Validation** : `npm run build && npx vitest run` (JAMAIS `npm test`)
4. **Commit + PR** : Worktree → commit → PR (regle PR-mandatory)
5. **Rapport** : Dashboard workspace `[DONE]` + commentaire GitHub

**`always-pick-next` reste obligatoire** : si une candidate est bloquee, l'exclure avec `WAIT_FOR` + `RESUME_WHEN`, puis prendre une autre tache actionnable. Le signal de reprise declenche un reexamen ; il n'accorde aucune autorisation.

---

## Coordination

### Canal principal : Dashboard workspace

```javascript
// Rapporter progression
roosync_dashboard(action: "append", type: "workspace", tags: ["DONE", "claude-interactive"], content: "...")

// Rapporter blocage
roosync_dashboard(action: "append", type: "workspace", tags: ["BLOCKED", "claude-interactive"], content: "...")

// Signaler friction
roosync_dashboard(action: "append", type: "workspace", tags: ["FRICTION", "claude-interactive"], content: "...")

// Repondre a un [ASK]/[PROPOSAL]/[REQUEST] — notifie l'expediteur via mentions (#1956)
roosync_dashboard(action: "append", type: "workspace", tags: ["REPLY", "claude-interactive"],
  mentions: [{ messageId: "<id-du-message-original>" }],
  content: "...")

// Accuser reception sans reponse substantielle (ACK seul)
roosync_dashboard(action: "append", type: "workspace", tags: ["ACK", "claude-interactive"],
  mentions: [{ messageId: "<id-du-message-original>" }],
  content: "...")
```

**Regle mentions (#1956 niveau 1) :** Quand tu reponds a un message tagge `[ASK]`/`[PROPOSAL]`/`[REQUEST]` (ou tout message qui attend une reponse), TOUJOURS inclure `mentions: [{ messageId: "..." }]` avec l'id du message original. Cela notifie l'expediteur via RooSync qu'il a une reponse a lire — sans cela, l'expediteur n'a aucun signal et la boucle de coordination se rompt. Detail complet (`userId` vs `messageId` XOR, crossPost, dedup) : [`docs/harness/reference/intercom-v3-mentions.md`](../../../docs/harness/reference/intercom-v3-mentions.md).

### Communication Roo (meme machine)

- Dashboard workspace pour coordination
- Si MCP dashboard indisponible (GDrive offline) : INTERCOM local comme LAST RESORT (DEPRECATED)

---

## Regles Critiques

### Autonomie maximale
- **NE PAS** demander "Que dois-je faire ?"
- **`always-pick-next`** : selectionner une autre tache actionnable lorsqu'une candidate est bloquee ; ne pas retraiter cette candidate avant son `RESUME_WHEN`.
- L'utilisateur intervient pour : arbitrages, approval issues, decisions irreversibles

### Ledger turn-local et observateur unique (#3647)

- Tenir un **ledger turn-local** : `candidate`, `state`, `WAIT_FOR`, `RESUME_WHEN`, `observer`, `evidence`. Aucun nouveau stockage persistant.
- Avant un sweep speculatif, solder chaque obligation en vol en `done`, `blocked` avec reprise nommee, ou `handed-off` avec destinataire.
- Reutiliser les lectures du tour ; rafraichir seulement apres mutation pertinente, acteur independant pertinent, ou frontiere de securite.
- Une condition asynchrone a **un seul observateur**. Aucun polling parallele si `Monitor`, une tache de fond ou `gh run watch` notifiera deja ; couvrir `success`, `failure`, `cancelled`, `timeout` et terminaison inattendue.
- Attribuer d'abord par `session_id`, puis machine ; distinguer `parent_session_id` et `subagent_id` quand disponibles. Machine-only ne prouve pas la cause.
- Messages : **3-5 lignes par defaut**, sauf decision, blocage ou preuve qui exige davantage.

### Tests
- `npx vitest run` (JAMAIS `npm test` — bloque en mode watch)
- Build obligatoire apres toute modification TypeScript
- Ne JAMAIS committer du code qui ne passe pas les tests

### Wakeup Cycle Cadence — PROVIDER-AWARE (#2203 ; unifiée 4h exécuteurs — mandates user 2026-08-15/17 ; arbitrage user 2026-08-18 : cron INTERACTIF primaire)

**Cadence dépend du provider de la machine** (split initial 2026-07-20 : ai-01 Anthropic cher → ralentir ; executors z.ai moins chers → accélérer. **Depuis 2026-08-15/17, l'utilisateur a unifié les exécuteurs à 4h**, machine par machine — supersede le 2h-conditionnel). `ScheduleWakeup` est clampé à `[60, 3600]s` → ne PEUT PAS porter un cycle multi-heures.

**Arbitrage user 2026-08-18 (revert #3141)** : le cron vit dans la **session interactive** — les cycles doivent être retrouvables dans la conversation que l'utilisateur rouvre dans VS Code. La schtask `Claude-Executor-Cron` est **interdite** (sessions headless invisibles et indépendantes) ; une résiduelle du rollout #3141/#3161 se supprime puis se remplace par `CronCreate`. Relay web1 c.283 ; appliqué web1/po-2025/po-204 le 18/08.

```
# Executors z.ai (po-2023/24/25/26, web1) — 4h (mandates user 2026-08-15/17) :
CronCreate(cron: "41 */4 * * *", prompt: "/executor", recurring: true)

# ai-01 coordinateur (Anthropic) — 5h (directive user 2026-09-15, #3660 ; supersede le 4h de #3629) :
# minute 23 : hors :00/:30 — aux heures communes avec les exécuteurs (:41), les 18 min d'écart évitent le tir groupé.
# Ne pas « corriger » :23 vers :41, ne pas décaler l'un pour « aérer » — c'est l'arbitrage.
CronCreate(cron: "23 */5 * * *", prompt: "/coordinate", recurring: true)
```

| Machine | Provider | Cadence | Condition |
|---------|----------|---------|-----------|
| ai-01 (coordinateur) | Anthropic | **5h** | Directive user 2026-09-15 (#3660) — supersede le 4h de #3629 (13/09) et le 6h de #3610 (12/09) ; minute `:23` (les exécuteurs sont à `:41`) |
| po-2023/24/25/26, web1 (executors) | z.ai | **4h** | Unifiée par mandates user 2026-08-15/17 (supersede le 2h-conditionnel 2026-07-20) |

- **Bar de production** : la cadence se mérite par un travail substantiel (fix/PR/review/investigation livrée), PAS par défaut. Si IDLE-storm répété → l'AUTO-STOP cap #2185 gère ; **NE PAS ajuster par timer adaptatif** (l'auto-régulation se fait via AUTO-STOP + WAKE-CLAUDE, pas via timer).
- **Historique** : 3h-uniforme 2026-07-14 → provider split 2026-07-20 (2h-conditionnel exécuteurs) → **4h unifié 2026-08-15/17** (mandates user directs aux 5 machines : po-204 c.227 + re-confirmation 17/08, po-2023, po-2025, web1 — cron IDs visibles dans les [DONE] dashboard) → brief schtask rollout #3141/#3161 (17-18/08) → **arbitrage user 2026-08-18 : retour au CronCreate interactif**, schtask executor-cron interdite (motif : continuité conversationnelle dans VS Code) → **coordinateur ai-01 : 8h #3396 (2026-09-03) → 4h #3485 (06/09) → 3h #3505 (07/09) → 2h #3539 (08/09 15:40Z) → 3h #3547 (2026-09-09) → 4h (2026-09-11, mandat user direct) → **6h #3610 (2026-09-12, mandat user)** → **4h #3629 (2026-09-13, directive user)** → **5h #3660 (2026-09-15, directive user)** (chaîne complète, cf. `coordinate.md` ; citation périmée = restaure silencieusement l'ancienne cadence) — **exécuteurs inchangés à 4h depuis le 15/08. Depuis #3660 (15/09), coordinateur à 5h et exécuteurs à 4h : l'asymétrie est l'état voulu — ne pas « réaligner » l'un sur l'autre dans un sens ni dans l'autre ; aux heures communes, la minute (`:23` coord / `:41` exécuteurs) sépare les tirs de 18 min.**
- **Session-only**, auto-expire 7j. **Phase 0 vérifie** à chaque cycle que le cron est actif à VOTRE cadence provider et le réarme si besoin (#2539).
- **Cap 3-IDLE** (#2185) → executors z.ai : 3 cycles × 4h = 12h avant AUTO-STOP.
- **Override urgent : `[WAKE-CLAUDE]`** routé `machine:workspace` (début de ligne, dashboard append). Permet réveil immédiat sans attendre le tick cadence.
- **NE PAS varier** l'intervalle selon « charge perçue » — l'auto-régulation se fait via AUTO-STOP + WAKE-CLAUDE, pas via timer adaptatif.
- **NE PAS** ajouter un `ScheduleWakeup` par-dessus — cela réintroduirait un cycle plus court superseded.

### Inactivity Cap (#2185)
- Après **3 cycles consécutifs** sans tâche exécutée (IDLE au sens : aucune investigation/implémentation/validation commencée) → **arrêter la session** (ne PAS appeler `ScheduleWakeup`)
- Poster `[IDLE] AUTO-STOP` sur le dashboard avec le nombre de cycles
- La session sera relancée par le prochain `[WAKE-CLAUDE]` du coordinateur ou à la réouverture de VS Code par l'utilisateur (plus de schtask executor-cron — arbitrage 2026-08-18)
- **Pourquoi :** Incident web1 (37.1 MB, 2417 lignes JSONL, 16+ cycles inactifs générant des messages redondants)
- Un cycle où une tâche a été ne serait-ce qu'investigée (code lu, commentaire posté) compte comme actif

### Session Hygiene — Restart Cadence (#2532)
- Une session **interactive** executor accumule ~30 KB/cycle (mesuré 10,3 MB / 7110 msgs sur 4 jours) → ralentissements MCP + risque de timeout
- **Redémarrer la session interactive** après **~25 cycles** OU dès que `conversation_browser(action: "current")` rapporte **> 5 MB**
- Workers **schedulés** (`claude -p`) = process frais par tâche → **non concernés**
- La lecture dashboard est déjà bornée `section: "intercom", intercomLimit: 20` — **ne PAS descendre sous 20** (plancher #2306). Le levier est le restart, pas `intercomLimit`

### PR obligatoire
- Tout changement de code passe par worktree → PR → review → merge
- Reference : `.claude/rules/pr-mandatory.md`

---

## Outils Utilises

- **Read/Write/Edit** : Code et fichiers
- **Bash** : Git, hostname, build, tests
- **roosync_dashboard** : Coordination cross-machine (CANAL PRINCIPAL)
- **roosync_messages** : Messages inter-machines (inbox, send, mark_read, archive)
- **conversation_browser** : Grounding conversationnel SDDD
- **gh** CLI : Issues, PRs, Project #67

---

## Invocation

```bash
# Session executor
/executor
```

---

**Derniere mise a jour :** 2026-06-09
