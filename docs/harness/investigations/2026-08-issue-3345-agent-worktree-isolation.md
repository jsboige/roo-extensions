# Issue #3345 — Agent harness isolation worktree bug (Windows, cross-repo)

**Date:** 2026-08-31
**Issue:** [#3345](https://github.com/jsboige/roo-extensions/issues/3345)
**Reporter:** jsboige (OWNER) on 2026-08-31 15:09Z
**Analysts:** jsboige (probes 15:29Z), myia-po-2023 (cause 15:42Z, c.286), claude on myia-web1 (mitigation 2026-08-31 18:15Z), myia-po-2026 (defect-class measurement 2026-09-02, c.343), myia-po-2024 (live re-validation on 2.1.86, 2026-09-03), myia-po-2026 (live reproduction on 2.1.236, 2026-09-07), myia-ai-01 (live reproduction + validator static read on 2.1.269, 2026-09-13), myia-po-2023 (partial-retry datapoint on 2.1.274, 2026-09-17), myia-po-2026 (live reproduction on 2.1.277 + F2 re-confirmed, 2026-09-18), myia-po-2023 (two-arm repair verification on 2.1.283 + in-session reproduction on 2.1.323, 2026-11-17), myia-ai-01 (D4 discrimination two-arm D:/G: + mechanism + parade on 2.1.283/2.1.328/2.1.330, 2026-11-22, #4875)
**Status:** ⚠️ **UPSTREAM BUG — STILL LIVE ON 2.1.323 (2026-11-16/17; VS Code extension channel: in-session ai-01 23:57Z + po-203, plus the po-2025 adjoint-belt canary refused pre-launch 16/11) and on 2.1.283 (npm headless)** — root cause lives in the Claude Code Agent tool, not in this repository. **A second, distinct refusal signature exists (D4, § below, #4875): `Cannot create worktree ... .git/logs/HEAD ... not a plain file, or could not be checked` — DriveFS-hosted repos, provisioner ≥ 2.1.328, still live on 2.1.330; measured mechanism `st_nlink = 0` on DriveFS.** Bisection to date: not reproducible on 2.1.86 and 2.1.141; reproduces deterministically on 2.1.236 / 2.1.269 / 2.1.277 / 2.1.283 / 2.1.323 (on 2.1.274 a normalized-cwd retry masks the refusal but leaves the first worktree `locked` — reported, po-2023 2026-09-17; no auto-retry observed on 2.1.323). **Spawn-site repair verified on 2.1.283 headless 2026-11-17; not re-tested on 2.1.323** (uppercase-drive cwd → provisioning succeeds; two-arm canary, § below — arm B is the repair witness; 2.1.323 datapoint is reproduction only). No CHANGELOG entry as of 2.1.277 (last checked) matches D1. Tracked upstream: [anthropics/claude-code#91618](https://github.com/anthropics/claude-code/issues/91618).

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
| D4 | Pre-creation "plain file" check on `.git/logs/HEAD` fails closed on DriveFS (`st_nlink = 0`) — § dedicated section | two-arm D:/G: witness, 7 runs, 2026-11-22 (#4875) | **VERIFIED** (ai-01, 2.1.328 + 2.1.330; absent on 2.1.283) |

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

> **Superseded 2026-09-07:** "latest stable does not reproduce" no longer holds — see the next
> section. D1, the `remote` silent fallback (F2), and the missing failure-path cleanup (D3) all
> reproduce **deterministically on 2.1.236** (dist-tag `stable` that day). The 2.1.86 datapoint
> remains valid for its version and now bounds the upstream bisection window from below.

---

## Live reproduction on Claude Code 2.1.236 — myia-po-2026 (2026-09-07)

Firsthand, deterministic. Methodology identical to po-2024's R2 probe, refreshed for the then-current
stable:

- Scratch repo `C:\Users\jsboi\AppData\Local\Temp\3345-probe\repo` (one commit) with **two historical
  worktrees** under `.claude/worktrees/` (`hist-1`, `hist-2`) — the criterion-1 trigger condition.
- Headless claude spawned via `ProcessStartInfo.WorkingDirectory` set to the **lowercase-drive form**
  `c:\Users\jsboi\AppData\Local\Temp\3345-probe\repo`; preservation into the child verified
  (`node process.cwd(): c:\Users\jsboi\AppData\Local\Temp\3345-probe\repo`).
- Claude Code **2.1.236** (dist-tag `stable` on 2026-09-07) via
  `npx -y @anthropic-ai/claude-code@2.1.236` — npx cache hash `f49fa6589d7d9c67` verified to carry
  `package.json` version 2.1.236 — with `DISABLE_AUTOUPDATER=1` so the machine's 2.1.41 install was
  untouched. Machine's standard provider env (proxy auth) inherited unchanged.
- Prompt: Task call with `isolation="worktree"` (step 1), Task call with `isolation="remote"`
  (step 2), then `git worktree list` (step 3).

| # | Question | Result |
|---|----------|--------|
| R1′ | Does D1 fire under the lowercase-drive trigger on 2.1.236? | **YES — verbatim incident refusal** (below) |
| R2′ | Is `isolation="remote"` schema-rejected (as R4 measured on 2.1.86)? | **NO — accepted, and it silently provisioned a LOCAL worktree** → same refusal, second agent id. F2 is live on stable |
| R3′ | Orphan locks after the refusal (D3)? | **YES — two `locked claude agent agent-… (pid 30992)` entries + directories left behind**, zero cleanup on the failure path |
| R4′ | Is the worktree admin actually corrupt (real redirect)? | **NO** — gitfile `gitdir: C:/…/repo/.git/worktrees/agent-a75f651045fa09cc5`, admin `gitdir` back-pointer consistent, `core.worktree` unset → the refusal's parenthetical guesses are falsified; refused ≡ resolved modulo drive-letter case + separators |

Verbatim refusal (step 1, `isolation="worktree"`):

```
Refusing to use c:\Users\jsboi\AppData\Local\Temp\3345-probe\repo\.claude\worktrees\agent-a75f651045fa09cc5 as an isolation worktree:
git resolves its working tree to C:/Users/jsboi/AppData/Local/Temp/3345-probe/repo/.claude/worktrees/agent-a75f651045fa09cc5
(a core.worktree redirect, or a checkout discovered above it), so commands run there would write outside the worktree.
Remove the redirect, restore the worktree's own .git, or recreate the worktree, then retry.
```

Step 2 (`isolation="remote"`) produced the **same refusal** for a second locally created worktree
(`agent-a1b07c0053e8af1de`): `remote` is an accepted enum value on 2.1.236 that stages a **local**
worktree without any error naming the mode actually used. **This overturns the 2.1.86-era R4
reading** ("remote structurally impossible") — the schema changed between the two builds and F2 is
live again on stable. Post-run registry (excerpt):

```
worktree C:/Users/jsboi/AppData/Local/Temp/3345-probe/repo/.claude/worktrees/agent-a1b07c0053e8af1de
branch refs/heads/worktree-agent-a1b07c0053e8af1de
locked claude agent agent-a1b07c0053e8af1de (pid 30992)
worktree C:/Users/jsboi/AppData/Local/Temp/3345-probe/repo/.claude/worktrees/agent-a75f651045fa09cc5
branch refs/heads/worktree-agent-a75f651045fa09cc5
locked claude agent agent-a75f651045fa09cc5 (pid 30992)
```

### Bisection window for upstream

- 2.1.41 — feature absent (no `isolation` parameter on the Task tool).
- 2.1.86 — **no repro** (R2, po-2024 2026-09-03; worktree path apparently derived from the resolved
  main working tree, not the raw session cwd).
- 2.1.141 — **no repro** (po-2023, 2026-09-10; both uppercase and lowercase cwd forms tested).
- 2.1.236 — **reproduces** (this probe; deterministic; the raw lowercase cwd string is back in the
  comparison chain).
- 2.1.238 / 2.1.257 / 2.1.259 — CHANGELOG entries touch worktree-isolation **Bash-command** refusals,
  not pre-flight provisioning validation; no entry up to 2.1.263 (checked 2026-09-07) matches D1.
- 2.1.269 — **reproduces** (myia-ai-01, 2026-09-13 — see the dedicated section above; also the first
  datapoint taken from the **VS Code extension** distribution channel rather than an npm install).
- 2.1.274 — **reproduces, with partial retry mitigation** (reported by po-2023, 2026-09-17 — issue
  #3345 datapoint #18): first attempt refused verbatim, harness retries with normalized cwd and the
  agent starts; the refused worktree stays `locked` (D3 unchanged).
- 2.1.277 — **reproduces, terminal** (myia-po-2026, 2026-09-18 — see the dedicated section above;
  dist-tag `latest` that day). F2 silent local fallback re-confirmed live on this build.
  CHANGELOG 2.1.275–2.1.277 has no matching fix entry (checked 2026-09-18).
- 2.1.283 — **reproduces (npm headless, arm A) and repair-arm verified green (arm B)** (myia-po-2023,
  2026-11-17 — see the two-arm section below; two months after the previous datapoint, D1 unchanged).
- 2.1.323 — **reproduces, terminal, no auto-retry** (VS Code extension channel): in-session canaries
  myia-ai-01 2026-11-16 23:57Z and myia-po-2023 2026-11-17 (both lowercase-drive session cwd →
  verbatim refusal), and the myia-po-2025 `adjoint-belt-20261116-45` canary refused pre-launch
  2026-11-16 (escalated `[DEGRADED]` on the roo-extensions dashboard 20:03Z).
- 2.1.328 — **reproduces** (ai-01 #4875 control arm 6, 2026-11-22: lowercase-drive headless cwd via
  `ProcessStartInfo` → verbatim D1 refusal + `locked` orphan `agent-ae3db21330b9c4962` + residual
  `worktree-agent-*` branch). 2.1.330 — D1 reported upstream (zachrisdev, 2026-11-21, local drive);
  the same 2.1.330 build refuses on DriveFS with the **D4** signature instead (§ below).

Upstream tracker: [anthropics/claude-code#91618](https://github.com/anthropics/claude-code/issues/91618)
(OPEN, labels `bug`/`has repro`/`platform:windows`/`area:agents`). The 2.1.236 reproduction was posted
there as a bisection datapoint on 2026-09-07.

---

## Live reproduction on Claude Code 2.1.269 — myia-ai-01 (2026-09-13)

Firsthand, deterministic, exact methodology match (scratch repo + **two** historical worktrees under
`.claude/worktrees/` + headless session with **lowercase-drive cwd** preserved, Task call with
`isolation="worktree"`).

**Version provenance — why this datapoint matters for the fleet.** The harness actually serving
agents on myia-ai-01 is **not** the npm global (`claude --version` → 2.1.17, which predates the
feature entirely: the refusal string has 0 occurrences in its `cli.js`, control string 19 —
instrument validated). It is the **VS Code extension**
`~/.vscode/extensions/anthropic.claude-code-2.1.269-win32-x64/`, whose
`resources/native-binary/claude.exe` (222 MB) answers `--version` as 2.1.269 and was installed
2026-09-12. Lesson: on any machine where agents run through VS Code, `claude --version` understates
the effective build — probe the extension's native binary instead.

### Result

Verbatim refusal (worktree id `agent-ae1af2b131ce6c04e`):

```
Refusing to use c:\Users\MYIA\AppData\Local\Temp\probe-3345-269\repo\.claude\worktrees\agent-ae1af2b131ce6c04e as an isolation worktree:
git resolves its working tree to C:/Users/MYIA/AppData/Local/Temp/probe-3345-269/repo/.claude/worktrees/agent-ae1af2b131ce6c04e
(a core.worktree redirect, or a checkout discovered above it), so commands run there would write outside the worktree.
Remove the redirect, restore the worktree's own .git, or recreate the worktree, then retry.
```

Post-run registry:

```
worktree C:/.../probe-3345-269/repo/.claude/worktrees/agent-ae1af2b131ce6c04e
branch refs/heads/worktree-agent-ae1af2b131ce6c04e
locked
```

**D1 reproduces and D3 reproduces**: the just-provisioned worktree is left `locked` with no cleanup
on the refusal path, exactly as on 2.1.236. (Note the `locked` reason field is empty here, unlike
the `(pid NNNN)` form seen on 2.1.236.)

### Static read of the 2.1.269 validator (from the native binary)

The refusal is emitted by a three-valued comparison:

```js
function lN(e, n) { return Fzn(e, n, U7) }                 // "same" | "distinct" | "indeterminate"
function Fzn(e, n, r) { let s = AT(e), d = AT(n);
  if (Tw(s) || Tw(d)) return "indeterminate";
  if (s.skipped !== d.skipped) return "indeterminate";
  return r(s, d) && r(d, s) ? "same" : "distinct" }
function U7(e, n) { /* ... */ return nyn(e.canonical, n.canonical) }   // canonical-vs-canonical
function nyn(e, n) { return B7(e, n, !1) }                 // case-SENSITIVE string compare
```

`AT()` is an up-to-8-iteration realpath-style canonicalizer. **Methodological note (recorded as a
lesson):** reading this statically suggested the canonicalization would fold the drive-letter case
and therefore that D1 might be fixed in 2.1.269. The live probe above **falsified that reading** —
the lowercase-`c:` held form still lands `"distinct"` against git's uppercase-`C:` toplevel, so the
canonical path does not normalize drive-letter case (or the held form bypasses it). Static reading
of a minified validator proposed; only execution disposed.

### `isolation="remote"` on 2.1.269 (criterion 3)

The Task schema still accepts `remote`, but the parameter is now documented distinctly:

> `"worktree"` creates a temporary git worktree so the agent works on an isolated copy of the repo.
> `"remote"` launches the agent in a remote cloud environment (always runs in background; availability is gated).

Whether the 2.1.236-era silent local fallback (F2) still occurs was **not** re-exercised live this
session; the description change is the only 2.1.269 evidence. Last live measurement of F2 remains
R2′ (2.1.236, po-2026).

---

## Live reproduction on Claude Code 2.1.274 (reported) and 2.1.277 (verified) — 2026-09-17 / 2026-09-18

**2.1.274 — RAPPORTE (po-2023, issue #3345 datapoint #18, 2026-09-17).** Same methodology (scratch
repo + 2 historical worktrees + lowercase-drive headless cwd). D1 fires verbatim on first attempt,
but the harness now **retries with a normalized cwd and the agent starts** in a second worktree — a
partial upstream mitigation: the end user no longer sees a failure, yet the first, refused worktree
stays `locked` with no cleanup (D3 unchanged).

**2.1.277 — VERIFIE (myia-po-2026, 2026-09-18; dist-tag `latest` that day, via
`npx -y @anthropic-ai/claude-code@2.1.277`, `DISABLE_AUTOUPDATER=1`).** Methodology identical:
scratch repo `c:\Users\jsboi\AppData\Local\Temp\3345-probe-277\repo`, lowercase-drive cwd verified
preserved in the child's `process.cwd()`, two historical worktrees (`hist-1`, `hist-2`).

| # | Question | Result |
|---|----------|--------|
| R1″ | Does D1 fire under the lowercase-drive trigger on 2.1.277? | **YES — verbatim refusal** (`agent-ab3b6c2b3ec1747e6`, `isolation="worktree"`): refused `c:\…` ≡ resolved `C:/…` modulo drive-letter case + separators |
| R2″ | Retry mitigation seen on 2.1.274 (reported)? | **NOT OBSERVED** — the Task call returned the refusal as a terminal tool failure (subagent never ran; `run_in_background=false`). Whether the 2.1.274 retry is version-gated or flag-gated is unresolved |
| R3″ | D3 orphan locks? | **YES** — every refused call left one `locked claude agent agent-… (pid …)` orphan; 3 orphans over 3 calls (pids 40952 / 34820 / 34528, all dead at inspection) |
| R4″ | F2: `isolation="remote"` silent local fallback? | **ALIVE** — `remote` provisioned a LOCAL worktree (`agent-a1dd6567485d8a2e4`) and failed with the same refusal; no error names the mode actually used |
| R5″ | Worktree admin integrity | Standard gitfile → same repo `.git/worktrees/agent-*`; the refusal's guesses falsified again |

CHANGELOG checked through 2.1.277 (2026-09-18): no entry in 2.1.275–2.1.277 matches D1 (the
worktree-refusal fixes that shipped in 2.1.274 concern Bash-command confinement and agent-worktree
removal safety, not pre-flight provisioning validation).

Post-probe cleanup: `cleanup-agent-orphan-worktrees.ps1 -Execute` detected 3/3 (dead pids) and
unlocked + removed + pruned all three — the mitigation stack processes live 2.1.277 debris. Scratch
repo deleted, 0 residue.

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
- Static guard: the upstream error message must not appear in this repo's production source (test file excluded). Enumerates **tracked files via `git ls-files`** (1,305 files) instead of a filesystem walk — a walk is unbounded by debris and did not stop at the filter: on ai-01's main checkout (2026-09-13) it enumerated >100k files (34 leftover `agent-*` worktrees = 62,037 files, plus ~40k in `node_modules`).

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
| 1. Reproduce on Windows with multiple historical worktrees | ✅ po-2023 c.286 (synthetic + live observation) · **deterministic live repro on 2.1.236** (2026-09-07, lowercase-drive cwd + 2 historical worktrees → verbatim refusal) · **repro on 2.1.269** (myia-ai-01, 2026-09-13, same methodology, from the VS Code-extension binary) · real-repo dry-run audit po-2026 2026-09-02 (`C:/dev/CoursIA-2`: 0 `agent-*` orphan remaining, script exits clean) | — |
| 2. Fix `.git` / `core.worktree` creation/validation | ❌ Upstream — refined 2026-09-02: the refusal is D1 (strict path comparison, no win32 normalization), see Class 3. No-repro on 2.1.86 and 2.1.141; **reproduces on 2.1.236, 2.1.269 and 2.1.277** (R1′ 2026-09-07; ai-01 2026-09-13; po-2026 2026-09-18 — dist-tag `latest`), with a masked-but-still-broken variant on 2.1.274 (retry succeeds, refused worktree stays locked). 2.1.269 ships a three-valued canonical comparison (`Fzn`/`AT`) but the lowercase-drive pair still lands `distinct` — static read alone suggested a fix, live probe falsified it | `anthropics/claude-code#91618` |
| 3. `isolation="remote"` does not silently use local provisioner, **or the real mode is documented** | ✅ documented (document-arm): on 2.1.236 `remote` is an accepted enum value that silently stages a **local** worktree (R2′, 2026-09-07 — supersedes the 2.1.86 "not offered" reading, which held only for that build). **Re-confirmed live on 2.1.277** (R4″, 2026-09-18). The defect itself remains upstream | this doc + `anthropics/claude-code#91618` |
| 4. Auto-cleanup on provisioning failure | ⚠️ Partial — defensive script. Failure-path orphan production **confirmed live on 2.1.236** (R3′: two locked `agent-*` left, no cleanup), **on 2.1.269** (ai-01 2026-09-13), **on 2.1.274** (reported, datapoint #18: refused worktree stays locked after retry) **and on 2.1.277** (R3″, 2026-09-18: 3 orphans / 3 calls, dead pids; script cleaned 3/3) → the script guards a real, current failure mode | `scripts/maintenance/cleanup-agent-orphan-worktrees.ps1` |
| 5. Windows test creating agent worktree + checking `rev-parse --show-toplevel` | ✅ 12 tests (incl. D1 normalization defect class, Windows-guarded), re-verified 12/12 on 2026-09-07 (Pester 6.1.0, pwsh 7.6.3, git 2.55.0.windows.4); 2026-09-13: re-verified live on ai-01 and the static-guard scan **bounded** (tracked-files enumeration via `git ls-files` — see deliverables); 2026-09-18: re-verified 12/12 on myia-po-2026 (pwsh 7.6.6, main `fe22ccf6`) | `scripts/testing/unit/agent-worktree-isolation.Tests.ps1` |
| 6. No orphan locked worktree after provisioning failure | ⚠️ Partial — defensive script (same as #4) | same as #4 |

---

## Upstream ticket

**Filed by an external reporter as [anthropics/claude-code#91618](https://github.com/anthropics/claude-code/issues/91618)**
(*Windows: isolation-worktree safety check rejects valid worktree due to case-sensitive drive-letter
comparison*, OPEN since 2026-09-02). A bisection datapoint comment (2.1.41 feature-absent / 2.1.86
no-repro / **2.1.236 deterministic repro** + the `remote` silent-fallback observation) was posted
there on 2026-09-07 from this investigation.

The technical content that fed the ticket:


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

## Fleet observation — unlocked `agent-*` debris on ai-01's main checkout (2026-09-13, reported, not actioned)

Dry-run of the cleanup script on `D:/roo-extensions` reports **34 `agent-*` worktrees, all
unlocked → "Detected orphans: 0"** (the script only handles the *locked* class — by design, since
the incident refusal leaves them locked). This is the **success/abandoned-path** debt, a sibling of
the worktree-lifecycle problem (#2638), not the #3345 failure path itself:

- 34 directories, **62,037 files** total under `.claude/worktrees/` (≈1,523 files per agent worktree).
- 2 of 34 are **dirty** (rule: dirty ≠ orphan — inspected, not deleted):
  - `agent-a6df703a71f9d1d3b` — abandoned WIP: `M .github/workflows/ci.yml`,
    `M scripts/scheduling/start-meta-audit.ps1`, `?? scripts/testing/harness/test-metaaudit-active-extension.ps1`,
    0 commits ahead of main.
  - `agent-ac34b6f199d572320` — branch `wt/submod-bundle-1133`, one commit ahead duplicating merged
    PR #3541, plus a modified `mcps/internal` gitlink (phantom-pointer risk per the submod rules).
- **No cleanup was performed** — deleting these is a worktree-lifecycle decision for the owner, not
  part of this issue. The two dirty ones should be inspected before any removal.

Provenance note: ai-01's npm-global `claude` is 2.1.17 (feature-absent), so these were created by a
newer harness — consistent with the VS Code extension lineage identified above.

---

## Spawn-site repair verified — two-arm canary (2026-11-17, myia-po-2023)

Context: po-2025:CoursIA-2 escalated `[DEGRADED]` (roo-extensions dashboard, 2026-11-16 20:03Z)
after their adjoint-belt canary was refused pre-launch; ai-01 replied 23:58Z (same refusal on
2.1.323, cause upstream, "no repair possible in our repos"). The measurement below adds what both
canaries could not show: **the discriminator is the cwd case form, and a launcher that controls its
spawn cwd can make isolation work again.**

Method: two-arm headless canary on the SAME scratch repo (`%TEMP%\3345probe323\repo` — scratch name
inherited from the earlier 2.1.323 in-session probe; the arms below ran the 2.1.283 npm build — one
commit, npm `claude` 2.1.283, `DISABLE_AUTOUPDATER=1`), identical prompt and Task call
(`isolation=worktree`, general-purpose, sonnet) — only the `ProcessStartInfo.WorkingDirectory`
case form differs between arms. Cwd preservation into the child confirmed (arm A's refusal prints
the lowercase form the harness held).

| Arm | cwd form | Result |
|---|---|---|
| A | `c:\…\Temp\3345probe323\repo` | **Refusal, verbatim D1** (`c:\…` refused vs `C:/…` resolved) + `agent-ab0ccaeeea4b69fab` left `locked` (D3) |
| B | `C:\…\Temp\3345probe323\repo` | **Success** — sub-agent provisioned, replied `OK` (~6 s), zero debris (auto-cleaned) |

Also reproduced in-session on myia-po-2023 the same night (VS Code extension 2.1.323, session cwd
`d:\Dev\roo-extensions`): verbatim refusal, and R4′ falsified firsthand on the leftover
`agent-a249c8e310470274b` — `gitdir` back-pointer consistent, `core.worktree` unset,
`git -C <worktree> rev-parse --show-toplevel` returns the worktree itself. The refused path and
the resolved path denote the same location, exactly as measured on 2.1.236/2.1.277.

**Repair recipe (programmatic launchers — belts, workers, `claude -p` spawners):** normalize the
drive letter to uppercase in the WorkingDirectory passed to the child process (git canonicalizes
separators on its own; only the drive-letter case form discriminates). Verified green by arm B.
For interactive VS Code sessions — where the session cwd is imposed by the window and cannot be
re-cased from inside — the manual-worktree workaround stands (create
`git worktree add .claude/worktrees/wt-<desc> -b wt/<desc>` yourself, launch the sub-agent without
`isolation`, give it the absolute path in the prompt).

Orphan cleanup unchanged: `scripts/maintenance/cleanup-agent-orphan-worktrees.ps1` (dry-run
default; skips entries whose locking PID is alive — a canary refusal inside a live session leaves
a PID-locked orphan that only becomes removable after that session exits).

---

## D4 — `Cannot create worktree ... .git/logs/HEAD ... not a plain file, or could not be checked` (DriveFS-hosted repos, provisioner ≥ 2.1.328) — #4875 (myia-ai-01, 2026-11-22)

**Context.** 2026-11-22 18:20Z, po-2025: a Maintenance `Agent(isolation: "worktree")` launch on a
repo hosted on `G:` (Google Drive for Desktop, DriveFS) was refused pre-inference with a message
containing « Cannot create worktree ... .git/logs/HEAD ... link ... or could not be checked »
(dashboard machine po-2025, elided by the reporter). The same afternoon the CoursIA-2 adjoint's
Haiku readers had been refused since 15:20Z (locking PID = a Claude Code **2.1.328.0** process;
PATH CLI reports 2.1.283). #4875 asked to discriminate this new signature from D1 on a disposable
two-arm witness, same drive-letter case on both arms.

### Reported refusals — classification

| Refusal | Repo drive | Build (best evidence) | Classification |
|---|---|---|---|
| Maintenance 22/11 18:20Z (test launch) | G: DriveFS | reported « CLI 2.1.283 » — **cannot be the refusing build**: 2.1.283 provisions fine on G: (arm 2 below); the machine's VS Code extension is 2.1.328, the minimum version carrying the check | **D4** — every quoted fragment (`Cannot create worktree`, `.git/logs/HEAD`, `link`, `could not be checked`) matches the verbatim below. Effective-build attribution on po-2025 should be re-probed via the extension's native binary (`claude --version` understates it — same pitfall as the 2.1.269 section) |
| CoursIA-2 adjoint, since 15:20Z | D: NTFS | 2.1.328.0 (PID carried by the lock) | **D1** — arm 6 reproduces the D1 refusal verbatim with the same build on the same drive class; CoursIA-2's Git readings on the refused child `agent-ac96a8b69e2db8da8` (show-toplevel = own path, git-common-dir = CoursIA-2 repo, absolute-git-dir = the child's own admin; refused ≡ resolved after case/separator folding) falsify any genuine redirect — D1's exact false positive. D4 cannot fire on NTFS (`nlink = 1`, see mechanism). The adjoint's verbatim text is still absent from the dashboards: classification rests on build × drive × git-readings, not on their quoted text |

Precision on a fleet reading: po-2025's note that « un tiers rapporte le 21/11 le même refus sur
Claude Code 2.1.330 » (upstream #91618, zachrisdev) conflates signatures — that upstream comment
quotes the **D1** text on a local drive, not D4.

### Two-arm witness experiment (2026-11-22, ai-01, git 2.50.1.windows.1, Windows 11 Pro)

Witness = disposable repo, 3 commits + two historical worktrees under `.claude/worktrees/`
(methodology match with the earlier probes), one copy on `D:\i4875-witness\repo` (NTFS), one on
`G:\Mon Drive\Synchronisation\RooSync\.tmp\i4875-witness\repo` (DriveFS). Headless `claude -p`
with `--strict-mcp-config` (empty MCP set), prompt fed by stdin, single
`Agent(isolation: "worktree", run_in_background: false)` call whose subagent must reply
`WITNESS-OK`. All isolation arms spawned with **uppercase** drive letters (D1 excluded by
construction; lowercase is the arm-6 D1 control). Builds: npm global **2.1.283** (`claude
--version` verified), VS Code extension native binary **2.1.328**
(`anthropic.claude-code-2.1.328-win32-x64/resources/native-binary/claude.exe`), npm **2.1.330**
via `npx -y @anthropic-ai/claude-code@2.1.330` (`--version` output captured; `latest` that day).

| # | Build | Drive (FS) | cwd form | isolation | Result |
|---|---|---|---|---|---|
| 1 | 2.1.283 npm | D: NTFS | `D:\…` | worktree | ✅ `WITNESS-OK`, zero debris |
| 2 | 2.1.283 npm | G: DriveFS | `G:\…` | worktree | ✅ `WITNESS-OK`, zero debris |
| 3 | 2.1.328 ext | G: DriveFS | `G:\…` | worktree | ❌ **D4 verbatim refusal**, pre-creation, zero debris |
| 4 | 2.1.328 ext | D: NTFS | `D:\…` | worktree | ✅ `WITNESS-OK` |
| 5 | 2.1.330 npm | G: DriveFS | `G:\…` | worktree | ❌ **D4 verbatim refusal** — still live on `latest` |
| 6 | 2.1.328 ext | D: NTFS | `d:\…` (ProcessStartInfo) | worktree | ❌ **D1 verbatim refusal** + `locked` orphan `agent-ae3db21330b9c4962` + residual `worktree-agent-*` branch (D3 debris) — D1 control |
| 7 | 2.1.328 ext | G: DriveFS | `G:\…` | none | ✅ `WITNESS-OK-NOISOLATION` — parade, below |

Transcript `cwd` verified per run (stream-json init event), so the exact drive-letter form each
harness held is recorded; arm 6's is lowercase.

**Method note:** `Push-Location 'd:\…'` does **not** preserve the lowercase form — PowerShell
normalizes the drive letter, and a first attempt at arm 6 silently became an uppercase duplicate
(recorded, not counted). A true lowercase arm requires `ProcessStartInfo.WorkingDirectory`, as in
the 2026-11-17 two-arm canary.

### Verbatim refusal (D4, arms 3 and 5, identical modulo the worktree id)

```
Cannot create worktree "agent-a8a7bb7970fc20db5": git could write outside this repository through G:\Mon Drive\Synchronisation\RooSync\.tmp\i4875-witness\repo\.git\logs\HEAD or a folder on the way to it, which is a link, a symbolic ref, a list naming another path or another entry that is not a plain file, or could not be checked. Checkouts made by git-new-workdir or older versions of Android's repo tool, and copies made with hard links (with cp -al, say), have such entries: use a plain clone instead. Otherwise a command run earlier may have planted it: look at that entry before changing anything.
```

Behavior: terminal tool failure of the `Agent` call (subagent never runs) and — unlike D1 — the
refusal fires **before anything is created**: no `agent-*` directory, no `.git/worktrees/`
registry entry, no branch (verified `git worktree list` + `git branch` after each refusal). No
D3 debris on this path.

### Mechanism — `st_nlink = 0` on DriveFS (measured)

```js
node -e "console.log(require('fs').lstatSync('<repo>/.git/logs/HEAD').nlink)"
D: (NTFS)   → isFile=true  isSymbolicLink=false nlink=1
G: (DriveFS)→ isFile=true  isSymbolicLink=false nlink=0
// on DriveFS EVERY entry reports nlink=0 — the file .git/logs/HEAD and each ancestor directory
```

The ≥ 2.1.32x pre-flight validates that `.git/logs/HEAD` (and the folders on the way to it) is a
"plain file" — hard-link territory is `nlink === 1`. DriveFS reports `st_nlink = 0` for every
entry, so the entry is neither plain nor an error: the checker's own text names exactly this
outcome (« or another entry that is not a plain file, **or could not be checked** ») and fails
closed. Git itself is innocent on two counts: `git worktree add` succeeds on the same DriveFS
repo (the witness's two `hist-*` worktrees were created by plain git), and 2.1.283 provisions the
same repo without complaint — the check and the refusal are the provisioner's, introduced
somewhere in **2.1.284..2.1.328** (not narrowed further; only 2.1.283 and ≥ 2.1.328 builds were
available on the machine).

### Verified workarounds

1. **Do not host working repos on DriveFS** (root-cause class): the same 2.1.328 build provisions
   the identical repo fine on `D:` (arm 4). For Maintenance's G:-hosted repos this is the durable
   answer — read-only subagents can stay on G:, anything needing worktree isolation moves to a
   local volume.
2. **Launch the subagent without `isolation`** (arm 7, verified live on the G: repo, 2.1.328): the
   subagent ran and returned `WITNESS-OK-NOISOLATION`. Immediate unblock for read-only delegation
   (the Maintenance case); the caller then owns any isolation discipline (the repo-local
   `git worktree add` + absolute-path prompt recipe of the D1 section also applies).
3. **Pin 2.1.283** for sessions that must provision isolation worktrees on DriveFS (arm 2) —
   version rollback, stopgap only (the build also lacks the newest fixes and D1 is present in it).
4. **Adjoint (D1, not D4)**: the existing D1 recipes apply unchanged — uppercase-drive
   `WorkingDirectory` in the adjoint-belt spawner (programmatic), manual worktree + no-isolation
   (interactive).

### Upstream

Datapoint posted 2026-11-22 as
[anthropics/claude-code#91618 (comment)](https://github.com/anthropics/claude-code/issues/91618#issuecomment-7087251685)
— new-signature flag on the D1 thread (the pattern `unyieldingclaw-dev` used for the third
signature), with the repro, the control matrix, the `st_nlink` mechanism and the offer to file a
standalone issue. Ticket text (verbatim as posted; the witnesses' user paths are already
non-sensitive):

> **New, distinct refusal signature (possibly related, different error text) — Windows + Google
> Drive for Desktop (DriveFS), Claude Code >= 2.1.328.**
>
> Repro (deterministic, 2026-11-22, Windows 11 Pro, git 2.50.1.windows.1): scratch repo hosted on
> a **DriveFS** volume; headless `claude -p` with an **uppercase-drive cwd** (NOT the
> drive-letter-case issue this thread tracks); single `Agent` call with `isolation: "worktree"`.
> Result on **2.1.328** (VS Code extension's native binary) and **2.1.330** (npm `latest`):
> terminal tool failure, subagent never starts — verbatim message above.
>
> Controls: same repo on NTFS → accepted on 2.1.328; same DriveFS repo → accepted on 2.1.283. The
> check appeared in 2.1.284..2.1.328 and is DriveFS-gated, not repo-state-gated.
>
> Mechanism (`fs.lstatSync` on `.git/logs/HEAD`): NTFS `nlink=1`; DriveFS `nlink=0` for **every**
> entry, files and directories alike. A "plain file / not a hard link" pre-flight requiring
> `nlink === 1` sees `0` and fails closed — the error's own "or could not be checked" branch.
> `git worktree add` succeeds on the same repo and the refusal fires pre-creation (no directory,
> no registry entry, no branch left).
>
> Workarounds verified: subagent without `isolation`; repo on NTFS; 2.1.283 on DriveFS.

---

## Related

- **#2772** — submodule deletion guard (used by the cleanup script via `path-guards.ps1`)
- **#2123** — nested-worktree guard (same module)
- **#1913** — worktree-husk prevention (worker-side cleanup, related class)
- **po-2023 c.286** — original cause analysis in dashboard intercom
