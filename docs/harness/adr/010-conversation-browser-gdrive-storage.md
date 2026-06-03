# ADR 010: conversation_browser — GDrive Cross-Machine Storage + Postgres Metadata Layer

**Date:** 2026-05-15 (v1.0) → 2026-05-15 (v2.0 — R43 Scenario B hybrid permanent)
**Status:** Proposed (Phase 1 — ADR for user review)
**Issue:** #2191
**Supersedes:** #1393 (hot/warm/cold tiered storage — rejected by user), ADR 010 v1.0 (Option D Qdrant+GDrive — partially superseded by v2.0)
**Related:** EPIC #2190 (vibe-conversation-browser), #1244 (multi-tier cache), #1360 (master plan), #1822 (STUCK sessions), #2121 (GDrive write storm), #1747 (per-tier health stats), #2193 (Qdrant payload `message_id` extension)
**Deciders:** jsboige (mandate R43), claude-interactive po-2025 (Phase 1 author)

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

Implémentation : `mcps/internal/servers/roo-state-manager/src/services/skeleton-cache.service.ts` (`../../../mcps/internal/servers/roo-state-manager/src/services/skeleton-cache.service.ts`) (517 lignes, singleton, `Map<string, ConversationSkeleton>` en mémoire avec validité 30 min).

Archivage GDrive : `mcps/internal/servers/roo-state-manager/src/services/task-archiver/TaskArchiver.ts` (`../../../mcps/internal/servers/roo-state-manager/src/services/task-archiver/TaskArchiver.ts`) — écrit `.json.gz` au format v2 (messages complets, pas de troncation) lors de l'indexation Qdrant.

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

## Decision History

### R42 (ADR 010 v1.0) — Option D : Hybride Qdrant + GDrive

- Qdrant = index global cross-machine. GDrive = artefacts skeleton. Cache local Map = couche chaude.
- **Verdict** : retenue initialement.

### R43 (2026-05-15) — Scénario B : Hybrid permanent Qdrant + Postgres

User réoriente après objection : *"Qdrant, il est fait pour stocker des chunks (…) c'est + du boulot pour une DB normale non ?"*. Puis confirmation :

1. **"Go pour postgres"** — confirme tech DB choisie
2. **"B également, ça ne me gène pas qu'ils se partagent les rôles et la charge"** — Scenario B retenu (hybrid permanent), PAS de migration full vers Postgres
3. **"le résultat de la recherche bénéficierait à profiter de la structure fournie par les champs des entités dont les chunks ont matchés. Ca fait 2 requêtes de données dans 2 containers afférents"**

**Architecture finale (Scénario B retenu) :**

| Container | Rôle | Statut |
|-----------|------|--------|
| **Qdrant** | Embeddings + chunks raw (content), sert ANN | **Conservé** — rôle ANN inchangé |
| **Postgres** | Metadata structurée (conversations, messages, tasks, workspaces, models, dates) | **Ajouté** comme complément |
| **GDrive** | Cold archives `.jsonl.gz` (>30j, optionnel) | Optionnel selon tiering finale |

**Search flow 2-step :**

1. **Qdrant ANN** → top-K chunks avec refs `task_id` / `message_id`
2. **Postgres JOIN** sur ces refs → enrichissement avec metadata + messages adjacents

User point clé : 2 requêtes dans 2 containers complémentaires = OK perfs, parce que la 2ème est un simple lookup indexé par PK, pas un scan.

### Ce qui change vs v1.0

- ❌ **PAS** de "decommission Qdrant after 6-month validation"
- ❌ **PAS** de migration des embeddings vers pgvector (au moins pas comme objectif)
- ✅ Postgres est **complément**, pas remplacement
- ✅ Hybrid permanent acceptable
- ✅ **PAS** de colonne `embedding vector(2560)` dans Postgres `chunks` table (laissé à Qdrant)
- ✅ Postgres `chunks` table (si ajoutée) stocke uniquement `{id, message_id, content, chunk_type}` — sans embedding
- ✅ Qdrant payload extension : ajouter `message_id` pour permettre le JOIN inverse
- ✅ Refactor search engine en 2-step query

---

## Decision

**Option E retenue : Hybrid permanent Qdrant + Postgres + GDrive.**

- **Qdrant** = embeddings + chunks raw content, sert ANN (rôle actuel préservé, PAS de décommission).
- **Postgres** = metadata structurée (conversations, messages, tasks). Complément à Qdrant, pas remplacement.
- **GDrive** = skeleton artifacts + cold archives `.jsonl.gz`.
- **Cache local Map** = couche chaude existante.

