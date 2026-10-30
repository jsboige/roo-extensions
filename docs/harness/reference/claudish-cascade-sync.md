# Claudish cascade synchronisation — RSM instrument (#4427)

**Outil visé :** `roosync_claudish_cascade` — **STATUT : PROPOSÉ, NON CÂBLÉ** (voir « Où en est-on »)
**Issue :** #4427 (côté roo-extensions) · volet réconciliation immédiate et politique : `jsboige/claudish#764`
**Code réel :** `mcps/internal/servers/roo-state-manager/src/services/cascade-payload.ts` (CONTRAT) + `mcps/internal/servers/roo-state-manager/src/services/cascade-sync.ts` (INSTRUMENT)

> Cette fiche est la **spec** de l'outil. Elle décrit un outil qui **n'existe pas encore** comme
> outil MCP : le contrat et l'instrument sont livrés, le **câblage MCP** ne l'est pas. Aucun
> inventaire d'outils ne doit donc être incrémenté tant que l'outil n'est pas câblé (le compte
> reste à **17**).

## Où en est-on (30/10)

| Volet | État | Où |
|---|---|---|
| **PR1** — contrat (schéma, parseur du canon, validateurs) | **MERGÉE** (`df0a6e3e`) | `cascade-payload.ts` |
| **PR2** — instrument (fraîcheur, comparaison de VALEURS, plan borné, sauvegarde) | **ouverte**, en re-review | `cascade-sync.ts` |
| **PR3a** — les 4 refus de l'APPROVE PR1 (RESET, reset illisible, DIRECTION écrasée, exclusion intégrale) | **ouverte** | `cascade-payload.ts` |
| **PR3** — câblage de l'outil `roosync_claudish_cascade` + canal de collecte du hub | **non commencé** | — |

Le code cité ci-dessous existe donc déjà pour le contrat et l'instrument ; les noms de fichiers
historiques (`ClaudishCascadeService.ts`, `src/tools/roosync/cascade.ts`) **n'existent pas**.

---

## Le partage de propriété (à respecter)

| Qui | Ce qu'il possède |
|---|---|
| **Lane Claudish** | La politique de cascade, la réconciliation immédiate, la vérification opérationnelle par consommateur, le contrat de non-régression |
| **Chaque siège** | L'application de SON `.env` |
| **roo-extensions (cet outil)** | L'instrument : schéma, collecte, publication, comparaison, apply, confirmation, tests |

L'outil ne décide **aucune** politique. Il ne modifie **jamais** l'infrastructure Claudish — le déploiement (recreate de conteneur) reste chez l'exécuteur côté propriétaire.

---

## Trois états, jamais fusionnés

| État | Source | Ce qu'il prouve |
|---|---|---|
| **INTENDED** | canon publié (`latest.json` du magasin partagé) | ce que la flotte devrait porter |
| **WRITTEN** | `.env` sur disque | ce que compose interprétera **au prochain** create |
| **RUNNING** | `/proc/1/environ` du conteneur (repli : `docker inspect .Config.Env`) | l'env que le conteneur a **reçu** |
| **CONSUMER** | `docker logs` → `[Failover] configured=N armed=[…] auto=…` | ce que le parseur a **accepté** |

**RUNNING et CONSUMER ne sont pas la même question.** L'env prouve ce qui a été *passé* ;
la ligne du parseur prouve ce qu'il en a *gardé*. Une valeur qu'il dégrade en silence
(direction hors vocabulaire, entrée malformée) est visible **là et nulle part ailleurs** :
`configured` est comparé au nombre de rôles du payload, et un `configured` inférieur vaut
`drift` — pas `aligned`. **Une lecture de conteneur seule n'est jamais une confirmation** :
consommateur muet ⇒ `no-snapshot` ⇒ verdict `non-covered`.

Mesuré sur ai-01 le 29/10 : le sidecar émet cette ligne **~1,6 s après le démarrage** — la
fenêtre de confirmation suit donc un recreate de très près. En dehors de cette fenêtre
transitoire, une absence de ligne signifie un build qui ne la produit pas.

