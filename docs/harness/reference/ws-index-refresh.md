# Boucle de rafraîchissement de l'index `ws-*` (#4736 P4)

**Version :** 1.0.0 · **Issues :** #4736 (P3 writer, P4 loop) · **MAJ :** 2026-11-16
**Source :** `ms#1782` (merge `6c43013d`), `src/services/code-index/ws-refresh-loop.ts`, `src/index.ts` (`initializeWsRefreshLoop`).

---

## Ce que la boucle fait

Le lecteur `codebase_search` sert une collection Qdrant `ws-<16 hex>` (nomimée `ws-` + `sha256(fsPath)[0:16]`, chemin VS Code brut). Le seul écrivain historique était l'extension Zoo/Roo, arrêtée sur la flotte depuis le 08/11 (#4737). Cette boucle prend la relève côté **roo-state-manager** : un daemon par siège écrivain qui **poll `git rev-parse HEAD`** et déclenche **une passe du writer P3** (`runWsIndexWriter`, `dryRun:false`) à chaque changement de HEAD.

- **Déclencheur = commit uniquement.** Un arbre sale n'est pas un déclencheur (critère de l'issue : « après un commit ») ; les modifications non commitées passent à la prochaine passe.
- **Périmètre = markdown** (`.md`/`.markdown`, chemins Zoo-éligibles, ≤ 1 Mo/fichier) — la population dont la parité ids/découpage a été prouvée en P2. Les autres types sont des skips avec raison jusqu'à la parité AST (P5).
- **Jamais de création de collection, jamais de reconfiguration** : la passe refuse si la collection manque ou si le modèle d'embedding a changé (garde P3).

## Armement (siège écrivain UNIQUEMENT)

```dotenv
WS_INDEX_REFRESH_ENABLED=true
WS_INDEX_REFRESH_WORKSPACE=C:\dev\roo-extensions          # racine à énumérer sur CE siège
WS_INDEX_REFRESH_HASH_PREFIX=d:\dev\roo-extensions       # préfixe historique hashé par Zoo
WS_INDEX_REFRESH_POLL_SECONDS=120
```

- Les valeurs vivent dans le `.env` du serveur (`mcps/internal/servers/roo-state-manager/.env`, chargé par le wrapper) — **une modification exige le restart de l'arbre wrapper**, pas seulement du processus serveur.
- `WS_INDEX_REFRESH_HASH_PREFIX` **doit** reproduire le nom de la collection servie : vérifier par calcul, `sha256('d:\dev\roo-extensions')[:16] = d2ffdbaa832aed16` → collection `ws-d2ffdbaa832aed16`. Le corpus a été écrit sous ce chemin (pas sous le `C:\dev\...` d'un autre siège).
- **Un seul siège écrivain.** La sentinelle mono-écrivain (P3) refuse une 2ᵉ lane ; le bail hôte (B2, ms#1782) borne une boucle **par machine**. N'armer qu'un siège.

## Observabilité — `roosync_indexing(action:"ws_refresh_status")`

Lecture seule, servie par l'hôte **écrivain**. Rend : `loop_running`, la config résolue, `indexed_head`, `last_run` (statut, fichiers, points, `elapsed_ms`), `consecutive_failures`, `last_error`, `last_refresh_ms` et `announced_delay_s`.

| Assertion | Sens |
|---|---|
| `indexed_head` | commit actuellement servi ; avance **uniquement sur `success`** |
| `partial` / `failed` | n'avancent PAS `indexed_head` ; retry avec backoff exponentiel (plafond 1 h) et rejeu à coût réduit (cache de hash) |
| `announced_delay_s` | SLO **dérivé**, jamais déclaré : `poll_seconds + ceil(passe réussie en s)` |
| `last_refresh_ms` | détection→servi mesuré ; c'est lui qu'on compare au SLO |

## Mesure de référence (16/11/2026, siège web1)

- Armement annoncé sur #4736 avant toute écriture (comment `6911176475`), collection servie `ws-d2ffdbaa832aed16`.
- Passe 1 = catch-up (3 154 fichiers `.md`/`.markdown`, ~30 Mo, `indexed_head=null` → baseline).
- Passe 2 = incrémentale canari (commit markdown via PR) : contrôle SLO `last_refresh_ms` vs `announced_delay_s`, symbole nouveau servi, chunk périmé disparu.
- Le jeton de canari de cette mesure est `WSIDX-P4-CANARY-20261116` (cette phrase n'existe nulle part ailleurs dans le dépôt).

## Pièges connus

- Le nom de collection dépend du **chemin VS Code brut** (casse et séparateurs natifs) : deux sièges avec des chemins différents produisent des hashs différents — mais la résolution lecteur par **content-match** peut servir une collection écrite ailleurs. C'est le préfixe de l'écrivain qui fixe la collection cible, pas le chemin local.
- Le bail hôte est renouvelé à chaque tick : une passe unique plus longue que le seuil de vol (~15 min) ouvre une fenêtre où un second hôte peut voler le bail (note non bloquante de la review ms#1782, correctif séparé).
- Une passe `partial` est normale en cas de coupure d'embedding : la suivante ne ré-embedde que les lots manquants.