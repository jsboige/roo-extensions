#!/usr/bin/env python3
"""Issue-claim guard — the "one command before you edit" of roo-extensions (#3676).

The dashboard-claim protocol (agent-claim-discipline.md v1.x) had three measured
defects, all inherited from the locus: (a) the per-workspace dashboard is a silo
-- the claim signal does not cross machines natively; (b) the intercom channel
is garbage-collected by auto-condensation at 92%, so a [CLAIMED] can vanish
during the "I decided to work on X" -> "I pushed" window; (c) body stamps mixed
local time and UTC. During the 2026-08-16 GDrive outage (PR #3155) the whole
claim organ went down with the dashboard -- CoursIA, whose claims live on the
GitHub issue, kept working (ADR 017).

This tool operationalises the worker side of ADR 017 (the locus change is in
.claude/rules/agent-claim-discipline.md v2.0):

  - **check** (default): before editing a file for work attached to issue #N, run
        python scripts/github/check_issue_claim.py N --agent myia-po-2026
    It reads the issue comments, reconstructs the claim state per machine, and
    exits 1 if ANOTHER machine holds an active (unreleased) claim -- do not
    start, pick elsewhere. Exit 0 means the way is clear (optionally: your own
    machine already claimed, you are resuming). The check precedes the EDIT,
    not the push.

  - **--stale-threshold HOURS** (check mode, default 24): treat OTHER machines'
    claims older than HOURS as STALE -- the guard no longer blocks on them, it
    prints a `STALE_CLAIM <machine> <age>h` warning instead. This unblocks work
    when a prior claimer died (killed session, re-image, exhausted credit)
    without a release. Age is the server `createdAt`, never the body. The new
    claimant MUST still post its own `[CLAIMED]`; a stale claim is not a silent
    bypass.

  - **--claim "<intention>"**: post a `[CLAIMED] <machine> -- <intention>`
    comment. GitHub server-stamps it UTC -- the body carries NO timestamp, so a
    local time wearing a `Z` suffix is impossible by construction.

  - **--release [--note "..."]**: post a `[RELEASED]` comment, closing the
    active claim of this machine on the issue. Posting `[DONE]` or `[RESULT]`
    on the issue at delivery closes the claim too.

The authoritative timestamp is the comment's server `createdAt`, NEVER a stamp
written in the body (ADR 017, decision 1).

Claim identity is the MACHINE token (`myia-ai-01`, `myia-po-2023`..`2027`,
`myia-web1`) read from the marker line -- not the comment author: agents post
under shared gh identities. A `[CLAIMED]` marker with NO identifiable machine is
fail-CLOSED: it blocks as an unowned claim and the guard prints the repair
gesture (re-post with the machine token), because silently ignoring a malformed
lock is how collisions happen.

Markers are line-anchored, case-insensitive and decoration-tolerant
(`**[CLAIMED] x**`, `## [CLAIMED] x`, `- [CLAIMED] x` are all events): a marker
MENTIONED mid-sentence in prose is not (the claim template itself cites
`[RELEASED]` in instructions). A comment carrying several markers is legal only
across lines -- each line-anchored marker is its own event and walk order
applies ("last marker wins": a `[CLAIMED] m1` followed on a LATER LINE by
`[RELEASED] m1` reduces to released).

Limitation (documented, same as the CoursIA organ): claim state is
comment-based. A merged PR referencing the issue is not auto-detected as a
release -- post `--release` (or `[DONE]`) when the PR lands.

Exit codes: 0 ok / 1 blocked (other machine holds active claim, unowned claim,
or issue closed) / 2 io-or-gh error.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone

DEFAULT_REPO = "jsboige/roo-extensions"

# --- markers -----------------------------------------------------------------

# A comment line is a claim EVENT only if it STARTS with one of these bracketed
# markers, after optional markdown decoration (header hashes, list dash, bold).
# Line-anchored: a marker mentioned mid-sentence is prose, not an event.
MARKER_RE = re.compile(
    r"(?im)^#{0,6}\s*[-*]?\s*\*{0,2}\["
    r"(?P<marker>CLAIMED|RELEASED|RESULT|DONE|CANCELLED|ABANDONED|DELIVERED)"
    r"\]",
)

# Opening / closing semantics for the reducer. RESULT closes as well as DONE:
# the worker protocol delivers as "[CLAIMED] by ..." then "[RESULT] ..." --
# a delivery that does not release its own lock is a 24h false-block
# (reproduced on live stock #3626 during the #3680 review).
OPEN_MARKERS = {"CLAIMED"}
CLOSE_MARKERS = {"RELEASED", "RESULT", "DONE", "CANCELLED", "ABANDONED", "DELIVERED"}

# Machine identity token: the fleet's canonical lane id. Read from the marker
# LINE (first match), not the whole body -- a repair comment may quote another
# machine's marker in prose below its own.
MACHINE_RE = re.compile(r"\b(myia-(?:ai|po|web)[a-z0-9-]*)\b", re.IGNORECASE)


# --- pure helpers ------------------------------------------------------------


def now_utc() -> datetime:
    return datetime.now(timezone.utc)


def parse_iso_utc(raw: str) -> datetime:
    """Parse a GitHub server `createdAt` (ISO 8601, UTC) into an aware datetime."""
    parsed = datetime.fromisoformat(raw.replace("Z", "+00:00"))
    if parsed.tzinfo is None:  # defensive: server stamps are always tz-aware
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed


def extract_machine(line: str) -> str | None:
    """First machine token on the marker line, lowercase. None if unidentifiable."""
    match = MACHINE_RE.search(line)
    return match.group(1).lower() if match else None


def scan_comment_events(body: str):
    """Yield (marker_upper, machine_or_None, line) for every line-anchored marker.

    Ordered top-to-bottom as written -- the reducer applies them in that order
    per machine ("last marker wins").
    """
    for line in body.splitlines():
        match = MARKER_RE.search(line)
        if match:
            yield match.group("marker").upper(), extract_machine(line), line.strip()


def reduce_claims(comments):
    """Reconstruct the claim state from issue comments.

    `comments`: iterable of dicts with `body` (str) and `createdAt` (ISO str),
    in ANY order -- they are sorted by server `createdAt` (stable) first.

    Returns dict machine -> {'state': 'active'|'released', 'since': datetime,
    'line': str}. Unowned markers (no machine on the line) aggregate under the
    sentinel key ``None``: fail-closed, they block everyone but their own
    (nonexistent) owner.
    """
    ordered = sorted(comments, key=lambda c: c.get("createdAt", ""))
    state: dict = {}
    for comment in ordered:
        for marker, machine, line in scan_comment_events(comment.get("body", "")):
            entry = state.get(machine)
            if marker in OPEN_MARKERS:
                state[machine] = {
                    "state": "active",
                    "since": parse_iso_utc(comment["createdAt"]),
                    "line": line,
                }
            elif marker in CLOSE_MARKERS and entry is not None:
                # A close without a prior open for that machine is a no-op
                # (e.g. [DONE] report on work never claimed via comment).
                entry["state"] = "released"
                entry["line"] = line
    return state


def classify(state, agent, threshold_hours, now=None):
    """Classify claims for the checking agent. Returns (blocking, warnings, notes).

    blocking : list of (machine, age_hours, line) -- OTHER active claims within
               the staleness threshold (plus the unowned sentinel, always).
    warnings : list of strings (STALE_CLAIM ...).
    notes    : list of strings (own-claim status).
    """
    now = now or now_utc()
    threshold = threshold_hours
    blocking, warnings, notes = [], [], []
    for machine, entry in state.items():
        if entry["state"] != "active":
            continue
        age = (now - entry["since"]).total_seconds() / 3600.0
        label = machine if machine else "<UNOWNED -- repair the marker>"
        if machine is None:
            # Fail-closed: an active claim nobody owns blocks every claimant.
            blocking.append((label, age, entry["line"]))
            continue
        if machine == agent:
            notes.append(
                f"own claim active since {entry['since'].isoformat()} "
                f"({age:.1f}h) -- resuming"
            )
            continue
        if age > threshold:
            warnings.append(
                f"STALE_CLAIM {machine} {age:.1f}h (> {threshold}h) -- not blocking; "
                "you MUST still post your own [CLAIMED]"
            )
        else:
            blocking.append((label, age, entry["line"]))
    return blocking, warnings, notes


# --- gh IO -------------------------------------------------------------------


def run_gh(args, check=True):
    """Run a gh command, return stdout. Raises RuntimeError with stderr on failure."""
    proc = subprocess.run(
        ["gh", *args],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if check and proc.returncode != 0:
        raise RuntimeError(
            f"gh {' '.join(args)} failed (exit {proc.returncode}): "
            f"{proc.stderr.strip() or proc.stdout.strip()}"
        )
    return proc.stdout


def fetch_issue(issue_number: str, repo: str):
    """Fetch issue state + comments as a dict. Raises RuntimeError on gh failure."""
    raw = run_gh(
        [
            "issue",
            "view",
            issue_number,
            "--repo",
            repo,
            "--json",
            "number,state,comments",
        ]
    )
    return json.loads(raw)


def post_comment(issue_number: str, repo: str, body: str) -> None:
    # --body-file from a temp file: bodies carry backticks that --body would
    # let the shell mangle (pr-mandatory.md, #2368).
    import tempfile
    from pathlib import Path

    with tempfile.NamedTemporaryFile(
        "w", suffix=".md", delete=False, encoding="utf-8"
    ) as handle:
        handle.write(body)
        path = handle.name
    try:
        run_gh(["issue", "comment", issue_number, "--repo", repo, "--body-file", path])
    finally:
        Path(path).unlink(missing_ok=True)


# --- main ---------------------------------------------------------------------


def default_agent() -> str | None:
    name = os.environ.get("COMPUTERNAME", "")
    return name.lower() if name.startswith("MYIA-") else None


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="Issue-claim guard -- check/pose/lift the cross-machine claim "
        "lock living on the GitHub issue (ADR 017, #3676)."
    )
    parser.add_argument("issue", help="issue number")
    parser.add_argument("--repo", default=DEFAULT_REPO, help=f"default: {DEFAULT_REPO}")
    parser.add_argument(
        "--agent",
        default=default_agent(),
        help="this machine's id (e.g. myia-po-2026); default: COMPUTERNAME",
    )
    parser.add_argument(
        "--stale-threshold",
        type=float,
        default=24.0,
        metavar="HOURS",
        help="other machines' claims older than this are STALE, not blocking "
        "(default: 24; age = server createdAt)",
    )
    parser.add_argument(
        "--claim",
        metavar="INTENTION",
        help='post "[CLAIMED] <agent> -- <intention>" (no timestamp: server createdAt is authoritative)',
    )
    parser.add_argument(
        "--release",
        action="store_true",
        help='post "[RELEASED] <agent>" closing this machine\'s claim',
    )
    parser.add_argument(
        "--note", default="", help="optional note appended to --release body"
    )
    args = parser.parse_args(argv)

    if args.claim or args.release:
        if not args.agent:
            print("error: --agent (or COMPUTERNAME) required to post a claim", file=sys.stderr)
            return 2
        if args.claim and args.release:
            print("error: --claim and --release are mutually exclusive", file=sys.stderr)
            return 2
        body = (
            f"[CLAIMED] {args.agent} -- {args.claim}\n"
            "(lock per ADR 017 -- server createdAt is authoritative; "
            "lift with --release, [DONE] or [RESULT])"
            if args.claim
            else f"[RELEASED] {args.agent}"
            + (f" -- {args.note}" if args.note else "")
        )
        try:
            post_comment(args.issue, args.repo, body)
        except RuntimeError as err:
            print(f"error: {err}", file=sys.stderr)
            return 2
        print(f"posted on #{args.issue} ({args.repo}):\n  {body.splitlines()[0]}")
        return 0

    # --- check mode ----------------------------------------------------------
    if not args.agent:
        print(
            "error: --agent (or COMPUTERNAME) required to distinguish self from others",
            file=sys.stderr,
        )
        return 2
    try:
        issue = fetch_issue(args.issue, args.repo)
    except (RuntimeError, json.JSONDecodeError) as err:
        print(f"error: {err}", file=sys.stderr)
        return 2

    if issue.get("state") != "OPEN":
        print(f"BLOCKED: issue #{args.issue} is {issue.get('state')} -- do not start work")
        return 1

    state = reduce_claims(issue.get("comments", []))
    blocking, warnings, notes = classify(
        state, args.agent, args.stale_threshold
    )

    for note in notes:
        print(f"note: {note}")
    for warning in warnings:
        print(warning)
    for machine, age, line in blocking:
        print(f"BLOCKED: active claim by {machine} ({age:.1f}h) -- {line}")
    if blocking:
        print("Another machine holds an active claim -- do not start, pick elsewhere.")
        print("Repair hint (unowned marker): re-post ONE comment with only "
              "'[CLAIMED] <machine> -- ...' on its first line.")
        return 1

    active = [m for m, e in state.items() if e["state"] == "active"]
    if active:
        print(f"CLEAR (resuming; active claims: {', '.join(sorted(str(m) for m in active))})")
    else:
        print("CLEAR -- no active claim on this issue; post yours with --claim")
    return 0


if __name__ == "__main__":
    sys.exit(main())
