# Connector V3 Spec — Shared agent contract (Roo / Claude / Copilot), as implemented

**Date:** 2026-11-02
**Status:** Normative, as-implemented — deliverable 1 of #622
**Supersedes:** the *target model* of [`copilot-roostate-v3-plan.md`](copilot-roostate-v3-plan.md) §3 (the plan is kept as history; its §9 rollout checklist and §10 rollback plan remain the operative references for those topics and are NOT duplicated here).
**Principle (unchanged since the plan):** `roo-state-manager` is the single control plane — no lane invents a parallel orchestration source of truth.

This document specifies the six connector dimensions **as they exist in the repo today**, with citations. Anything not yet uniform is listed in [§8 Gaps](#8-gaps-named-not-hidden) rather than described as if it existed.

---

## 1. Identity

Every write carries a **lane identity** `machine[:workspace]`.

| Lane | Identity source | Notes |
|---|---|---|
| Claude Code | `COMPUTERNAME` + basename of the git toplevel (`check_issue_claim.py`, #4114) | A linked worktree resolves to the **main checkout** toplevel (a worktree is a workplace, not a workspace — #4122). `--workspace` overrides the suffix, `--agent` replaces the whole id. |
| Roo Scheduler | machine id from its own config | Same lane grammar; Roo and Claude on one machine are distinct lanes only when workspaces differ. |
| Copilot | gh account (`jsboige`) + host seat | Interactive Copilot has **no lane identity yet** (see §8). |
| Off-fleet cloud session | gh account (`jsboige`), no fleet machine | **No lane identity** and no control-plane access (see §8). Its locks are posed by the sponsoring fleet lane — [`off-fleet-cloud-sessions.md`](../harness/reference/off-fleet-cloud-sessions.md). |

**Remote identity assertion (HTTP transport, ms#1578 merged 2026-10-31):** a caller may assert
`x-roosync-as: <machine>[:<workspace>]`; the assertion is honored only if the entry is listed in
`ROOSYNC_TRUSTED_CALLER_IDS` (server env). Untrusted assertions are refused loudly (403
`identity_refused` — measured: the refusal fires **at `initialize`**, every request carrying the
header goes through the gate). Writes without any identity: 403 `identity_required`. No/invalid
bearer: 401. The daemon binds loopback only and fails closed without `ROOSYNC_HTTP_API_KEY`.

**GitHub identity:** all lanes share gh accounts whose tokens live in machine-global
`hosts.yml` — any public `gh` action carries the identity guard **in the same command**
(`gh auth switch --user X && [ "$(gh api user --jq .login)" = "X" ] && <action>`, #3032).

## 2. Inbox — unified read model

| Concern | Contract | Reference |
|---|---|---|
| Inter-machine inbox | `roosync_messages` — PG-primary channel, fail-closed under PG outage (no silent GDrive fan-out) | lived through the #4131 outage, c.88–91 |
| Command channel | dashboard `workspace`, read `section:"all"` (never `status` alone) | #2306 |
| Local fallback | `.claude/local/INTERCOM-{MACHINE}.md` — DEPRECATED, last resort | `.claude/rules/intercom-protocol.md` |
| Copilot interactive | reads the same MCP surface (`configure-copilot-mcp.ps1` injects `roo-state-manager` into `%APPDATA%\Code\User\mcp.json`, idempotent, preserves existing entries) | `scripts/copilot/configure-copilot-mcp.ps1` |
| Copilot scheduled | the dispatcher reads **local state + the `copilot-target` pool**, not the inbox; it posts no routine issue comments (`IssueNumber 0` default) | `scripts/scheduling/setup-copilot-dispatcher.ps1` |

Reading the inbox is the **first effective action** of every executor cycle ([INBOX-GATE, #3554]) —
the enumeration goes through the MCP, never a raw scan of `messages/inbox` on GDrive.

## 3. Claim — anti-duplicate lock protocol

**Locus: the GitHub issue comment** (ADR 017, accepted 2026-09-15). The dashboard keeps the
narrative, never the lock.

1. Form: `[CLAIMED] <lane> — <one-line intention>`. No timestamp in the body — server `createdAt`
   is authoritative. Lift: `[RELEASED]` (or `[DONE]` at delivery), under the **same identity** as
   the pose.
2. Instrument before any mutation: `python scripts/github/check_issue_claim.py <N>` —
   exit `0` free · `1` foreign active claim · `2` I/O or gh failure (incl. undeterminable repo) ·
   `3` number is an issue in **both** repos and `--repo` was not passed (#3768 — the guard never
   guesses; a wrong guess locks the *other* repo).
3. Peremption 24 h: a stale foreign claim warns but does not block; the new claimant still posts.
4. Pre-delivery re-read (dashboard intercom + claim re-check) before `gh pr create` — the state
   read at departure is not the state at delivery.
5. Anti-double-claim PR sweep in **both** repos with word boundary (`#N([^0-9]|$)`), #3407.
6. Tie-break (HARD): an issue-claim **outranks** a dashboard-claim, even an older one.

**Copilot does not claim today.** Target designation is the `copilot-target` label, posed by the
coordinator (ai-01, measured 02/11 on #4081); the dispatcher executes labeled grains and reports.
Duplicate processing is instead guarded by the pilot window (AC3, 6 consecutive scheduled tirs —
running since AC0 success 2026-11-02 01:16Z).

## 4. Execution mode

| Lane | Interactive | Scheduled |
|---|---|---|
| Claude Code | session cron (`CronCreate`, arbitrage 2026-08-18 — schtask `Claude-Executor-Cron` **interdite**) | workers `claude -p` (fresh process per task) |
| Roo | VS Code extension session | scheduler extension (win-cli MCP fork; no `command` group on any mode, #1482) |
| Copilot | VS Code / Copilot CLI | schtask `Copilot-Dispatcher` → `scripts/scheduling/start-copilot-dispatcher.ps1`, Phase C fallback `gh copilot -p` with the **prompt passed via file** and a short argv (AC0 constraint: argv > 32 767 chars kills the spawn; AC0 passed 02/11 01:16Z) |

Cadences are **decided by the user, per lane, and asymmetric by design** (executors 4h at `:41`,
coordinator 12h at `:23`; Copilot dispatcher currently PT12H — measured 02/11). Never "realign"
one lane onto another's cadence.

## 5. Status — reporting with evidence

- Dashboard `workspace` tags: `INFO`, `TASK`, `DONE`, `WARN`, `ERROR`, `ASK`, `REPLY`, `ACK`,
  `PROPOSAL`, `BLOCKED`, `CLAIMED`. A `[DONE]` citing an artifact requires the artifact to be
  **verifiable at the moment of the report** (`agent-claim-discipline.md`: no SHA without
  `git cat-file -e`, no PR without a live URL, tests visible in the log).
- GitHub writes use `--body-file` (absolute path) — inline `--body` mangles markdown backticks
  with exit 0 (#2368).
- Copilot dispatcher: per-run log + report under `outputs/scheduling/{logs,reports}/`, local
  state `.claude/scheduler/copilot-dispatcher-state.json`; routine runs post **no** issue
  comments.

## 6. Handoff — structured transfer

| Mechanism | Use | Reference |
|---|---|---|
| Dashboard `[REPLY]` + `mentions:[{messageId}]` | answering an `[ASK]`/`[PROPOSAL]`/`[REQUEST]` — the mention is what notifies the sender | #1956 |
| DM `roosync_messages` | decisions/urgency, point-to-point | DMs defer to the single rendez-vous point |
| Cross-workspace escalation | one post at the **superior** level (dashboard `global`, `machine` if seat-specific) + `crossPost`, naming who carries what and where the follow-up lives | arbitration 2026-09-06 |
| Dispatcher escalation | after `MaxConsecutiveBlocked` (default 2) blocked runs → `claude-worker-haiku` (low) / `claude-worker-sonnet` (balanced); rate-limited (`MinEscalationIntervalMinutes` 180, `MaxEscalationsPerDay` 3) | `scripts/scheduling/start-copilot-dispatcher.ps1` |

The handoff **payload** is a convention (tagged markdown + mentions), not a JSON schema — see §8.

## 7. Budget guards (Copilot-specific)

`-BudgetProfile low|balanced|throughput`, `-PremiumUsagePercent` override, soft cap 70 % /
hard cap 90 % of the premium entitlement (measured 02/11 by ai-01: 1500 premium requests/month,
~18.6 per call; coordinator recommendation 8–12 targets/month). The API key never enters the
repo. Budget state lives beside the dispatcher state, not in git.

## 8. Gaps (named, not hidden)

1. **Copilot interactive has no lane identity** — no `machine:workspace` identity, no claim
   capability; it can read/write through the MCP but cannot yet hold a lock. Until closed, the
   `copilot-target` label + single-dispatcher execution is the duplicate guard.
2. **Handoff payload is conventional, not schema'd** — structured JSON transfer is in the issue
   body's target model; today it is tagged markdown + mentions.
3. **Roo has no per-request identity on the HTTP transport** — the identity gate (ms#1578) is
   exercised by Claude lanes; Roo remains stdio.
4. **Project #67 field consistency is measured for Claude lanes only** — the AC5 check over all
   three lanes starts with the pilot window.
5. **Claim peremption vs Copilot long cycles** — 24 h peremption is tuned for 4 h executor
   cadences; a PT12H dispatcher holding a target across two tirs has no claim to expire. No
   incident measured; revisit if the dispatcher starts claiming.
6. **Off-fleet cloud sessions sit outside the control plane** — an agent session hosted outside
   the `myia-*` machines reads neither the MCP nor the dashboards and writes under the
   maintainer's gh account. The claim guard cannot represent it: a `[CLAIMED]` line naming no
   fleet machine reduces to the unowned sentinel, which blocks every lane and never goes stale
   (probe 2026-11-13, pinned by `test_off_fleet_lane_token_is_unowned`). Until a lane token
   exists for it, the contract is conventional: frame issue, sponsor-posed locks, fleet-side
   review and merge — [`off-fleet-cloud-sessions.md`](../harness/reference/off-fleet-cloud-sessions.md).

## 9. References

- Plan & history: [`copilot-roostate-v3-plan.md`](copilot-roostate-v3-plan.md) (§9 rollout
  checklist, §10 rollback plan — operative, not duplicated here)
- Claim locus: [`docs/harness/adr/017-issue-claim-locus.md`](../harness/adr/017-issue-claim-locus.md)
- Claim discipline (identity, two repos, pre-delivery): [`.claude/rules/agent-claim-discipline.md`](../../.claude/rules/agent-claim-discipline.md)
- Identity gate & HTTP transport: PR jsboige/jsboige-mcp-servers#1578 (merged `ee5d7a8c`; `eb216a1f` is its head, not the merge commit)
- Pilot evidence: #622 comments 2026-11-02 (AC0 tir 01:16Z, budget measurement 14:26Z)
