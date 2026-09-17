# Quota GraphQL : l'instrument REST enseigne l'inverse de l'état

**Créé le** 2026-09-13 — issue #3623 (ouverte par Hermes, `myia-po-2026:hermes-agent`).

---

## Le fait

Sur le même token, à la même minute, **deux instruments GitHub rendent deux réponses
contradictoires** sur le quota GraphQL :

| Instrument | Ce qu'il rend |
|---|---|
| `GET /rate_limit` → `.resources.graphql` (**REST**) | `limit=5000, remaining=5000, used=0` |
| `POST /graphql { rateLimit { … } }` (**GraphQL**) | l'état réel, ex. `remaining=4619, used=381` |

Quand le compte est épuisé, le premier continue d'annoncer **5000/5000** pendant que le second
rend **0/5000**. Le REST ne décrit donc pas le budget qui sert réellement les requêtes : il décrit
un budget **frais**. Un garde-fou qui n'interroge que le REST se croit autorisé alors que toute
lecture GraphQL va échouer.

## Reproduction firsthand (`myia-po-2023`, 2026-09-13 ~12:47Z)

Compte actif : `jsboige` (`gh api user --jq .login`), token OAuth de `hosts.yml`.

```
GET /rate_limit .resources.graphql  → {"limit":5000,"remaining":5000,"used":0}
POST /graphql { rateLimit }         → {"remaining":4619,"used":381,"resetAt":"2026-09-13T13:32:44Z"}
```

Même divergence que celle rapportée par po-2026, sur une **seconde machine** et un **token d'un
autre type** (OAuth `gho_` ici, PAT `github_pat_` là-bas).

### Le mécanisme, mesuré

Le champ `reset` du REST **avance avec l'horloge murale** — ce n'est pas une fenêtre horaire
ancrée :

```
now=1789303684 reset=1789307284 delta=3600
now=1789303687 reset=1789307288 delta=3601
now=1789303691 reset=1789307291 delta=3600
```

`reset` vaut `now + 3600` à chaque appel. La vraie fenêtre GraphQL, elle, est **ancrée**
(`resetAt=2026-09-13T13:32:44Z`, stable d'un appel à l'autre). **Les deux instruments ne décrivent
pas la même fenêtre** : le REST rend l'état d'un bucket fraîchement émis — donc `used=0` par
construction — là où le GraphQL rend le bucket réellement consommé.

**Ce qui reste NON ÉTABLI** (comme dans #3623) : la cause côté GitHub. Bucket « app/installation »
distinct du bucket « utilisateur » ? Comportement propre aux tokens de ce compte ? Le constat
empirique tient sans trancher le mécanisme, et il suffit à la conduite à tenir.

### Corroboration (RAPPORTÉ, po-2026)

Hermes a mesuré sur les 4 entrées de `/opt/data/.env` : le REST rend `5000/0` pour **les trois**
tokens testés, y compris `GH_TOKEN_JSBOIGE` dont le GraphQL était à `0/5000` (épuisé). Il a aussi
relevé **30 occurrences** de `rate limit already exceeded` dans ses logs de crons
(`hermes-pr-review`, `hermes-inbox-poll`), toutes sur le même id `3159389`, étalées du 02/09 au
13/09. Chaque occurrence est une lecture qui n'a pas eu lieu. *(Non revérifié depuis ce siège.)*

## Conséquence opérationnelle

Ces chemins `gh` sont adossés à **GraphQL** et tombent d'un bloc dès que la fenêtre est épuisée :

```
gh pr view N          → GraphQL: API rate limit already exceeded for user ID 3159389
gh issue view N       → idem
gh search issues|prs  → idem
```

Le diagnostic naturel — « quota plein, réessayer » — est **faux** : l'instrument qui prétend le
contraire (REST `5000/5000`) a tort. Le message d'erreur ne nomme **que l'id numérique**, jamais
le token : un siège qui lit `gh api user` d'une part et l'erreur d'autre part ne voit pas qu'il
parle du **même** compte épuisé.

## Contournements mesurés

1. **REST plutôt que GraphQL pour la lecture** — budget **séparé**, quasi intact :

   ```bash
   gh api repos/O/R/issues/N             # au lieu de gh issue view N
   gh api repos/O/R/issues/N/comments
   gh api repos/O/R/pulls/N
   gh api 'repos/O/R/pulls?state=open'
   ```

   Vérifié depuis po-2023 : `gh api repos/jsboige/roo-extensions/pulls/3618` et
   `.../issues/3623` traversent sans toucher au budget GraphQL.

2. **`GH_TOKEN` explicite** — ne pas dépendre du compte actif de `hosts.yml` (défaut = `jsboige`,
   le compte partagé le plus sollicité de la flotte) :

   ```bash
   GH_TOKEN="$GH_TOKEN_CLUSTERMANAGER" gh pr view N   # un token non épuisé rétablit GraphQL
   ```

3. **Ne jamais conclure « rate limit / à réessayer » sur un échec GraphQL** sans vérifier **le
   compte réellement utilisé**. L'erreur ne nomme que l'id.

## Routage de token — recommandation

**Tout harnais/cron qui lit GitHub devrait poser `GH_TOKEN` explicitement**, pas hériter du
compte actif de `hosts.yml`. La garde d'identité in-command (`.claude/rules/pr-mandatory.md`,
[`gh-identity-concurrency.md`](gh-identity-concurrency.md)) répond à un autre problème — la
concurrence entre processus ; elle ne protège pas du quota d'un compte épuisé. Poser le token
explicite ferme les deux : identité déterministe **et** budget connu.

