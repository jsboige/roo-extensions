# PR Obligatoire — Zero Push Direct sur Main

**Version:** 3.0.0 (harmonized Claude + Roo, #1053, aligned with .claude/rules/)
**MAJ:** 2026-04-08

---

## Regle Absolue

**AUCUN push direct sur `main`.** Tout changement passe par :

```
Worktree branch -> PR -> Review -> Merge -> Cleanup
```

Pas d'exception. Ni "petits fix", ni "docs only", ni coordinateur. S'applique a **TOUS les agents** (Claude ET Roo).

---

## Workflow PR — Claude Code (interactif ou scheduler)

1. **Verifier anti-double-claim :** `gh pr list --state open --search "<issue>" --repo jsboige/roo-extensions`. Si PR existe -> SKIP
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

## Workflow PR — Roo Scheduler

Les modes Roo travaillent dans des worktrees. Le workflow depend du type de mode :

- **Roo -complex** (terminal natif) : DOIT `git push` + `gh pr create` depuis le worktree. Meme workflow que Claude.
- **Roo -simple** (pas de terminal natif, win-cli MCP) : DOIT committer sur la branche worktree, puis le Claude Worker (`start-claude-worker.ps1`) cree la PR automatiquement.
- **Orchestrateurs** : NE PAS toucher au code. Delegation pure via `new_task`.

**INTERDIT pour TOUS :** `git push origin main`, `git checkout main && git merge wt/...`

**Si le worktree reste sans PR >24h**, le coordinateur le detecte et cree la PR ou ferme le worktree.

## Repertoires PROTEGES

Suppression INTERDITE sans approbation utilisateur :

- `src/services/synthesis/` — Pipeline LLM (3 destructions erronees)
- `src/services/narrative/` — Stubs = cibles d'IMPLEMENTATION, PAS code mort

## Review Checklist

- [ ] **Anti-double-claim** : Aucune PR ouverte ne couvre deja cette issue
- [ ] Pas de suppression sans justification + remplacement PROUVE
- [ ] Pas de suppression dans repertoires PROTEGES
- [ ] Tests preserves, pas de nouveaux stubs (`return null`, `TODO`)
- [ ] Pas de console.log dans code nouveau
- [ ] Build + tests passent (CI vert)
- [ ] Un plan d'agent n'est PAS une autorisation de suppression

## Pas de PR necessaire pour

- MEMORY.md, INTERCOM (deprecated), dashboards (coordination)
- `.claude/rules/`, `.roo/rules/` (harnais)
- Fichiers gitignored

---

**Historique versions completes :** Git history avant 2026-04-05