Les options écartées sont conservées avec leur argumentaire (section *Alternatives considered*).

### Architecture cible

```
┌─────────────────────────────────────────────────────────────────────┐
│  Machine X (writer)                                                 │
│                                                                     │
│  Roo task / Claude session                                          │
│        │                                                            │
│        ├─► local persistence (Roo: tasks/  Claude: ~/.claude/)     │
│        │                                                            │
│        └─► SkeletonCacheService.upsertSkeleton(taskId, data)        │
│              │                                                      │
│              ├─► Map<string, ConversationSkeleton> (60min)          │
│              ├─► local file .skeletons/<taskId>.json                │
│              ├─► GDrive write .shared-state/skeletons/              │
│              │       <machineId>/<taskId>.json (NEW, not .gz)       │
│              │                                                      │
│              ├─► Qdrant upsert (skeleton-pointer + chunk-embeddings)│
│              │    payload: { taskId, machineId, message_id,         │
│              │       lastActivity, source, workspace, gdrivePath }  │
│              │                                                      │
│              └─► Postgres upsert (metadata only)                     │
│                   INSERT INTO conversations ... (ON CONFLICT UPDATE) │
│                   INSERT INTO messages ... (per tool-call batch)     │
└─────────────────────────────────────────────────────────────────────┘
                               │
          ┌────────────────────┼────────────────────┐
          ▼                    ▼                    ▼
   ┌──────────────┐   ┌──────────────┐   ┌──────────────────┐
   │  Qdrant      │   │  Postgres    │   │  GDrive          │
   │  (ANN index) │   │  (metadata)  │   │  (skeletons+cold)│
   └──────────────┘   └──────────────┘   └──────────────────┘
                               │
                               ▼  (Qdrant = ANN, Postgres = JOIN)
┌─────────────────────────────────────────────────────────────────────┐
│  Machine Y (reader)                                                 │
│                                                                     │
│  conversation_browser(list / view / search)                         │
│        │                                                            │
│        ├─► Qdrant ANN query (embeddings)                            │
│        │    → top-K chunks: { taskId, message_id, content, score }  │
│        │                                                            │
│        ├─► Postgres JOIN on refs                                   │
│        │    SELECT c.content, m.role, m.content AS parent_msg,       │
│        │           prev.content AS prev_msg, next.content AS next_msg│
│        │        FROM chunks c                                        │
│        │        JOIN messages m ON c.message_id = m.id               │
│        │        LEFT JOIN messages prev ON prev.id = m.id - 1        │
│        │        LEFT JOIN messages next ON next.id = m.id + 1        │
│        │        WHERE c.task_id IN (taskId from Qdrant)              │
│        │    → rich results: chunks + adjacent messages + metadata     │
│        │                                                            │
│        ├─► cache local Map ? → return skeleton (warm path)          │
│        │                                                            │
│        └─► GDrive read .shared-state/skeletons/<m>/<t>.json         │
│              → cache → return skeleton (cold path)                  │
└─────────────────────────────────────────────────────────────────────┘
```

### Composants

#### 1. Index Qdrant (étendu — payload message_id)

- **Collection** : `roo_tasks_semantic_index` (existante, PAS de nouvelle collection séparée pour skeletons — le skeleton-pointer est un champ supplémentaire dans la même collection chunks).
- **Payload existing** : `taskId`, `machineId`, `content` (chunk text), `embedding` (vector), `chunk_type`.
- **Payload étendu** (réponse R43) : ajouter `message_id` (BIGINT, lien vers Postgres `messages.id`) et `task_id` (déjà présent) pour permettre le JOIN inverse dans Postgres.
- **Vecteur** : embedding du chunk (2560 dim, modèle existant). ANN via distance Cosine.
- **Tombstone pattern** : un skeleton supprimé n'est pas hard-delete dans Qdrant — flag `deleted: true` dans payload, hard-delete via job nettoyage 30j.

**Qdrant payload migration (réponse Q2 review po-2023, étendu R43) :** quand un reader détecte `gdrivePath: null` dans le résultat Qdrant, il déclenche une fetch cross-machine via `roosync_messages(action: "send", attachments: [...])` adressé à la `machineId` d'origine (déjà loggée dans le payload). **Pas de SPOF** : la dégradation est par-skeleton, pas globale.

#### 2. Postgres (nouveau — metadata structurée)

- **Installation** : PostgreSQL 16+ sur `ai-01` (master), logical/streaming replicas (read-only) sur `po-2024` et `po-2026`.
- **Schema** :