Cette recommandation vise les crons Hermes de po-2026 (hors dépôt) **et les harnais schedulés de
ce dépôt** — l'audit ci-dessous montre que ces derniers partagent exactement la même exposition.

## Portée in-repo — audit des harnais schedulés (2026-09-17, po-2023)

Les livraisons initiales (#3624, #3667) lisaient la demande de routage comme visant les seuls
crons Hermes. **Audit du 17/09** (VERIFIÉ firsthand : grep `gh ` croisé avec `GH_TOKEN` /
`--user` / `auth switch` sur `scripts/scheduling/`, `scripts/scheduler/`,
`scripts/dashboard-scheduler/`, `scripts/github/`) :

| Script | appels `gh` | chemins notables |
|---|---|---|
| `scheduling/start-claude-worker.ps1` | 24 | `gh issue view/list`, `gh pr list`, **`gh api graphql` direct** (l.606, champs Project #67) |
| `scheduling/start-claude-coordinator.ps1` | 9 | même famille |
| `scheduling/start-vibe-worker.ps1` | 8 | même famille |
| `github/review-bot.ps1` | 5 | `gh pr list/view/diff/review` |
| `scheduling/pick_idle_grain.py` | 2 vivants | `gh issue list`, `gh pr list` (l.83, l.95) |
| `dashboard-scheduler/dashboard-listener.ps1` | 1 | `gh issue view` (l.628 — le listener de wake) |
| `scheduler/workflow-meta-analyst.ps1` | 3 | — |
| `scheduling/start-meta-audit.ps1` | 2 | — |

**Aucun de ces 8 scripts ne référence `GH_TOKEN`, `gh auth switch` ni `--user`** : tous héritent
du compte actif de `hosts.yml` — compte qui **drifte au restart** (constaté sur po-2023) et dont
la valeur par défaut est `jsboige`, le compte partagé dont l'épuisement GraphQL est le fait
générateur de #3623. La dégradation est propre (le worker rend `{}` sur erreur GraphQL,
l.608-611) mais silencieuse : chaque lecture GraphQL perdue est un pickup, un champ Project ou un
réveil qui n'a pas eu lieu.

### Pourquoi le fix n'est pas un export global de `GH_TOKEN`

`GH_TOKEN` prime sur `hosts.yml` **pour tout l'arbre de processus**. Un harnais qui poserait
`$env:GH_TOKEN` en tête de script puis spawnerait ses sessions Claude neutraliserait la garde
d'identité in-command (#3032, `gh auth switch --user X && assert`) chez **tous les enfants** :
le switch devient no-op, l'assert lit le token épinglé. Le pinçage doit être **scopé** — env
posé par appel, ou retiré avant chaque spawn. C'est un chantier dédié (multi-sites, par machine),
pas un export en tête de script.

En attendant : lectures en REST (`gh api repos/O/R/...`) là où GraphQL n'apporte rien — c'est le
contournement §1, déjà applicable à tout siège.

## Ce qu'il ne faut PAS refaire

La famille « rate limit GraphQL » est connue (#1288, fermé sur le circuit breaker GraphQL). Ne pas
re-diagnostiquer l'échec à chaque occurrence : le **seul** point qui n'était tracké nulle part est
l'**instrument de mesure trompeur** — c'est #3623, et ce document.

---

**Voir aussi :** [`github-cli.md`](github-cli.md) (commandes, scopes, Project #67) ·
[`gh-identity-concurrency.md`](gh-identity-concurrency.md) (concurrence multi-processus).

---

## Datapoints ultérieurs (2026-09-13, après merge de #3624)

Les sections qui suivent ne sont **pas** dans la mesure d'origine : elles élargissent le constat
au-delà du seul `resources.graphql` et ferment deux hypothèses résiduelles.

### `/rate_limit` ment pour **toutes** les ressources, pas seulement `graphql` (ai-01)

Mesure ai-01 ~13:23Z, compte `jsboige`, dans la même session où des appels REST venaient d'être
comptabilisés sur le budget `core` (`/repos/O/R/pulls/N/reviews`, `/issues/N/comments`,
`/pulls/3618/reviews`) :

| Instrument | Résultat |
|---|---|
| REST `/rate_limit` → `.resources.core` | `remaining=5000, used=0` |
| REST `/rate_limit` → `.resources.graphql` | `remaining=5000, used=0` |
| GraphQL `POST { rateLimit }` | `remaining=3690, used=1310, resetAt=2026-09-13T13:32:44Z` |

**Le défaut n'est pas propre à `graphql`** : `core` présente exactement la même `used=0` alors
que la session enchaînait des appels dessus. `GET /rate_limit` rend un bucket frais pour
**l'ensemble** des ressources. L'hypothèse « bug isolé au reporting GraphQL » est exclue.

### Conséquence pour le repli REST — il n'a plus d'indicateur de charge

Le repli REST reste valide en traversée (les routes traversent), mais **sa justification écrite —
« budget REST séparé, 5000/h, quasi intact »** — se lit sur `/rate_limit`, c'est-à-dire sur
l'instrument que cette issue déclare non fiable. La mesure `core: 5000/0` ci-dessus en est la
démonstration directe : je sais avoir consommé, l'instrument dit non.

Conséquence opérationnelle :

> Un harnais qui bascule sur REST puis surveille `/rate_limit` pour savoir quand ralentir **ne verra
> jamais approcher la limite**. Le repli n'a aucun indicateur de charge — il faut soit le doser
> à l'aveugle, soit compter les appels soi-même côté client.

### La fenêtre GraphQL est **par-compte et stable** — corroboration à 36 min d'écart (ai-01)

Deux observateurs, deux sièges, **même `resetAt`** :

- po-2023 ~12:47Z : `resetAt=13:32:44Z`, `used=381`
- ai-01    ~13:23Z : `resetAt=13:32:44Z`, `used=1310`

36 min d'écart, `used` qui a crû de 381 → 1310 (929 requêtes), `resetAt` inchangé. La fenêtre
GraphQL est **par-compte et stable**, ce qui n'était jusqu'ici établi que depuis un seul siège.

### Le REST ne se recale pas à la frontière de fenêtre (Hermes, po-2026)

Mesure **à cheval** sur la frontière mesurée de `jsboige` (13:32:44Z → 14:32:47Z). Deux lectures,
T0 = 4 min avant la frontière, T1 = 20 s après.

| | REST `GET /rate_limit` → `.resources.graphql` | POST `{ rateLimit }` |
|---|---|---|
| `jsboige` T0 | `used=0, remaining=5000, reset=1789309729` | `used=1710 → 1716, resetAt=13:32:44Z` |
| `jsboige` T1 (**après** frontière) | `used=0, remaining=5000, reset=1789309986` | `used=18, remaining=4982, resetAt=14:32:47Z` |

Le chiffre qui tranche est le `reset` du REST : **1789309729 → 1789309986 = +257 s**, exactement
le temps mural écoulé entre les deux lectures. Le POST, lui, a réellement changé de fenêtre.

**L'hypothèse résiduelle — « le miroir REST est dégénéré mais se réaligne au changement de
fenêtre, donc il décrit la bonne fenêtre en régime établi » — tombe.** Le `reset` du REST n'est
pas le miroir décalé d'une fenêtre : il est **découplé** de celle qu'applique l'endpoint GraphQL.
Il n'y a pas de recalage, ni au coup par coup, ni à la frontière.

### Piège Windows — réécriture MSYS du `/` initial (ai-01)

Sous Git Bash, **`gh api /rate_limit`** (avec barre oblique initiale) est réécrit par MSYS en
`C:/Program Files/Git/rate_limit` et échoue avec :

```
invalid API endpoint: … Your shell might be rewriting URL paths as filesystem paths
```

Un lecteur pressé en conclut que l'endpoint a disparu. Forme portable, à utiliser sur tout
siège Windows : **`gh api rate_limit`**, sans slash initial. Idem pour tout chemin `gh api` que
MSYS pourrait tenter de résoudre localement.

---

**Sources des datapoints :**
- ai-01 : commentaires #3623 de jsboige (2026-09-13 ~13:27Z) — reproduction depuis un 3ᵉ siège,
  élargissement à `core`, MSYS pitfall.
- Hermes po-2026 : commentaires #3623 de clusterManager-Myia (2026-09-13 ~13:34Z) — mesure à
  cheval sur la frontière, élimination de l'hypothèse « recalage à la frontière ».
