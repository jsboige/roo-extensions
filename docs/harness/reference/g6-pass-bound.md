# g6 — la borne d'une passe d'indexation est dérivée du paceur, pas une horloge plate

**Issue :** #4352 (critère g6) · **Instrument :** `scripts/diagnostic/g6-pass-bound.py`
**Décision :** on **ne relève pas** `EMBEDDING_OPS_PER_MINUTE` — on rescope la borne.

---

## Le problème que la borne plate mesurait

Le critère g6 initial disait : « une passe d'indexation ne doit pas dépasser **10 minutes, 5/5** ».
Mesure du 2026-10-28 sur po-2028 : une passe à **655 s** (10 min 55 s) indexant ~1 750 sub-chunks.
Lue telle quelle, la mesure condamne le worker ; lue correctement, elle décrit **le paceur** :

```
655 s ÷ 6 s/requête = 109 requêtes  ≈  109 ops × 16 sub-chunks  ≈  1 750 sub-chunks
```

`EMBEDDING_OPS_PER_MINUTE` vaut **10 par défaut** (`background-services.ts`, `VectorIndexer.ts`) :
une requête d'embedding toutes les 6 s, fenêtre glissante 60 s **par process** (a6). Toute tâche de
plus de ~800 sub-chunks dépasse donc mécaniquement 5 min de passe. Une horloge plate ne mesure pas
la santé du worker, elle mesure le débit qu'on lui a donné.

## La borne

```
allowed_ms = Δrequests × (60 000 / EMBEDDING_OPS_PER_MINUTE) × marge      (marge = 1,5)
```

- `Δrequests` = delta du compteur `requests=` de `[EMB-METRICS]` sur une fenêtre qui **contient**
  la passe (dernière ligne avant le début, première ligne après la fin).
- `marge` absorbe la latence HTTP par requête et les reprises dedup.
- Aux défauts (10 ops/min, marge 1,5) et pour la charge observée : **~981 s**, et la passe de 655 s
  est **dedans**.

### `requests`, pas `called` — correction du 29/10 (revue ai-01)

La première version bornait sur `called`, **et c'était faux**. Les deux compteurs ne mesurent pas la
même chose :

| compteur | unité | où |
| --- | --- | --- |
| `called` | **sub-chunks** — `+= batch.length` | `VectorIndexer.ts:1067` |
| `requests` | **requêtes HTTP** — le paceur réserve **un** slot par requête | `acquireEmbeddingSlot`, `VectorIndexer.ts:216` |

À `EMBEDDING_BATCH_SIZE=16` (défaut), les deux diffèrent d'un **facteur 16** : la borne lue sur
`called` était jusqu'à **16× trop généreuse**, donc **aveugle** — une panne de 655 s y passait pour
saine. `requests=` est cumulatif depuis le boot, comme les autres : on soustrait deux instantanés.
Un `[EMB-METRICS]` **sans** `requests=` signifie que le build qui sert le log précède le compteur :
la borne n'est alors pas calculable et le verdict est **`INSTRUMENT` (exit 2)**, jamais un `PASS`
sur le compteur faible.

Deuxième critère, la **vivacité du tick** : `[EMB-METRICS]` est émis à **chaque** intervalle, y
compris les cycles vides ou bloqués — c'est ce qui en fait l'instrument. Une passe de N intervalles
doit donc montrer ~N de ces lignes ; plus de `--max-missing` (défaut 2) intervalles muets est une
violation, pas un arrondi.

## D'où vient le taux (CHANGES ai-01, 29/10)

Le plafond appartient au **RSM mesuré**, pas au shell de l'opérateur. Précédence :

| rang | source | note |
| --- | --- | --- |
| 1 | `--ops-per-minute N` | explicite, gagne sur tout |
| 2 | `--env-file <rsm>/.env` | le `.env` que le RSM mesuré charge réellement ; illisible ou sans la clé → `INSTRUMENT` (exit 2) — après qu'on a nommé la config mesurée, l'outil ne **devine plus** |
| 3 | env `EMBEDDING_OPS_PER_MINUTE` | environnement de l'**opérateur** — la provenance l'écrit : ce n'est pas forcément la config du process mesuré |
| 4 | défaut 10/min | `background-services.ts` — même mise en garde |

La provenance est **toujours rendue** (`rate: N/min (source: …)`, champ `rate_provenance` en JSON).
Une valeur **non numérique** dans l'env ou l'env-file est un `INSTRUMENT` (exit 2) — la conversion se
faisait à la construction du parser et s'échappait en traceback, donc en **exit 1**, que tout
appelant lit comme `VIOLATION` ; le flag CLI peut maintenant la surcharger.

