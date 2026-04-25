# Trivial Auto-Merge Policy (#1582)

**Source :** `.claude/rules/pr-mandatory.md` (version slim)
**MAJ :** 2026-04-21

---

## Exception : Trivial Auto-Merge

**Le scheduled coordinator ai-01 UNIQUEMENT** peut approve+merger sans validation interactive, dans un perimetre etroit. Rule 16 (review retroactive du coordinateur interactif) reste en vigueur.

### Patterns eligibles (cumulatif, ALL conditions)

1. **Titre PR** match l'une des regex :
   - `^test(\(coverage\))?: .+`
   - `^chore\(submod\): bump pointer [a-f0-9]{7,} -> [a-f0-9]{7,}.*$`
   - `^docs\([^)]+\): .+`
2. **Diff contraintes** :
   - Aucune modification dans : `src/`, `lib/`, `mcps/internal/servers/*/src/`, `mcps/internal/servers/*/build/`, `.claude/`, `.roo/`, `CLAUDE.md`, `.roomodes`, `package*.json`, `.github/workflows/`, `*.env*`, `*.yml` (CI/infra), `*.ts` hors `**/tests/**`
   - Zero suppression de test existant
   - Pour pointer bump : **UNIQUEMENT** `mcps/internal` change, `+1/-1` exact
   - **Pour pointer bump : commit cible DOIT etre reachable depuis submod origin/main** (`git -C mcps/internal merge-base --is-ancestor <new_commit> origin/main` → exit 0). Empeche les pointeurs orphan pointant sur un commit pre-squash. Pattern incident : PR #1593 orphan sur `13b4516e` apres squash-merge #165 → fresh PR #1594 (2026-04-21).
3. **CI** : tous les checks required en `SUCCESS`
4. **Review decision** : pas `CHANGES_REQUESTED`
5. **Auteur** : different de `jsboige` (evite self-approve+self-merge) OU auteur est un worker/scheduler automatique

### Procedure (scheduled coordinator ai-01)

A chaque cycle 6-12h, phase `trivial-merge` :
1. `gh pr list --state open --search "is:pr author:app/* OR (type:coverage) OR (pointer bump)"` — lister PRs matching
2. Pour chaque PR, verifier les 5 conditions ci-dessus
3. Si conditions OK : `gh auth switch --user myia-ai-01 && gh pr review <N> --approve --body "LGTM trivial per #1582"`
4. `gh auth switch --user jsboige && gh pr merge <N> --squash --delete-branch`
5. Log dashboard avec tag `[TRIVIAL-MERGE]` : PR num, titre, LOC +/-, temps total
6. Snapshot compact en fin de phase : total mergees, erreurs, PRs ignorees

### Garde-fous

- **Max 5 trivial-merges par cycle** pour limiter le blast radius
- **Coordinateur interactif audit retroactif OBLIGATOIRE** a chaque cycle /coordinate
- **Si anomalie detectee** : desactiver via `TRIVIAL_MERGE_DISABLED=1` dans `~/.claude/settings.json`, incidenter via issue `needs-approval`
- **Pilot 2 semaines** (2026-04-21 → 2026-05-05). Review en fin de periode.

### Ce que ca NE change PAS

- Rule 16 inchangee pour toute PR hors patterns ci-dessus
- Review sk-agent obligatoire pour PRs >50 LOC non-test
- Integration tracing template obligatoire pour PRs touchant `src/`, `.claude/`, `.roo/`
- Coordinateur interactif peut re-review retroactivement et reverter
