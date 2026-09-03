# Issue #3345 — Agent harness isolation worktree bug (Windows, cross-repo)

**Date:** 2026-08-31
**Issue:** [#3345](https://github.com/jsboige/roo-extensions/issues/3345)
**Reporter:** jsboige (OWNER) on 2026-08-31 15:09Z
**Analysts:** jsboige (probes 15:29Z), myia-po-2023 (cause 15:42Z, c.286), claude on myia-web1 (mitigation 2026-08-31 18:15Z), myia-po-2026 (defect-class measurement 2026-09-02, c.343), myia-po-2024 (live re-validation on 2.1.86, 2026-09-03)
**Status:** ⚠️ **UPSTREAM BUG** — root cause lives in the Claude Code Agent tool, not in this repository. **Not reproducible on Claude Code 2.1.86** under a reconstructed trigger (see *Live re-validation* below); the original harness version is unknown and may still carry D1.

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

### Class 3 — D1, the refusal itself: strict path comparison without Windows normalization (measured 2026-09-02, myia-po-2026)

Re-read the reported error: the refused path and the "resolves to" path **are the same
location**, differing only in drive-letter case and separators:

```
Refusing to use d:\dev\CoursIA-2\.claude\worktrees\agent-aa68ca4c87a32b5a0 ...
git resolves its working tree to D:/dev/CoursIA-2/.claude/worktrees/agent-aa68ca4c87a32b5a0
```

A worktree that resolves to itself cannot make commands "write outside the worktree" — the
validator's conclusion is false. The owner's probes (2026-08-31 15:32Z) already falsified the
message's own parenthetical guesses for this instance: no repo above `C:/dev`, no `core.worktree`
set, standard gitfiles. What remains is a **strict string comparison** between the path form the
harness held (`d:\...`, lowercase drive, backslashes) and git's canonical output (`D:/...`,
uppercase, forward slashes).

**Measured firsthand** (myia-po-2026, 2026-09-02, git 2.55.0.windows.4, Windows 11):

```
variant:   c:\Users\...\repo\.claude\worktrees\agent-x      (lowercase drive, backslashes)
resolved:  C:/Users/.../repo/.claude/worktrees/agent-x      (git -C <variant> rev-parse --show-toplevel)
strict equality: FALSE — while both denote the same worktree
read-only command from the variant cwd: OK (anchors inside the worktree)
```

Git canonicalizes the drive letter to uppercase and separators to `/` **even when invoked with
the lowercase/backslash form**. Any `resolved !== expected` comparison (no case-fold, no
separator-fold) false-positives on this exact pair — producing precisely the reported refusal.
Pinned as a regression test in `agent-worktree-isolation.Tests.ps1` (Context *Windows
path-normalization defect class*), which also encodes the correct comparison semantics
(fold separators + case on win32).

The lowercase form enters when the session/project path is recorded as typed or as reported by
shells that render the drive letter lowercase (e.g. git-bash `/d/dev/...`). Trigger condition:
any recorded path whose drive case differs from git's canonical output — **sibling repos are not
required** for this class.

**Defect split (supersedes the single "cross-repo collision" reading of the refusal):**

| # | Defect | Evidence | Status |
|---|--------|----------|--------|
| D1 | Validator false-positive: strict path comparison, no win32 normalization | error text (refused ≡ resolved modulo case/separators) + owner probes falsifying redirects + measurement above | **VERIFIED** (primitive-level) |
| D2 | Cross-repo admin/physical mismatch (po-2023 c.286 observation) explains the orphan topology | `gitdir` files read firsthand by po-2023 | **REPORTED** — mechanism unverified (the provisioner binary, newer than any local install, was not inspectable; local harness is 2.1.41, which predates the isolation feature) |
| D3 | No cleanup on provisioning failure (locked orphans left behind) | `git worktree list` after both failures (issue + po-2023) | **VERIFIED** — mitigated defensively in this repo |

---

## Live re-validation on Claude Code 2.1.86 (myia-po-2024, 2026-09-03)