Un `.env` correct avec un conteneur périmé vaut **`needs-recreate`**, pas « drift ». C'est la distinction qui justifie l'outil : docker compose **fige** `environment:` au `create`, donc écrire le fichier ne déploie rien.

Sources de vérité live, toutes gratuites :

```bash
docker exec <ct> cat /proc/1/environ | tr '\0' '\n' | grep CLAUDISH_FAILOVER   # RUNNING (reçu)
docker inspect --format '{{.State.StartedAt}}' <ct>                            # péremption
docker logs --tail 400 <ct> | grep '\[Failover\] configured='                  # CONSUMER (accepté)
curl -s http://127.0.0.1:3002/health   # gratuit — /v1/messages est PAYANT, ne jamais sonder
```

---

## Actions

| Action | Effet |
|---|---|
| `collect` | Lit le RUNNING (ou le `.env`) et **projette** sur les clés allow-listées. Rejette si le conteneur est illisible plutôt que de rendre un payload vide. |
| `publish` | Écrit un canon **versionné et immuable** (hash + provenance) dans `<store>/claudish-cascade/`. Refuse un payload invalide. Même version + contenu différent = refus. |
| `compare` | INTENDED vs WRITTEN/RUNNING, **valeurs concrètes**, avec états de couverture. |
| `apply` | Écrit le canon dans le `.env` **local** : `dry_run`, `backup`, rollback, `exempted_keys`. Ne touche jamais le conteneur. |
| `confirm` | Relecture **live** du conteneur. Un hash revendiqué ne compte **jamais**. |
| `status` | Rapport des trois états sur la machine locale. |
| `list` | Versions publiées. |

Cycle normal : `publish` (hub) → `compare` (siège) → `apply --dry_run` → `apply` → *recreate par l'exécuteur propriétaire* → `confirm`.

**Instrument déjà livré** : l'instrument de PR2 couvre le cœur de `compare` et de `apply` — évaluation de fraîcheur (`assessCascadeSource`), comparaison de valeurs (`compareCascadeEnv`), plan borné (`planCascadeApply`), sauvegarde/rétablissement (`CascadeBackupStore`). Il ne lit **ni** le conteneur **ni** le hub : la lecture live et l'écriture restent à câbler.

---

## Couverture — « non couvert » n'est pas « conforme »

| État | Sens |
|---|---|
| `covered` | comparaison exploitable |
| `no-snapshot` | rien à lire (pas de fichier / conteneur absent) |
| `empty` | lisible mais aucune clé de cascade |
| `stale` | **mesuré** : conteneur démarré avant la publication du canon (ou mtime du `.env` antérieur) — il ne peut pas le porter |
| `invalid` | payload ou valeurs non interprétables (incohérence positionnelle) |
| `unreadable` | docker refuse la lecture (daemon, CLI, nom) |

Seul un état `covered` **et** aligné sur **toutes** les surfaces observées donne `aligned`.

L'instrument de PR2 distingue en outre `missing` (lecture impossible) et `empty` (lecture vide) de
`invalid` (canon illisible) et de `stale` (lecture datée trop ancienne). **La fraîcheur est
fail-closed** : un horodatage illisible ou une date dans le futur rendent la lecture `invalid` —
elle n'est jamais lue « fraîche par défaut ».

---

## Ce qui n'est JAMAIS lu, publié ni écrit

`CLAUDISH_PROXY_KEY`, `CLAUDISH_PROXY_KEY_PREVIOUS`, `CLAUDISH_RELAY_UPSTREAM`, `CLAUDISH_HOST_PORT`, `CLAUDISH_CONTAINER_NAME`, `CLAUDISH_CAPTURE_HOST_DIR`, `CLAUDISH_CONFIG_DIR`, toute variable `ANTHROPIC_*`, `~/.claudish/config.json`.

Un `.env` complet n'est jamais publié : l'instrument ne lit que les clés allow-listées
(`parseCascadeEnv` puis `extractCascadeEnv`), les clés préservées sont **rapportées par leur nom
et un motif** (`findPreservedKeys`), jamais par leur valeur, et le sérialisé du plan est vérifié
sans secret. `apply` réécrit les clés allow-listées **ligne à ligne** et préserve tout le reste
**octet pour octet** (CRLF inclus).

