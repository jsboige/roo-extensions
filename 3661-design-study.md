# Issue #3661 — Design study: borner cache + scans N× par client MCP

**Statut :** étude d'analyse (rapport seulement — aucune modification de `background-services.ts`).
**Périmètre :** `mcps/internal/servers/roo-state-manager/src/services/background-services.ts:699-903, 1075-1179`
**Référence :** complémentaire de #2352 (élections Qdrant), préserve #1110 (zéro I/O bloquant), préserve #1747 (visibilité Tier 2/3).
**Anti-double-claim vérifié (15/09 04:5xZ) :** 0 PR ouverte sur `#3661` dans `jsboige/roo-extensions` ni `jsboige/jsboige-mcp-servers`.

---

## 1. Cartographie des trois axes (verbatim du source)

### Axe 1 — hydratation eager du cache (N× privé)
- `background-services.ts:705-709` — `enablePrewarm = process.env.SKELETON_PREWARM !== 'false'`.
- `:733-737` — appel non bloquant à `SkeletonCacheService.getInstance().warmCache()`.
- Commentaire mesuré `:719-732` : **3217 Mo/hôte** (Tier1+2+3), **1092 Mo** sans Tier 3, **142 Mo** sans les deux. Sur 30 hôtes → **72 Go privés**.
- Le kill-switch `SKELETON_PREWARM=false` existe déjà ; il n'est juste **pas appliqué par défaut** sur les machines à forte multiplicité.

### Axe 2 — scans de démarrage + Worker A (N×)
- `:750-794` — `loadSkeletonsFromDisk` + `loadClaudeCodeSessions` lancés par chaque hôte (chaque hôte ré-indexe le disque local).
- `:796-799` — `startProactiveMetadataRepair` par hôte.
- `:807-808` — `startSkeletonRefreshWorker` (Worker A, cadence 2 min) par hôte, **sans élection**.
- `:865-887` — `verifyQdrantConsistency` + `scanForOutdatedQdrantIndex` par hôte, **avant** l'élection.

