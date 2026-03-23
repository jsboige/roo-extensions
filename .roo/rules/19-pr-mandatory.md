# PR Obligatoire — Zero Push Direct sur Main

**REGLE ABSOLUE :** Aucun push direct sur `main`. Tout changement de code passe par :

```
Worktree branch → PR → Review coordinateur → Merge
```

## Pourquoi

La moitie du "code mort" detecte est du code fonctionnel detruit par des agents qui refactorent sans comprendre. Les push directs empechent la verification AVANT le dommage.

## Pour les modes -simple et -complex

1. Travailler dans le worktree (deja le cas)
2. Committer sur la branche worktree
3. **NE PAS merger dans main**
4. **NE PAS `git push origin main`**
5. Rapporter dans le bilan que les changements sont sur la branche worktree

Le coordinateur ou le Claude Worker creera la PR et la review.

## Interdit

- `git push origin main` — INTERDIT
- `git checkout main && git merge wt/...` — INTERDIT
- Toute operation qui modifie `main` directement — INTERDIT

## Exception

Fichiers de coordination non-code : INTERCOM, dashboards, MEMORY.md, `.roo/rules/`, `.claude/rules/`.
