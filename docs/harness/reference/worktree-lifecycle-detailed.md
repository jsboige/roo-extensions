# Cycle de vie des worktrees — narratif déporté

**Déporté de** `.claude/rules/worktree-lifecycle.md` v1.1.0 (claudish#445, 2026-10-12).
**Issues :** #2638 (branches accumulées) · #2123 (worktrees imbriqués) · incident jonction po-203 c.525.

La règle auto-chargée garde les impératifs (les 3 issues, la recette jonction, les garde-fous). Ce
document porte le **pourquoi** : coût mesuré, mécanique git, incidents fondateurs. On le lit quand
on se demande pourquoi la règle est écrite ainsi — pas à chaque conversation.

---

## Révisions de la règle

- **1.0.0** (20/08) — [PROPOSAL] po-2026, approuvée par l'utilisateur — ancrages (a) + (b).
- **1.0.1** — points Hermes/jsboige confirmés par web1 sur #3197 : `-d` → `-D` après lecture d'état
  (un `-d` qui passe n'est pas une preuve), worktree sale ≠ orphelin.
- **1.1.0** — garde jonction : délier les reparse points **avant** tout `worktree remove` (incident
  po-203 c.525 du 05/10 : remove à travers une jonction `node_modules` → contenu du checkout
  principal supprimé, récupéré ; constat jumeau po-2027 `mcps-2639-*` dirs vides le même jour).

## Le coût qui motive la règle

~300 worktrees orphelins purgés à la main en **4 vagues** sur la flotte (14→20/08), dont certains
portaient du travail **jamais livré** — un notebook complet, un fix tsync absent de `main`. C'est
ce qui a fait passer le worktree du statut « lieu de travail » à celui de **dette** : un worktree
n'est pas un lieu de stockage, la PR l'est.

## La mécanique squash-merge, en détail

**Sous squash-merge, aucune propriété du graphe git ne dit « livré ».**

- `git log main..<branche>` affiche des commits **même quand le travail est mergé** : le squash a
  réécrit l'historique, la branche d'origine n'est plus ancêtre de `main`.
- `git cherry` ment pour la même raison.

Un agent qui vérifierait l'ascendance conclurait « travail non livré » sur une PR mergée — et
garderait indéfiniment des worktrees morts. C'est exactement ce qui a produit les 4 vagues de purge
manuelle.

**L'état de PR tranche, pas l'ascendance :**

```bash
gh pr view <N> --repo <owner>/<repo> --json state,mergedAt
```

### `-d` ne refuse PAS systématiquement après un squash-merge

Le critère de `git branch -d` est « contenue dans HEAD **ou** dans son upstream de suivi ». Une
branche poussée sur `origin` avant le squash y est contenue **par construction**, donc `-d` la
supprime. Il ne refuse que la branche qui n'est **ni** dans HEAD **ni** poussée.

**Corollaire : l'échec de `-d` n'est pas un filet de sécurité, et sa réussite n'est pas une preuve
de livraison.** La preuve reste `gh pr view --json state`.

## `worktree remove` ne supprime jamais la branche (#2638)

Deux gestes distincts, toujours. Retirer le worktree en croyant avoir supprimé la branche laisse une
branche locale de plus à chaque cycle — c'est l'origine des **151 `wt/worker-*` accumulées**
(#2638, cleanup user-gated).

## Incident fondateur : la jonction (po-203, c.525, 05/10/2026)

`git worktree remove` **suit les jonctions** (`mklink /J`) et supprime tout ce qui y est
atteignable — y compris dans le checkout principal.

Le remove d'un worktree submod a suivi `node_modules\roo-state-manager` → **serveur RSM du checkout
principal** : 144 fichiers trackés partis. Récupérés (index intact, `.env` depuis GDrive, rebuild),
mais le vecteur est le **pattern standard des worktrees submod** : jonction `node_modules` depuis le
checkout principal pour économiser le disque.

Le même jour, po-2027 constatait la même famille sur `mcps-2639-*` (dirs vidées).

**Recette (dans la règle auto-chargée) :** énumérer les reparse points **par niveau**, délier chaque
jonction **sans la traverser** (`[IO.Directory]::Delete($j, $false)` — jamais `Remove-Item
-Recurse`, jamais `rm -rf`, jamais `/S`), et seulement ensuite remove/rm.

## Balayage (ancrage b)

Le tick Maintenance signale à l'agent **propriétaire** les worktrees sans session vivante depuis
> 24 h. Il **notifie**, il ne supprime pas : le tick voit la saleté, l'agent connaît l'intention.
La décision reste chez celui qui a ouvert le worktree.

---

**Règle canonique :** [`.claude/rules/worktree-lifecycle.md`](../../../.claude/rules/worktree-lifecycle.md)
**Voir aussi :** [`worktree-cleanup.md`](worktree-cleanup.md) (scripts de cleanup) ·
[`pr-workflow-guards.md`](pr-workflow-guards.md) (#2123 worktrees imbriqués, detached HEAD).
