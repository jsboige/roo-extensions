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

Cette recommandation est **documentaire** : elle vise des crons hors de ce dépôt (po-2026) et ne
se réécrit pas d'ici.

## Ce qu'il ne faut PAS refaire

La famille « rate limit GraphQL » est connue (#1288, fermé sur le circuit breaker GraphQL). Ne pas
re-diagnostiquer l'échec à chaque occurrence : le **seul** point qui n'était tracké nulle part est
l'**instrument de mesure trompeur** — c'est #3623, et ce document.

---

**Voir aussi :** [`github-cli.md`](github-cli.md) (commandes, scopes, Project #67) ·
[`gh-identity-concurrency.md`](gh-identity-concurrency.md) (concurrence multi-processus).
