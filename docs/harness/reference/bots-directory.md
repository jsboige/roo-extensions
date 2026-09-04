# Bots Directory — Hermes & NanoClaw

> **Note relocalisation (2026-05-19)** : Ancien `.claude/rules/bots-directory.md`. Déplacé hors des rules auto-chargées car annuaire factuel (pas une règle de comportement).

**Version:** 1.4.0
**Issue :** #2243, #3219, #3413
**MAJ:** 2026-09-04 (#3413 : accès RooSync Hermes corrigé — bridge mcp-remote, l'ancienne lecture « pas de RSM » est périmée ; adresse inbox NanoClaw corrigée — `myia-ai-01:roo-extensions` effectif, `:nanoclaw` n'aboutit pas)

---

## Hermes (po-2026:hermes-agent)

- **Rôle** : Cron intercom review, fleet ping, patrol erreurs, PR review fallback
- **Host** : myia-po-2026
- **Scheduler** : **Python scheduler** dans le fork `hermes-agent` (`github.com/jsboige/hermes-agent`, fork de `NousResearch/hermes-agent`). `cron/scheduler.py` (`tick()` appelé ~60s par le gateway Docker `hermes`). Jobs = prompts agent LLM dans **runtime** `~/.hermes/cron/jobs.json` (hors-git). *(Corrigé 2026-06-15 #2242 : l'ancienne description « Roo Hermes scheduler cron 0,30 » était inexacte — Roo Code n'est plus installé sur po-2026 depuis la migration Zoo #2379.)*

  **MAJ 2026-08-25 (#3219 audit)** : distribution des minutes des 183 reviews `[Hermes]` mesurée (po-2025, échantillon 200 PRs). Aucun pic à `:00` ou `:30` — la cadence réelle est étalée (top minutes : `:29`=19, `:28`=19, `:26`=16, `:32`=14, `:27`=14). Le tick interne est plus rapide que l'intervalle apparent entre revues (qui dépend des PRs à reviewer). **La description "tick toutes les X minutes" ne se mesure PAS à partir des timestamps GitHub.**
- **Identité GitHub** : TBD
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
  - Conteneur Docker `nanoclaw-v2-telegram_main` (restart policy Docker ; Up depuis 2026-08-22T16:45:00Z post-panne-17h).
  - **Attribution de mécanisme corrigée, cadence RÉTABLIE (2026-08-29, mesure ai-01).** L'ancienne description « Roo NanoClaw scheduler, cron `15,45 * * * *` » se trompe sur le **mécanisme** (Roo Code n'est plus installé sur ai-01 : ce n'est pas un scheduler Roo), **pas sur la cadence**. Le conteneur nomme lui-même ses cycles dans ses propres logs — `docker logs nanoclaw-v2-telegram_main`, ai-01, 2026-08-29 :

    ```
    [poll-loop] Result: Cycle :15 clos — review #13456 postée et vérifiée (id 5057152018)
    [poll-loop] Result: Cycle :45 clos — review #13458 postée et vérifiée (id 5057203106)
    ```

    **La grille `:15/:45` est vivante.**

    ⚠️ **Ne jamais réfuter une cadence de FEU avec des heures de POST.** Le relevé « aucune concentration à `:15/:45` » (`:16`=7, `:06`=6, `:18`/`:46`/`:31`/`:24`/`:20`=5 sur 92 mesures) mesurait l'instant où la review est **publiée**, pas celui où le cycle **démarre** : les deux sont séparés par la durée de la review. Un feu à `:15` qui publie à `:16`–`:21` produit **exactement** cette distribution — elle **confirme** la grille au lieu de l'infirmer. Le décalage entre les deux événements est le signal, pas le bruit.

    Finding posé par po-2025 sur #3302 (review arrivée 6 s après le merge, donc non prise en compte), vérifié ici par les logs de l'émetteur lui-même.

  ✅ **MAJ 2026-08-29 (#3219, po-2026)** : la récupération est **confirmée côté GitHub**. Reviews NanoClaw postées après le silence 2026-08-20T19:18:16Z → 2026-08-26T16:21:07Z (**gap ~5,9 jours** fermé) : #3282 (26/08 16:21Z), #3299 (28/08 18:17Z), #3301 (28/08 23:16Z) — minutes `:21`/`:17`/`:16` — soit le cycle `:15` augmenté de la durée de la review (cf. correction cadence ci-dessus), et `:46` pour #3302 = cycle `:45`. Le diagnostic "NanoClaw tire peu = panne de disponibilité, pas défaut de cadence" tient. (Un audit live du service sur ai-01 reste la vérification autorité, mais l'activité review observée est le signal disponible le plus fort.)
- **Identité GitHub** : `clusterManager-Myia` (permission **write**, vérifié `gh api .../collaborators/clusterManager-Myia/permission` 2026-08-29 ; login confirmé sur 5 reviews #3165→#3301). **Comptage branch protection** : ce login n'est jamais l'auteur d'une PR flotte, et la protection `main` exige 1 approbation sans `require_code_owner_reviews` → un `APPROVED` NanoClaw **compterait** tel quel (pas besoin de la règle per-author d'Hermes, qui n'existe que parce qu'Hermes poste sous `jsboige`). En pratique, toutes les reviews NanoClaw observées sont `COMMENTED`, y compris à verdict positif (#3301 « merge prêt ») — le signal existe, il est muet sur sa propre force (#3219 §3).
- **Contacter** :
  - Dashboard : `roosync_dashboard(action: "append", type: "workspace", tags: ["BOT-MENTION", "nanoclaw"], content: "...")`
  - Inbox direct : `roosync_messages(action: "send", to: "myia-ai-01:roo-extensions", ...)` — **inbox effectif confirmé firsthand par le bot lui-même (#3413, 04/09)** : l'identité de chaîne du container est résolue `myia-ai-01:roo-extensions`, l'adresse `myia-ai-01:nanoclaw` **n'aboutit pas** (classe #3230). Pickup au cycle `:15/:45`.
- **Cas d'usage** :
  - Review PR du coord ai-01 (workaround CODEOWNERS self-merge protocol)
  - Co-hébergé OpenWebUI + sk-agent HTTP
- **Ne PAS contacter pour** : Modifier code prod (use workers PR pattern)

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
- Audit cadence bot : #3219 (po-2025, 2026-08-25 — correction scheduler NanoClaw)
