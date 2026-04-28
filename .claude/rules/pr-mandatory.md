# PR Obligatoire — Zero Push Direct sur Main

**Version:** 3.2.0 (slim)
**MAJ:** 2026-04-28

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

## Detached HEAD Guard (#1666 Phase A2)

**Risque :** Un commit sur detached HEAD est orphelin — perdu au cleanup worktree.

**Prevention :**
1. Avant commit : `git symbolic-ref -q HEAD` — si echec, NE PAS committer
2. Si detached : `git checkout -b worker/recovery-YYYYMMDD-HHmmss` puis commit
3. Apres commit : verifier `git symbolic-ref -q HEAD` passe

**Automatique :** `start-claude-worker.ps1` implemente ce guard (ligne 1903). En cas de recovery, le nom de branche est rapporte dans le [RESULT].

**Claude Code :** Verifier `git branch --show-current` avant chaque commit dans un worktree. Si resultat vide ou "(HEAD detached", creer une branche de recovery.

## Pas de PR necessaire pour

MEMORY.md, INTERCOM, dashboards, `.claude/rules/`, `.roo/rules/`, fichiers gitignored

---

**Trivial auto-merge policy (#1582) :** [`docs/harness/reference/pr-trivial-merge-policy.md`](docs/harness/reference/pr-trivial-merge-policy.md)
