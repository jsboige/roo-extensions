# Cycle de vie des worktrees — pas d'orphelin

**Version:** 1.0.1
**Origine :** [PROPOSAL] po-2026 (20/08), approuvée par l'utilisateur — ancrages (a) + (b)
**Révisions :** 1.0.1 — points Hermes/jsboige confirmés par web1 sur #3197 : `-d` → `-D` après lecture d'état, worktree sale ≠ orphelin.
**Coût qui la motive :** ~300 worktrees orphelins purgés à la main en 4 vagues sur la flotte (14→20/08), dont certains portaient du travail jamais livré (un notebook complet, un fix tsync absent de `main`).

---

## Règle

**Un worktree n'est pas un lieu de stockage. La PR l'est.**

À la fin de chaque session, l'agent est responsable de l'état de **ses** worktrees. Trois issues, pas quatre :

1. **Le contenu a de la valeur → le livrer en PR.** Une PR ouverte conserve le travail, le rend visible et reviewable. Un worktree ne fait aucune des trois.
2. **Le contenu est supplanté → suppression propre**, preuves d'abord : `git worktree remove`, puis la branche **séparément**, puis `git worktree prune`. L'état de livraison se lit dans `gh pr view --json state` — jamais dans l'ascendance (piège ci-dessous). La preuve porte la sécurité, pas le flag :
   - `state=MERGED` lu → `git branch -D` ;
   - branche jamais poussée et sans valeur → `git branch -d` ;
   - **`-d` après squash-merge refusera toujours** (« not fully merged ») : c'est l'ascendance qu'il vérifie.
3. **Doute réel → arbitrage humain.** Le doute n'est pas une raison de laisser traîner, c'est une raison de demander.

## Le piège qui rend cette règle nécessaire

**Sous squash-merge, aucune propriété du graphe git ne dit « livré ».**

`git log main..<branche>` affiche des commits **même quand le travail est mergé** : le squash a réécrit l'historique, la branche d'origine n'est plus ancêtre de `main`. `git cherry` ment pour la même raison.

**L'état de PR tranche, pas l'ascendance :**

```bash
gh pr view <N> --repo <owner>/<repo> --json state,mergedAt
```

Un agent qui vérifierait l'ascendance conclurait « travail non livré » sur une PR mergée — et garderait indéfiniment des worktrees morts. C'est exactement ce qui a produit les 4 vagues de purge manuelle.

## `worktree remove` ne supprime **jamais** la branche

Deux gestes distincts, toujours. Retirer le worktree en croyant avoir supprimé la branche laisse une branche locale de plus à chaque cycle — c'est l'origine des 151 `wt/worker-*` accumulées (#2638, cleanup user-gated).

Seul le cas **detached HEAD** perd réellement du travail au retrait : vérifier `git branch --show-current` **avant** tout commit dans un worktree ; si le résultat est vide, créer une branche de recovery avant de committer.

## Garde-fous permanents

- **Jamais de `rm -rf` sur un worktree.** Passer par `git worktree remove`.
- **Sale ≠ orphelin.** `worktree remove` refuse un worktree avec modifications non commitées sans `--force`. Ce refus est une protection : des modifications non commitées peuvent être du travail jamais livré ailleurs. Examiner le contenu (`git status` + `git diff` dans le worktree) **avant** d'utiliser `--force` — pas l'inverse.
- **Jonctions `.mathlib-cache` et projet SEED : intouchables.**
- **Preuves avant suppression de branche** — état de PR lu, ou absence de contenu constatée.
- Un worktree imbriqué dans un submodule est un défaut en soi (#2123) : vérifier `git rev-parse --show-toplevel` avant `git worktree add`.

## Balayage (ancrage b)

Le tick Maintenance signale à l'agent **propriétaire** les worktrees sans session vivante depuis > 24 h. Il **notifie**, il ne supprime pas : le tick voit la saleté, l'agent connaît l'intention. La décision reste chez celui qui a ouvert le worktree.
