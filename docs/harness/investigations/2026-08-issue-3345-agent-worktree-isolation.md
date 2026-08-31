# Issue #3345 — Agent harness isolation worktree bug (Windows, cross-repo)

**Date:** 2026-08-31
**Issue:** [#3345](https://github.com/jsboige/roo-extensions/issues/3345)
**Reporter:** jsboige (OWNER) on 2026-08-31 15:09Z
**Analysts:** jsboige (probes 15:29Z), myia-po-2023 (cause 15:42Z, c.286), claude on myia-web1 (mitigation 2026-08-31 18:15Z)
**Status:** ⚠️ **UPSTREAM BUG** — root cause lives in the Claude Code Agent tool, not in this repository.

---

## TL;DR

The error message **`Refusing to use ... as an isolation worktree: git resolves its working tree to ...`** originates from the Claude Code Agent tool's pre-flight validation, not from any file in `jsboige/roo-extensions`. The repo's response is therefore **defensive mitigation, not a root-cause fix**:

1. `scripts/maintenance/cleanup-agent-orphan-worktrees.ps1` — detect and unlock orphan `agent-*` worktrees that the harness leaves locked after a failed provisioning.
2. `scripts/testing/unit/agent-worktree-isolation.Tests.ps1` — Pester tests verifying that `git worktree add` produces an actually isolated worktree (the guard the upstream harness *should* enforce).
3. This document — scope, manual cleanup procedure, and the upstream ticket.

**The upstream bug must be fixed in `anthropics/claude-code` (or the relevant harness repository).** All 6 acceptance criteria of #3345 cannot be fully satisfied from this repo alone.

---

## Reproduction

```powershell
# On a Windows machine where two repos share a path prefix
# (e.g. D:/Dev/CoursIA and D:/Dev/CoursIA-2)
cd D:/Dev/CoursIA-2
claude --agent pr-helper --isolation worktree --model sonnet --prompt "..."
```

Result:

```
Refusing to use d:\dev\CoursIA-2\.claude\worktrees\agent-aa68ca4c87a32b5a0 as an isolation worktree:
git resolves its working tree to D:/dev/CoursIA-2/.claude/worktrees/agent-aa68ca4c87a32b5a0
(a core.worktree redirect, or a checkout discovered above it), so commands run there would write outside the worktree.
Remove the redirect, restore the worktree's own .git, or recreate the worktree, then retry.
```

`git worktree list` afterwards shows the agent-* entries created and `locked`, with no cleanup:

```
D:/Dev/CoursIA-2/.claude/worktrees/agent-a9ff221497ceadf2a ... locked
D:/Dev/CoursIA-2/.claude/worktrees/agent-aa68ca4c87a32b5a0 ... locked
```

`isolation="remote"` produces the same failure (silent fallback to local provisioner).

---

## Cause analysis (verified by myia-po-2023 c.286)

Three contributing factors, only one of which can be partially mitigated here:

| # | Factor | Where | In this repo? |
|---|--------|-------|---------------|
| **F1** | The `agent-XXXX` name has no cross-repo guard | Agent tool provisioner (upstream) | ❌ No |
| **F2** | `isolation="remote"` silently falls back to the local provisioner | Agent tool remote mode (upstream) | ❌ No |
| **F3** | No try/finally cleanup on provisioning failure | Agent tool (upstream) | ⚠️ Partially — defensive cleanup only |
| **F4** | Orphan `agent-*` worktrees accumulate (effect) | Filesystem / git registry | ✅ Yes — `cleanup-agent-orphan-worktrees.ps1` |

### Class 1 (cross-repo path collision)

When two repos share a path prefix (`D:/Dev/CoursIA` and `D:/Dev/CoursIA-2`), git's `core.worktree` resolution can match either repo's `.git/worktrees/agent-*` admin. The harness's validator sees a `gitdir` path that resolves outside the worktree's expected scope and refuses (fail-closed — the isolation barrier does its job).

### Class 2 (proven by po-2023 c.286)

`gitdir` content observed on `D:/Dev/CoursIA-2/.git/worktrees/agent-a5476242efb0be670/gitdir`:

```
D:/Dev/CoursIA/.claude/worktrees/agent-a5476242efb0be670/.git
```

The admin is registered in `CoursIA-2` but points physically into `CoursIA` (a sibling repo). Same root cause: cross-repo name collision.

---

## Why this repo cannot fully fix it

The error message is generated inside the Claude Code binary. `grep -R "Refusing to use" .` in this repo returns 0 hits in production source (verified 2026-08-31 18:15Z, web1). Fixing the provisioner logic would require:

- A `git worktree add agent-XXXX` cross-repo collision check before name reuse
- A `try/finally` cleanup block in the provisioner when downstream validation fails
- A real `isolation="remote"` path that does not silently fall back to local

These are upstream changes in `anthropics/claude-code`.

---

## What this repo provides (defensive mitigation)

### 1. Cleanup script: `scripts/maintenance/cleanup-agent-orphan-worktrees.ps1`

Detects `agent-*` worktrees that are `locked` but whose locking PID is no longer alive, and unlocks+prunes them. Default is dry-run; `-Execute` actually performs the cleanup.

```powershell
# Dry-run: report orphans without unlocking
pwsh -File scripts/maintenance/cleanup-agent-orphan-worktrees.ps1

# Actually unlock + prune
pwsh -File scripts/maintenance/cleanup-agent-orphan-worktrees.ps1 -Execute

# Custom pattern (e.g. for a specific test scenario)
pwsh -File scripts/maintenance/cleanup-agent-orphan-worktrees.ps1 -NamePattern 'worktree-*' -Execute
```

Safety:
- Uses `scripts/common/path-guards.ps1` (#2772/#2123) to refuse any deletion target outside the repo root.
- Skips worktrees whose locking PID is currently alive (refuses to act on a live agent).

### 2. Pester tests: `scripts/testing/unit/agent-worktree-isolation.Tests.ps1`

8 tests covering:
- A normal `git worktree add` produces an actually isolated worktree (`rev-parse --show-toplevel` matches the worktree path).
- `core.worktree` and `gitdir` point under the parent repo's `.git/worktrees/`.
- The cleanup script detects a synthetic locked `agent-*` worktree.
- DRY-RUN does not unlock.
- `-Execute` unlocks + prunes.
- Non-`agent-*` worktrees are ignored by default.
- `-NamePattern` allows matching other patterns.
- Static guard: the upstream error message must not appear in this repo's production source (test file excluded).

### 3. Manual cleanup procedure (USER-GATED, before this script existed)

Documented by myia-po-2023 c.286 for `CoursIA-2` on `D:/Dev`:

```bash
# 1. Verify the locking PID is dead
tasklist /FI "PID eq 16716"   # must return "no tasks"

# 2. Unlock the orphan worktree (from the repo that owns the admin entry)
git -C D:/Dev/CoursIA-2 worktree unlock D:/Dev/CoursIA/.claude/worktrees/agent-a5476242efb0be670

# 3. Remove + prune
git -C D:/Dev/CoursIA-2 worktree remove --force D:/Dev/CoursIA/.claude/worktrees/agent-a5476242efb0be670
git -C D:/Dev/CoursIA-2 worktree prune
```

⚠️ The harness should perform steps 2-3 automatically; doing them manually is a workaround.

---

## Acceptance criteria status

| Criterion | Status | Where |
|-----------|--------|-------|
| 1. Reproduce on Windows with multiple historical worktrees | ✅ Reproduction verified (po-2023 c.286 + this PR's test) | — |
| 2. Fix `.git` / `core.worktree` creation/validation | ❌ Upstream | `anthropics/claude-code` |
| 3. `isolation="remote"` does not silently use local provisioner | ❌ Upstream | `anthropics/claude-code` |
| 4. Auto-cleanup on provisioning failure | ⚠️ Partial — defensive script | `scripts/maintenance/cleanup-agent-orphan-worktrees.ps1` |
| 5. Windows test creating agent worktree + checking `rev-parse --show-toplevel` | ✅ | `scripts/testing/unit/agent-worktree-isolation.Tests.ps1` |
| 6. No orphan locked worktree after provisioning failure | ⚠️ Partial — defensive script | same as #4 |

---

## Upstream ticket recommendation

When filing in the upstream `anthropics/claude-code` repository (or wherever the Agent tool lives), the technical content is:

> **Title:** Generated isolation worktrees fail validation on Windows when path-prefix sibling repos exist
>
> **Steps to reproduce:**
> 1. Have two repos with a path-prefix sibling relationship (e.g. `D:/Dev/CoursIA` and `D:/Dev/CoursIA-2`).
> 2. Invoke an `Agent` with `isolation="worktree"`.
> 3. The provisioner creates `.claude/worktrees/agent-XXXX` with a `gitdir` admin that may resolve across repos.
> 4. The pre-flight validator refuses: "Refusing to use ... as an isolation worktree".
>
> **Expected:**
> - The provisioner must reject cross-repo name collisions (`agent-XXXX` already in any accessible sibling repo) or suffix the name (e.g. `agent-XXXX-CoursIA-2`).
> - `isolation="remote"` must not silently fall back to the local provisioner; if the remote target is unavailable, return an explicit error.
> - On validation failure, the just-created worktree must be unlocked + pruned (try/finally).
> - No orphan locked worktree entries should remain after a failure.
>
> **Workaround (until fixed):** `scripts/maintenance/cleanup-agent-orphan-worktrees.ps1 -Execute` from the roo-extensions repo.

---

## Related

- **#2772** — submodule deletion guard (used by the cleanup script via `path-guards.ps1`)
- **#2123** — nested-worktree guard (same module)
- **#1913** — worktree-husk prevention (worker-side cleanup, related class)
- **po-2023 c.286** — original cause analysis in dashboard intercom
