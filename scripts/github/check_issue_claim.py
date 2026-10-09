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

Claim identity is the LANE id `machine[:workspace]` (#4114), e.g.
`myia-po-2026:roo-extensions` -- the machine token (`myia-ai-01`,
`myia-po-2023`..`2027`, `myia-web1`, `myia-web2`) plus an optional workspace
suffix, read from the marker line, never the comment author: agents post under
shared gh identities. The workspace defaults to the basename of the git
toplevel (`--workspace` overrides the suffix, `--agent` replaces the whole
id). A pre-#4114 claim carrying NO workspace is seen by a lane of the SAME
machine as a FOREIGN claim -- fail-closed with a `LEGACY_CLAIM` warning: two
lanes share one machine, only the workspace tells them apart. A `[CLAIMED]`
marker with NO identifiable machine at all is fail-CLOSED: it blocks as an
unowned claim and the guard prints the repair gesture (re-post with the lane
id), because silently ignoring a malformed lock is how collisions happen.

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
from pathlib import Path
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

# The quota-exhaustion vocabulary GitHub itself uses, primary ("API rate limit
# exceeded") and secondary ("You have exceeded a secondary rate limit"). Unlike
# the 404 trap above, this phrase family only ever appears in an actual limit
# error, so matching it is safe. It gates the two automatic fallbacks this tool
# allows: when the GraphQL read (`gh issue view --json`, #3899) or the GraphQL
# write (`gh issue comment`, #4155) dies on a recognised quota error, the call
# is retried over REST (`gh api`), whose budget is separate. Any OTHER failure
# (network, auth, 5xx) still raises as-is -- a timeout is not a quota
# condition, and retrying it on a second API would just move the outage around.
# The match runs on run_gh's error text, which quotes the command's args: free
# text must never travel as an arg of a classified call (see post_comment).
RATE_LIMIT_RE = re.compile(r"rate limit", re.IGNORECASE)

# --- markers -----------------------------------------------------------------

# A comment line is a claim EVENT only if it STARTS with one of these bracketed
# markers, after optional markdown decoration (header hashes, list dash, bold,
# inline-code backticks -- #3826: a release comment whose marker is wrapped in
# backticks must still close the claim).
# Line-anchored: a marker mentioned mid-sentence is prose, not an event.
#
# ACCEPTED RESIDUAL (#3878 follow-up): a backticked marker that starts a line
# of its own inside a QUOTATION (a fenced example block, or a quoted reply
# where the quote marker was stripped and the line rejoins column 0) is
# indistinguishable from a real event -- the line anchor cannot see quoting
# context. Tolerated because the false direction is a RELEASE (cost: one
# re-claim race, bounded by the pre-claim check), while excluding backticks
# entirely would drop REAL release comments again (#3826). Mitigation, such
# as it is: the lane token still has to resolve (extract_lane), so a quote
# naming no machine stays inert.
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

# Lane identity token (#4114): machine + optional ":workspace" suffix. Read
# from the marker LINE (first match), not the whole body -- a repair comment
# may quote another lane's marker in prose below its own. The machine part is
# lowercased; the workspace keeps its written case (display only -- every
# comparison is case-insensitive).
LANE_RE = re.compile(
    r"\b(?P<machine>myia-(?:ai|po|web)[a-z0-9-]*)(?::(?P<workspace>[A-Za-z0-9._-]+))?",
    re.IGNORECASE,
)


# --- pure helpers ------------------------------------------------------------


def now_utc() -> datetime:
    return datetime.now(timezone.utc)


def parse_iso_utc(raw: str) -> datetime:
    """Parse a GitHub server `createdAt` (ISO 8601, UTC) into an aware datetime."""
    parsed = datetime.fromisoformat(raw.replace("Z", "+00:00"))
    if parsed.tzinfo is None:  # defensive: server stamps are always tz-aware
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed


def extract_lane(line: str) -> str | None:
    """First lane id on the marker line: "machine" or "machine:workspace".

    Machine part lowercased, workspace kept as written (#4114). None when no
    machine token resolves.
    """
    match = LANE_RE.search(line)
    if not match:
        return None
    machine = match.group("machine").lower()
    workspace = match.group("workspace")
    return f"{machine}:{workspace}" if workspace else machine


def scan_comment_events(body: str):
    """Yield (marker_upper, lane_or_None, line) for every line-anchored marker.

    Ordered top-to-bottom as written -- the reducer applies them in that order
    per lane ("last marker wins").
    """
    for line in body.splitlines():
        match = MARKER_RE.search(line)
        if match:
            yield match.group("marker").upper(), extract_lane(line), line.strip()


def reduce_claims(comments):
    """Reconstruct the claim state from issue comments.

    `comments`: iterable of dicts with `body` (str) and `createdAt` (ISO str),
    in ANY order -- they are sorted by server `createdAt` (stable) first.

    Returns dict lane -> {'state': 'active'|'released', 'since': datetime,
    'line': str} where lane is "machine" or "machine:workspace" (#4114).
    Unowned markers (no machine on the line) aggregate under the sentinel key
    ``None``: fail-closed, they block everyone but their own (nonexistent)
    owner.
    """
    ordered = sorted(comments, key=lambda c: c.get("createdAt", ""))
    state: dict = {}
    for comment in ordered:
        for marker, lane, line in scan_comment_events(comment.get("body", "")):
            entry = state.get(lane)
            if marker in OPEN_MARKERS:
                state[lane] = {
                    "state": "active",
                    "since": parse_iso_utc(comment["createdAt"]),
                    "line": line,
                }
            elif marker in CLOSE_MARKERS and entry is not None:
                # A close without a prior open for that lane is a no-op
                # (e.g. [DONE] report on work never claimed via comment).
                entry["state"] = "released"
                entry["line"] = line
    return state


def _same_lane(claim_lane: str, agent: str) -> bool:
    """Case-insensitive lane equality (workspace case is display-only)."""
    return claim_lane.lower() == agent.lower()


def _legacy_same_machine(claim_lane: str, agent: str) -> bool:
    """Same machine, one side without a workspace suffix (#4114).

    A pre-#4114 claim ("myia-po-2026") seen by "myia-po-2026:roo-extensions"
    -- or the converse. Both sides lane-less is plain equality (handled by
    _same_lane); this predicate catches only the half-migrated shape.
    """
    claim_machine, _, claim_ws = claim_lane.partition(":")
    agent_machine, _, agent_ws = agent.partition(":")
    return claim_machine.lower() == agent_machine.lower() and (
        not claim_ws or not agent_ws
    )


def classify(state, agent, threshold_hours, now=None):
    """Classify claims for the checking agent. Returns (blocking, warnings, notes).

    Identity is the lane id "machine[:workspace]" (#4114): the agent resumes
    only its OWN lane's claim. A different machine, or the same machine with
    a different workspace, is FOREIGN (blocks while fresh, STALE past the
    threshold). A claim without a workspace seen from a lane of the same
    machine is LEGACY: fail-closed -- it blocks while fresh, with a
    LEGACY_CLAIM warning naming the repair gesture.

    blocking : list of (lane, age_hours, line) -- OTHER active claims within
               the staleness threshold (plus the unowned sentinel, always).
    warnings : list of strings (STALE_CLAIM ... / LEGACY_CLAIM ...).
    notes    : list of strings (own-claim status).
    """
    now = now or now_utc()
    threshold = threshold_hours
    blocking, warnings, notes = [], [], []
    for lane, entry in state.items():
        if entry["state"] != "active":
            continue
        age = (now - entry["since"]).total_seconds() / 3600.0
        label = lane if lane else "<UNOWNED -- repair the marker>"
        if lane is None:
            # Fail-closed: an active claim nobody owns blocks every claimant.
            blocking.append((label, age, entry["line"]))
            continue
        if _same_lane(lane, agent):
            notes.append(
                f"own claim active since {entry['since'].isoformat()} "
                f"({age:.1f}h) -- resuming"
            )
            continue
        if _legacy_same_machine(lane, agent):
            warnings.append(
                f"LEGACY_CLAIM {lane} -- claim without workspace on this "
                "machine; treated as FOREIGN (fail-closed, #4114); repair: "
                "its owner re-posts with its lane id, or wait out the "
                "staleness threshold"
            )
        if age > threshold:
            warnings.append(
                f"STALE_CLAIM {lane} {age:.1f}h (> {threshold}h) -- not blocking; "
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
    """Fetch issue state + comments as a dict. Raises RuntimeError on gh failure.

    GraphQL first (`gh issue view --json`), REST fallback ONLY when the GraphQL
    call died on an explicitly recognised quota error (#3899): the fleet hits
    the GraphQL limit at active hours, precisely when collisions matter most.
    The REST endpoints run on a separate budget, so the guard keeps answering.
    If REST is limited too, `run_gh` raises and the caller exits 2 -- the
    fail-closed contract is unchanged.

    The REST comments endpoint is paginated; with `--paginate --jq` gh emits
    one compact JSON object per line across pages, which is parsed line-wise.
    Field names are mapped to the GraphQL shape reduce_claims expects
    (`createdAt`), so both paths feed the same reducer.
    """
    try:
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
    except RuntimeError as err:
        if not RATE_LIMIT_RE.search(str(err)):
            raise
    state = json.loads(
        run_gh(
            ["api", f"repos/{repo}/issues/{issue_number}", "--jq", "{state: .state}"]
        )
    )
    comments_raw = run_gh(
        [
            "api",
            f"repos/{repo}/issues/{issue_number}/comments",
            "--paginate",
            "--jq",
            ".[] | {createdAt: .created_at, body: .body}",
        ]
    )
    comments = [
        json.loads(line) for line in comments_raw.splitlines() if line.strip()
    ]
    # REST serves open/closed in lower case; main() compares "OPEN" (#3909).
    return {"state": state["state"].upper(), "comments": comments}


def post_comment(issue_number: str, repo: str, body: str) -> None:
    """Post a comment, REST fallback on a GraphQL quota error (write leg of
    #3899).

    fetch_issue has fallen back to REST since #3899, but posting stayed on
    `gh issue comment` (GraphQL): during a fleet quota window a lane could
    READ the verdict yet not TAKE the lock -- measured 2026-10-09, a bare
    check answered CLEAR while `--claim` died, leaving the collision guard
    silently disarmed exactly when the fleet is most active. Same
    recognition rule as fetch_issue: explicitly recognised quota errors only
    (a network error propagates untouched), and if REST is limited too the
    error surfaces -- fail-closed, no silent no-op claim.

    A double post cannot corrupt the ledger: both legs carry the SAME marker
    for the SAME lane, and the reducer is last-marker-wins per lane.
    """
    # --body-file from a temp file, not --body: run_gh quotes the command's
    # args in its error text and RATE_LIMIT_RE scans that text, so an inline
    # body that says "rate limit" would turn a 5xx into a REST retry. (No shell
    # is involved -- subprocess.run gets an argv list -- so backticks are not
    # the concern.) The REST leg below passes the body inline with -f: its
    # error is terminal, never classified, and a claim body is two lines.
    import tempfile
    from pathlib import Path

    with tempfile.NamedTemporaryFile(
        "w", suffix=".md", delete=False, encoding="utf-8"
    ) as handle:
        handle.write(body)
        path = handle.name
    try:
        try:
            run_gh(["issue", "comment", issue_number, "--repo", repo, "--body-file", path])
            return
        except RuntimeError as err:
            if not RATE_LIMIT_RE.search(str(err)):
                raise
        run_gh(
            [
                "api",
                "--method",
                "POST",
                f"repos/{repo}/issues/{issue_number}/comments",
                "-f",
                f"body={body}",
            ]
        )
    finally:
        Path(path).unlink(missing_ok=True)


# --- main ---------------------------------------------------------------------


def _resolve_gitfile_toplevel(gitfile: Path) -> Path | None:
    """Main-checkout toplevel from a linked worktree's `.git` file (#4122).

    The file holds `gitdir: <main>/.git/worktrees/<name>`; stripping the
    `worktrees/<name>` tail reaches the common `.git` dir, whose parent is
    the main toplevel. A pointer without a worktrees segment (submodule:
    `.git/modules/<name>`) or an unreadable file returns None -- the caller
    keeps walking instead of guessing.
    """
    try:
        text = gitfile.read_text(encoding="utf-8", errors="replace").strip()
    except OSError:
        return None
    if not text.startswith("gitdir:"):
        return None
    gitdir = Path(text[len("gitdir:"):].strip())
    if not gitdir.is_absolute():
        gitdir = (gitfile.parent / gitdir).resolve()
    parts = gitdir.parts
    for i in range(len(parts) - 2):
        if parts[i] == ".git" and parts[i + 1] == "worktrees":
            return Path(*parts[:i])
    return None


def detect_workspace() -> str:
    """Default workspace: basename of the git toplevel (#4114).

    A pure-filesystem walk-up -- NO subprocess: the picker's tests mock all
    of subprocess.run with exact call sequences, and a stray `git` call would
    both consume a mocked response and return garbage as a workspace. A
    linked worktree's `.git` is a FILE (gitdir pointer): it resolves back to
    the main checkout's toplevel -- a worktree is where a lane works, not a
    workspace of its own, so claiming from a worktree must not fragment the
    lane identity (#4122 review). A `.git` file that does not parse
    (submodule pointer, corrupt) falls through and the walk-up continues.
    """
    try:
        cwd = Path.cwd().resolve()
        for candidate in (cwd, *cwd.parents):
            git = candidate / ".git"
            if git.is_dir():
                return candidate.name
            if git.is_file():
                resolved = _resolve_gitfile_toplevel(git)
                if resolved is not None:
                    return resolved.name
    except OSError:
        pass
    return ""


def default_agent(workspace: str | None = None) -> str | None:
    """Lane identity "machine[:workspace]" from the environment (#4114).

    `workspace` overrides the suffix; the default is the basename of the git
    toplevel. Without a detectable toplevel the identity degrades to the
    machine token (legacy shape). Off-fleet COMPUTERNAME -> None.
    """
    name = os.environ.get("COMPUTERNAME", "")
    machine = name.lower() if name.startswith("MYIA-") else None
    if machine is None:
        return None
    ws = workspace if workspace is not None else detect_workspace()
    return f"{machine}:{ws}" if ws else machine


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
        default=None,
        help="this lane's id, machine[:workspace] (e.g. myia-po-2026:roo-extensions); "
        "default: COMPUTERNAME + detected workspace (#4114)",
    )
    parser.add_argument(
        "--workspace",
        default=None,
        metavar="NAME",
        help="workspace suffix override; default: basename of the git toplevel "
        "(#4114); ignored when --agent already carries a workspace",
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

    if args.agent is None:
        # Lane identity composition (#4114): --agent replaces the whole id,
        # --workspace overrides only the suffix.
        args.agent = default_agent(args.workspace)

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
    for lane, age, line in blocking:
        print(f"BLOCKED: active claim by {lane} ({age:.1f}h) -- {line}")
    if blocking:
        print("Another lane holds an active claim -- do not start, pick elsewhere.")
        print("Repair hint (unowned marker): re-post ONE comment with only "
              "'[CLAIMED] <machine[:workspace]> -- ...' on its first line.")
        return 1

    active = [l for l, e in state.items() if e["state"] == "active"]
    if active:
        print(f"CLEAR (resuming; active claims: {', '.join(sorted(str(l) for l in active))})")
    else:
        print("CLEAR -- no active claim on this issue; post yours with --claim")
    return 0


if __name__ == "__main__":
    sys.exit(main())
