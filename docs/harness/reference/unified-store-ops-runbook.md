# Unified Store (Postgres) — Runbook Ops

**Issues :** #2957 (AC restants) · Epic #2191 · déploiement prod #2553 (clos) · #3151 Phase D (§7)
**MAJ :** 2026-08-23 (§7 Phase D-1 : écriture canal PG-primaire + rétention, po-2023)
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

## 7. Phase D (#3151) — retrait GDrive du canal messagerie

**État au 23/08 :** Phases A/A.2 (dual-write), B (lecture messages), C (dashboards) mergées et
déployables par flags. La Phase D-1 ci-dessous (écriture canal PG-primaire + rétention) est livrée
en [PR submod jsboige-mcp-servers#1030](https://github.com/jsboige/jsboige-mcp-servers/pull/1030),
par défaut **OFF** — aucun comportement ne change tant que les flags ne sont pas posés.

### 7.1 Ce que fait `UNIFIED_STORE_CHANNEL_PG_PRIMARY=1`

- **Écriture PG-primaire** : `send`/`reply`/`amend`/`mark_read`/`archive`/`destroy` persiste dans
  `roosync_messages` et **n'écrit plus les fichiers GDrive** (`messages/inbox|sent`). GDrive devient
  archive legacy **en lecture seule** — rien n'y est jamais supprimé (preuve de préservation).
- **Le flag implique la lecture PG** (`UNIFIED_STORE_CHANNEL_READ_PG`) : une machine qui ne write
  plus GDrive ne doit pas non plus y lire en primaire, sous peine d'être aveugle aux envois
  PG-primary des autres.
- **Dégradation gracieuse** : panne PG → fallback sur le chemin fichier d'origine (l'envoi n'est
  jamais perdu). La divergence résultante se re-synchronise par le backfill canal
  (`scripts/backfill-roosync-channel.mjs`).

### 7.2 Séquence d'activation d'une machine (canal)

1. `.env` : `UNIFIED_STORE_DUAL_WRITE=1` + `UNIFIED_STORE_PG_URL=…` (runbook §1), backfill canal
   fait, lecture PG validée ≥ 1 semaine (`UNIFIED_STORE_CHANNEL_READ_PG=1`).
2. Ajouter `UNIFIED_STORE_CHANNEL_PG_PRIMARY=1` → restart host MCP (`[INTERACTIVE-ONLY]`).
3. Vérifier : un `roosync_messages send` de test → row dans PG (`SELECT count(*) FROM
   roosync_messages WHERE id = '<id>'`), **aucun** nouveau fichier dans `messages/inbox/`.
4. Pilote 1 machine ≥ 48 h, puis généralisation échelonnée (§5).

**Prérequis flotte** : activer PG_PRIMARY sur UNE machine d'écriture n'est sûr que si toutes les
machines destinataires lisent déjà PG (`READ_PG`). Sinon les messages PG-only sont invisibles aux
laggards — under-show, le pire défaut du canal. Activer la lecture partout AVANT la première
écriture PG-primaire.

### 7.3 Rétention PG (`UNIFIED_STORE_CHANNEL_RETENTION_DAYS`)

- L'action `roosync_messages cleanup` purge les rows `status='archived'` plus vieilles que N jours
  **avec leurs attachments bytea**, en une transaction (`purgeArchivedRooSyncMessages`).
- **0 / absent = OFF** (aucune suppression par défaut — règle no-deletion). Valeur conseillée : 180.
- GDrive n'est **jamais** touché par la rétention (archive legacy).
- Compteur observable dans la sortie du cleanup (« Rétention PG : N message(s) purgé(s) »).

### 7.4 Backup du canal (aligné #3134)

Le backup PG couvre tout le store — pas de procédure séparée pour le canal :

```powershell
# ai-01 (héberge pg.myia.io) — cron hebdo conseillé, rétention 4 dumps
pg_dump --host=pg.myia.io --port=5432 --username=unified_store \
  --format=custom --file="unified_store-$(Get-Date -Format yyyyMMdd).dump" unified_store
```

Vérification mensuelle : restaurer le dernier dump sur une DB jetable et compter
`roosync_messages` / `roosync_dashboards` (proche des counts prod = backup sain).

### 7.5 Reste de la Phase D (non couvert par D-1)

- **Dashboards write-side** : gate `UNIFIED_STORE_DASHBOARD_PG_PRIMARY` NON livrée — les listeners
  wake (`poll-dashboard.ps1`, 6 machines) lisent les fichiers `workspace-*.md` sur G:. Arrêter
  l'écriture fichier avant leur bascule = casser le wake-routing flotte. Séquence : CLI lecture
  journal PG → patch listener → pilote → seulement alors gate d'écriture.
- **Attachments read/write PG-primaire** : les blobs restent écrits GDrive + miroir bytea
  (Phase A). Le destroy purge bien les deux couches.
- **Critères d'acceptation finaux** (#3151) : mesure 2 cycles complets × 6 machines après
  généralisation — coordination ai-01.

---

**Historique :** 3 défauts diagnostiqués ai-01 c.73 (#2957) · fixes web1 (#898/#899) + po-2026 (#970) · verdict deploy-ready web1 12/08 · runbook po-204 16/08 — **séquence §2 validée firsthand** (dry-run intégral po-204 : 14 squelettes, 0 erreur, EXIT=0) + fix découverte au passage : submod #993 (timer unref, le CLI ne terminait pas).
