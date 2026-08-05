# Submodule pointer safety — procédure et incident fondateur

**Déporté de** `.claude/rules/submod-pointer-safety.md` (v1.0.0) le 2026-08-05.
**Issue :** #2089 follow-up — incident 2026-05-11, commit `67514ec1`

La règle auto-chargée garde l'invariant (`cat-file -e` après fetch, sinon STOP). Ce qui suit est la
procédure, l'incident et les cas limites : on le lit quand on touche effectivement un pointeur.

---

## Incident fondateur (2026-05-11)

Commit `67514ec1 fix(mcp): resolve submodule conflict and update win-cli deployment` — push direct sur
`main`, token `jsboige` — a posé le pointeur `mcps/internal` vers la SHA
`0464277894e953025e622807cbc872a537fad16d`, qui n'était sur **aucune** branche remote du submodule.

Conséquence : `git pull` cassé **sur toute la flotte** —
`fatal: remote error: upload-pack: not our ref 0464...` — et CI `check-submodule-pointer` en échec.

L'agent voulait traiter #1967 (win-cli deployment), qui concerne `mcps/external/win-cli/server`, mais a
touché `mcps/internal` par confusion — probablement après un `git submodule update --init --recursive`
qui avait checkout un état stale.

## Pourquoi les garde-fous existants n'ont pas suffi

| Garde-fou | Couvre | Ne couvre pas |
|---|---|---|
| `Reset-PhantomSubmodulePointers` (`start-claude-worker.ps1`, guard #1156 v2, L1846-1909) | worker schedulé | sessions interactives |
| CI `check-submodule-pointer` | les PRs | les push direct sur `main` (token OWNER) |
| `.claude/rules/pr-mandatory.md` | la doctrine | un agent OWNER qui la contourne |

Le trou était donc exactement : **session Claude Code interactive ne passant pas par worker.ps1**.
D'où la règle.

## Procédure — avant tout commit avec pointeur submod modifié

```bash
# 1. Identifier les submodules modifiés
git status --porcelain | grep -E '^\s*M\s+(mcps/|roo-code)'

# 2. Récupérer le HEAD local du submod concerné
SUBMOD_HEAD=$(git -C mcps/internal rev-parse HEAD)

# 3. Fetch upstream
git -C mcps/internal fetch upstream main 2>&1 || git -C mcps/internal fetch origin main

# 4. Vérifier que la SHA est atteignable
git -C mcps/internal merge-base --is-ancestor $SUBMOD_HEAD origin/main \
  && echo "OK reachable" || echo "ORPHAN — STOP"

# 5. Si ORPHAN :
#    - commit local non poussé  -> pousser le submod d'abord (PR + merge)
#    - sinon                    -> git -C mcps/internal reset --hard origin/main
```

## Anti-patterns

- `git submodule update --init --recursive` puis `git add mcps/...` puis `git commit` → checkout
  arbitraire = pointeur arbitraire.
- « Résoudre un conflit submod » sans vérifier la cible : `git checkout HEAD -- mcps/...` ou
  `git checkout --theirs mcps/...` peuvent pointer vers une SHA orpheline.
- Push direct sur `main` avec pointeur changé sans avoir d'abord ouvert **et mergé** la PR submod.

## Pattern correct (PR submod puis parent)

1. Travailler dans le submod : commit + push sur une branche du submod.
2. `gh pr create --repo jsboige/jsboige-mcp-servers ...`
3. Attendre le merge → récupérer la SHA de squash : `gh pr view N --json mergeCommit`.
4. **Après** merge submod seulement, créer le pointer-bump parent vers cette SHA.
5. PR parent → merge.

Voir aussi la section « Anti pointer-bump prématuré » de `.claude/rules/pr-mandatory.md`.

## Cas légitimes de modification d'un pointeur

- Bundle pointer-bump après merge de plusieurs PRs submod (pattern cycle 31 W7).
- Re-bump après un squash-merge qui a changé la SHA cible.
- Recovery après corruption : repointer vers une SHA canonique connue atteignable.

Dans **tous** ces cas, la vérification `cat-file -e` après fetch reste obligatoire.

## Post-mortem — pointeur orphelin détecté sur `main`

1. **NE PAS force-push** sur `main` (interdit, et risque de perte de travail utilisateur).
2. Créer une PR de fix qui repointe vers la SHA canonique (lineage `main` upstream).
3. Documenter l'incident dans MEMORY.md : les SHAs et le commit fautif.
4. Proposer un fix structurel sur le dashboard pour approbation utilisateur.
