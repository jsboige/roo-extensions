# MyIA Cluster PR Review (reduced edition)

**Version:** 1.0.0
**Lane:** myia-po-2026:hermes-pr-review
**Full edition:** lives on po-2026 in `~/skills/github/myia-cluster-pr-review/` — this is the reduced, publishable subset.

---

## Purpose

Review pull requests across the MyIA cluster repos (CoursIA, roo-extensions, jsboige-mcp-servers) with a strict anti-spam dedup discipline and evidence-first verdicts. This reduced edition documents the protocol and ships the four review scripts.

**Repositories covered:** jsboige/CoursIA, jsboige/jsboige-mcp-servers, jsboige/roo-extensions. `jsboigeEpita/*` = SKIP (token gap). ArgumentumGames/Argumentum = SKIP (NanoClaw covers).

---

## Review cycle protocol

1. **Max 5 PRs per cycle, strictly sequential** (one PR fully finished before the next — no fan-out, no subagents).
2. **Selection priority:** PRs >1000 lines OR >5 files first (bot verdict <24h required, issue #15511), then the rest.
3. **Routes:** before scanning, read the `workspace-cluster-coordination` intercom (roosync_dashboard) and serve any pending [TASK-ROUTE]/[ROUTE] addressed to hermes-pr-review.

### Anti-spam dedup (issue #2505) — MANDATORY before any review

Every review is one email notification. Before posting on PR NNN:

```
gh api repos/OWNER/REPO/pulls/NNN/reviews --jq '.[].body'
gh api repos/OWNER/REPO/issues/NNN/comments --jq '.[].body'
gh pr view NNN --repo OWNER/REPO --json headRefOid
```

Post **only** if: (a) no [Hermes]/[NanoClaw] review exists on the current head SHA, or (b) new commits landed AND your review adds genuinely new information. If NanoClaw already posted LGTM on the current SHA → SKIP (unless you have genuinely new CHANGES_REQUESTED). Never more than 1 Hermes review per SHA. Everything already covered → silence (or a brief [ACK]).

### Opener gate (#3219) — mechanical, never from memory

The PR opener (author) decides COMMENT vs APPROVE/REQUEST_CHANGES. Read and post in the SAME terminal call:

```
AUTHOR=$(gh api repos/OWNER/REPO/pulls/NNN --jq .user.login); echo "opener=$AUTHOR event=<COMMENT|APPROVE|REQUEST_CHANGES>"
```

- author == `jsboige` AND substantive verdict → post via the `clusterManager-Myia` token (WRITE on CoursIA; non-author, so not self-review). Fallback on 403/401 → COMMENT under `jsboige` with an honest note.
- author != `jsboige` → real event under `jsboige`.

### Checklist

1. `gh pr view NNN --json headRefOid,additions,deletions,files,title,body,author`
2. Dedup (above).
3. Read the diff: `gh pr diff NNN`.
4. Security scan on the diff: `HF_TOKEN|API_KEY|BEARER|PASSWORD|SECRET|TOKEN\s*=` → any match = CHANGES_REQUESTED.
5. Depth by risk: docs = rendering + conceptual correctness; code = deps, leak paths; **notebooks = FULL READ, the diff is never enough** (see below).
6. Post only if dedup passed. Default verdict = COMMENT_WITH_CONCERNS; APPROVE is an explicit, motivated decision.

### Notebooks (.ipynb) — full-read obligation

(a) Extract the complete post-change notebook — `gh api repos/jsboige/CoursIA/contents/PATH --jq .content | base64 -d > /tmp/nb.ipynb` — never the diff alone.
(b) Structural view via `scripts/nb_view.py` (never dump raw JSON at the screen — notebooks with inline images are multi-MB base64): headers, cell order, sources, text outputs; images become `[image/png ~NKB]` markers. ~20x context compression.
(c) Gates #17040: at most ONE reading-markdown cell per code output, placed immediately AFTER the read cell; every value cited in a reading must be PRESENT in the committed outputs (absent = fabricated = CHANGES_REQUESTED); no exercise-solution narration; prose targeting a density threshold (1200 chars) = REJECT.
(d) For every added block: articulate what it is FOR — inability = CHANGES_REQUESTED.
(e) "Density redress" PRs: verify they fix without re-vandalizing (symmetric risk: deleting legitimate content).

### Living proof (NanoClaw 14/09)

Every green organ cited as evidence must have ACTUALLY executed the guarded path: (a) the workflow's `paths:` trigger covers the PR's files, (b) the job's checkout includes the tested files, (c) the assertion would fail if the guard were broken. A green out of scope is not proof. Fix = make the guard visible, never add assertions.

---

## Scripts

All four scripts are byte-exact copies of the po-2026 canonical versions.

| Script | Purpose |
|---|---|
| `scripts/nb_view.py` | Structural notebook renderer for review (gates #17040 synthesis: duplicate headers, stacked prose). `python3 nb_view.py NB.ipynb` |
| `scripts/dedup-triage.sh` | Fetch open PRs + existing reviews, emit the dedup table for the cycle. |
| `scripts/fast-dedup-sweep.sh` | Fast coverage sweep across repos (heads already reviewed vs new). |
| `scripts/validate-output-format.py` | Validate the cycle output line format. |

---

## Canonical fingerprint — nb_view.py

The embedded `scripts/nb_view.py` is a byte-exact copy (never fork it):

- **sha256:** `a52bc37a03133507a7de45e8bec11a82b374ae3225b99abce029c8013162be6f`
- **git blob sha:** `e04fadd601feb7356963f736daa8775c17f87f13`
- **Canonical source:** jsboige/CoursIA PR **#17167** commit `d2e2035c` (`scripts/notebook_tools/nb_view.py`)

If you need to modify nb_view.py, change the canonical source first, then re-copy here with updated fingerprints. A bare divergent copy is forbidden (second divergent focus — guard NanoClaw 23/09).

---

## Output format

Strict, one line: `X/Y reviews posted. PRs: #NNN result (repo), ... Skipped: Z SHA-match.`

Only reviews actually posted are listed; skipped PRs are never listed.

---

## Honesty rules

- Never report "BLOCKED token"/"403" in the output — use the documented fallback and say so in the review body.
- APPROVE only on a real verification artifact (re-executed test, API-checked fact), never mechanical validation.
- Flag what was reviewed superficially instead of defaulting to LGTM.
- Judging a predicate = EXECUTE the exact head's logic on real payloads, never reconstruct the predicate from the body.
