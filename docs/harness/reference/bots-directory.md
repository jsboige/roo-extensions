# Bots Directory — Hermes & NanoClaw

> **Note relocalisation (2026-05-19)** : Ancien `.claude/rules/bots-directory.md`. Déplacé hors des rules auto-chargées car annuaire factuel (pas une règle de comportement).

**Version:** 1.6.0
**Issue :** #2243, #3219, #3413
**MAJ:** 2026-09-24 (#3219, po-2024 ; fenêtre #3761→#3822 : ratio 3:4 — première fenêtre où NanoClaw passe devant ; post-GO 23/09 : 0 APPROVED exercé, garde « ai-01 → COMMENT » vérifiée 1/1, aucune PR où les deux lectures du mandat s'accordent sur l'éligibilité ; jetons NanoClaw 4/4 exacts, Hermes 1/3 — variante `[Hermes — …]` persiste après le ruling jeton canonique). — 2026-09-21 (#3219, po-2025 ; fenêtre #3751→#3760 : ratio Hermes:NanoClaw 2:0, classe #3534/#3536 0/2 — 2ᵉ fenêtre consécutive à zéro, attestation par signature de corps seule clé valide confirmée ; blocker (b) NanoClaw 0 APPROVED cumulé inchangé ; datapoint governance #3760 APPROVE bot + APPROVE coord « APPROVE inéligible remplacé »). — 2026-09-08 (#3219 re-mesure : identité GitHub Hermes résolue — `clusterManager-Myia` **partagé** avec NanoClaw + `jsboige` ; λ.51 attributions par `clusterManager-Myia` révisées ; Hermes approuve désormais depuis ~09-06, NanoClaw reste `COMMENTED` ; note audit contenu + nom runtime conteneur NanoClaw). — 2026-09-04 (#3413 : accès RooSync Hermes corrigé — bridge mcp-remote, l'ancienne lecture « pas de RSM » est périmée ; adresse inbox NanoClaw corrigée — `myia-ai-01:roo-extensions` effectif, `:nanoclaw` n'aboutit pas)

---

## Hermes (po-2026:hermes-agent)

- **Rôle** : Cron intercom review, fleet ping, patrol erreurs, PR review fallback
- **Host** : myia-po-2026
- **Scheduler** : **Python scheduler** dans le fork `hermes-agent` (`github.com/jsboige/hermes-agent`, fork de `NousResearch/hermes-agent`). `cron/scheduler.py` (`tick()` appelé ~60s par le gateway Docker `hermes`). Jobs = prompts agent LLM dans **runtime** `~/.hermes/cron/jobs.json` (hors-git). *(Corrigé 2026-06-15 #2242 : l'ancienne description « Roo Hermes scheduler cron 0,30 » était inexacte — Roo Code n'est plus installé sur po-2026 depuis la migration Zoo #2379.)*

  **MAJ 2026-08-25 (#3219 audit)** : distribution des minutes des 183 reviews `[Hermes]` mesurée (po-2025, échantillon 200 PRs). Aucun pic à `:00` ou `:30` — la cadence réelle est étalée (top minutes : `:29`=19, `:28`=19, `:26`=16, `:32`=14, `:27`=14). Le tick interne est plus rapide que l'intervalle apparent entre revues (qui dépend des PRs à reviewer). **La description "tick toutes les X minutes" ne se mesure PAS à partir des timestamps GitHub.**
- **Identité GitHub** : `clusterManager-Myia` (compte bot **partagé avec NanoClaw** — résolu 2026-09-08 #3219 ; l'attribution se fait par la signature `[Hermes]`/`[NanoClaw]`, pas par login) **et** `jsboige` (OWNER partagé, utilisé quand l'opener n'est pas `jsboige` afin d'éviter le self-approve). **Mandat d'event formel (2026-09-13, coordinateur ; runtime vérifié firsthand po-2026, `~/.hermes/cron/jobs.json`)** : APPROVE/REQUEST_CHANGES licites sous `clusterManager-Myia` sur `jsboige/roo-extensions` — exercé 5× (APPROVED) dans la fenêtre 18-19/09, y compris sur openers `jsboige`. CoursIA reste COMMENT-only **tenu-jusqu'à-octroi** (CoursIA#15511 OPEN au 2026-09-19).
- **Contacter** :
  - Dashboard : `roosync_dashboard(action: "append", type: "workspace", tags: ["BOT-MENTION", "hermes"], content: "...")`
  - Inbox direct : `roosync_messages(action: "send", to: "myia-po-2026:hermes-agent", ...)`
- **Accès RooSync (important pour #2242)** : le runtime Hermes charge roo-state-manager **par le réseau** via le bridge **`mcp-remote`** (stdio→HTTP) vers la chaîne proxy `myia-mcp-proxy` — `http://192.168.0.47:9090/roo-state-manager/mcp` (LAN ai-01, jeton A ; visible dans les logs npm quotidiens `~/.hermes/.npm/_logs/*-debug-0.log`, finding firsthand #2242 24/07, re-sondé #3413 04/09 : 401 <5 ms sans jeton = chaîne debout). L'ancienne lecture « le `.mcp.json` d'Hermes n'expose que searxng/playwright/sk-agent, donc pas de RSM » **est périmée** — elle décrit le fichier de déclaration local, pas le bus effectif. Résilience : `scripts/hermes-watchdog/hermes-mcp-watchdog.ps1` (po-2026, restart auto sur `ClosedResourceError`, #2014).
  ⚠ **Identité de chaîne résolue serveur-side** : les appels passant par la chaîne apparaissent comme `myia-ai-01:roo-extensions` (classe #3230) — un message adressé à un autre workspace de po-2026 peut être visible en liste mais illisible en `action:message`.
- **Cas d'usage** :
  - Escalade review PR si CODEOWNERS bloque
  - Ping fleet status
  - Patrol erreurs récurrentes
- **Ne PAS contacter pour** : Tâches code (use workers), décisions architecturales (use coord/user)

## NanoClaw (ai-01:nanoclaw)

- **Rôle** : Cron review-pr, identité review CODEOWNERS, dashboard listener auxiliaire
- **Host** : myia-ai-01
- **Scheduler** : **Service Windows NSSM + conteneur Docker** (corrigé 2026-08-25 #3219 audit).
  - `Get-Service NanoClaw` → `Running`, `StartMode Auto`, `LocalSystem` (PathName `D:\nanoclaw\scripts\service\nssm.exe`, audit ai-01 2026-08-22).
  - Conteneur Docker `nanoclaw-v2-telegram_main` (restart policy Docker ; Up depuis 2026-08-22T16:45:00Z post-panne-17h). **Nom runtime vérifié 2026-09-08 (#3219)** : le conteneur effectif porte un suffixe numérique — `nanoclaw-v2-telegram_main-1788816819774` (image `nanoclaw-agent-v2-fdcb96b5`) — variable à chaque rebuild ; `docker logs` doit donc être ciblé par `docker logs $(docker ps -q --filter "name=nanoclaw-v2-telegram_main")` et non par le nom projet.
  - **Attribution de mécanisme corrigée, cadence RÉTABLIE (2026-08-29, mesure ai-01).** L'ancienne description « Roo NanoClaw scheduler, cron `15,45 * * * *` » se trompe sur le **mécanisme** (Roo Code n'est plus installé sur ai-01 : ce n'est pas un scheduler Roo), **pas sur la cadence**. Le conteneur nomme lui-même ses cycles dans ses propres logs — `docker logs nanoclaw-v2-telegram_main`, ai-01, 2026-08-29 :

    ```
    [poll-loop] Result: Cycle :15 clos — review #13456 postée et vérifiée (id 5057152018)
    [poll-loop] Result: Cycle :45 clos — review #13458 postée et vérifiée (id 5057203106)
    ```

    **La grille `:15/:45` est vivante.**

    ⚠️ **Ne jamais réfuter une cadence de FEU avec des heures de POST.** Le relevé « aucune concentration à `:15/:45` » (`:16`=7, `:06`=6, `:18`/`:46`/`:31`/`:24`/`:20`=5 sur 92 mesures) mesurait l'instant où la review est **publiée**, pas celui où le cycle **démarre** : les deux sont séparés par la durée de la review. Un feu à `:15` qui publie à `:16`–`:21` produit **exactement** cette distribution — elle **confirme** la grille au lieu de l'infirmer. Le décalage entre les deux événements est le signal, pas le bruit.

    Finding posé par po-2025 sur #3302 (review arrivée 6 s après le merge, donc non prise en compte), vérifié ici par les logs de l'émetteur lui-même.

  ✅ **MAJ 2026-08-29 (#3219, po-2026)** : la récupération est **confirmée côté GitHub**. Reviews NanoClaw postées après le silence 2026-08-20T19:18:16Z → 2026-08-26T16:21:07Z (**gap ~5,9 jours** fermé) : #3282 (26/08 16:21Z), #3299 (28/08 18:17Z), #3301 (28/08 23:16Z) — minutes `:21`/`:17`/`:16` — soit le cycle `:15` augmenté de la durée de la review (cf. correction cadence ci-dessus), et `:46` pour #3302 = cycle `:45`. Le diagnostic "NanoClaw tire peu = panne de disponibilité, pas défaut de cadence" tient. (Un audit live du service sur ai-01 reste la vérification autorité, mais l'activité review observée est le signal disponible le plus fort.)
- **Identité GitHub** : `clusterManager-Myia` (permission **write**, vérifié `gh api .../collaborators/clusterManager-Myia/permission` 2026-08-29 ; login confirmé sur 5 reviews #3165→#3301). ⚠ **Login PARTAGÉ avec Hermes** (résolu 2026-09-08 #3219) : les review `[Hermes]` postent aussi sous `clusterManager-Myia` (ex. #3509, #3505, #3504, #3485 en `APPROVED`) — **l'attribution par login est donc cassée**, seul le préfixe `[NanoClaw]`/`[Hermes]` du corps tranche. **Comptage branch protection** : ce login n'est jamais l'auteur d'une PR flotte, et la protection `main` exige 1 approbation sans `require_code_owner_reviews` → un `APPROVED` NanoClaw **compterait** tel quel. En pratique, **toutes les reviews NanoClaw observées restent `COMMENTED`**, y compris à verdict positif (#3301 « merge prêt », et les 2 reviews du 2026-09-07 #3496/#3500) — le signal existe, il est muet sur sa propre force (#3219 §3). (À l'inverse, **Hermes approuve désormais** depuis ~2026-09-06, fix #1767/#3509 : §3 est résolu pour Hermes, pas pour NanoClaw.)
- **Contacter** :
  - Dashboard : `roosync_dashboard(action: "append", type: "workspace", tags: ["BOT-MENTION", "nanoclaw"], content: "...")`
  - Inbox direct : `roosync_messages(action: "send", to: "myia-ai-01:roo-extensions", ...)` — **inbox effectif confirmé firsthand par le bot lui-même (#3413, 04/09)** : l'identité de chaîne du container est résolue `myia-ai-01:roo-extensions`, l'adresse `myia-ai-01:nanoclaw` **n'aboutit pas** (classe #3230). Pickup au cycle `:15/:45`.
- **Cas d'usage** :
  - Review PR du coord ai-01 (workaround CODEOWNERS self-merge protocol)
  - Co-hébergé OpenWebUI + sk-agent HTTP
- **Ne PAS contacter pour** : Modifier code prod (use workers PR pattern)

  **Audit contenu 2026-09-08 (#3219, ai-01)** : sur les 30 dernières PRs mergées de roo-extensions, NanoClaw pèse ~2 reviews (toutes `COMMENTED`, #3496/#3500) contre ~14 pour Hermes — ratio ~7:1 qui **confirme** la mesure initiale. La faible couverture roo-extensions **n'est pas** une panne : le conteneur tire sur `:15/:45` et review des PRs **multi-dépôts** (#1128 jsboige, #15073/#15126/#15132) sous un **protocole « fenêtre structurelle »** (reads section + source refs, pas toujours de full diff). À retenir : attribuer par **signature**, pas par login (`clusterManager-Myia` est partagé) ; et la thèse initiale « Hermes = surface / NanoClaw = profondeur » n'est **pas établie par le contenu** (`n=2`, longueur ≠ profondeur) — seule l'**asymétrie de fréquence/approbation** l'est.

  **MAJ 2026-09-18 (#3219, po-2023 ; reviews gelées ~12:50Z le 18/09)** : l'asymétrie de fréquence s'est **réduite de ~7:1 à ~2,5:1** — fenêtre #3630→#3719 (13/09 20:17Z → 18/09, ~67 PRs, ~137 reviews totales) : **~30** reviews `[Hermes]` contre **12 `[NanoClaw]`** (~2,7/jour). Précision atténuée délibérément : deux re-mesures indépendantes de la même fenêtre (po-2023, puis ai-01 au même périmètre) divergent de ~15 % (27↔31 Hermes, 156↔137 total) — la fenêtre est un périmètre **par PR**, pas un gel temporel, et les reviews continuaient d'arriver pendant la mesure ; un tiers qui rejoue la méthode publiée doit s'attendre à un chiffre dans cette plage, pas à une valeur exacte. Les 12 restent toutes `COMMENTED` (7 verdicts LGTM, 5 CONCERNS) — le point « 0 APPROVED » ci-dessus tient. Les minutes de post (`:17`-`:23` et `:48`-`:54`, aucun `:15`/`:45` littéral) **corroborent** la lecture « grille :15/:45 + durée de review » du paragraphe cadence ci-dessus.

  **Limite de mesure — attribution par signature, angle mort du login partagé (ajout 2026-09-19, volet ai-01 du 23:22Z)** : le comptage ci-dessus attribue par **corps signé** (préfixe `[NanoClaw]`/`[Hermes]`), mais les reviews **sans signature** postées sous `clusterManager-Myia` par des **sessions agent** n'entrent dans aucune famille et se trient selon l'heuristique du compteur. Mesure d'impact (ai-01, 60 PRs roo-extensions) : la famille « C » non signée (`## Approval — exact head <40 car.>` + « I independently reread the complete PR surface », 3 occurrences le 15/09 en 34 min — les seules 3 PR jamais mergées sous ce compte) a été comptée comme NanoClaw dans la fenêtre #3630→#3719 à hauteur de **2/33** — volume faible, le ratio ~2,5:1 tient ; le biais reste **structurel** : un login partagé entre un bot et des sessions agent n'identifie plus personne (signalement complet : dashboard global 23:22Z, réponse #3219). Toute future télémétrie de reviews doit (a) documenter sa clé d'attribution, (b) traiter les reviews non signées d'un login partagé comme **non attribuées** — jamais réparties par défaut, et (c) exiger une signature d'acteur pour tout merge/approbation sous login partagé.

  **MAJ 2026-09-19 (#3219, po-2026 ; fenêtre #3720→#3737 — PRs créées 18/09 12:57Z → 19/09 11:16Z, 15 PRs, 26 reviews)** : ratio Hermes:NanoClaw **7:5 (~1,4:1)** — la trajectoire se poursuit (~8:1 le 22/08 → ~2,5:1 le 18/09 → ~1,4:1). Les 5 reviews NanoClaw (4 LGTM + 1 CONCERNS à finding réel — #3736 : claim « zero live references » littéralement faux, 1 référence vive mesurée `advanced-monitoring.ps1:311`) restent **toutes `COMMENTED` : 0 APPROVED, blocker (b) inchangé** ; minutes `:16 :46 :18 :19 :16` — deux grappes (`:16`-`:19`, `:46`), grille `:15/:45` corroborée, streak sans gap observé côté GitHub ≥ 24 j. Hermes : 5 APPROVED (mandat 13/09 exercé) + 2 LGTM en event `COMMENTED` (#3734/#3735) — **signés, pas muets** : `VERDICT:` en ligne 1, signature `[Hermes]`, ancre au head exact (`d110806aea05`, `4741d5d3c498`), corps de ~2,1 Ko chacun. Sur openers `jsboige`, les **événements** restent mixtes (**5 `APPROVED` + 2 `COMMENTED`**) alors que les **corps** sont signés **7/7** — deux axes distincts, à ne jamais fusionner en un décompte unique. La classe #3534/#3536 (event `COMMENTED` portant un verdict) subsiste donc à **2/7**, mais « muet » n'en est plus la description : la trajectoire post-mandat s'améliore de façon mesurable. Corroboré par **deux instruments indépendants** — citation directe d'Hermes au head exact (CHANGES sur #3738, 19/09 14:37Z) et re-dérivation REST complète par po-2024 (15:16Z : **12/12** des reviews `clusterManager-Myia` de la fenêtre ouvrent par `VERDICT:`, Hermes **et** NanoClaw). **Famille C : 0/12** — toutes les reviews `clusterManager-Myia` de la fenêtre sont signées, zéro merge sous ce login : l'engagement ai-01 du 18/09 23:20Z (sessions ai-01 ne review/mergent plus sous ce compte) est **tenu** sur la fenêtre (reviews sous `myia-ai-01`, merges sous `jsboige`/`myia-ai-01`). ⚠ **Convergence de format — l'attribution par 1ère ligne est définitivement morte** : les 5 reviews NanoClaw de la fenêtre ouvrent toutes par `VERDICT:` (gabarit jusqu'ici lu comme marqueur Hermes, famille B de la passe du 18/09) ; le présent cycle a d'abord compté **0** NanoClaw sur ce motif avant correction par signature. La signature du corps reste la seule clé d'attribution valide — et l'est davantage encore que la limite ci-dessus ne le laissait prévoir.

  **MAJ 2026-09-20 (#3219, po-2024 ; fenêtre #3738→#3750 — PRs créées 19/09 13:29Z → 20/09 11:50Z, 12 PRs réelles — #3743 inexistant —, 24 reviews)** : ratio Hermes:NanoClaw **6:5 (~1,2:1)** — trajectoire ~8:1 (22/08) → ~1,4:1 (19/09) → ~1,2:1. Les 5 reviews NanoClaw (5 LGTM, dont #3741 chaîne pointer→merge→blobs vérifiée firsthand) restent **toutes `COMMENTED` : 0 APPROVED, blocker (b) inchangé** ; minutes `:16 :47 :17 :48 :47` — deux grappes, grille `:15/:45` corroborée. **Hermes 6/6 événements formels (4 APPROVED + 2 CHANGES_REQUESTED), zéro review à verdict muet — la classe #3534/#3536 (2/7 le 19/09) ne s'est pas reproduite sur cette fenêtre (0/6)** ; les 2 CHANGES portent des findings réels (#3738 : claim « 2 LGTM muets » littéralement fausse, corroborée par deux instruments indépendants — re-dérivation REST po-2024 15:16Z + consolidation ai-01 17:00Z ; #3749 : régression CI au head). **Première articulation explicite de la division du travail proto-B (#3741)** : l'APPROVED Hermes cite lui-même le LGTM NanoClaw comme non-qualifiant (« event formel posé car le LGTM NanoClaw (COMMENTED) ne peut pas lever `reviewDecision` ») — la passe structurelle précède l'événement formel, 3ᵉ séquence proto-B observée en nature (#3621, #3736, #3741). **Famille C : 0/11** — toutes les reviews `clusterManager-Myia` signées (6 Hermes + 5 NanoClaw), **0 merge sous ce login** (9 PRs mergées : 7 par `myia-ai-01`, 1 par `myia-po-2023`, 1 par `jsboige`) : engagement ai-01 du 18/09 23:20Z tenu sur une 2ᵉ fenêtre consécutive.

  **MAJ 2026-09-21 (#3219, po-2025 ; fenêtre #3751→#3760 — PRs créées 20/09 11:50Z → 21/09 07:21Z, 8 PRs réelles, 13 reviews formelles via `pulls/N/reviews`)** : ratio Hermes:NanoClaw **2:0** — trajectoire ~8:1 (22/08) → ~2,5:1 (18/09) → ~1,4:1 (19/09) → ~1,2:1 (20/09) → **2:0 (21/09)**. ⚠ **Lecture prudente obligatoire** : l'échantillon est **petit (8 PRs, 13 reviews)** et la fenêtre est **homogène** — **5/8 PRs portent `fix(scheduling)`, dont 4 cmd-stderr lot 2/3** (#3752 F1/F2/F3, #3754, #3759, #3760 ; **#3756 = passe feeder** #3755/#3643, pas cmd-stderr ; #3758 = bump submod #1179 ; #3753 = doc OAUTH-EXPIRED ; #3751 = la télémétrie 20/09 elle-même). La « fenêtre structurelle » NanoClaw (#3219 §6, doc lignes 60) **ne couvre pas cette classe de PRs de routine** — ce qui **explique au moins partiellement** le 0/8 sans conclure à une panne de cadence. La lecture inverse (« NanoClaw s'est tu ») reste **non prouvée** sur 8 PRs ; les minutes de post et le service sur ai-01 (Docker, NSSM, `~/.hermes/cron/jobs.json`) seraient les instruments qui trancheraient — non vérifiés firsthand cette passe. Données brutes : `$TEMP/pr-reviews-3219-21sep/` (po-2025, reproductibles via `gh pr view N --repo jsboige/roo-extensions --json reviews`, N ∈ [3751, 3760]).

  **Détail par revue :**

  | PR | #reviews | Hermes `[Hermes]` | NanoClaw `[NanoClaw]` | Autres |
  |---:|---:|---:|---:|---|
  | #3751 | 1 | 1 APPROVED (télémétrie 20/09, body `VERDICT: LGTM`) | 0 | 0 |
  | #3752 | 2 | 0 | 0 | po-204 COMMENTED (probes drift-guard) + po-2023 APPROVED |
  | #3753 | 1 | 0 | 0 | po-2023 APPROVED |
  | #3754 | 1 | 0 | 0 | ai-01 APPROVED (coordinateur) |
  | #3756 | 2 | 0 | 0 | ai-01 CHANGES_REQUESTED (`c566ff127`) puis APPROVED (`6f6a4eed`) — passe-fix #3756 lot M1/M2/M3 |
  | #3758 | 1 | 0 | 0 | jsboige APPROVED (bump submod #1179) |
  | #3759 | 2 | 0 | 0 | po-204 COMMENTED (F1/F2 vérifiés par probes) + po-2023 APPROVED |
  | #3760 | 3 | 1 APPROVED (body `[Hermes]`, `VERDICT: LGTM (APPROVE)`, head `eea7a088`) | 0 | po-204 COMMENTED + ai-01 APPROVED |

  **Hermes — 2/2 événements formels, classe #3534/#3536 à 0/2 (2ᵉ fenêtre consécutive à zéro)** : les 2 reviews Hermes sont **APPROVED**, signées `[Hermes]` dans le corps, `VERDICT:` en ligne 1 pour #3751 / en ligne 3 pour #3760 (layouts opposés : `[Hermes]` en l.1 sur #3760) — convergentes avec le gabarit post-mandat du 13/09. **Datapoint d'attribution** : la review #3751 commence par `VERDICT: LGTM` SANS signature `[Hermes]`/`[NanoClaw]` ligne 1 — c'est la signature ligne 3 (`**[Hermes]** — #3751 review du head b58c5f1c`) qui tranche. La convergence de format du 19/09 reste vraie : attribution par 1ère ligne **morte**, signature de corps **seule clé valide** (règle (a) confirmée).

  **Datapoint governance (faible gravité, login propre, disclosed)** : #3760 porte un APPROVE `clusterManager-Myia` à 07:28Z (Hermes, post-19/09 cycle :15) **+** un APPROVE `myia-ai-01` à 10:56Z (coord, explicitement *« Cet APPROVE n'est pas un doublon de courtoisie : il remplace un APPROVE inéligible »* — cite l'engagement option 1 du 18/09, mais constate qu'il **n'a pas été appliqué côté identité** sur ce cycle). Lecture : la règle d'or « ne pas review/merger sous `clusterManager-Myia` » est respectée pour les merges (8/8 sous openers machines), **mais pas** pour les reviews (2/2 `clusterManager-Myia` APPROVED sur la fenêtre). L'arbitrage option 1 vs 2 (retrait `hosts.yml` vs signature obligatoire) reste ouvert — le datapoint rapproche le ruling, mais ne le tranche pas. La passe coord d'ai-01 corrige *a posteriori* (#3760 APPROVED 10:56Z post-APPROVE-bot 07:28Z, écart 3h28) : c'est un filet de production, pas un dispositif de gouvernance.

  **Blockers état au 21/09 :**

  - **(a) Disponibilité NanoClaw** — streak sans gap observé côté GitHub ≥ 25 jours (26/08 → 21/09). Le 0/8 sur cette fenêtre est cohérent avec le profil « fenêtre structurelle » (multi-dépôts + pointer-bumps) et **ne démontre pas** de panne de cadence — vérification firsthand NSSM/Docker/jobs.json non conduite cette passe.
  - **(b) Événement formel NanoClaw** — **0 APPROVED cumulé** sur l'ensemble du corpus #3219 (toujours). La question du 13/09 demeure, intacte : *NanoClaw reçoit-il le même mandat qu'Hermes, oui/non/variante gate ?*
  - **(c) Gouvernance login partagé** — l'engagement ai-01 du 18/09 23:20Z est **partiellement tenu** : 0/8 merges sous `clusterManager-Myia` (axe merge ✅), 2/2 reviews APPROVED sous ce login (axe review ❌). Le ruling user (option 1 ou 2) reste nécessaire pour fermer ce volet.

  **MAJ 2026-09-24 (#3219, po-2024 ; fenêtre #3761→#3822 — PRs créées 21/09 07:21Z → 24/09 07:36Z, 51 PRs réelles, 68 reviews formelles via `pulls/N/reviews`)** : ratio Hermes:NanoClaw **3:4** — **première fenêtre où NanoClaw passe devant**. Trajectoire ~8:1 (22/08) → ~2,5:1 (18/09) → ~1,4:1 (19/09) → ~1,2:1 (20/09) → 2:0 (21/09) → **3:4 (24/09)**. Minutes NanoClaw `:47 :23 :48 :17` — deux grappes, grille `:15/:45` corroborée (5ᵉ fenêtre consécutive). **Mesure post-GO** (arbitrage user 23/09 11:09Z, GO relayé 11:16Z, accepté par la lane 11:20Z) — 22 PRs créées après le GO, openers **10 `jsboige` + 12 `myia-ai-01`, zéro tiers (po-*/web1)** : NanoClaw y poste **2 reviews, toutes `COMMENTED` — 0 APPROVED**. Garde « PR ouverte par `myia-ai-01` → COMMENT » : **vérifiée 1/1** (#3809, opener ai-01, verdict LGTM en COMMENT ✓). Garde « éligible → APPROVED » : **jamais exercée** — aucune PR post-GO où les **deux lectures du mandat** (ruling coord : tout opener sauf ai-01 ; phrasé lane relayé 23/09 15:08Z : « author is not `jsboige` ») s'accordent sur l'éligibilité ; l'unique occasion où elles divergent (#3806, opener `jsboige`, verdict LGTM à 14:48Z) est restée COMMENT — cohérent avec la lecture étroite, déviation de la lecture large. **Blocker (b) : levé de jure, non exercé de facto.** Jetons canoniques (ruling 23/09) : **NanoClaw 4/4 exacts** (`[NanoClaw]` littéral), **Hermes 1/3** — #3805 exact, #3792/#3816 en variante `[Hermes — …]` ; **#3816 (22:52Z) est postérieur au ruling** → la déviation persiste après la règle, un gate littéral sur `[Hermes]` la raterait. Hermes : 3/3 événements formels (APPROVED, openers `jsboige` — mandat 13/09 exercé), classe #3534/#3536 à 0 (4ᵉ fenêtre consécutive). Proto-B : **2 séquences de plus** (#3806 : NanoClaw structurel 14:48Z → APPROVED formel ai-01 15:02Z « with an independent read-only pre-review » ; #3809 : LGTM NanoClaw round 1 → APPROVED `jsboige` le citant explicitement). Famille C : **0/49 merges** sous `clusterManager-Myia` (31 `myia-ai-01`, 16 `jsboige`, 2 `myia-po-2023`). Données brutes : `$TEMP/pr-reviews-3219-24sep/` (po-2024, reproductibles via `gh api repos/jsboige/roo-extensions/pulls/N/reviews`, N ∈ [3761, 3822]). **Correction du total (24/09, re-mesure ai-01 + réconciliation po-2024)** : la version initiale de cette MAJ citait **79** — c'était le **nombre de lignes du fichier brut**, dont **11 lignes `Not Found`** (numéros sans PR) ; les reviews valides font exactement **68** (52 APPROVED + 6 CHANGES_REQUESTED + 10 COMMENTED, 68 ids distincts), mesuré indépendamment par les deux instruments. Le total d'une fenêtre se compte en **entrées valides, jamais en lignes de fichier**.

  **Blockers état au 24/09 :**

  - **(a) Disponibilité NanoClaw** — tenue : reviews les 22/09 (#3779) et 23/09 (#3790, #3806, #3809), ratio fenêtre 3:4 ; dernier post 23/09 17:17Z, silence ~16 h au moment de la mesure (< seuil historique 18 h ; PRs du 24/09 matin = submod bumps + docs, hors « fenêtre structurelle »).
  - **(b) Événement formel NanoClaw** — **levé de jure** (GO 23/09 11:09Z) mais **non exercé de facto** : 0 APPROVED post-GO, et la population post-GO (openers `jsboige`/`myia-ai-01` uniquement) n'offre **aucune occasion** où les deux lectures du mandat s'accordent. Discriminateurs : une PR ouverte par po-*/web1, ou une clarification du phrasé lane (étendu aux openers `jsboige` ou non).
  - **(c) Gouvernance login partagé** — axe merge propre (0/49) ; l'arbitrage option 1 vs 2 reste au user. Volet jeton : Hermes 1/3 exact **post-ruling** — la forme canonique `[Hermes]` n'est pas encore un invariant de sortie du bot.

## Wake-on-Demand

Pour réveil immédiat hors cron tick (mécanisme listener #2244) :
- `[WAKE-HERMES]` en header markdown sur cluster-coord → trigger Hermes
- `[WAKE-NANOCLAW]` en header markdown sur cluster-coord → trigger NanoClaw

## Intercom Coverage

⚠ **INEXACT depuis au moins 2026-06-15 (#2242)** — corrigé en partie le 2026-08-25 (#3219 audit).

Le tableau historique ci-dessous **n'est pas confirmé** par les timestamps GitHub mesurés (po-2025,
2026-08-25). Les cadences réelles sont sub-15min au niveau service (cf. sections ci-dessus), mais
les timestamps des revues postées ne montrent aucun alignement strict aux quarts d'heure :

| Minute | Doc historique | Mesure réelle (po-2025, 92 reviews NC + 183 Hermes) |
|--------|----------------|------------------------------------------------------|
| :00 | Hermes | Hermes : 0 — distribution étalée (`:28`/`:29` top) |
| :15 | NanoClaw | NanoClaw : **0 reviews** sur 92 |
| :30 | Hermes | Hermes : 11 — pas un pic |
| :45 | NanoClaw | NanoClaw : 1 review sur 92 |

Le "chaque quart d'heure" est une **vue de l'esprit**, pas une mesure. Les cadences sont plus
rapides (services sub-15min) mais le throttle GitHub API + la dépendance aux PRs ouvertes
expliquent l'irrégularité des timestamps.

**Recommandation** : retirer ce tableau de la version publiée ou le requalifier en "vue
historique non auditée". Une nouvelle mesure, idéalement côté scheduler interne des deux bots
(tick counter log), remplacerait l'estimation externe par des chiffres vérifiés.

## Références

- Epic parent : #2245
- Wake-Claude routing : #2240
- Bots inbox standardisé : #2241
- Bots active polling : #2242
- Wake-on-tag listener : #2244
- Audit cadence bot : #3219 (po-2025, 2026-08-25 — correction scheduler NanoClaw ; po-2025, 2026-09-21 — fenêtre #3751→#3760 ratio 2:0, attestation convergence de format ; po-2024, 2026-09-24 — fenêtre #3761→#3822 ratio 3:4, post-GO 0 APPROVED exercé, jetons Hermes 1/3 exacts)
