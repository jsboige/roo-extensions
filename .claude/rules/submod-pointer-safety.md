# Submodule Pointer Safety — Interactive Agent Guard

**Version:** 1.0.0
**Issue :** #2089 follow-up (incident 2026-05-11 commit `67514ec1`)
**MAJ:** 2026-05-11

---

## Règle Absolue

**Avant tout commit modifiant un pointer submodule (`mcps/internal`, `mcps/external/win-cli/server`, `roo-code`), VÉRIFIER que la SHA cible est `git cat-file -e` après `git fetch upstream/origin` du submodule.**

Si la SHA n'est pas reachable depuis upstream → **STOP**. Push d'abord le commit submodule sur son upstream, ou reset à `origin/main` du submodule.

## Pourquoi cette règle existe

**Incident 2026-05-11** : Commit `67514ec1 fix(mcp): resolve submodule conflict and update win-cli deployment` (push direct main, jsboige token, Co-Authored-By Claude Opus 4.6) a posé le pointer `mcps/internal` vers SHA `0464277894e953025e622807cbc872a537fad16d` qui n'était sur **aucune** branche remote du submodule. Conséquence : `git pull` flotte-wide → `fatal: remote error: upload-pack: not our ref 0464...`. CI `check-submodule-pointer` cassée.

L'agent voulait traiter #1967 (win-cli deployment) qui concerne `mcps/external/win-cli/server`, mais a touché `mcps/internal` par confusion (probablement après un `git submodule update --init --recursive` qui checkout un état stale).

## Garde-fou existants

- **Worker scheduled (`start-claude-worker.ps1`)** : `Reset-PhantomSubmodulePointers` (Guard #1156 v2, lignes 1846-1909) reset tout pointer submod vers `origin/main` si la SHA n'est pas sur upstream. **Robuste pour worker.**
- **CI `check-submodule-pointer`** : bloque les PRs avec pointer cassé. **MAIS** ne bloque pas les push direct sur main (token OWNER).
- **`.claude/rules/pr-mandatory.md`** : "AUCUN push direct sur `main`". Mais user OWNER + agent peut bypasser.

## Ce qui manque (= cette règle)

**Pour les sessions Claude Code interactives** (ne passent pas par worker.ps1), aucun garde automatique. La présente règle comble ce trou.

## How to apply

### Avant tout commit avec pointer submod modifié

```bash
# 1. Identifier les submodules modifiés
git status --porcelain | grep -E '^\s*M\s+(mcps/|roo-code)'

# 2. Pour chaque submod modifié, récupérer le HEAD local
SUBMOD_HEAD=$(git -C mcps/internal rev-parse HEAD)

# 3. Fetch upstream du submod
git -C mcps/internal fetch upstream main 2>&1 || git -C mcps/internal fetch origin main

# 4. Vérifier que la SHA est reachable
git -C mcps/internal merge-base --is-ancestor $SUBMOD_HEAD origin/main && echo "OK reachable" || echo "ORPHAN — STOP"

# 5. Si ORPHAN :
#    - Soit la SHA correspond à un commit local non pushé : push d'abord le submod (gh pr create + merge)
#    - Soit reset : git -C mcps/internal reset --hard origin/main
```

### Anti-patterns à JAMAIS faire

- ❌ `git submodule update --init --recursive` puis `git add mcps/...` puis `git commit` → checkout aléatoire = pointer arbitraire
- ❌ "Resolve submodule conflict" sans verifier la cible : `git checkout HEAD -- mcps/...` ou `git checkout --theirs mcps/...` → peut pointer vers SHA orpheline
- ❌ Push direct sur main avec submod pointer changé sans avoir d'abord ouvert PR submod et l'avoir mergée

### Pattern correct (workflow PR submod + parent)

1. Travail sur le submod dans son worktree : commit + push sur branche du submod
2. Ouvrir PR submod : `gh pr create --repo jsboige/jsboige-mcp-servers ...`
3. Attendre merge submod → récupérer SHA squash : `gh pr view N --json mergeCommit`
4. **APRÈS merge submod**, créer le pointer-bump parent vers cette SHA squash
5. PR parent → merge

**Référence anti pointer-bump premature : `.claude/rules/pr-mandatory.md` section dédiée.**

## Cas d'usage légitime modifier pointer

- Bundle pointer-bump après merge multiple PRs submod (cycle 31 W7 pattern)
- Re-bumping après squash-merge change la SHA cible
- Recovery après corruption pointer (cas présent : repointer vers SHA canonique connue reachable)

Dans tous ces cas : **toujours vérifier `git cat-file -e` après fetch** avant le commit du pointer-bump parent.

## Si tu détectes un pointer orphelin sur main (post-mortem)

1. **NE PAS force-push** sur main (interdit + risque de perte travail user)
2. Créer PR de fix qui repointe vers SHA canonique (lineage main upstream)
3. Documenter l'incident dans MEMORY.md avec les SHAs et le commit fautif
4. Proposer fix structurel (cette règle, hook git, etc.) sur dashboard pour approbation user