### Axe 3 — accès lazy réel d'un client (axe « utile »)
- `loadSkeletonsFromDisk` + `loadClaudeCodeSessions` sont idempotents — un client qui les déclenche lazy ne perturbe pas l'élection, mais il paye le coût du cold-load à la première requête.
- Tier 3 (`includeArchives:true`) reste accessible via `awaitFreshnessWithBudget` qui dégrade gracieusement (résultats locaux + notice, pas d'échec dur) — déjà documenté `:716-717`.

### Élections existantes (à NE PAS régresser)
- `#2352` — `tryAcquireLeaderLock` (`:1135-1179`) sur `os.tmpdir()/roosync-indexer-leader-${machineId}.lock`.
- **Cadence** : 5 min (intervalle `qdrantIndexInterval`).
- **Stale** : 15 min.
- **Portée** : Worker B (Qdrant upserts) + drain de la file d'indexation.
- **Hors portée actuelle** : Worker A (refresh squelettes), scans de démarrage, hydratation prewarm, Tier 3 GDrive.

---

## 2. Diagnostic de la perte de linéarité ~3,2 Go × N

Le commentaire mesuré (`:721-732`) est la vérité du terrain :

| Configuration | Mémoire privée/hôte | Sur 29 hôtes | Commentaire |
|---|---|---|---|
| Tier 1 + 2 + 3 + prewarm (défaut) | **~3 217 Mo** | **~93 Go** | mesuré ai-01 |
| Tier 1 + 2 (sans prewarm Tier 3) | ~1 092 Mo | ~32 Go | mesuré ai-01 |
| Tier 1 seul | ~142 Mo | ~4 Go | mesuré ai-01 |
| Tier 1 + prewarm seulement | ~142 Mo + prewarm Tier 2/3 = ~3 217 Mo | ~93 Go | « prewarm » = hydratation eager d'un cache que chaque hôte duplique |

**Coût marginal d'un client inactif supplémentaire : ~3,2 Go.**
**Cause structurelle :** le cache est privé et l'hydratation eager N× duplique ~2 125 Mo (Tier 3 GDrive) + ~950 Mo (Tier 2 Claude).

---

## 3. Trois axes — trois gestes distincts

### Geste A — rendre `SKELETON_PREWARM=false` effectif par défaut sur les machines à forte multiplicité
- **Cible** : axe 1 (empreinte mémoire).
- **Effet attendu** : -2 125 Mo (Tier 3) - 950 Mo (Tier 2) = **~3 075 Mo / hôte** sur les machines qui basculent, soit **~89 Go** sur 29 hôtes.
- **Risque** : première requête Tier 3 paye le cold-load (~30 s). Atténuation : `awaitFreshnessWithBudget` dégrade déjà gracieusement (résultats locaux + notice).
- **Rollback** : `SKELETON_PREWARM=true` dans `.env` revient à la flotte inchangée.
- **Critère d'activation auto** : `process.env.ROO_CLIENT_MULTIPLICITY` ou un détecteur runtime (compte MCP hosts vivants). Suggestion : opt-in via flag d'environnement par machine, pas auto — la décision est opérationnelle.

### Geste B — étendre l'élection machine-locale de #2352 à Worker A + scans de démarrage
- **Cible** : axe 2 (N× scans).
- **Effet attendu** :
  - `startSkeletonRefreshWorker` : 29 → 1 timer actif par machine.
  - `verifyQdrantConsistency` + `scanForOutdatedQdrantIndex` : 29 → 1 exécution à froid.
  - `startProactiveMetadataRepair` : 29 → 1.
- **Mécanisme** : réutiliser `tryAcquireLeaderLock(machineId)` avec un nom de lock distinct — `roosync-worker-a-leader-${machineId}.lock` — pour ne pas coupler le cycle de vie de Worker A à celui de Worker B (sinon un leader Qdrant mort paralyse aussi le refresh squelette).
- **Risque** : si l'élection Worker A échoue (lock corrompu), ne **jamais** démarrer Worker A en double — dégrader en lecture seule (`state.isWorkerALeader = false`, skip le setInterval). Comportement fail-closed cohérent avec `:1145-1148` de Qdrant.
- **Critère test** : à N=8+ processus, `setInterval` actifs = 1, scans au démarrage = 1.

### Geste C — cache partagé inter-processus OU clients secondaires légers
- **Cible** : axes 1 + 3 (mémoire + accès lazy légitime).
- **Option C.1 — service de cache partagé (HTTP sur localhost :port)** : un daemon `roo-state-manager-cache-daemon` expose `getArchive(id)` / `search(query)` / `getByTask(id)`. Les clients stdio s'y connectent et n'hydratent plus leur propre Tier 3 (économie ~2 125 Mo / hôte).
- **Option C.2 — clients secondaires en lecture seule** : un seul processus est `primary` (porte la warmup, l'élection Worker A, Worker B) ; les autres sont `secondary` (pas de warmup, pas de workers, lecture lazy via cache partagé ou via primary over IPC).
- **Risque C.1** : surface protocole à définir (cache stampede, invalidation, transport crash → fall-back local).
- **Risque C.2** : le primary devient SPOF local — perdre le primary = perdre la warmup mais pas la lecture (les secondary servent en lazy, dégradé).
- **Recommandation** : C.2 est plus simple et plus chirurgical. C.1 est une refonte plus profonde.

### Synthèse — combinaison recommandée (par incrément)

| Étape | Geste | Gain mémoire/hôte | Risque | Rollback |
|---|---|---|---|---|
| **1** | Geste A (`SKELETON_PREWARM=false` par défaut sur machines ≥10 hôtes) | -3 075 Mo | faible (lazy dégradé gracieux) | `PREWARM=true` |
| **2** | Geste B (élection Worker A + scans) | -0 Mo (CPU/disk I/O) | moyen (logique d'élection à dupliquer) | lock retiré |
| **3** | Geste C.2 (primary/secondary) | -2 125 Mo (Tier 3) | fort (refonte spawn) | flag `ROLE=primary` |

L'étape 1 est **seule** à même de faire passer l'empreinte agrégée de **77 Go** à **~4-10 Go** (29 × 142 Mo + 1 × 3 075 Mo) ; les étapes 2 et 3 sont complémentaires (CPU, complexité, résilience).

---

## 4. Critères d'acceptation — mapping

| Critère (issue) | Étape qui le couvre | Test reproductible |
|---|---|---|
| Test multi-processus N≥8, mémoire privée agrégée | Étape 1 + 3 | `npx vitest run --config vitest.config.ci.ts services/__tests__/multi-process-budget.test.ts` (à créer) |
| Pas N prewarm au démarrage | Étape 1 | Compteur `warmCache` invoqué dans `background-services.ts` sur N processus mockés |
| Pas N scans identiques au démarrage | Étape 2 | Compteur `scanForOutdatedQdrantIndex` + `verifyQdrantConsistency` |
| Worker A : 1 timer actif | Étape 2 | Compteur `setInterval` créés depuis `startSkeletonRefreshWorker` |
| Budget mémoire borné ~3,2 Go × N → ~142 Mo × N + 1 × 3 075 Mo | Étape 1 + 3 | `process.memoryUsage().rss` sommé sur N processus |
| Visibilité Tier 2/Tier 3 préservée | déjà OK | Réutiliser `indexing-controls.test.ts:255-264` |
| Élection #2352 préservée | Étape 2 | Réutiliser `leader-election.test.ts` |
| Latence cold-start documentée + kill-switch rollback | Étape 1 | doc + `.env` flags |

---

## 5. Pièges à éviter (leçons incidents #1747, #2352, #1110)

1. **Ne pas éteindre les tiers pour éteindre le prewarm** — `#1747` les a allumés pour rendre visibles les sessions Claude et les archives cross-machine. Étteindre un TIER est le coup de pendule inverse (cf. `indexing-controls.test.ts:213-218`). Le kill-switch doit porter **uniquement** sur l'hydratation eager, pas sur la disponibilité des tiers.
2. **Ne pas coupler les élections Worker A et Worker B** — utiliser des fichiers de lock distincts (`roosync-worker-a-leader-*.lock` vs `roosync-indexer-leader-*.lock`). Un leader Qdrant mort paralyse aussi le refresh squelette = boucle.
3. **Fail-closed sur l'élection Worker A** — si `tryAcquireLeaderLock` échoue pour cause inattendue, **skipper** Worker A (cohérent avec `:1145-1148`), pas l'inverse.
4. **Préserver le zéro I/O bloquant de #1110** — toute étape doit rester fire-and-forget. Pas de `await` au top-level de `initializeBackgroundServices`.
5. **Pas d'auto-détection de multiplicité** — la décision « bascule PREWARM off » est opérationnelle, pas algorithmique. Un `.env` flag par machine est plus auditable qu'un compteur runtime.
6. **Préserver la parité des tests `indexing-controls.test.ts`** — toute modification de `SKELETON_PREWARM` doit garder vert les 4 cas (defaut → on, `false` → off, `false` → tiers allumés, `'0'` → on).

---

## 6. Plan d'implémentation recommandé (à valider par coordinateur avant code)

1. **Validation mesure** (PR standalone, ~50 LOC) :
   - Ajouter un mode instrumentation `ROO_INSTRUMENT_BOOT=1` qui logge, par hôte : `pid`, `rss_after_30s`, `warmCache_called`, `scanForOutdatedQdrantIndex_called`, `startSkeletonRefreshWorker_called`, `setInterval_count`.
   - Reproduire sur ai-01 (29 hôtes) avant/après `PREWARM=false` → preuve de la mesure 3 217 Mo → 1 092 Mo.
2. **Étape 1 — kill-switch effectif** (~30 LOC + 1 test) :
   - Default change : `SKELETON_PREWARM` devient `false` par défaut **uniquement** quand `process.env.ROO_AUTO_DISABLE_PREWARM=auto` est posé sur la machine (par déploiement, pas par détection runtime).
   - Test : `indexing-controls.test.ts` étendu avec un 5ᵉ cas « `auto` sans autre variable → off sur machines configurées ».
3. **Étape 2 — élection Worker A + scans** (~80 LOC + 2 tests) :
   - Nouveau lock `os.tmpdir()/roosync-worker-a-leader-${machineId}.lock` (stale 10 min, cadence refresh 2 min calée sur le worker).
   - Wrap `startSkeletonRefreshWorker` dans `if (state.isWorkerALeader)`.
   - Wrap `startProactiveMetadataRepair` et le bloc `verifyQdrantConsistency` / `scanForOutdatedQdrantIndex` dans `if (state.isWorkerALeader)`.
   - Test multi-processus avec 8 workers forks + lock partagé dans `os.tmpdir()`.
4. **Étape 3 — primary/secondary** (hors scope de cette PR initiale) — laisser ouvert pour une PR séparée après stabilisation des étapes 1+2.
5. **Documentation** — ajouter dans `docs/harness/reference/skeleton-cache-multiplicity.md` la table des trois étapes + le kill-switch + le compromis cold-start.

---

## 7. Conclusion exécutive

L'empreinte **~3,2 Go × N** est entièrement imputable au couple **Tier 2/3 + hydratation eager privée**. Le levier principal (étape 1) ne touche pas la disponibilité des tiers (`#1747`), ne touche pas les élections Qdrant (`#2352`), ne touche pas le zéro-I/O bloquant (`#1110`) — il ne fait que rendre le kill-switch déjà documenté (`SKELETON_PREWARM=false`) **effectif par défaut sur les machines qui le déclarent**.

L'étape 1 seule fait passer l'empreinte de **77 Go** à **~4-10 Go** sur 29 hôtes. Les étapes 2 et 3 sont des compléments (CPU, complexité) mais ne sont pas le chemin critique pour atteindre le budget mémoire.

Le critère d'acceptation **« test multi-processus reproductible N≥8 »** doit être conçu en premier : il est la **mesure** qui valide ou invalide chaque étape. Sans cette mesure, on ne peut pas prouver la borne.

**Aucun changement de code effectué dans cette session.** Étude d'analyse seulement — la proposition d'implémentation attend l'arbitrage du coordinateur (ai-01) avant toute PR.

---

*Rapport préparé par myia-po-2025 (worker) — 2026-09-15 — session `wt-worker-myia-po-2025-20260915-043939`.*