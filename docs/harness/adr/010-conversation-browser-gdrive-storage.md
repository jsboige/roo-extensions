# ADR 010: conversation_browser — GDrive Cross-Machine Storage

**Date:** 2026-05-15
**Status:** Proposed (Phase 1 — ADR for user review)
**Issue:** #2191
**Supersedes:** #1393 (hot/warm/cold tiered storage — rejected by user)
**Related:** EPIC #2190 (vibe-conversation-browser), #1244 (multi-tier cache), #1360 (master plan), #1822 (STUCK sessions), #2121 (GDrive write storm), #1747 (per-tier health stats)
**Deciders:** jsboige (mandate), claude-interactive po-2025 (Phase 1 author)

---

## Context

`conversation_browser` est l'outil principal d'accès aux historiques de conversations Roo et Claude Code à travers le multi-agent (6 machines). Sa valeur dépend d'une question simple : **est-ce que je peux retrouver une conversation faite sur n'importe quelle machine de la flotte ?**

À ce jour la réponse est *partiellement*. L'état actuel se décompose ainsi :

### État courant — Skeleton storage en 3 tiers (#1244)

| Tier | Localisation | Couverture | Activation |
|------|-------------|------------|-----------|
| **Tier 1 — Roo local** | `<storagePath>/tasks/.skeletons/<taskId>.json` | Tâches Roo de la machine locale uniquement | Toujours actif |
| **Tier 2 — Claude local** | `~/.claude/projects/<workspace-hash>/.skeletons/` | Sessions Claude Code locales (JSONL) | `enableClaudeTier: true` (opt-in) |
| **Tier 3 — GDrive archives** | `.shared-state/task-archive/<machineId>/<taskId>.json.gz` | Tâches archivées cross-machine | `enableArchiveTier: true` (opt-in) |

Implémentation : [`mcps/internal/servers/roo-state-manager/src/services/skeleton-cache.service.ts`](../../../mcps/internal/servers/roo-state-manager/src/services/skeleton-cache.service.ts) (517 lignes, singleton, `Map<string, ConversationSkeleton>` en mémoire avec validité 30 min).

Archivage GDrive : [`mcps/internal/servers/roo-state-manager/src/services/task-archiver/TaskArchiver.ts`](../../../mcps/internal/servers/roo-state-manager/src/services/task-archiver/TaskArchiver.ts) — écrit `.json.gz` au format v2 (messages complets, pas de troncation) lors de l'indexation Qdrant.

Index sémantique : Qdrant collection `roo_tasks_semantic_index` (~54.8M points, `qdrant.myia.io`) — vecteurs de chunks de messages, métadonnées indexées pour recherche par concept.

### Problème observé

