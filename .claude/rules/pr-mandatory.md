# PR Obligatoire — Zero Push Direct sur Main

**Version:** 3.6.0 (slim 2 — narratives déportées vers les docs de référence, #2368)
**MAJ:** 2026-09-25

---

## Regle Absolue

**AUCUN push direct sur `main`.** Tout changement passe par worktree → PR → review → merge.

## Workflow PR — Claude Code

1. **Anti-double-claim** : vérifier PR concurrente dans les **DEUX dépôts** (une PR submod vit
   dans `jsboige/jsboige-mcp-servers`, #3407), frontière de mot sur le numéro — commande canonique
   dans [`agent-claim-discipline.md`](agent-claim-discipline.md) § Pre-Claim.
2. **Créer worktree :** `git worktree add .claude/worktrees/wt-{desc} -b wt/{desc}` — jamais
   imbriqué dans un submodule (#2123 : vérifier `git rev-parse --show-toplevel` avant).
3. **Travailler :** commits atomiques, tests passent
4. **Créer PR :** `gh pr create`
5. **Review → Merge (squash)**
6. **Cleanup :** `git worktree remove` + `git branch -D`

## Workflow PR — Roo

- **-complex** : push + PR depuis le worktree · **-simple** : committer sur branche, Claude Worker
  crée la PR · **Orchestrateurs** : NE PAS toucher au code.

## Repertoires PROTEGES

- `src/services/synthesis/` — Pipeline LLM
- `src/services/narrative/` — Stubs = cibles d'IMPLEMENTATION

## Review Checklist

Anti-double-claim OK · pas de suppression sans preuve (ni dans PROTEGES) · tests préservés, pas de
stubs · pas de console.log · build + tests passent · submod pointer reachable depuis origin/main.

## Anti Pointer-Bump Premature (#1799)

**Un pointer-bump parent ne doit être créé QU'APRÈS merge de la PR submod source** — avant, la SHA
est orpheline et `check-submodule-pointer` échoue systématiquement. Séquence complète et incidents :
[`pr-workflow-guards.md`](../../docs/harness/reference/pr-workflow-guards.md). Garde interactive
`cat-file -e` : [`submod-pointer-safety.md`](submod-pointer-safety.md).

## Detached HEAD Guard (#1666 Phase A2)

**Vérifier `git branch --show-current` avant chaque commit dans un worktree** ; si vide, créer
`git checkout -b worker/recovery-YYYYMMDD-HHmmss` **avant** de committer — un commit sur HEAD
détaché est orphelin, perdu au cleanup du worktree.

## Identite `gh` (#3032)

`gh` n'a aucun modèle de concurrence : l'identité vit dans un `hosts.yml` machine-global que
d'autres processus réécrivent. **La garde d'identité va dans la MÊME commande que l'action**
(`gh auth switch --user X && [ "$(gh api user --jq .login)" = "X" ] && <action>`). Jamais deux
actions publiques avec `gh auth switch` en parallèle dans une même session (lectures parallèles
OK). Un `gh auth status` de début de session ne dit rien de la commande suivante.
**Détail et pistes écartées :** [`gh-identity-concurrency.md`](../../docs/harness/reference/gh-identity-concurrency.md)

## Economie d'identite review (#2368)

Avant un APPROVE sous `jsboige` : lire `gh pr view N --json reviews` — si un reviewer qualifiant a
**déjà APPROVÉ sur la tête courante**, faire sa passe en **COMMENT** ; réserver l'APPROVE à la
première review qualifiante ou à une 2e review exigée.

## Bodies gh : `--body-file`, jamais `--body` inline (#2368)

Dans `--body "..."`, les backticks markdown sont de la substitution de commande bash : corps
écorché, **exit code 0**, retry « propre » = **doublon**. Toujours `--body-file` (`gh pr
review/comment`, `gh issue create|comment`) ; `gh issue close` n'expose pas `--comment-file` →
commenter **puis** fermer. Stderr d'erreur shell → vérifier via l'API avant de retenter.
**Incidents fondateurs :** [`pr-workflow-guards.md`](../../docs/harness/reference/pr-workflow-guards.md)

## Pas de PR necessaire pour

MEMORY.md (`~/.claude/projects/…`), dashboards (GDrive), fichiers gitignored — non versionnés.
**Mais** `.claude/rules/` et `.roo/rules/` sont versionnés et sous branch protection → **PR
obligatoire** (#3140) : un OWNER qui passe en direct exerce un privilège d'identité, pas une
propriété du chemin.

---

**Trivial auto-merge policy (#1582) :** [`docs/harness/reference/pr-trivial-merge-policy.md`](../../docs/harness/reference/pr-trivial-merge-policy.md)
