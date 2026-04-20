# PR Obligatoire — Zero Push Direct sur Main

**Version:** 3.1.0 (add trivial-merge exception, #1582)
**MAJ:** 2026-04-21

---

## Regle Absolue

**AUCUN push direct sur `main`.** Tout changement passe par :

```
Worktree branch → PR → Review → Merge → Cleanup
```

Pas d'exception. Ni "petits fix", ni "docs only", ni coordinateur. S'applique a **TOUS les agents** (Claude ET Roo).

---

## Workflow PR — Claude Code (interactif ou scheduler)

1. **Verifier anti-double-claim :** `gh pr list --state open --search "<issue>" --repo jsboige/roo-extensions`. Si PR existe → SKIP
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

- [ ] **Anti-double-claim** : Aucune PR ouverte ne couvre deja cette issue (`gh pr list --state open --search "#issue"`)
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

## Exception : Trivial Auto-Merge (#1582)

**Le scheduled coordinator ai-01 UNIQUEMENT** peut approve+merger sans validation interactive, dans un perimetre etroit. Rule 16 (review retroactive du coordinateur interactif) reste en vigueur — le trivial auto-merge est une optimisation de latence, pas un contournement.

### Patterns eligibles (cumulatif, ALL conditions)

1. **Titre PR** match l'une des regex :
   - `^test(\(coverage\))?: .+`
   - `^chore\(submod\): bump pointer [a-f0-9]{7,} -> [a-f0-9]{7,}.*$`
   - `^docs\([^)]+\): .+`
2. **Diff contraintes** :
   - Aucune modification dans : `src/`, `lib/`, `mcps/internal/servers/*/src/`, `mcps/internal/servers/*/build/`, `.claude/`, `.roo/`, `CLAUDE.md`, `.roomodes`, `package*.json`, `.github/workflows/`, `*.env*`, `*.yml` (CI/infra), `*.ts` hors `**/tests/**`
   - Zero suppression de test existant
   - Pour pointer bump : **UNIQUEMENT** `mcps/internal` change, `+1/-1` exact
3. **CI** : tous les checks required en `SUCCESS`
4. **Review decision** : pas `CHANGES_REQUESTED`
5. **Auteur** : different de `jsboige` (evite self-approve+self-merge) OU auteur est un worker/scheduler automatique

### Procedure (scheduled coordinator ai-01)

A chaque cycle 6-12h, phase `trivial-merge` :
1. `gh pr list --state open --search "is:pr author:app/* OR (type:coverage) OR (pointer bump)"` — lister PRs matching
2. Pour chaque PR, verifier les 5 conditions ci-dessus
3. Si conditions OK : `gh auth switch --user myia-ai-01 && gh pr review <N> --approve --body "LGTM trivial per #1582"` (review independante)
4. `gh auth switch --user jsboige && gh pr merge <N> --squash --delete-branch` (merge)
5. Log dans le dashboard workspace avec tag `[TRIVIAL-MERGE]` : PR num, titre, LOC +/-, temps total
6. Snapshot compact en fin de phase : total mergees, erreurs, PRs ignorees et pourquoi

### Garde-fous

- **Max 5 trivial-merges par cycle** pour limiter le blast radius en cas de regression
- **Coordinateur interactif audit retroactif OBLIGATOIRE** a chaque cycle /coordinate : lire les messages `[TRIVIAL-MERGE]` du dashboard, verifier que les patterns tenaient
- **Si une anomalie detectee** (test failure post-merge, regression introduite) : desactiver la clause via flag `TRIVIAL_MERGE_DISABLED=1` dans `~/.claude/settings.json`, incidenter via issue `needs-approval`
- **Pilot 2 semaines** (2026-04-21 → 2026-05-05). Review en fin de periode.

### Ce que ça NE change PAS

- Rule 16 inchangee pour toute PR hors patterns ci-dessus
- Review sk-agent obligatoire pour PRs >50 LOC non-test
- Integration tracing template obligatoire pour PRs touchant `src/`, `.claude/`, `.roo/`
- Coordinateur interactif peut re-review retroactivement et reverter

---

**Historique versions completes :** Git history avant 2026-04-05
