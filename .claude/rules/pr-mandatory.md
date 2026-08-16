# PR Obligatoire — Zero Push Direct sur Main

**Version:** 3.4.0 (slim)
**MAJ:** 2026-05-22

---

## Regle Absolue

**AUCUN push direct sur `main`.** Tout changement passe par worktree → PR → review → merge.

## Workflow PR — Claude Code

1. **Anti-double-claim :** `gh pr list --state open --search "<issue>"`
2. **Creer worktree :** `git worktree add .claude/worktrees/wt-{desc} -b wt/{desc}`
3. **Travailler :** Commits atomiques, tests passent
4. **Creer PR :** `gh pr create`
5. **Review → Merge (squash)**
6. **Cleanup :** `git worktree remove` + `git branch -D`

### Anti-Nested Worktrees (#2123 incident 2026-05-22)

**JAMAIS créer un worktree dont le chemin est imbriqué dans un submodule.** Un worktree doit toujours vivre dans le repo git qui le gère.

- **OK** : `.claude/worktrees/wt-foo` dans le repo parent → worktree du repo parent
- **OK** : `../roo-extensions-wt/wt-foo` (en dehors du repo) via `create-worktree.ps1`
- **INTERDIT** : `mcps/internal/.claude/worktrees/wt-foo` → worktree du submodule imbriqué dans le working tree du parent → 136k fichiers fuient comme untracked

**Règle :** Avant `git worktree add`, vérifier `git rev-parse --show-toplevel`. Si ce toplevel est dans un sous-répertoire d'un repo parent (ex: `mcps/internal`), le worktree sera imbriqué → **utiliser un chemin en dehors du working tree** ou travailler directement dans le submodule sans worktree.

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

## Anti Pointer-Bump Premature (#1799, post cycle 22ter cascade CI)

**Risque :** Creer un pointer-bump parent avant que la PR submod source soit mergee → SHA orphelin, `check-submodule-pointer` CI fail systematique.

**Regle :** Un pointer-bump parent ne doit etre cree QU'APRES merge de la PR submod source.

**Workflow correct :**
1. Worker cree PR submod (ex: `mcps/internal` PR #234)
2. Attendre merge submod (`gh pr view 234 --json state` = MERGED)
3. Recuperer SHA mergee : `git -C mcps/internal rev-parse origin/main`
4. ALORS creer bump parent avec ce SHA

**Anti-pattern observe cycle 22ter :** PRs #1788, #1793, #1795, #1796 toutes en CI fail car pointers cibaient des SHAs non mergees. Resolu via re-creation post-merge.

**Variante interactive (incident `67514ec1` 2026-05-11)** : Agent qui resout un conflit submod en checkant out une SHA locale jamais pushee → pointer orphelin sur main, fetch fail flotte-wide. Pour les sessions interactives qui ne passent pas par worker.ps1 (qui a son `Reset-PhantomSubmodulePointers`), voir [`.claude/rules/submod-pointer-safety.md`](submod-pointer-safety.md) pour le check `git cat-file -e` obligatoire.

**Alternative coordinateur :** Bundle pointer-bump (pattern #1764, #1801) — 1 PR parent groupant plusieurs merges submod = moins de PRs, moins de race conditions.

## Detached HEAD Guard (#1666 Phase A2)

**Risque :** Un commit sur detached HEAD est orphelin — perdu au cleanup worktree.

**Prevention :**
1. Avant commit : `git symbolic-ref -q HEAD` — si echec, NE PAS committer
2. Si detached : `git checkout -b worker/recovery-YYYYMMDD-HHmmss` puis commit
3. Apres commit : verifier `git symbolic-ref -q HEAD` passe

**Automatique :** `start-claude-worker.ps1` implemente ce guard (ligne 1903). En cas de recovery, le nom de branche est rapporte dans le [RESULT].

**Claude Code :** Verifier `git branch --show-current` avant chaque commit dans un worktree. Si resultat vide ou "(HEAD detached", creer une branche de recovery.

## Identite `gh` — la garde est DANS la commande agissante (#3032)

Plus de 5 sessions Claude Code, le worker, le listener et des conteneurs appellent `gh` de front sur
la meme machine. `gh` n'a **aucun** modele de concurrence : l'identite vit dans un unique
`hosts.yml` machine-globale, qu'un autre processus peut reecrire entre deux de tes commandes.

**Ne jamais separer « choisir l'identite » de « agir ».** Assert l'identite dans la **meme** commande :

```bash
gh auth switch --user <bot> && [ "$(gh api user --jq .login)" = "<bot>" ] \
  && gh pr review N --approve --body "..." && gh pr merge N --squash
```

Un `gh auth status` lu en debut de session ne dit rien de l'identite de la commande suivante.
**Detail et pistes ecartees :** [`docs/harness/reference/gh-identity-concurrency.md`](../../docs/harness/reference/gh-identity-concurrency.md)

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
