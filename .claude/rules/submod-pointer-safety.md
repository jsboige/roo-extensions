# Submodule Pointer Safety

**Version:** 2.4.0 (branches worker #4098 — le garde s'étend du commit au PUSH)
**Issue :** #2089 follow-up (incident 2026-05-11, `67514ec1`) ; garde dépôt #3454 (2026-09-05) ; SHA 40 car. #3056 ; branches worker #4098 (incident po-2026 03/10)

---

## Règle Absolue

**Avant tout commit modifiant un pointeur submodule** (`mcps/internal`,
`mcps/external/win-cli/server`, `roo-code`) : **asserter que l'instrument vise le bon dépôt,
puis `git fetch` le submodule, puis vérifier que la SHA cible est atteignable depuis son
upstream** (`merge-base --is-ancestor`). Non atteignable → **STOP** : pousser d'abord le commit
submod sur son upstream, ou `reset --hard origin/main`. Un pointeur orphelin casse `git pull`
**sur toute la flotte** (`upload-pack: not our ref`). Le worker schedulé et la CI ne couvrent pas
les sessions interactives OWNER — c'est le trou que cette règle ferme.

## Branches worker — l'invariant s'étend au PUSH (#4098)

Un gitlink orphelin sur une branche **worker** (jamais mergée sur main) casse tout autant
`git fetch` flotte-wide que sur main — mesuré po-2026 03/10 (`upload-pack: not our ref` ×4).
**Avant `git push origin <branche>` du parent** : chaque gitlink modifié depuis `origin/main`
doit être atteignable depuis une branche remote du submodule. Organe :

```bash
python scripts/git/check_gitlinks_pushed.py <branche>   # exit 1 = ORPHAN, STOP
```

Le delta seul est vérifié (gitlink inchangé depuis la base = déjà atteignable) ; le dépôt
submodule est résolu via `--git-common-dir`, jamais `git -C <path>` (garde 0). Rémediation
identique : pousser le submodule d'abord (branche + PR), le parent ensuite.

## Garde 0 — le BON dépôt, avant toute lecture `git -C` (#3454)

Un submodule non peuplé (worktree neuf) est un répertoire **vide** : `git -C <submod> …` remonte
alors au dépôt **parent** et répond en son nom — les autres gardes vérifient une propriété réelle
du **mauvais** dépôt. Le garde teste le **mécanisme**, avant toute lecture :

```bash
[ "$(git -C <submod> rev-parse --show-toplevel)" != "$(git rev-parse --show-toplevel)" ] \
  || { echo "git -C a remonté au PARENT (submodule non peuplé) — STOP"; exit 1; }
```

**Rattrapage de second ordre :** lire **ce que la SHA porte** (`git -C <submod> log -1
--format=%s "$SHA"`) — un titre de PR du parent là où on attend un commit submod signe le mauvais
dépôt, même toutes gardes vertes. C'est ce contrôle qui a rattrapé #3454, aucune des trois gardes.

## SHA complète à 40 caractères, jamais une abréviation (#3056)

`git update-index --cacheinfo` ne valide rien et exige 40 caractères ; les autres gardes acceptent
une abréviation — on peut « vérifier » `45388458` pendant que le gitlink stocke une autre SHA aux
8 premiers caractères près. **Ne jamais recopier ni reconstituer une SHA** : la lire en entier
dans une variable, comparer la valeur **écrite** à la valeur **voulue** sur les 40 caractères.
**Bloc bash complet :** [`submod-pointer-safety-procedure.md`](../../docs/harness/reference/submod-pointer-safety-procedure.md)

## Les trois pièges

- `git submodule update --init --recursive` puis `git add` → checkout arbitraire = pointeur arbitraire.
- « Résoudre le conflit submod » par `checkout --theirs` / `checkout HEAD --` sans regarder la cible.
- Bumper le pointeur parent **avant** merge de la PR submod (voir [`pr-mandatory.md`](pr-mandatory.md)).

---

**Procédure complète (blocs bash, boucle multi-submodules), incident fondateur, cas légitimes,
post-mortem :** [`docs/harness/reference/submod-pointer-safety-procedure.md`](../../docs/harness/reference/submod-pointer-safety-procedure.md)
