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
or issue closed) / 2 io-or-gh error, which INCLUDES "the repo could not be
determined" -- a lookup that failed, or a number that is an issue in neither
repo / 3 repo ambiguity (#3768: the number is an issue in BOTH repos and --repo
was not given -- the guard refuses to guess).

Exit 3 is reserved for a question that WAS answered and whose answer is
ambiguous. A lookup that never happened is an io error (2), not an ambiguity:
reporting an outage as an ambiguity would send the operator hunting for a
collision that does not exist.
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
SUBMODULE_REPO = "jsboige/jsboige-mcp-servers"
KNOWN_REPOS = (DEFAULT_REPO, SUBMODULE_REPO)

# The ONE failure `gh api` reports that actually means "this number is not here".
# Every other non-zero exit (403 secondary limit, auth, network) means the lookup
# did not happen -- see classify_number.
#
# Matched on the HTTP code alone, never on the prose: `gh api` always renders an
# API error as "... (HTTP NNN)", while "not found" appears in plenty of messages
# that are NOT a 404 -- including this module's own "gh could not be launched"
# when the OS strerror happens to contain it. Sniffing prose for a status code
# re-opens the fail-open this guard exists to close.
NOT_FOUND_RE = re.compile(r"HTTP 404")

# `_gh_exec` returncode when gh could not be launched at all. Distinct from any
# exit code gh itself can return, so it never has to be recognised from prose.
GH_UNRUNNABLE = -1

# --- markers -----------------------------------------------------------------

