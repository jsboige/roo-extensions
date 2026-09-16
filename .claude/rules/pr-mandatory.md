# PR Obligatoire — Zero Push Direct sur Main

**Version:** 3.5.2 (slim)
**MAJ:** 2026-09-16 (actions GitHub publiques sérialisées dans une session)

---

## Regle Absolue

**AUCUN push direct sur `main`.** Tout changement passe par worktree → PR → review → merge.

## Workflow PR — Claude Code

1. **Anti-double-claim (les 2 depots — une PR submod vit dans `jsboige/jsboige-mcp-servers`, #3407 ; frontiere de mot sur le numero — `--search` GitHub est flou) :**
   ```bash
   for R in jsboige/roo-extensions jsboige/jsboige-mcp-servers; do
     gh pr list --repo "$R" --state open --json number,author,title \
       --jq '.[] | select(.title | test("#<issue>([^0-9]|$)"))'
   done
   ```
2. **Creer worktree :** `git worktree add .claude/worktrees/wt-{desc} -b wt/{desc}`
3. **Travailler :** Commits atomiques, tests passent
4. **Creer PR :** `gh pr create`
5. **Review → Merge (squash)**
6. **Cleanup :** `git worktree remove` + `git branch -D`

### Anti-Nested Worktrees (#2123)

**JAMAIS créer un worktree dont le chemin est imbriqué dans un submodule** — 136k fichiers fuient
alors comme untracked. Avant `git worktree add`, vérifier `git rev-parse --show-toplevel` : si ce
toplevel est dans un sous-répertoire d'un repo parent (ex. `mcps/internal`), prendre un chemin
**en dehors** du working tree, ou travailler dans le submodule sans worktree.

## Workflow PR — Roo

- **-complex** : push + PR depuis le worktree
- **-simple** : committer sur branche, Claude Worker cree la PR
- **Orchestrateurs** : NE PAS toucher au code

## Repertoires PROTEGES

- `src/services/synthesis/` — Pipeline LLM
- `src/services/narrative/` — Stubs = cibles d'IMPLEMENTATION

## Review Checklist

- Anti-double-claim OK
- Pas de suppression sans preuve
- Pas de suppression dans PROTEGES
- Tests preserves, pas de stubs
- Pas de console.log
- Build + tests passent
- Submod pointer reachable depuis origin/main

## Anti Pointer-Bump Premature (#1799)

**Un pointer-bump parent ne doit etre cree QU'APRES merge de la PR submod source** — avant, la SHA
est orpheline et `check-submodule-pointer` echoue systematiquement. Sequence : PR submod →
`gh pr view N --json state` = `MERGED` → `git -C <submod> rev-parse origin/main` → bump parent.

Garde `cat-file -e` pour les sessions interactives (qui ne passent pas par `worker.ps1` et son
`Reset-PhantomSubmodulePointers`) : [`submod-pointer-safety.md`](submod-pointer-safety.md).
Alternative coordinateur : bundle pointer-bump (#1764, #1801).

## Detached HEAD Guard (#1666 Phase A2)

Un commit sur detached HEAD est **orphelin** — perdu au cleanup du worktree. **Verifier
`git branch --show-current` avant chaque commit dans un worktree** ; si le resultat est vide ou
`(HEAD detached`, creer `git checkout -b worker/recovery-YYYYMMDD-HHmmss` **avant** de committer.
`start-claude-worker.ps1` implemente ce garde et rapporte la branche de recovery dans le `[RESULT]`.

## Identite `gh` — la garde est DANS la commande agissante (#3032)

Plus de 5 sessions Claude Code, le worker, le listener et des conteneurs appellent `gh` de front sur
la meme machine. `gh` n'a **aucun** modele de concurrence : l'identite vit dans un unique
`hosts.yml` machine-globale, qu'un autre processus peut reecrire entre deux de tes commandes.

**Ne jamais separer « choisir l'identite » de « agir ».** Assert l'identite dans la **meme** commande :

```bash
gh auth switch --user <bot> && [ "$(gh api user --jq .login)" = "<bot>" ] \
  && gh pr review N --approve --body-file review.md
```

**Ne jamais lancer en parallele deux actions GitHub publiques qui font chacune `gh auth switch` dans
une meme session.** Deux blocs gardes peuvent s'entrelacer apres leurs assertions : A verifie A, B
bascule vers B, puis A agit sous B. Parallelliser les lectures est permis ; reviews, commentaires,
merges, fermetures et creations sont serialises par la session. Ce garde local n'est pas un verrou
machine-global et ne remplace jamais l'assertion inline.

Un `gh auth status` lu en debut de session ne dit rien de l'identite de la commande suivante.
**Detail et pistes ecartees :** [`docs/harness/reference/gh-identity-concurrency.md`](../../docs/harness/reference/gh-identity-concurrency.md)

## Economie d'identite review — l'APPROVE OWNER se depense (#2368)

Avant de poster un APPROVE sous `jsboige` (compte partage) : lire `gh pr view N --json reviews`.
Si un reviewer qualifiant a **deja APPROVE sur la tete courante**, faire sa passe independante en
**COMMENT** — un 2e approval ne deplace rien. Reserver l'APPROVE a : (1) ma review est la 1ere
qualifiante, ou (2) la branch protection exige une 2e review.

## Bodies gh : `--body-file`, jamais `--body` inline (#2368)

Dans `--body "..."` a guillemets doubles, les backticks markdown sont de la **substitution de
commande** pour bash : le corps part ecorche, **exit code 0**, et le retry « propre » cree un
**doublon**.

- **Toujours** `--body-file <path>` (scratchpad) — `gh pr review`, `gh pr comment`,
  `gh issue create|comment`
- `gh issue close` n'expose **pas** `--comment-file` : commenter d'abord
  (`gh issue comment --body-file`), **puis** fermer — jamais rebasculer en `--body` inline
- Stderr montrant une erreur shell → **verifier via l'API avant de retenter**

**Incidents fondateurs et mecanisme :** [`docs/harness/reference/pr-workflow-guards.md`](../../docs/harness/reference/pr-workflow-guards.md)

## Pas de PR necessaire pour

MEMORY.md (`~/.claude/projects/…`), dashboards (GDrive), fichiers gitignored.

Ces trois-la ne sont **pas versionnes** : il n'y a pas de PR a faire, faute de commit.

### `.claude/rules/` et `.roo/rules/` : PR OBLIGATOIRE (#3140)

Ces deux repertoires **sont versionnes** et **proteges par la branch protection**. Ils figuraient
par erreur dans la liste ci-dessus. La regle generale s'applique : **aucun push direct sur `main`**.

Constate le 2026-08-16 (po-2023 c.18) : push refuse cote serveur, PR #3138 ouverte a la place.
Le fait qu'un OWNER passe parfois en direct ne fait pas une exception — c'est un privilege
d'identite, pas une propriete du chemin. Un agent qui croyait l'exception perd un cycle sur un
push refuse.

---

**Trivial auto-merge policy (#1582) :** [`docs/harness/reference/pr-trivial-merge-policy.md`](../../docs/harness/reference/pr-trivial-merge-policy.md)
