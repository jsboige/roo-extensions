# Trivial Auto-Merge Policy (#1582, etendue #1715)

**Source :** `.claude/rules/pr-mandatory.md` (version slim)
**MAJ :** 2026-05-08

---

## Exception : Trivial Auto-Merge

**Le scheduled coordinator ai-01 UNIQUEMENT** peut approve+merger sans validation interactive, dans un perimetre etroit. Rule 16 (review retroactive du coordinateur interactif) reste en vigueur.

### Patterns eligibles (cumulatif, ALL conditions)

1. **Titre PR** match l'une des regex :
   - `^test(\(coverage\))?: .+` — tests / coverage
   - `^chore\(submod\): bump pointer [a-f0-9]{7,} -> [a-f0-9]{7,}.*$` — pointer bump simple
   - `^chore\(submod\): bundle pointer-bump .+` — bundle pointer-bump (#1715, plusieurs PRs submod regroupees)
   - `^docs\([^)]+\): .+` — documentation
   - `^(chore|docs)\(#?\d+\): .+\.gitkeep$` — creation .gitkeep dans docs/meta-analysis/ (#1715)
   - `^fix\(#?\d+\): .+ test (only|fixup).+$` — test fixup pur (#1715)
2. **Diff contraintes** :
   - Aucune modification dans : `src/`, `lib/`, `mcps/internal/servers/*/src/`, `mcps/internal/servers/*/build/`, `.claude/`, `.roo/`, `CLAUDE.md`, `.roomodes`, `package*.json`, `.github/workflows/`, `*.env*`, `*.yml` (CI/infra), `*.ts` hors `**/tests/**`
   - Zero suppression de test existant
   - Pour pointer bump simple : **UNIQUEMENT** `mcps/internal` change, `+1/-1` exact
   - Pour bundle pointer-bump (#1715) : **UNIQUEMENT** `mcps/internal` change, `+1/-1` exact, et reference >=2 PRs submod dans le titre/body, ancestry check OK pour TOUS les PRs cites
   - Pour `.gitkeep` (#1715) : diff = 0 LOC effective, path commence par `docs/meta-analysis/`
   - Pour test fixup (#1715) : diff < 50 LOC, tous les fichiers dans `tests/` ou `__tests__/`
   - **Pour tout pointer bump : commit cible DOIT etre reachable depuis submod origin/main** (`git -C mcps/internal merge-base --is-ancestor <new_commit> origin/main` → exit 0). Empeche les pointeurs orphan pointant sur un commit pre-squash. Pattern incident : PR #1593 orphan sur `13b4516e` apres squash-merge #165 → fresh PR #1594 (2026-04-21).
3. **CI** : tous les checks required en `SUCCESS` (sync-project workflow fail = faux positif PROJECT_TOKEN connu, ne bloque pas)
4. **Review decision** : pas `CHANGES_REQUESTED`
5. **Auteur** : different de `jsboige` (evite self-approve+self-merge) OU auteur est un worker/scheduler automatique. Si auteur=jsboige → exclu de trivial-merge (pas d'auto-bypass)

### Procedure (scheduled coordinator ai-01)

A chaque cycle 6-12h, phase `trivial-merge` :
1. `gh pr list --state open --search "is:pr author:app/* OR (type:coverage) OR (pointer bump)"` — lister PRs matching
2. Pour chaque PR, verifier les 5 conditions ci-dessus
3. Si conditions OK : `gh auth switch --user myia-ai-01 && gh pr review <N> --approve --body "LGTM trivial per #1582"`
4. `gh auth switch --user jsboige && gh pr merge <N> --squash --delete-branch`
5. Log dashboard avec tag `[TRIVIAL-MERGE]` : PR num, titre, LOC +/-, temps total
6. Snapshot compact en fin de phase : total mergees, erreurs, PRs ignorees

### Garde-fous

- **Max 8 trivial-merges par cycle** (#1715, etendu de 5 → 8 le 2026-05-08 apres observation cycles 28-30 ou 5 etait insuffisant pour les merge tours coordinateur). Cap conservateur : pas plus haut sans nouvelle observation.
- **Coordinateur interactif audit retroactif OBLIGATOIRE** a chaque cycle /coordinate, en particulier sur les bundle pointer-bumps (verifier ancestry de tous les SHAs cites)
- **Si anomalie detectee** : desactiver via `TRIVIAL_MERGE_DISABLED=1` dans `~/.claude/settings.json`, incidenter via issue `needs-approval`
- **Pilot etendu** (2026-05-08 → 2026-05-22). Review en fin de periode.

### Ce que ca NE change PAS

- Rule 16 inchangee pour toute PR hors patterns ci-dessus
- Review sk-agent obligatoire pour PRs >50 LOC non-test
- Integration tracing template obligatoire pour PRs touchant `src/`, `.claude/`, `.roo/`
- Coordinateur interactif peut re-review retroactivement et reverter