All probes firsthand on myia-po-2024 (Claude Code **2.1.86**, git 2.51.0.windows.1, Windows 11).
This is the first live exercise of the actual provisioner on a current install — po-2026's 2.1.41
predates the isolation feature, so only the git-level primitive had been measurable until now.

| # | Question | Method | Result |
|---|----------|--------|--------|
| R1 | Does D1 (path false-positive) fire on an uppercase-C session? | Probe A: in-session `Agent(isolation="worktree")` (real repo; session cwd itself a linked worktree) | Launched, **no refusal**. Worktree created under the **main repo root's** `.claude/worktrees/agent-<8hex>` |
| R2 | Does D1 fire under the reported trigger (lowercase drive letter)? | Probe B: headless `claude -p` spawned via CreateProcess with `cwd: d:\tmp-3345-probe\repo` — lowercase form verified preserved into the child's `process.cwd()` — scratch repo with 2 historical worktrees in `.claude/worktrees/` | Agent call **succeeded** (37.9 s run): **no refusal** |
| R3 | Cleanup after agent completion (D3, success path) | `git worktree list` + `git branch` after both probes | **Zero debris**: worktree dir removed, registry entry pruned, `worktree-agent-*` branch deleted, 0 locked entries — both probes |
| R4 | `isolation="remote"` silent local fallback (F2)? | Agent tool schema on 2.1.86 | `isolation` enum is `["worktree"]` **only** — `remote` is not an offered mode; an invalid value is rejected at schema level, so the silent remote→local fallback cannot occur |
| R5 | Merged Windows test suite on an actual Windows runner | Local Pester 5.7.1 run of `agent-worktree-isolation.Tests.ps1` (CI `unit-pester` runs ubuntu and skips the D1 context) | **12/12 passed**, including the Windows-guarded D1 path-normalization context |

Mechanistic notes: the worktree path is built from the **resolved main working tree** (probe A:
session cwd was inside a linked worktree, yet the agent worktree landed under the primary repo
root), which suggests 2.1.86 no longer derives the worktree path from the raw session cwd string —
the D1 entry vector. The id format also differs (`agent-<8 hex>` vs the incident's
`agent-<16 hex>`), confirming a different provisioner generation.

**Scope of the claim (do not over-read):** D1 is *not reproducible on 2.1.86 under a
deterministically reconstructed trigger*. The harness that produced the 2026-08-31 incident is of
unknown version — it accepted `isolation="remote"`, which 2.1.86 does not even offer — so it is a
different build lineage that may still carry D1. The upstream report below remains worth filing,
with the version pinned; the 2.1.86 datapoint goes in it as "latest stable does not reproduce".

---

## Why this repo cannot fully fix it

The error message is generated inside the Claude Code binary. `grep -R "Refusing to use" .` in this repo returns 0 hits in production source (verified 2026-08-31 18:15Z, web1). Fixing the provisioner logic would require:

- **Path normalization before comparison** (D1): on win32, fold drive-letter case and separators
  when comparing the held worktree path against `git rev-parse --show-toplevel` output (or compare
  via case-insensitive realpath resolution). Without this, any session whose recorded path carries
  a lowercase drive letter is refused even when the worktree is perfectly isolated.
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

