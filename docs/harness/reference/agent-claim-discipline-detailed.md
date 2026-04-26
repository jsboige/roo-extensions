# Agent Claim Discipline — Garde-fous Harness

**Source :** `.claude/rules/agent-claim-discipline.md` (version slim)
**Issues :** #1605, #1666 Phase A2

---

## Classes d'incidents a prevenir

| Pattern | Exemple | Consequence |
|---|---|---|
| **Hallucination de commit** | "J'ai commite `826894f5...`" alors que `git cat-file -e` echoue | Travail perdu |
| **Commit orphelin non-pousse** | Vrai commit local, jamais push, worktree nettoye → GC | Travail perdu silencieusement |
| **PR fantome** | "PR creee" sans URL, ou URL 404 | Review impossible |
| **Push fantome** | "Pousse" alors que `git log origin/BRANCH -1` ne contient pas le SHA | Workflow deraille |
| **Exit-code fallacy** | Script exit 0 → caller traite comme succes → ne verifie pas l'artefact | Amplificateur systemique |
| **Detached HEAD silent loss** | Worker commit sur detached HEAD → worktree cleanup → GC perd le travail | Travail perdu silencieusement |

---

## Garde-fous Worker Scripts (`scripts/scheduling/start-claude-worker.ps1`)

Le worker DOIT, avant de poster son `[RESULT]` final :

1. Si `$PrUrl` est cite → `gh pr view $PrUrl` doit reussir
2. Si un commit est cite → le SHA doit etre reachable depuis `origin/<branch>`
3. Sinon → "completed (no code changes needed)", PAS "PASS — commit X"
4. **Detached HEAD guard (#1613 + #1666 A2)** : triple-guard avant/pendant/apres :
   - Pre-commit : `git symbolic-ref -q HEAD` — si echec, creer `worker/recovery-YYYYMMDD-HHMMSS`
   - Post-commit : re-verifier HEAD attache + reachable via `git branch --contains`
   - Pre-push : refuser si `git rev-parse --abbrev-ref HEAD` retourne "HEAD"
   - Post-push : verifier `git ls-remote origin refs/heads/<branch>` retourne le SHA local
   - Si guard a tire : `[RESULT]` DOIT inclure `[RECOVERY_BRANCH] <nom>`

## Garde-fous Spawn/Poll Scripts (`scripts/dashboard-scheduler/spawn-claude.ps1`)

Distinguer :
- Exit 0 reel = succes
- Exit 1 avec `auto-compact produit reply` = succes deguise (OK, cf. #1423)
- Exit 1 avec `rapid_refill_breaker` = **vrai echec** (cf. #1605)

---

## Sanctions

- **1er incident** : capture MEMORY/dashboard + rappel
- **2e incident meme classe** : escalade issue `needs-approval`
- **Pattern systemique (>=3)** : modifier le harness concerne
