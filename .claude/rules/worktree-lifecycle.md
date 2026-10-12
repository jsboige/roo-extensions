# Cycle de vie des worktrees — pas d'orphelin

**Version:** 1.2.0 (slim — narratif déporté vers `docs/harness/reference/worktree-lifecycle-detailed.md`, claudish#445)
**Origine :** [PROPOSAL] po-2026 (20/08), approuvée par l'utilisateur — ancrages (a) + (b)

---

## Règle

**Un worktree n'est pas un lieu de stockage. La PR l'est.**

À la fin de chaque session, l'agent est responsable de l'état de **ses** worktrees. Trois issues, pas quatre :

1. **Le contenu a de la valeur → le livrer en PR.** Une PR ouverte conserve le travail, le rend visible et reviewable. Un worktree ne fait aucune des trois.
2. **Le contenu est supplanté → suppression propre**, preuves d'abord : `git worktree remove`, puis la branche **séparément**, puis `git worktree prune`. L'état de livraison se lit dans `gh pr view --json state` — **jamais dans l'ascendance** (le squash la réécrit). `state=MERGED` lu → `git branch -D` ; branche jamais poussée et sans valeur → `git branch -d`. **`-d` ne refuse PAS systématiquement après un squash-merge** (son critère : « contenue dans HEAD **ou** dans son upstream de suivi ») — un `-d` qui passe n'est donc pas une preuve de livraison.
3. **Doute réel → arbitrage humain.** Le doute n'est pas une raison de laisser traîner, c'est une raison de demander.

## Le piège qui rend cette règle nécessaire

**Sous squash-merge, aucune propriété du graphe git ne dit « livré »** : `git log main..<branche>` et `git cherry` affichent des commits même quand le travail est mergé — la branche d'origine n'est plus ancêtre de `main`. L'état de PR tranche, pas l'ascendance :

```bash
gh pr view <N> --repo <owner>/<repo> --json state,mergedAt
```

Un agent qui vérifierait l'ascendance conclurait « travail non livré » sur une PR mergée, et garderait indéfiniment des worktrees morts (→ 4 vagues de purge manuelle ; récit : doc détaillé).

## `worktree remove` ne supprime **jamais** la branche

Deux gestes distincts, toujours — sinon une branche locale de plus à chaque cycle (#2638 : 151 `wt/worker-*` accumulées, cleanup user-gated).

Seul le cas **detached HEAD** perd réellement du travail au retrait : vérifier `git branch --show-current` **avant** tout commit dans un worktree ; si le résultat est vide, créer une branche de recovery avant de committer.

## Garde-fous permanents

- **Jamais de `rm -rf` sur un worktree.** Passer par `git worktree remove`.
- **Jonction = frontière : délier AVANT tout remove.** `git worktree remove` **suit les jonctions** (`mklink /J`) et supprime tout ce qui y est atteignable — y compris dans le checkout principal (incident fondateur po-203 c.525 du 05/10, 144 fichiers trackés ; récit : doc détaillé). Recette, **avant tout `worktree remove`/`rm`** :
  1. énumérer les reparse points **par niveau** : `Get-ChildItem -Force | Where-Object LinkType` ;
  2. délier chaque jonction **sans la traverser** : `[IO.Directory]::Delete($j, $false)` (équivalent `rmdir` nu — jamais `Remove-Item -Recurse`, jamais `rm -rf`, jamais `/S`) ;
  3. seulement ensuite remove/rm.
- **Sale ≠ orphelin.** `worktree remove` refuse un worktree avec modifications non commitées sans `--force`. Ce refus est une protection : des modifications non commitées peuvent être du travail jamais livré ailleurs. Examiner le contenu (`git status` + `git diff` dans le worktree) **avant** d'utiliser `--force` — pas l'inverse.
- **Jonctions `.mathlib-cache` et projet SEED : intouchables.**
- **Preuves avant suppression de branche** — état de PR lu, ou absence de contenu constatée.
- Un worktree imbriqué dans un submodule est un défaut en soi (#2123) : vérifier `git rev-parse --show-toplevel` avant `git worktree add`.

## Balayage (ancrage b)

Le tick Maintenance signale à l'agent **propriétaire** les worktrees sans session vivante depuis > 24 h. Il **notifie**, il ne supprime pas : le tick voit la saleté, l'agent connaît l'intention. La décision reste chez celui qui a ouvert le worktree.

---

**Narratif déporté (révisions, coût des 4 vagues, mécanique squash-merge détaillée, incident jonction) :** [`docs/harness/reference/worktree-lifecycle-detailed.md`](../../docs/harness/reference/worktree-lifecycle-detailed.md)