---

## Validation — RSM refuse ce que Claudish réinterprète en silence

Les règles sont dérivées du parseur réel (`packages/cli/src/fork/failover.ts`) :

| Cas | Claudish | RSM |
|---|---|---|
| LABEL/DIRECTION/NOTE de longueur ≠ steps | prévient et **complète** | **refuse avant écriture** |
| RESET de longueur ≠ steps | positionnel (`>` vide = pas de reset) | **refuse** ; les vides restent significatifs |
| direction hors `improved\|degraded\|lateral` | **dégrade** en `degraded` | le parseur dégrade, le **validateur refuse** le payload |
| date de reset illisible | prévient et ignore | **refuse** |
| délégation `role:` cyclique | **refuse le rôle** au chargement | **refuse le payload** |
| `ROLE_MODELS` malformé | ignore la pièce | **refuse** |
| `STEP_EXCLUDE` sans étape correspondante | ignore | **refuse** |
| exclusion couvrant **toutes** les étapes d'un rôle | supprime l'exclusion | **refuse** |
| DIRECTION en ligne **et** bloc DIRECTION | le bloc écrase | **refuse** (la seconde valeur écraserait la première) |

**Piège de sérialisation** : `STEP_EXCLUDE` se découpe sur `,` **d'abord**, puis sur `/[\s,]+/`. Les machines d'une entrée sont donc jointes par une **espace** (`target:m1 m2`) — une jointure par virgule produirait une seconde entrée sans `:` que le runtime ignore, perdant silencieusement toutes les machines sauf la première.

---

## Format du payload (forme RÉELLE)

Le payload livré par `cascade-payload.ts` est **versionné et typé** — la forme ci-dessous est
celle du code, pas une esquisse :

```json
{
  "schemaVersion": 1,
  "provenance": { "source": "hub-live", "readAt": "2026-10-29T19:35:00.000Z" },
  "roles": {
    "SONNET": {
      "steps": [
        { "ref": "glm-5.3@zai", "label": "glm", "direction": "degraded" },
        { "ref": "kimi-k3@moonshot", "label": "kimi", "direction": "lateral" }
      ]
    }
  },
  "roleModels": { "glm-5.3": "sonnet" },
  "stepExclude": [{ "stepTarget": "glm-5.3@zai", "machines": ["myia-po-2025"] }],
  "active": ["sonnet@myia-po-2025"],
  "auto": 1,
  "qwenThinking": "budget:4096"
}
```

Points à retenir :

- les **rôles** sont indexés par leur nom canonique **majuscule** (`SONNET`, `OPUS`, `FABLE`, `HAIKU`) ;
- une **`provenance` non `hub-live`** ou sans `readAt` est **refusée** — un snapshot non daté est invérifiable ;
- le `snapshotHash` **revendiqué** ne confirme rien : le validateur le **recalcule** ;
- la provenance ne participe pas au hash canonique : même canon collecté deux fois = même identité.

---

## Magasin

```
<ROOSYNC_SHARED_PATH>/claudish-cascade/latest.json
<ROOSYNC_SHARED_PATH>/claudish-cascade/versions/v{version}-{ts}/payload.json
<ROOSYNC_SHARED_PATH>/claudish-cascade/versions/v{version}-{ts}/manifest.json
```

Sous-arbre **propre**, hors `configs/` : le payload est une politique machine-indépendante, pas un snapshot de config par machine — le mélanger ferait écraser le canon par un `roosync_config collect`. Rétention : 5 versions. Création de répertoire uniquement via `ensureStoreSubdir` (garde structurelle #3459).

---

## Ce que l'outil ne fait PAS

- **Aucun restart docker**, aucune recréation de conteneur, aucune action flotte automatique. `apply` le dit explicitement dans son champ `deployment`.
- **Aucune publication de `.env` ou `config.json` complet.**
- **Aucune décision de politique** : ajouter une étape à la cascade est un acte de la lane Claudish, publié comme nouvelle version.
- **Aucune écriture sur un siège** : l'APPLY est un geste du propriétaire du siège ; l'instrument produit le plan, pas l'écriture.