12 tests covering:
- A normal `git worktree add` produces an actually isolated worktree (`rev-parse --show-toplevel` matches the worktree path).
- `core.worktree` and `gitdir` point under the parent repo's `.git/worktrees/`.
- The cleanup script detects a synthetic locked `agent-*` worktree.
- DRY-RUN does not unlock.
- `-Execute` unlocks + prunes.
- A locked worktree whose PID is alive is left alone.
- Non-`agent-*` worktrees are ignored by default.
- `-NamePattern` allows matching other patterns.
- Cross-repo orphans: default `-Execute` SKIPs (defense); `-AllowCrossRepo` cleans them with nothing locked left behind.
- **D1 defect class (Windows)**: a lowercase-drive/backslash path variant of a worktree resolves to the same canonical toplevel; a strict string comparison false-positives (the reported refusal class) while a case/separator-folded comparison passes. Skips on non-Windows (CI `unit-pester` runs ubuntu).
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
| 1. Reproduce on Windows with multiple historical worktrees | ✅ po-2023 c.286 (synthetic + live observation) · real-repo dry-run audit po-2026 2026-09-02 (`C:/dev/CoursIA-2`: 20+ historical sibling worktrees, 0 `agent-*` orphan remaining, script exits clean) | — |
| 2. Fix `.git` / `core.worktree` creation/validation | ❌ Upstream — refined 2026-09-02: the refusal is D1 (strict path comparison, no win32 normalization), see Class 3. **Not reproducible on 2.1.86** (R2, 2026-09-03); incident build unknown | `anthropics/claude-code` |
| 3. `isolation="remote"` does not silently use local provisioner | ❌ Upstream (fallback observed firsthand in the issue). On 2.1.86 `remote` is **not an offered mode** (schema enum `["worktree"]` only, R4) — silent fallback structurally impossible there | `anthropics/claude-code` |
| 4. Auto-cleanup on provisioning failure | ⚠️ Partial — defensive script. Success-path cleanup verified clean on 2.1.86 (R3); the original *failure-path* refusal no longer triggers, so its orphan-producing path could not be re-exercised | `scripts/maintenance/cleanup-agent-orphan-worktrees.ps1` |
| 5. Windows test creating agent worktree + checking `rev-parse --show-toplevel` | ✅ 12 tests (incl. D1 normalization defect class, Windows-guarded) | `scripts/testing/unit/agent-worktree-isolation.Tests.ps1` |
| 6. No orphan locked worktree after provisioning failure | ⚠️ Partial — defensive script | same as #4 |

---

## Upstream ticket recommendation

When filing in the upstream `anthropics/claude-code` repository (or wherever the Agent tool lives), the technical content is:

> **Pin the harness version.** The incident build (2026-08-31) is unidentified — it accepted
> `isolation="remote"`, which Claude Code 2.1.86 does not offer — while 2.1.86 does **not**
> reproduce D1 under a reconstructed lowercase-drive trigger (worktree path appears to be derived
> from the resolved main working tree, not the raw session cwd). The report should state both
> facts so upstream can bisect between the two builds.


> **Title:** Agent isolation worktree validation false-positives on Windows (drive-letter case / separator normalization)
>
> **Steps to reproduce:**
> 1. On Windows, start a session whose recorded project path carries a lowercase drive letter (e.g. launched from a shell reporting `/d/dev/...`, project path held as `d:\dev\MyRepo`).
> 2. Invoke an `Agent` with `isolation="worktree"`.
> 3. The provisioner creates `.claude/worktrees/agent-XXXX` under the held path form, then validates: `git rev-parse --show-toplevel` inside the worktree returns the canonical form (`D:/dev/MyRepo/.claude/worktrees/agent-XXXX`).
> 4. The pre-flight validator compares the held form against the canonical form with strict string equality, concludes the resolution points outside the worktree, and refuses — although the worktree resolves to itself. The created worktree is left `locked` (no cleanup on the failure path).
> 5. Observed in the wild with path-prefix sibling repos also present (`D:/dev/CoursIA` vs `D:/dev/CoursIA-2`), but siblings are NOT required for this class — only the case/separator mismatch is.
>
> **Expected:**
> - Normalize both sides before comparing on win32 (fold drive-letter case and separators, or compare via case-insensitive realpath) — the refused and resolved paths in the reported error denote the same location.
> - The provisioner must also reject genuine cross-repo name collisions (`agent-XXXX` registered in one repo, physical tree under a sibling repo — observed on myia-po-2023: admin in `CoursIA-2/.git/worktrees/`, tree under `CoursIA/.claude/worktrees/`).
> - `isolation="remote"` must not silently fall back to the local provisioner; if the remote target is unavailable, return an explicit error naming the mode actually used.
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
