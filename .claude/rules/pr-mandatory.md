# PR Obligatoire — Zero Push Direct sur Main

**Version:** 2.1.0 (condensed from 1.0.0)
**MAJ:** 2026-04-05 (anti-double-claim #1096)

---

## Regle Absolue

**AUCUN push direct sur `main`.** Tout changement passe par :

```
Worktree branch → PR → Review → Merge → Cleanup
```

Pas d'exception. Ni "petits fix", ni "docs only", ni coordinateur.

---

## Workflow PR

1. **Verifier qu'aucune PR n'existe deja** (anti-double-claim) :
   ```bash
   gh pr list --state open --search "<issue-number>" --repo jsboige/roo-extensions
   ```
   Si une PR existe deja → NE PAS creer de worktree. Skip l'issue.
2. **Creer worktree :** `git worktree add .claude/worktrees/wt-{desc} -b wt/{desc}`
3. **Travailler :** Commits atomiques, tests passent
4. **Creer PR :** `gh pr create --title "type(#issue): description"`
5. **Review :** Coordinateur ou utilisateur approuve
6. **Merge :** Squash merge
7. **CLEANUP OBLIGATOIRE :**
   ```bash
   git worktree remove .claude/worktrees/wt-{desc}
   git branch -D wt/{desc}
   ```

**Reference :** Issue #1096 - Protection anti-double-claim pour eviter les worktrees dupliques.

## Repertoires PROTEGES

Suppression INTERDITE sans approbation utilisateur :
- `src/services/synthesis/` — Pipeline LLM (3 destructions erronees)
- `src/services/narrative/` — Stubs = cibles d'IMPLEMENTATION, PAS code mort

## Review Checklist

- [ ] Pas de suppression sans justification + remplacement PROUVE
- [ ] Pas de suppression dans repertoires PROTEGES
- [ ] Tests preserves, pas de nouveaux stubs (`return null`, `TODO`)
- [ ] Pas de console.log dans code nouveau
- [ ] Build + tests passent (CI vert)
- [ ] Un plan d'agent n'est PAS une autorisation de suppression

## Pas de PR necessaire pour

- MEMORY.md, INTERCOM, dashboards (coordination)
- `.claude/rules/`, `.roo/rules/` (harnais)
- Fichiers gitignored

---

**Historique versions completes :** Git history avant 2026-04-05
