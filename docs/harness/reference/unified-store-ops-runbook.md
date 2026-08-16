# Unified Store (Postgres) — Runbook Ops

**Issues :** #2957 (AC restants) · Epic #2191 · déploiement prod #2553 (clos)
**MAJ :** 2026-08-16 (po-204, séquence vérifiée contre le code `c42f1706`)
**Audience :** ai-01 (DB prod + corpus de référence), puis chaque machine qui rejoint le dual-write.

---

## 0. État des pièces — tout le code est livré

| Pièce | Chemin (submod `servers/roo-state-manager/`) | État |
|---|---|---|
| Dual-write conversations + messages | `src/services/unified-store/dual-write.ts` | ✅ MERGED (submod #898, #970 ; parent #2960, #3080) |
| Normalisation `machine_id` casse | `dual-write.ts` frontière unique (`toLowerCase()`) | ✅ MERGED (submod #898) |
| Isolation CI→prod | connexion DB en mode test isolée | ✅ MERGED + purgé (submod #899, `DELETE 1068`) |
| Factory env-gate | `src/services/unified-store/writer-factory.ts` | ✅ `UNIFIED_STORE_DUAL_WRITE=1` + `UNIFIED_STORE_PG_URL` → Pg, sinon Null (no-op) |
| Module backfill | `src/services/unified-store/backfill.ts` | ✅ idempotent (upsert), injectable, dry-run SANS DB |
| **CLI backfill** | `scripts/backfill-unified-store.mjs` | ✅ `--dry-run` / `--limit N` / `.env` auto-chargé |
| Schéma | `migrations/001_init_unified_store.sql` | ✅ appliqué en prod (#2553) |
| Compose DEV | `docker-compose.postgres.yml` (port 5433) | ✅ pour validation locale uniquement |
| Postgres prod | ai-01, Docker, pg.myia.io TCP+SSL | ✅ déployé et vérifié (#2553, conversations peuplées) |

**Ce runbook ne déploie rien** — il séquence les opérations qui ferment les 4 AC de #2957.

---

## 1. Activer le dual-write sur une machine d'écriture

Deux clés dans `.env` (submod `servers/roo-state-manager/.env`) :

```ini
UNIFIED_STORE_DUAL_WRITE=1
UNIFIED_STORE_PG_URL=postgres://unified_store:<password>@pg.myia.io:5432/unified_store?sslmode=require
```

(URL exacte — hôte/port/SSL — à reprendre de la config prod ai-01 posée par #2553 ; la ligne ci-dessus est la forme attendue, le port 5432 étant la convention Postgres.)

- Le mot de passe transite par **RooSync (GDrive)**, jamais par git (règle sécurité).
- **Datapoint flotte :** po-204 a 0 clé `UNIFIED_STORE_*` en `.env` le 16/08 — le dual-write y est OFF (NullWriter). ai-01 l'a ON (10 955 conversations ingérées au 25/07).
- Toute machine dont les 2 clés sont absentes = no-op silencieux par construction (factory). Aucun risque à ne rien faire.

**Après ajout : restart du host MCP** (`[INTERACTIVE-ONLY]` — le process charge `.env` au démarrage). Vérification dans les logs de démarrage RSM :

```text
[UnifiedStore] Dual-write ENABLED — connecting to postgres://unified_store:***@...
```

La ligne `Dual-write DISABLED` = gate off (clés absentes ou mal orthographiées — le gate exige exactement `'1'`).

---

## 2. Backfill du corpus existant (messages = AC1)

Le dual-write live ne couvre que les conversations indexées APRÈS le restart. Le corpus déjà sur disque (`tasks/.skeletons/`) doit passer par le CLI — c'est ce qui peuple `messages` pour l'existant.

Depuis `servers/roo-state-manager/` (build/ requis — `npm run build` au besoin) :

```powershell
# 1. Smoke : 10 squelettes, écrit rien (NullWriter forcé)
node scripts/backfill-unified-store.mjs --dry-run --limit 10

# 2. Rehearsal complet : counts sans écriture
node scripts/backfill-unified-store.mjs --dry-run

# 3. LIVE : persiste (upsert idempotent — reprenable après interruption)
node scripts/backfill-unified-store.mjs
```

Sorties attendues : `Mode: DRY RUN (NullUnifiedStoreWriter)` / `Mode: LIVE (PgUnifiedStoreWriter)`, puis `total / processed / skipped / errors`.

⚠️ **Prérequis submod — fix #993 (`cache-manager` timer unref) :** sans lui, le CLI **complete son travail puis ne se termine jamais** (timer de cleanup jamais `unref()`'d maintient l'event loop ; mesuré po-204 : run fini, 0 CPU, process vivant 28+ min — données OK, process jamais rendu). Sur un build antérieur au fix, wrapper avec `timeout`. Post-fix, validé firsthand : dry-run intégral EXIT=0 en secondes (14 squelettes po-204).

**Durée :** `--limit` borne le nombre d'*upserts*, pas la lecture — le CLI lit **tout** le corpus `.json` avant d'appliquer la limite (lecture directe dans le script). Sur le corpus ai-01 (~7 400 squelettes), lancer en tâche de fond et vérifier le EXIT=0.

- `--dry-run` **supprime** les clés après le chargement du `.env` (fix #2815 — avant, une machine avec `.env` configuré se connectait LIVE malgré le flag).
- Chaque machine ne backfill que **son** corpus disque local (lecture directe de ses `tasks/.skeletons/`, pas via le cache singleton).
- Durée : proportionnelle au corpus (ai-01 = ~7 400 squelettes ; prévoir un run en tâche de fond, pas interactif).

**Validation du delta réel (la source de vérité, le CLI ne compte que ses appels) :**

```sql
SELECT count(*) FROM conversations;   -- doit augmenter du nombre de nouvelles machines/corpus
SELECT count(*) FROM messages;        -- AC1 : doit passer de 0 à > 0
```

---

## 3. Catchup SQL `machine_id` (AC2, moitié base)

Le write-side est normalisé depuis #898 (MERGED) — le rattrapage des lignes legacy peut s'exécuter.

```sql
-- Pre-check : visualiser la divergence
SELECT machine_id, count(*) FROM conversations GROUP BY 1 ORDER BY 2 DESC;
-- Attendu avant : 'myia-ai-01' ET 'MyIA-AI-01' en doublon

-- Rattrapage (idempotent — re-lower() est un no-op)
UPDATE conversations SET machine_id = lower(machine_id);

-- Post-check : plus aucun doublon de casse
SELECT machine_id, count(*) FROM conversations GROUP BY 1 ORDER BY 2 DESC;
```

⚠️ Contrainte d'ordre : exécuter **une fois que toutes les machines écrivaines servent le build post-#898** — sinon des écritures en casse mixte re-créent le doublon après le rattrapage. Aujourd'hui seule ai-01 écrit (build à jour depuis le bump #2960), donc le rattrapage est sûr dès maintenant pour l'existant.

---

## 4. Vérification des AC #2957 (requêtes de clôture)

| AC | Requête | Critère |
|---|---|---|
| 1 — messages peuplé | `SELECT count(*) FROM messages;` | `> 0` et croissant sur les nouvelles conversations |
| 2 — casse résorbée | `SELECT count(*) FROM (SELECT lower(machine_id) FROM conversations GROUP BY 1 HAVING count(*) > 1) d;` — combiné au GROUP BY du §3 | 0 doublon ; 1 ligne par machine réelle |
| 3 — CI purgé + écoulement fermé | `SELECT count(*) FROM conversations WHERE machine_id = 'ci-test-machine';` | `0` (purge #899 faite ; source fermée côté submod) |
| 4 — décompte réel | `SELECT machine_id, harness, count(*) FROM conversations GROUP BY 1, 2 ORDER BY 3 DESC;` | reflète les machines qui écrivent (aujourd'hui ai-01 seule ; le rollout §5 l'étend) |

---

## 5. Rollout flotte (ordre recommandé)

1. **Pilote** : 1 machine executor ajoute les 2 clés → restart host → backfill (§2) → mesure 24 h (`messages` croît, zéro erreur circuit-breaker dans les logs RSM).
2. **Généralisation** : les 4 autres executors, même séquence (échelonnée, pas simultanée — le pool PG par défaut = 5 connexions/machine, `UNIFIED_STORE_POOL_MAX` ajustable).
3. **Re-rattrapage casse** : re-exécuter le §3 après l'arrivée de nouvelles machines (idempotent).
4. **Bascule lecture** : hors scope #2957 — gate séparée (`reader-factory`), à décider après ≥ 1 semaine de parité mesurée.

## 6. Ce qui reste user-gated

- Credentials PG vers les machines (canal RooSync, pas git).
- Restart des hosts MCP (`[INTERACTIVE-ONLY]`, un par machine).
- Décision pilote + GO rollout flotte (reco : po-204, host le plus GDrive-impacté = stress test réaliste).

---

**Historique :** 3 défauts diagnostiqués ai-01 c.73 (#2957) · fixes web1 (#898/#899) + po-2026 (#970) · verdict deploy-ready web1 12/08 · runbook po-204 16/08 — **séquence §2 validée firsthand** (dry-run intégral po-204 : 14 squelettes, 0 erreur, EXIT=0) + fix découverte au passage : submod #993 (timer unref, le CLI ne terminait pas).