```sql
CREATE TABLE conversations (
  task_id TEXT PRIMARY KEY,
  machine TEXT,
  workspace TEXT,
  model TEXT,
  created_at TIMESTAMPTZ,
  message_count INT,
  archived_url TEXT NULL  -- set when conversation moved to cold tier
);

CREATE TABLE messages (
  id BIGSERIAL PRIMARY KEY,
  task_id TEXT REFERENCES conversations(task_id),
  idx INT,
  role TEXT,
  content TEXT,
  tool_calls JSONB,
  created_at TIMESTAMPTZ
);

CREATE INDEX idx_messages_task_idx ON messages(task_id, idx);
-- Index per-machine pour requêtes cross-machine via replica
CREATE INDEX idx_messages_task_id ON messages(task_id);
```

- **PAS de colonne `embedding vector(2560)` dans Postgres** — pgvector exclu. Les vecteurs restent exclusivement dans Qdrant.
- **PAS de table `chunks` dans Postgres** — le chunking (texte découpé + embedding) reste exclusivement dans Qdrant payload. Postgres stocke uniquement `conversations` + `messages` au niveau message complet.
- **Duplication texte** : `messages.content` dans Postgres contient le texte complet du message. Qdrant `chunks.content` contient les fragments découpés. Du texte est dupliqué (quelques KB par message), mais cela évite de devoir Qdrant pour la lecture simple et permet les JOIN messages adjacents sans passer par Qdrant.
- **Replication** : logical replication (par-table, plus flexible) du master `ai-01` vers replicas `po-2024`/`po-2026`. Chaque machine consulte sa replica locale → pas de round-trip MCP cross-machine pour les requêtes Postgres.

#### 3. GDrive skeleton artifacts (étendu)

- **Path** : `.shared-state/skeletons/<machineId>/<taskId>.json` (non gzippé, < 50KB typique).
- **Contenu** : `ConversationSkeleton` JSON UTF-8 no-BOM, identique à Tier 1 actuel.
- **Pas de .gz par défaut** : skeletons sont petits ; gzip overhead read pas justifié. La compression reste sur Tier 3 archives (gros volumes de messages).
- **Atomic write** : pattern `HeartbeatService` (`fs.writeFile(tmp); fs.rename(tmp, final)`) pour éviter 0-byte corruption sur sync GDrive.

#### 4. Cache local (existant, conservé)

- `SkeletonCacheService` singleton + `Map<string, ConversationSkeleton>`.
- Validité étendue à **60 min** (vs 30 actuel). Justification : Qdrant + Postgres index permettent l'invalidation explicite, donc on peut allonger le TTL sans risquer la staleness.

#### 5. Writer path

- `SkeletonCacheService.upsertSkeleton(taskId, skeleton)` (méthode à ajouter) :
  1. Update Map mémoire.
  2. Atomic write local `.skeletons/<taskId>.json` (existant).
  3. Atomic write GDrive `.shared-state/skeletons/<machineId>/<taskId>.json` (nouveau).
  4. Qdrant upsert (avec retry 3× backoff exponentiel, idempotent).
  5. Postgres upsert metadata (ON CONFLICT UPDATE, idempotent).
- **Throttle** : 1 write GDrive/skeleton/30s (anti #2121 storm). Si plusieurs upserts dans la fenêtre, seul le dernier est flushé.
- **Caller wiring** (réponse Q3 review po-2023) : `upsertSkeleton()` est déclenché par l'extension du **`ToolUsageInterceptor` existant** (déjà câblé pour l'indexation Qdrant des chunks par tool-call dans `VectorIndexer`). Pas de nouveau hook à ajouter : à la fin de chaque tool-call, après que le chunk Qdrant soit écrit avec succès, l'intercepteur appelle aussi `upsertSkeleton(taskId, skeleton)`. Conséquence pour #1822 (sessions STUCK) : le skeleton est rafraîchi à granularité **tool-call**, pas seulement à la fin de la tâche — les sessions bloquées sont donc visibles dès qu'elles produisent un outil, sans attendre la complétion.
- **Failure mode** : si GDrive indisponible au moment du write → Qdrant + Postgres upsert avec `gdrivePath: null` dans le payload Qdrant. **Reader fallback** : quand un reader détecte `gdrivePath: null` dans le résultat Qdrant, il déclenche une fetch cross-machine via `roosync_messages(action: "send", attachments: [...])` adressé à la `machineId` d'origine. Si la machine d'origine est offline → retour gracieux (entry partial dans le list avec flag `stale: true`). **Pas de SPOF**.

