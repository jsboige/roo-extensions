# Orphan Branches Audit — 2026-05-01

**Issue:** #1666 Phase D
**Machine:** myia-web1
**Script:** `scripts/cleanup-orphan-branches.ps1`

## Summary

| Category | Count |
|----------|-------|
| Total remote branches | 553 |
| Protected (main) | 1 |
| Recent (<30 days) | 444 |
| **Safe to delete** | **103** |
| Need review | 5 |
| Open PRs | 7 |

## Safe to Delete (103 branches)

### Worker branches (65)
All `wt/worker-myia-*` branches older than 30 days with no open PR. These are
ephemeral branches created by `start-claude-worker.ps1` — safe to delete after
PR merge or close.

### Feature/fix branches (21)
Old `fix/*`, `feat/*`, `chore/*`, `test/*` branches >30 days with no PR.
Likely merged or abandoned.

### Worktree branches (14)
Old `wt/*` (non-worker) branches >30 days with no PR.

### PR/sub branches (3)
Old `pr/*` branches from completed PRs.

## Need Review (5 branches)

| Branch | Date | Note |
|--------|------|------|
| `clean-repo-structure` | 2025-05-14 | Ancient, may have unique history |
| `sauvegarde-urgence-principal-` | 2025-09-21 | Emergency backup — verify before delete |
| `final-recovery-complete` | 2025-09-27 | Recovery branch — verify before delete |
| `recovery-merge` | 2025-11-10 | Recovery branch — verify before delete |
| `copilot-v3-bridge` | 2026-03-10 | Experimental — verify before delete |

## Recommendation

1. **Delete 103 safe branches** using `./scripts/cleanup-orphan-branches.ps1 -DeleteSafe -DryRun:$false`
2. **Review 5 branches** manually before deciding
3. **Schedule recurring cleanup** — add to weekly maintenance (Sunday 03:00 alongside worktree cleanup from #1913)

## Script Usage

```powershell
# Dry run (report only)
./scripts/cleanup-orphan-branches.ps1 -DaysThreshold 30 -DryRun

# Delete safe branches
./scripts/cleanup-orphan-branches.ps1 -DaysThreshold 30 -DeleteSafe -DryRun:$false

# Custom threshold
./scripts/cleanup-orphan-branches.ps1 -DaysThreshold 14 -DryRun
```