1. **Pas de visibilité cross-machine par défaut.** Tier 3 est opt-in. Une session démarrée sur po-2024 n'est pas visible depuis ai-01 sauf si Tier 3 est activé ET que la tâche a été archivée (ce qui n'arrive qu'à l'indexation Qdrant, pas en temps réel).
2. **Latence d'apparition.** Une tâche fraîche n'est trouvable cross-machine qu'après : (a) indexation Qdrant locale, (b) écriture archive GDrive, (c) sync GDrive (~5–60s sous charge), (d) lecture machine consommatrice + invalidation cache 30 min.
3. **Sessions STUCK (#1822).** Quand une session ne se termine pas proprement, elle n'est jamais archivée. Tier 3 = ∅, donc invisible cross-machine.
4. **Couplage Tier 3 ↔ Qdrant.** Si l'indexer crash ou GDrive est offline (#2121 write storm), Tier 3 est gelé.
5. **Concurrent writes (6 machines).** Pas de coordination écrivain unique. Risque collision sur même `taskId` si deux machines ré-archivent.
6. **Backward compat 30j.** Le mandate utilisateur exige que les sessions des 30 derniers jours restent accessibles après changement de stockage.

### Mandat utilisateur (#2191 verbatim)

> Le système hot/warm/cold de #1393 ne me convient pas. Je veux pouvoir naviguer dans n'importe quelle conversation faite sur n'importe quelle machine, sans contrainte de fraîcheur artificielle. Analyse 4 options et propose-moi un ADR avec recommandation argumentée.

> Acceptance criteria :
> - Latence read < 500ms (warm path)
> - Latence write < 2s
> - Toutes sources supportées (Roo + Claude Code)
> - Backward compat 30j (sessions existantes accessibles)

### Contraintes infrastructure

- **GDrive sync latency** : 5s minimum, 30–60s sous charge, jamais < 1s. Pas un système de fichiers transactionnel.
- **6 machines actives** : `myia-ai-01` (coord), `myia-po-2023/24/25/26`, `myia-web1`. Pas toutes online simultanément.
- **Qdrant** : déjà infrastructure partagée (`qdrant.myia.io`), résilient, latence < 200ms p95.
- **Bandwidth GDrive** : `rclone` saturable, #2121 a observé un write storm causé par dashboard sync.
- **NTFS/GDrive atomic rename** : disponible (utilisé par HeartbeatService #1674).

---

## Decision

**Option D retenue : Hybride Qdrant + GDrive.**

- **Qdrant = index global cross-machine** (déjà en place, déjà partagé, déjà résilient).
- **GDrive = artefacts skeleton** (déjà en place pour Tier 3, étendu à temps réel).
- **Cache local Map en mémoire** (existant, 30 min) → conservé comme couche chaude.

Les options écartées sont conservées avec leur argumentaire (section *Alternatives considered*).

### Architecture cible

```
┌─────────────────────────────────────────────────────────────────┐
│  Machine X (writer)                                             │
│                                                                 │
│  Roo task / Claude session                                      │
│        │                                                        │
│        ├─► local persistence (Roo: tasks/  Claude: ~/.claude/)  │
│        │                                                        │
│        └─► SkeletonCacheService.upsertSkeleton(taskId, data)    │
│              │                                                  │
│              ├─► Map<string, ConversationSkeleton> (30min)      │
│              ├─► local file .skeletons/<taskId>.json            │
│              ├─► GDrive write .shared-state/skeletons/          │
│              │       <machineId>/<taskId>.json (NEW, not .gz)   │
│              │                                                  │
│              └─► Qdrant upsert (skeleton-pointer payload)       │
│                    collection: roo_skeletons_index              │
│                    payload: { taskId, machineId, lastActivity,  │
│                               source, workspace, gdrivePath,    │
│                               summary, messageCount }           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼  (Qdrant = single source of truth for index)
┌─────────────────────────────────────────────────────────────────┐
│  Machine Y (reader)                                             │
│                                                                 │
│  conversation_browser(action: "list" / "view")                  │
│        │                                                        │
│        ├─► Qdrant query (filter by workspace / lastActivity)    │
│        │     → list of {taskId, machineId, gdrivePath}          │
│        │                                                        │
│        ├─► cache local Map ? → return skeleton (warm path)      │
│        │                                                        │
│        └─► GDrive read .shared-state/skeletons/<m>/<t>.json     │
│              → cache → return skeleton (cold path)              │
└─────────────────────────────────────────────────────────────────┘
```

### Composants

#### 1. Index Qdrant (nouveau)

- **Collection** : `roo_skeletons_index` (séparée de la collection chunks `roo_tasks_semantic_index`).
- **Payload obligatoire** : `taskId`, `machineId`, `lastActivity` (ISO 8601), `source` (`roo` / `claude-code`), `workspace`, `gdrivePath` (chemin relatif sous `.shared-state/`), `summary` (titre court).
- **Payload optionnel** : `messageCount`, `parentTaskId`, `tags`, `mode`.
- **Vecteur** : embedding du `summary` (256 dim, modèle existant). Permet recherche sémantique cross-machine *du même outil*, pas seulement filtrage exact.
- **Tombstone pattern** : un skeleton supprimé n'est pas hard-delete dans Qdrant — flag `deleted: true` dans payload, hard-delete via job nettoyage 30j (alignement contrainte backward compat).

#### 2. GDrive skeleton artifacts (étendu)

- **Path** : `.shared-state/skeletons/<machineId>/<taskId>.json` (non gzippé, < 50KB typique).
- **Contenu** : `ConversationSkeleton` JSON UTF-8 no-BOM, identique à Tier 1 actuel.
- **Pas de .gz par défaut** : skeletons sont petits ; gzip overhead read pas justifié. La compression reste sur Tier 3 archives (gros volumes de messages).
- **Atomic write** : pattern `HeartbeatService` (`fs.writeFile(tmp); fs.rename(tmp, final)`) pour éviter 0-byte corruption sur sync GDrive.

#### 3. Cache local (existant, conservé)

- `SkeletonCacheService` singleton + `Map<string, ConversationSkeleton>`.
- Validité étendue à **60 min** (vs 30 actuel). Justification : Qdrant index permet l'invalidation explicite (« si Qdrant `lastActivity > cache.cachedAt` alors purge cette entrée »), donc on peut allonger le TTL sans risquer la staleness.

#### 4. Writer path

- `SkeletonCacheService.upsertSkeleton(taskId, skeleton)` (méthode à ajouter) :
  1. Update Map mémoire.
  2. Atomic write local `.skeletons/<taskId>.json` (existant).
  3. Atomic write GDrive `.shared-state/skeletons/<machineId>/<taskId>.json` (nouveau).
  4. Qdrant upsert (avec retry 3× backoff exponentiel, idempotent).
- **Throttle** : 1 write GDrive/skeleton/30s (anti #2121 storm). Si plusieurs upserts dans la fenêtre, seul le dernier est flushé.
- **Caller wiring** (réponse Q3 review po-2023) : `upsertSkeleton()` est déclenché par l'extension du **`ToolUsageInterceptor` existant** (déjà câblé pour l'indexation Qdrant des chunks par tool-call dans `VectorIndexer`). Pas de nouveau hook à ajouter : à la fin de chaque tool-call, après que le chunk Qdrant soit écrit avec succès, l'intercepteur appelle aussi `upsertSkeleton(taskId, skeleton)`. Conséquence pour #1822 (sessions STUCK) : le skeleton est rafraîchi à granularité **tool-call**, pas seulement à la fin de la tâche — les sessions bloquées sont donc visibles dès qu'elles produisent un outil, sans attendre la complétion.
- **Failure mode** (réponse Q2 review po-2023) : si GDrive indisponible au moment du write → Qdrant upsert avec `gdrivePath: null` dans le payload. **Reader fallback explicite** : quand un reader détecte `gdrivePath: null` dans le résultat Qdrant, il déclenche une fetch cross-machine via `roosync_messages(action: "send", attachments: [...])` adressé à la `machineId` d'origine (déjà loggée dans le payload). RooSync proxie le file read via GDrive `attachments/`. Si la machine d'origine est offline → retour gracieux (entry partial dans le list avec flag `stale: true`, ou erreur explicite dans `view`). **Pas de SPOF** : la dégradation est par-skeleton, pas globale.

#### 5. Reader path

- `conversation_browser(list)` :
  1. Query Qdrant `roo_skeletons_index` avec filtre payload (`workspace`, `lastActivity > Date.now() - N days`).
  2. Pour chaque résultat, vérifier cache Map → hit → return summary.
  3. Miss → lazy load depuis `gdrivePath` (1 read par taskId demandé, pas batch).
- `conversation_browser(view, task_id)` :
  1. Cache Map ? → return.
  2. Miss → Qdrant query par `taskId` → récupère `gdrivePath`.
  3. Read GDrive → populate cache → return.

#### 6. Migration & backward compat

- **Phase 2 (implémentation)** : script `migrate-skeletons-to-gdrive.ts` itère sur Tier 1 local de chaque machine (run sur chaque machine), copie chaque `.skeletons/*.json` vers `.shared-state/skeletons/<machineId>/`, upserte Qdrant.
- **Lecture v1 archives** : `TaskArchiver.readArchivedTask()` reste utilisable comme fallback ; les archives .json.gz existantes (Tier 3) ne sont pas migrées immédiatement, elles restent accessibles via le path actuel pendant la fenêtre 30j.
- **Suppression `enableClaudeTier` / `enableArchiveTier` flags** : reportée à une ADR de cleanup ultérieure. Pour cette phase, les flags continuent à fonctionner pour compat.

### Acceptance criteria — vérification

| Critère | Mécanisme | Estimation |
|---------|-----------|-----------|
| Latence read < 500ms (warm) | Cache Map mémoire | < 5ms (mesure cache hit existant) |
| Latence read < 500ms (cold) | GDrive read 1 fichier ~10KB | 100–300ms typique GDrive desktop |
| Latence write < 2s | Atomic write + Qdrant upsert async | local : <10ms ; GDrive throttled : best-effort ; Qdrant : <200ms p95 |
| Toutes sources supportées | Format identique `ConversationSkeleton`, payload `source` | Acquis (TaskArchiver couvre déjà Roo + Claude Code JSONL) |
| Backward compat 30j | Migration script + lecture Tier 3 archives existantes | Acquis pendant fenêtre, suppression Tier 3 deferred |

---

## Alternatives considered

### Option A — DB distribuée (SQLite/PostgreSQL/Qdrant exclusif)

**Idée** : centraliser skeletons dans une vraie DB (Postgres distant, ou Qdrant payload-only sans GDrive).

**Pros** :
- Transactions ACID, pas de coordination GDrive.
- Query SQL/filter natif.

**Cons** :
- **Nouvelle infrastructure** : Postgres signifie hosting, sauvegarde, ACLs, monitoring — pas de précédent dans la flotte.
- **Qdrant payload-only** : Qdrant n'est pas un store général-purpose, payloads > 64KB pénalisent les performances index. Skeletons sont typiquement 5–30KB mais certains atteignent 100KB+ (longs résumés).
- **Backward compat lourd** : aucune des données actuelles n'est dans Postgres → migration totale à faire d'un coup.
- **SPOF** : si Postgres down, plus de skeleton du tout (vs Option D qui dégrade gracieusement).

**Verdict** : rejeté. Ajoute un composant infrastructure sans bénéfice par rapport à Qdrant+GDrive déjà en place et résilients.

### Option B — Index global GDrive (`tasks-index.json` append-only)

**Idée** : un seul fichier `.shared-state/tasks-index.json` que toutes les machines append-only, plus N fichiers `<taskId>.json` à côté.

**Pros** :
- Pas de nouvelle dépendance (Qdrant inutile pour l'index).
- Simple conceptuellement.

**Cons** :
- **#2121 write storm reproduit** : 6 machines qui écrivent un même fichier index → conflicts GDrive sync, 0-byte files, dupes.
- **Pas de query** : pour lister les tâches d'un workspace, il faut télécharger tout `tasks-index.json` (peut atteindre plusieurs MB après quelques mois) et filter côté client.
- **Pas de recherche sémantique** : Qdrant aurait dû être conservé en parallèle, donc on n'évite pas la dépendance, on l'ajoute en doublon.

**Verdict** : rejeté. Le pattern « append-only sur GDrive partagé entre 6 writers » est exactement ce qui a causé #2121.

### Option C — Fichier par task GDrive + index local cache

**Idée** : juste N fichiers `<taskId>.json` sur GDrive, chaque machine maintient son propre index local (SQLite) construit par `rclone lsf` + tail.

**Pros** :
- Pas de coordination centrale.
- Lecture cold = 1 fichier GDrive (rapide).

**Cons** :
- **Discovery slow** : `rclone lsf` sur quelques milliers de fichiers prend 5–30s. Pour `conversation_browser(list)` ce n'est pas tenable.
- **Pas d'index sémantique** : retombe sur recherche textuelle ou refait Qdrant.
- **N index locaux divergents** : chaque machine reconstruit le sien, source de bugs de cohérence (déjà vu sur `roosync_search` quand les caches divergent).

**Verdict** : rejeté pour la latence discovery. Conceptuellement proche d'Option D mais sans Qdrant, donc inférieur.

### Option D — Hybride Qdrant + GDrive (retenue)

**Pros** :
- **Réutilise l'existant** : Qdrant déjà déployé, déjà partagé, déjà résilient. TaskArchiver et SkeletonCacheService déjà en place.
- **Pas de SPOF** : si Qdrant down → fallback Tier 1 local + Tier 3 archives existantes. Si GDrive down → fallback Qdrant payload résumé (sans contenu complet, mais navigable).
- **Search sémantique gratuit** : déjà disponible via Qdrant.
- **Migration douce** : Tier 3 archives restent lisibles pendant la fenêtre 30j, suppression deferred.
- **Latence claims tenables** : warm path cache Map < 5ms ; cold path GDrive < 500ms ; index Qdrant < 200ms.

**Cons** :
- **Couplage Qdrant accru** : si Qdrant index corrompu, conversation_browser dégradé. Mitigation : reconstruction Qdrant possible depuis GDrive + local (script de rebuild, pattern existant `roosync_indexing rebuild`).
- **Throttle GDrive write peut masquer updates récents** : une tâche modifiée puis re-modifiée dans la fenêtre 30s ne flush que la dernière version sur GDrive. Acceptable : la cache Map locale a la dernière version pour la machine writer ; l'autre machine la verra au prochain Qdrant upsert (qui n'est pas throttled).
- **Backward compat partielle pendant migration** : pendant Phase 2 (script de migration), il existe une fenêtre où certaines tâches sont sur Tier 3 .json.gz et d'autres sur nouveau path .json. Reader doit gérer les deux. Code complexity temporaire.

**Verdict** : retenue. Meilleur ratio bénéfice/risque sur infrastructure existante.

---

## Consequences

### Bénéfices attendus

- **Visibilité cross-machine par défaut** : plus besoin d'opt-in. Toutes les tâches deviennent navigables depuis n'importe quelle machine après ~10s (GDrive sync + cache reader).
- **Sessions STUCK (#1822) visibles** : l'écriture skeleton est faite au fil de l'eau, pas seulement à l'archivage. Une session non terminée reste navigable.
- **#2121 risk contenu** : throttle 30s + atomic write + path par-machine (`<machineId>/`) évitent les collisions multi-writer sur même fichier.
- **EPIC #2190 débloqué** : vibe-conversation-browser peut s'appuyer sur cet index pour ses features de navigation cross-machine.

### Risques résiduels

1. **Qdrant collection drift** : si un upsert échoue silencieusement, le skeleton existe sur GDrive mais pas dans l'index → orphelin. Mitigation : job nightly `rebuild-qdrant-from-gdrive`.
2. **Concurrent overwrite par-machine** : deux processus de la même machine qui upsertent simultanément le même taskId. Mitigation : `SkeletonCacheService` est singleton, donc 1 process MCP par machine = pas de race interne. Si plusieurs processes (rare), `last-write-wins` accepté.
3. **GDrive quota / latence dégradée** : pas d'observabilité en place. Mitigation : ajouter métrique `gdrive_write_throttled_count` au dashboard observability (#2186).
4. **Migration partielle si une machine reste offline > 30j** : ses skeletons locaux ne sont pas copiés vers GDrive avant son retour. Acceptable car backward compat 30j ne s'étend pas aux machines mortes.

### Travail Phase 2 (hors scope de cet ADR)

- Implémentation `SkeletonCacheService.upsertSkeleton()` avec throttle 30s + atomic write GDrive.
- Création collection Qdrant `roo_skeletons_index` (script setup).
- Migration script `migrate-skeletons-to-gdrive.ts` (idempotent, par-machine).
- Adapter `conversation_browser(list/view)` pour query Qdrant en premier.
- Tests vitest CI : write/read round-trip cross-machine simulé via tmp dirs.
- Métrique observability sur dashboard listener (#2186).
- Documentation `docs/harness/reference/conversation-browser-storage.md`.

### Travail Phase 3 (post-validation)

- Suppression flags `enableClaudeTier` / `enableArchiveTier` (deviennent automatiques).
- Suppression Tier 3 `.json.gz` archives au profit du nouveau path `.json` (après 30j de coexistence).
- Job nightly Qdrant integrity check + rebuild from GDrive.

---

## Open questions (pour user review)

1. **Throttle GDrive write 30s suffisant ?** Si une session change toutes les 5s pendant 1h, on perd 119 versions intermédiaires sur GDrive (mais on a la dernière + Qdrant log). Acceptable ?
2. **Collection Qdrant séparée ou même que `roo_tasks_semantic_index` ?** Séparée évite la pollution mais coûte un setup. Recommandation actuelle : séparée.
3. **Suppression hard à 30j ou tombstone éternel ?** Le mandate dit « backward compat 30j » mais ne dit pas si on peut purger après. Recommandation : tombstone éternel sur Qdrant (lookup), hard-delete sur GDrive à 90j (espace).
4. **Qui exécute la migration Phase 2 ?** Coordinator ai-01 (1 fois), ou chaque machine via worker (parallel) ? Recommandation : worker par-machine pour éviter qu'une machine offline bloque la flotte.

---

**Implementation tracking** : Phase 2 sera ouvert en sous-issue de #2191 après approbation de cet ADR. Phase 3 dépend de l'observabilité runtime issue de Phase 2.