#### 6. Reader path — Search 2-step

**`conversation_browser(list)` :**
1. Query Qdrant `roo_tasks_semantic_index` avec filtre payload (`workspace`, `lastActivity`).
2. Pour chaque résultat, vérifier cache Map → hit → return summary.
3. Miss → lazy load depuis `gdrivePath` ou fallback Postgres metadata.

**`conversation_browser(view, task_id)` :**
1. Cache Map ? → return.
2. Miss → Qdrant query par `taskId` → récupère `gdrivePath` + `message_id`.
3. Postgres JOIN sur `message_id` pour enrichir avec metadata.
4. Read GDrive → populate cache → return skeleton.

**`conversation_browser(semantic_search, query_embedding)` (nouveau, Phase 2) :**
1. **Step 1 — Qdrant ANN** : recherche vectorielle → top-K chunks avec `{task_id, message_id, content, score}`.
2. **Step 2 — Postgres JOIN** : pour chaque chunk result, JOIN `messages` sur `message_id` → enrichir avec `role`, `tool_calls`, messages adjacents (`prev.id = message_id - 1`, `next.id = message_id + 1`), metadata conversation (`conversations.model`, `conversations.workspace`).
3. Fusionner résultats Qdrant + enrichissements Postgres → return.

**Exemple enrichissement query Postgres :**
```sql
SELECT c.task_id, m.role, m.content, m.created_at,
       prev.content AS prev_msg, next.content AS next_msg,
       conv.model, conv.workspace
FROM chunks c
  JOIN messages m ON c.message_id = m.id
  JOIN conversations conv ON m.task_id = conv.task_id
  LEFT JOIN messages prev ON prev.task_id = m.task_id AND prev.idx = m.idx - 1
  LEFT JOIN messages next ON next.task_id = m.task_id AND next.idx = m.idx + 1
WHERE c.task_id IN (SELECT task_id FROM (Qdrant top-K results))
ORDER BY score
LIMIT 20;
```
→ chunks + leurs voisins immédiats + metadata parent, dans un seul query Postgres.

#### 7. Migration & backward compat

- **Phase 2 (implémentation)** :
  - Script `migrate-skeletons-to-gdrive.ts` : itère Tier 1 local de chaque machine, copie `.skeletons/*.json` vers `.shared-state/skeletons/<machineId>/`, upserte Qdrant.
  - Script `migrate-to-postgres.ts` : export metadata Qdrant chunks → Postgres `conversations` + `messages` inserts (idempotent).
  - Qdrant payload migration : ajouter `message_id` à chunks existants (backfill depuis Postgres après import).
  - Setup Postgres : install ai-01, replicas po-2024/po-2026, replication slots.
- **Lecture v1 archives** : `TaskArchiver.readArchivedTask()` reste fallback ; archives .json.gz existantes (Tier 3) accessibles via path actuel pendant 30j.
- **Suppression `enableClaudeTier` / `enableArchiveTier` flags** : reportée à ADR de cleanup ultérieure.

### Acceptance criteria — vérification

| Critère | Mécanisme | Estimation |
|---------|-----------|-----------|
| Latence read < 500ms (warm) | Cache Map mémoire | < 5ms |
| Latence read < 500ms (cold) | GDrive read 1 fichier ~10KB | 100–300ms typique |
| Latence search 2-step | Qdrant ANN < 200ms + Postgres JOIN < 100ms | < 350ms total |
| Write < 2s | Atomic write + Qdrant/Postgres upsert async | local : <10ms ; GDrive throttled : best-effort ; Qdrant : <200ms p95 |
| Toutes sources supportées | Format identique `ConversationSkeleton`, payload `source` | Acquis |
| Backward compat 30j | Migration script + lecture Tier 3 archives | Acquis pendant fenêtre |

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
- **SPOF** : si Postgres down, plus de skeleton du tout (vs Option E qui dégrade gracieusement).

**Verdict** : rejeté en standalone. Partiellement réactivé en R43 comme **complément** à Qdrant (Option E), PAS comme remplacement.

### Option B — Index global GDrive (`tasks-index.json` append-only)

**Idée** : un seul fichier `.shared-state/tasks-index.json` que toutes les machines append-only, plus N fichiers `<taskId>.json` à côté.

