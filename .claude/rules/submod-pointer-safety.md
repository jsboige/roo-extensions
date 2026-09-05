# Submodule Pointer Safety

**Version:** 2.2.0 (+ garde d'identité de dépôt — incident 2026-09-05, retarget #3454)
**Issue :** #2089 follow-up (incident 2026-05-11, commit `67514ec1`)

---

## Règle Absolue

**Avant tout commit modifiant un pointeur submodule** (`mcps/internal`,
`mcps/external/win-cli/server`, `roo-code`) : **asserter que l'instrument vise le bon dépôt,
puis `git fetch` le submodule, puis vérifier que la SHA cible est atteignable depuis son
upstream.**

```bash
git -C <submod> fetch origin main
git -C <submod> merge-base --is-ancestor $(git -C <submod> rev-parse HEAD) origin/main \
  && echo OK || echo "ORPHAN — STOP"
```

**Si la SHA n'est pas atteignable → STOP.** Pousser d'abord le commit submodule sur son upstream,
ou `reset --hard origin/main`. Un pointeur orphelin casse `git pull` **sur toute la flotte**
(`upload-pack: not our ref`), pas seulement chez soi.

## Asserter que l'instrument vise le BON dépôt avant de croire sa réponse (incident 2026-09-05, retarget #3454)

Dans un worktree neuf, `mcps/internal` est **vide** (submodule non peuplé). `git -C
mcps/internal rev-parse origin/main` ne rend alors **pas** une erreur : il remonte au dépôt
**parent** et rend le `origin/main` de roo-extensions. Les gardes de cette règle (existence de
l'objet, ancêtre commun, relecture 40 caractères) vérifient alors une propriété **réelle du
mauvais dépôt** — toutes trois ont passé sur `b141dc32`, le squash d'une PR de roo-extensions,
écrit dans le gitlink du submodule. Trois contrôles qui partagent le même instrument n'en font
qu'un.

Corroboration croisée le même jour, autre objet : po-2024 (c.364) sur les husks
`wt-worker-po-2024-*` — « dir vide → status/wc issus du parent ». Deux machines, deux objets,
un seul mécanisme : **`git -C` sur un répertoire non-peuplé répond au nom du parent.**

Le garde, AVANT toute **lecture** `git -C <submod>` de cette règle (c'est la lecture qui est
empoisonnée : à l'écriture, la mauvaise valeur est déjà en main et les gardes de la règle la
valident). Il teste le **mécanisme** — `git -C` a remonté au parent — pas l'une de ses
conséquences (un nom d'upstream) : il vaut pour les trois submodules sans adaptation et ne
périme pas si un quatrième arrive :

```bash
[ "$(git -C <submod> rev-parse --show-toplevel)" != "$(git rev-parse --show-toplevel)" ] \
  || { echo "git -C a remonté au PARENT (submodule non peuplé) — STOP"; exit 1; }
```

Rattrapage de second ordre, en toutes circonstances : **lire ce que la SHA porte** — le sujet
du commit qu'elle désigne (`git -C <submod> log -1 --format=%s "$SHA"`) — pas seulement
qu'elle existe. Un titre de PR de roo-extensions là où on attend un commit
`jsboige-mcp-servers` est une signature de mauvais dépôt, même quand chaque garde isolé est
vert. C'est ce contrôle qui a réellement rattrapé l'incident, aucune des trois gardes.

## Pourquoi cette règle existe pour les sessions **interactives**

Le worker schedulé a son propre garde (`Reset-PhantomSubmodulePointers`), et la CI bloque les PRs.
Ni l'un ni l'autre ne couvre une session Claude Code interactive qui pousse sur `main` avec un token
OWNER — c'est exactement ce qui a produit l'incident du 2026-05-11.

## Vérifier la chaîne **exacte** qu'on écrit, jamais son préfixe (incident 2026-08-07, PR #3056)

`git update-index --cacheinfo` prend un SHA **complet à 40 caractères** et ne valide rien. Les trois
gardes ci-dessus acceptent, elles, une **abréviation** — que git résout correctement. On peut donc
vérifier `45388458` avec succès pendant que le gitlink stocke un SHA de 40 caractères dont seuls les
8 premiers sont vrais. C'est arrivé : `45388458d0e05e02…` écrit, `45388458191dec35…` attendu, CI
rouge sur `upload-pack: not our ref`.

Ne jamais recopier un SHA à la main ni le reconstituer : le lire en entier dans une variable, et
comparer la valeur **écrite** à la valeur **voulue** sur les 40 caractères.

```bash
SHA=$(git -C <submod> rev-parse origin/main)          # 40 car., jamais une abréviation
[ ${#SHA} -eq 40 ] || { echo "pas un SHA complet — STOP"; exit 1; }
git -C <submod> cat-file -e "$SHA^{commit}" || exit 1
git -C <submod> merge-base --is-ancestor "$SHA" origin/main || exit 1
git update-index --cacheinfo 160000,$SHA,mcps/internal
[ "$(git ls-files -s mcps/internal | awk '{print $2}')" = "$SHA" ] || { echo "DIVERGENCE — STOP"; exit 1; }
```

La relecture de `ls-files -s` existe précisément pour rattraper ce que `--cacheinfo` ne valide pas :
comparée sur le préfixe, elle ne rattrape rien.

## Les trois pièges

- `git submodule update --init --recursive` puis `git add` → checkout arbitraire = pointeur arbitraire.
- « Résoudre le conflit submod » par `checkout --theirs` / `checkout HEAD --` sans regarder la cible.
- Bumper le pointeur parent **avant** que la PR submod soit mergée (voir `pr-mandatory.md`).

---

**Procédure complète, incident fondateur, cas légitimes, post-mortem :**
[`docs/harness/reference/submod-pointer-safety-procedure.md`](../../docs/harness/reference/submod-pointer-safety-procedure.md)