`EMBEDDING_OPS_PER_MINUTE=0` **désactive** le paceur dans le RSM (`VectorIndexer.ts:217`) : la borne
est **vacante** — aucune allocation ne peut se dériver d'une fenêtre non pacée. Le verdict est
`INSTRUMENT` (« pacing disabled »), jamais le `PASS` à allocation infinie des versions précédentes.

`rate_limited=` (ms#1572) sert de **témoin** : un delta positif dans une fenêtre jugée dit que le
paceur a **effectivement attendu** — il ne dit jamais quelle est la clé configurée.

## Pourquoi ne pas relever le paceur

L'embedder est **partagé par la flotte** ; po-2023 a déjà subi un plafond de connexions et un double
bind sur 8004. Monter la valeur par siège déplace la contention au lieu de la supprimer, et rend la
borne dépendante d'un réglage local non mesuré ailleurs. Le paceur reste donc à 10 : c'est un
**débit décidé**, et le critère s'y conforme.

## Ce que l'instrument ne prétend pas

- Il ne juge pas le **contenu** : une passe qui indexe les mauvais chunks peut être dans la borne.
- Il ne sépare pas des callbacks **qui se recouvrent** : la fenêtre du paceur est par process, donc
  les requêtes du callback suivant sortent du même plafond. `Δrequests` est alors le plafond du temps
  mural — exactement la grandeur que la borne décrit. La question posée est « le worker a-t-il été
  retenu **seulement** par son propre débit », jamais « cette tâche était-elle lente ».
- La borne **n'établit pas** que le paceur est la cause **exclusive** du temps écoulé : les
  consommateurs non pacés partagent le même embedder (les chemins search/query ne passent pas par
  `acquireEmbeddingSlot`), et leur latence peut apparaître dans le temps mural sans jamais
  apparaître dans `Δrequests`. « Dans la borne » veut dire « pas plus lent que ce que le paceur
  permet », pas « le paceur explique chaque milliseconde ».
- Un **reset de compteur** dans la fenêtre (redémarrage de process) rend le delta ininterprétable :
  verdict `INSTRUMENT`, jamais `PASS`. Fail-closed, comme le reste du corpus.
- Une ligne **sans horodatage** n'est pas devinée : si elle est nécessaire pour fermer une fenêtre,
  la passe est `INSTRUMENT`.
- Une ligne **sans `requests=`** (build antérieur au compteur) ne permet pas de calculer la borne :
  `INSTRUMENT`, jamais un `PASS` replié sur `called`.

## Usage

```bash
python scripts/diagnostic/g6-pass-bound.py --log <log RSM contenant [EMB-METRICS] et "pass done">
python scripts/diagnostic/g6-pass-bound.py --log <f> --json
python scripts/diagnostic/g6-pass-bound.py --log <f> --env-file <rsm>/.env
python scripts/diagnostic/g6-pass-bound.py --selftest      # 8 fixtures hors ligne
```

Les deux lignes lues viennent de `background-services.ts` : `[EMB-METRICS] … called=… requests=…
rate_limited=… cache_size=…` (émis chaque tick) et `⏱️ [Qdrant-Worker] pass done: N task(s) in Xms`
(émis seulement quand un batch a réellement traité ≥ 1 tâche — ms#1572, qui rend la borne
**calculable**). `requests=` vient de la PR ms qui accompagne cette correction (#4352 g6).

Le selftest est **branché en CI** (`scripts/testing/python/test_g6_pass_bound.py`, job statique) : la
fixture qui reproduit le défaut du 29/10 (655 s, 400 sub-chunks, 5 requêtes → `VIOLATION`, là où la
borne sur `called` disait `PASS`) et celle du paceur désactivé (taux 0 → `INSTRUMENT`, jamais le
`PASS` à allocation infinie) ne peuvent plus pourrir sans rendre la CI rouge. Le wrapper couvre en
plus, en sous-processus : env non numérique → exit 2, surcharge CLI de l'environnement cassé,
précédence `--env-file` + provenance rendue, env-file sans la clé → exit 2.

Exit codes : `0` toutes les passes dans la borne et cadence préservée · `1` au moins une violation
(dépassement **ou** tick affamé) · `2` erreur d'instrument (log illisible, fenêtre non fermée,
reset de compteur, métriques sans `requests=`, entrée malformée, **source de taux non numérique,
env-file illisible/sans clé, paceur désactivé**) — jamais un « propre » par silence :
un log sans `pass done` est un exit 2.

## Le critère, en une ligne

> Une passe est saine si sa durée tient dans `Δrequests × 60 000 / EMBEDDING_OPS_PER_MINUTE × 1,5`
> **et** si `[EMB-METRICS]` continue de tomber pendant qu'elle tourne.

Le critère « 10 min plates, 5/5 » peut être retiré : il condamnait un worker qui faisait exactement
ce qu'on lui avait demandé.