**Pros** :
- Pas de nouvelle dépendance (Qdrant inutile pour l'index).
- Simple conceptuellement.

**Cons** :
- **#2121 write storm reproduit** : 6 machines qui écrivent un même fichier index → conflicts GDrive sync, 0-byte files, dupes.
- **Pas de query** : pour lister les tâches d'un workspace, il faut télécharger tout `tasks-index.json` et filter côté client.
- **Pas de recherche sémantique** : Qdrant aurait dû être conservé en parallèle.

**Verdict** : rejeté. Le pattern « append-only sur GDrive partagé entre 6 writers » est exactement ce qui a causé #2121.

### Option C — Fichier par task GDrive + index local cache

**Idée** : juste N fichiers `<taskId>.json` sur GDrive, chaque machine maintient son propre index local (SQLite) construit par `rclone lsf` + tail.

**Pros** :
- Pas de coordination centrale.
- Lecture cold = 1 fichier GDrive (rapide).

**Cons** :
- **Discovery slow** : `rclone lsf` sur quelques milliers de fichiers prend 5–30s.
- **Pas d'index sémantique** : retombe sur recherche textuelle ou refait Qdrant.
- **N index locaux divergents** : source de bugs de cohérence.

**Verdict** : rejeté pour la latence discovery. Conceptuellement proche d'Option E mais sans Qdrant, donc inférieur.

### Option D — Hybride Qdrant + GDrive (v1.0 — partiellement superseded)

**Verdict v1.0** : retenue.

**Verdict v2.0** : partiellement supersédée par Option E. Les composants GDrive + Qdrant skeleton-pointer sont conservés, mais l'architecture est enrichie avec Postgres metadata layer. Le "decommission Qdrant after 6 months" de R42 est supprimé (R43 : Qdrant permanent).

**Pros conservés** :
- Réutilise l'existant : Qdrant, TaskArchiver, SkeletonCacheService.
- Pas de SPOF : Qdrant + GDrive + Postgres dégrade gracieusement.
- Search sémantique : Qdrant ANN.

**Nouveaux risques R43** :
- **Synchronisation Qdrant ↔ Postgres** : si l'un crash, l'autre peut diverger. Mitigation : upsert atomique dans le writer path, retry sur les deux, job nightly reconcile.
- **Complexité accrue** : 3 containers au lieu de 2. Mitigation : Postgres = metadata uniquement, Qdrant = embeddings uniquement. Séparation claire des responsabilités.
- **2 requêtes pour une recherche** : Qdrant ANN + Postgres JOIN. User validated : perfs OK car Postgres lookup est indexé par PK (pas de scan).

### Option E — Hybrid permanent Qdrant + Postgres + GDrive (retenue)

**Pros** :
- **Qdrant garde son rôle** : embeddings + chunks raw. Pas de refonte, pas de migration de vectors.
- **Postgres enrichit** : metadata structurée + messages adjacents → résultats de recherche bien plus utiles que des chunks nus.
- **2-step query validé par user** : 2 requêtes dans 2 containers complémentaires, perfs OK (Postgres lookup indexé PK).
- **Pas de SPOF** : Qdrant down → fallback GDrive + Postgres metadata. Postgres down → Qdrant ANN + GDrive (sans enrichissement, mais navigable). GDrive down → Qdrant + Postgres (sans skeleton complet, mais list + view via metadata).
- **Migration progressive** : Qdrant existe déjà, Postgres s'ajoute sans casser l'existant.

**Cons** :
- **3 containers à maintenir** au lieu de 2. Complexité opérationnelle plus élevée.
- **Sync Qdrant↔Postgres** : écrire dans les 2 en même temps ajoute une étape dans le writer path. Mitigation : upsert async Postgres (non-bloquant pour Qdrant).
- **Schema design** : Postgres ne stocke ni embeddings ni chunks lourds → schema minimaliste mais cohérent avec le besoin (metadata + structure).

**Verdict** : retenue. Meilleur ratio bénéfice/complexité. Qdrant conserve son expertise ANN, Postgres apporte la structure que Qdrant ne peut pas offrir.

---

## Consequences

### Bénéfices attendus

- **Visibilité cross-machine par défaut** : plus besoin d'opt-in. Toutes les tâches navigables depuis n'importe quelle machine.
- **Sessions STUCK (#1822) visibles** : skeleton écrit au fil de l'eau, pas seulement à l'archivage.
- **#2121 risk contenu** : throttle 30s + atomic write + path par-machine.
- **Recherche enrichie (2-step)** : résultats Qdrant + metadata Postgres + messages adjacents → bien plus utiles que chunks seuls.
- **EPIC #2190 débloqué** : vibe-conversation-browser peut s'appuyer sur cette architecture hybride.
- **Postgres metadata** : query SQL pour `conversations.model`, `conversations.workspace`, `messages.role`, `messages.tool_calls` → analytics et filtres avancés.

### Risques résiduels

1. **Qdrant collection drift** : upsert échoue silencieusement → skeleton sur GDrive mais pas dans l'index. Mitigation : job nightly `rebuild-qdrant-from-gdrive`.
2. **Postgres ↔ Qdrant sync lag** : metadata Postgres slightly behind Qdrant chunks. Acceptable : write Postgres est async et non-bloquant.
3. **Concurrent overwrite par-machine** : `SkeletonCacheService` singleton = 1 process MCP = pas de race interne.
4. **Postgres SPOF local** : si machine hébergeant Postgres (ai-01) down, replicas ne sont plus accessibles. Mitigation : replicas sur `po-2024`/`po-2026` (read-only, pas d'écriture).
5. **GDrive quota / latence** : ajout métrique `gdrive_write_throttled_count` au dashboard observability (#2186).

### Travail Phase 2 (hors scope de cet ADR)

- Implémentation `SkeletonCacheService.upsertSkeleton()` avec throttle 30s + atomic write GDrive.
- Setup Postgres 16 sur ai-01 + replicas logical sur po-2024/po-2026.
- Qdrant payload migration : ajouter `message_id` à chunks existants (backfill depuis Postgres).
- Migration script `migrate-to-postgres.ts` : export metadata → Postgres inserts.
- Adaptation `conversation_browser` pour search 2-step (Qdrant ANN + Postgres JOIN).
- Tests vitest CI : write/read round-trip cross-machine + search 2-step validation.
- Métrique observability sur dashboard listener (#2186).
- Documentation `docs/harness/reference/conversation-browser-storage.md`.

### Travail Phase 3 (post-validation)

- Suppression flags `enableClaudeTier` / `enableArchiveTier`.
- Suppression Tier 3 `.json.gz` au profit du nouveau path `.json` (après 30j coexistence).
- Job nightly Qdrant integrity check + rebuild from GDrive.
- **Optionnel** : hot/cold rotation — nightly job archive `.jsonl.gz` vers GDrive, NULL heavy columns dans Postgres.

---

## Open questions (pour user review)

1. **Replication Postgres** : logical (par-table, plus flexible, peut répliquer subset) vs streaming (whole cluster, plus simple). Recommandation : logical pour pouvoir exclure des tables très volumineuses à l'avenir si besoin.

2. **Postgres hosting sur ai-01** : container Docker vs install native. Docker = isolation + backup facile. Native = perf + simplicité. Recommandation : Docker pour faciliter la maintenance et les snapshots.

3. **Backup retention Postgres** : quelle rétention pour les backups ? 7 jours (standard), 30 jours (compliance), 90 jours (long-term) ?

4. **Failover procedure** : si ai-01 down, comment promouvoir un replica (`po-2024` ou `po-2026`) en master ? Procedure manuelle ou automatique ?

5. **Qdrant payload `message_id` backfill** : les chunks existants n'ont pas `message_id`. Faut-il un script de backfill depuis les metadata Postgres après import ? Ou `message_id` nullable et rempli à la volée ? Recommandation : nullable au départ, backfill progressif.

6. **Duplication texte messages** : Postgres `messages.content` et Qdrant `chunks.content` stockent du texte en doublon. Acceptable (quelques KB de duplication par message) ou préférer référence Qdrant dans Postgres ? Recommandation : dupliquer le texte dans Postgres (lookup plus rapide, pas besoin de Qdrant pour la lecture).

7. **Throttle GDrive write 30s suffisant ?** Si une session change toutes les 5s pendant 1h, on perd 119 versions intermédiaires sur GDrive (mais on a la dernière + Qdrant log). Acceptable ?

---

**Implementation tracking** : Phase 2 sera ouvert en sous-issue de #2191 après approbation de cet ADR. Phase 3 dépend de l'observabilité runtime issue de Phase 2.

---

## Version History

| Version | Date | Change |
|---------|------|--------|
| v1.0 | 2026-05-15 | Option D — Hybride Qdrant + GDrive (R42) |
| v2.0 | 2026-05-15 | Option E — Hybrid permanent Qdrant + Postgres + GDrive (R43 Scenario B). Supersede R42 "decommission Qdrant". Add Postgres metadata layer, 2-step search, schema definition, Qdrant payload `message_id` extension. |