# A comment line is a claim EVENT only if it STARTS with one of these bracketed
# markers, after optional markdown decoration (header hashes, list dash, bold,
# inline-code backticks -- #3826: a release comment whose marker is wrapped in
# backticks must still close the claim).
# Line-anchored: a marker mentioned mid-sentence is prose, not an event.
MARKER_RE = re.compile(
    r"(?im)^#{0,6}\s*[-*]?\s*[*/`]{0,2}\["
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


def _gh_exec(args):
    """The single seam every gh invocation goes through.

    Returns `(returncode, stdout, stderr)` instead of raising, so a caller can
    tell a PROVEN 404 from a lookup that never happened. Tests patch this.

    An unrunnable `gh` (absent from PATH, not executable) is reported the same
    way rather than raised: letting OSError escape produced a traceback and
    exit 1 -- which this tool's contract defines as "another machine holds the
    claim". A cron worker with a broken PATH would read an environment failure
    as a concurrent lock and quietly route elsewhere. Same shape as the exit-3
    confusion this organ was just fixed for: never let a failure to measure
    borrow the exit code of a measured verdict.
    """
    try:
        proc = subprocess.run(
            ["gh", *args],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
    except OSError as err:
        return GH_UNRUNNABLE, "", f"gh could not be launched: {err}"
    return proc.returncode, proc.stdout, proc.stderr


def run_gh(args, check=True):
    """Run a gh command, return stdout. Raises RuntimeError with stderr on failure."""
    code, out, err = _gh_exec(args)
    if check and code != 0:
        raise RuntimeError(
            f"gh {' '.join(args)} failed (exit {code}): "
            f"{err.strip() or out.strip()}"
        )
    return out


def classify_number(number: str, repo: str) -> str:
    """Is `number` an ISSUE, a PULL REQUEST, absent, or UNMEASURED in `repo`?

    Issues and PRs share ONE numbering space per repo, and `gh issue view` renders
    a PR without complaint. The discriminant is the `pull_request` key of the REST
    payload (#3768): #980 was a MERGED PR in the parent and an OPEN issue in the
    submodule, so reading the parent produced a sincere -- and false --
    "BLOCKED: issue #980 is MERGED", skipping a grain nobody had claimed.

    Returns "issue", "pr", "absent" (a 404 the server actually returned) or
    "error" (the question was never answered: 403 secondary limit, auth, network).
    That last value is the whole point of this function's contract. Folding a
    failed lookup into "absent" is fail-OPEN: `resolve_repo` would then see a
    single candidate and silently resolve to the repo that happened to answer,
    writing `--claim` on the wrong repo's ticket. "The instrument returned
    nothing" is never "there is nothing".
    """
    code, out, err = _gh_exec(
        [
            "api",
            f"repos/{repo}/issues/{number}",
            "--jq",
            'if .pull_request then "pr" else "issue" end',
        ]
    )
    if code == 0:
        kind = out.strip()
        return kind if kind in ("issue", "pr") else "error"
    if code == GH_UNRUNNABLE:
        return "error"
    return "absent" if NOT_FOUND_RE.search(f"{err}\n{out}") else "error"


def resolve_repo(number: str):
    """Pick the repo carrying issue `number` when --repo was NOT given.

    Returns `(repo, note, 0)` on a unique match, or `(None, message, code)` with
    the exit code the caller must use: 2 when the question could not be ANSWERED
    (a lookup failed, or the number is an issue in neither repo), 3 when it was
    answered and the answer is genuinely ambiguous.

    Fail-closed by construction, and that includes PARTIAL failure: if either
    repo could not be read, the guard refuses instead of resolving to the one
    that answered. A wrong pick does not merely skip a grain -- it makes
    `--claim` write the lock on the WRONG repo's issue, leaving the real grain
    unlocked while polluting an unrelated one. Since the fleet meets GitHub's
    secondary rate limit at active hours, "one repo did not answer" is an
    ordinary condition here, not an exotic one.

    PRECONDITION: the caller's token must reach BOTH repos. GitHub answers 404
    -- not 403 -- for a private repo the token cannot see, so a seat without
    submodule access reads every submodule issue as genuinely absent and
    resolves to the parent. That is indistinguishable from a real absence at
    the protocol level; it is a fleet-configuration invariant, not something
    this function can detect. Pass --repo explicitly from such a seat.
    """
    kinds = {repo: classify_number(number, repo) for repo in KNOWN_REPOS}

    unmeasured = [repo for repo, kind in kinds.items() if kind == "error"]
    if unmeasured:
        return None, (
            f"error: cannot tell where #{number} lives -- the lookup FAILED in "
            f"{', '.join(unmeasured)}.\n"
            "       That is a measurement failure, not an absence (403 secondary\n"
            "       limit, auth, network). Pass --repo explicitly, or retry."
        ), 2

    candidates = [repo for repo, kind in kinds.items() if kind == "issue"]
    if len(candidates) == 1:
        other = next(r for r in KNOWN_REPOS if r != candidates[0])
        note = ""
        if kinds[other] == "pr":
            note = (
                f"note: #{number} is a PULL REQUEST in {other}; resolved to "
                f"{candidates[0]} (the #3768 trap)"
            )
        return candidates[0], note, 0
    if not candidates:
        detail = ", ".join(f"{r}={k}" for r, k in kinds.items())
        return None, (
            f"error: #{number} is an issue in neither known repo ({detail}).\n"
            "       Pass --repo explicitly if it lives somewhere else."
        ), 2
    return None, (
        f"AMBIGUOUS: #{number} is a numbering collision -- it is an issue in\n"
        "           BOTH repos, and guessing would lock the wrong one. Re-run with:\n"
        f"             --repo {DEFAULT_REPO}\n"
        f"             --repo {SUBMODULE_REPO}"
    ), 3


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
    parser.add_argument(
        "--repo",
        default=None,
        help=f"default: auto-detected between {DEFAULT_REPO} and {SUBMODULE_REPO}; "
        "pass it explicitly on submodule grains to skip detection (#3768)",
    )
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

    if args.repo is None:
        resolved, message, code = resolve_repo(args.issue)
        if resolved is None:
            print(message, file=sys.stderr)
            return code
        args.repo = resolved
        if message:
            print(message, file=sys.stderr)
        if args.claim or args.release:
            # A mutation under an auto-detected repo must be legible in the log:
            # the operator has to be able to see WHICH ticket got the lock.
            print(
                f"note: --repo was not given; this MUTATION targets {resolved}",
                file=sys.stderr,
            )

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
