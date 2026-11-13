#!/usr/bin/env python3
"""Issue state block -- insert or refresh the dated state block at the top of an issue body.

Convention: docs/harness/reference/issue-state-block.md. The block lives between
the markers `<!-- etat:debut -->` and `<!-- etat:fin -->`; the original statement
stays below it, unchanged. The tool never touches the rest of the body except
for the checkboxes named with --tick.

Usage (fix the write identity in the SAME command, GH_TOKEN exported):
  python scripts/github/apply_issue_state_block.py [--repo R] [--blocks-dir D]
      [--backup-dir D] [--local-patterns F] [--expect-login L] [--dry-run]
      [--tick N:"substring"[::note]]... N [N ...]

For each N:
  1. SKIP if <blocks-dir>/<N>.md is absent; REFUSED if it matches a forbidden
     pattern or does not start with the dated heading;
  2. read the CURRENT body from GitHub (REST); a pull request is skipped;
  3. back the body up once to <backup-dir>/<N>.md (the first version seen is kept);
  4. replace the marked block if present, else insert it at the top, then tick;
  5. REFUSED if a tick target is missing, the checkbox count changed, or the
     body would exceed 64,000 characters;
  6. PATCH, read back, compare (CRLF-insensitive).

Forbidden patterns specific to the fleet (a key file name, for instance) are
not versioned: this repository is public. They are read, one regex per line,
from --local-patterns (default: a gitignored file of the scratch area).

Exit codes: 0 = every issue named was written, passed the dry-run, or is a pull
request; 1 = at least one issue was refused, skipped for a missing block, or
differs at read-back -- or the run was aborted (identity, gh failure).

The pure functions (check_block, compose, tick, plan_body) have no network access.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

DEFAULT_REPO = "jsboige/roo-extensions"
DEFAULT_LOGIN = "myia-ai-01"
REPO_ROOT = Path(__file__).resolve().parents[2]
SCRATCH = REPO_ROOT / ".tmp" / "issue-state-blocks"

BEGIN = "<!-- etat:debut -->"
END = "<!-- etat:fin -->"
FOOT = ("_Bloc d'état tenu par le coordinateur, à rafraîchir quand l'état change. "
        "L'énoncé d'origine suit, inchangé._")
HEADING = "### État au"
MAX_BODY = 64000

FORBIDDEN = [
    (r"\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b", "IPv4 address"),
    (r"[\w.+-]+@[\w-]+\.[\w.-]+", "e-mail address"),
    (r"(?m)^\s*[-*] \[[ xX]\]", "checkbox syntax"),
    (r"- \[ \]", "checkbox pattern"),
    (r"\[DEGRADED\]|\[REPAIRED\]", "escalation token"),
    (r"[A-Za-z]:\\Users\\", "user profile path"),
    (r"\bghp_|\bgho_|\bsk-[A-Za-z0-9]{6}|Bearer\s+[A-Za-z0-9]", "token fragment"),
    (r"\bid_rsa\b|\bid_ed25519\b|\.pem\b", "key file name"),
    (r"(?<![\w/.-])(?!github\.com)[a-z0-9-]+\.(?:com|net|org|io|fr|ai|dev|cloud|local)\b(?!/jsboige)",
     "domain name"),
]
ALLOWED_DOMAIN = re.compile(r"github\.com|claude\.com")
BOX_RE = re.compile(r"(?m)^\s*[-*] \[[ xX]\]")
OPEN_BOX_RE = re.compile(r"(?m)^\s*[-*] \[ \]")


class GhError(RuntimeError):
    """A gh call failed: the run stops, nothing more is written."""


# --- pure functions (no network) ---------------------------------------------

def load_local_patterns(path):
    """Read fleet-specific regexes (one per line, '#' starts a comment). Absent file = []."""
    p = Path(path)
    if not p.exists():
        return []
    pats = []
    for line in p.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            re.compile(line)  # an invalid regex raises re.error here, not mid-run
            pats.append((line, "local pattern"))
    return pats


def check_block(block, extra=()):
    """Return the list of problems of a block (empty list = the block may be written)."""
    bad = []
    for rx, name in list(FORBIDDEN) + list(extra):
        for m in re.finditer(rx, block):
            if name == "domain name" and ALLOWED_DOMAIN.search(m.group(0)):
                continue
            bad.append("%s: %r" % (name, m.group(0)))
    if not block.lstrip().startswith(HEADING):
        bad.append("block does not start with the dated heading")
    return bad


def compose(old, block):
    """Replace the marked block of `old` if present, else insert it at the top."""
    marked = "%s\n%s\n\n%s\n%s" % (BEGIN, block.strip("\n"), FOOT, END)
    if BEGIN in old and END in old:
        a, b = old.index(BEGIN), old.index(END) + len(END)
        return old[:a] + marked + old[b:]
    return marked + "\n\n---\n\n" + old


def tick(body, sub, note):
    """Check the first open checkbox whose line contains `sub`; append ` — note` if given."""
    lines = body.split("\n")
    for i, line in enumerate(lines):
        if re.match(r"\s*[-*] \[ \]", line) and sub in line:
            l2 = re.sub(r"\[ \]", "[x]", line, count=1)
            cr = "\r" if l2.endswith("\r") else ""
            l2 = l2.rstrip("\r")
            if note:
                l2 += " — " + note
            lines[i] = l2 + cr
            return "\n".join(lines), True
    return body, False


def count_boxes(text):
    return len(BOX_RE.findall(text))


def plan_body(old, block, ticks=()):
    """Compose the new body. Return (new, notes, refusal); refusal is None when writable."""
    new = compose(old, block)
    notes = []
    for sub, note in ticks:
        new, done = tick(new, sub, note)
        notes.append("tick %s %r" % ("OK" if done else "MISSING", sub[:40]))
    before, after = count_boxes(old), count_boxes(new)
    if before != after:
        return new, notes, "checkbox count changed %d -> %d" % (before, after)
    if any("MISSING" in x for x in notes):
        return new, notes, "; ".join(notes)
    if len(new) > MAX_BODY:
        return new, notes, "body would be %d chars" % len(new)
    return new, notes, None


def parse_tick(spec):
    """`N:substring[::note]` -> (N, substring, note)."""
    n, sep, rest = spec.partition(":")
    if not sep or not n.strip().isdigit() or not rest:
        raise argparse.ArgumentTypeError("expected N:\"substring\"[::note], got %r" % spec)
    sub, _, note = rest.partition("::")
    return n.strip(), sub, note


# --- gh seam (tests patch it) -------------------------------------------------

def _gh(args):
    try:
        r = subprocess.run(["gh"] + args, capture_output=True)
    except OSError as err:
        raise GhError("gh could not be launched: %s" % err)
    if r.returncode != 0:
        raise GhError("gh %s failed: %s" % (" ".join(args[:4]),
                                            r.stderr.decode("utf-8", "replace")[:400]))
    return r.stdout.decode("utf-8")


def _fetch(repo, n):
    return json.loads(_gh(["api", "repos/%s/issues/%s" % (repo, n)]))


# --- main ---------------------------------------------------------------------

def main(argv=None):
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description="Insert or refresh the dated state block of issues.")
    ap.add_argument("issues", nargs="+", help="issue numbers")
    ap.add_argument("--repo", default=DEFAULT_REPO)
    ap.add_argument("--blocks-dir", default=str(SCRATCH / "blocks"), help="holds <N>.md")
    ap.add_argument("--backup-dir", default=str(SCRATCH / "backup"),
                    help="original bodies, written once per issue")
    ap.add_argument("--local-patterns", default=str(SCRATCH / "forbidden-local.txt"),
                    help="fleet-specific forbidden regexes, one per line (not versioned)")
    ap.add_argument("--expect-login", default=DEFAULT_LOGIN,
                    help="refuse to write under any other gh identity")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--tick", action="append", default=[], type=parse_tick,
                    metavar='N:"substring"[::note]')
    args = ap.parse_args(argv)

    ticks = {}
    for n, sub, note in args.tick:
        ticks.setdefault(n, []).append((sub, note))
    try:
        extra = load_local_patterns(args.local_patterns)
    except re.error as err:
        print("ABORTED — invalid regex in %s: %s" % (args.local_patterns, err))
        return 1
    if not extra:
        print("note: no local patterns read from %s" % args.local_patterns)

    if not args.dry_run:
        try:
            login = _gh(["api", "user", "--jq", ".login"]).strip()
        except GhError as err:
            print("ABORTED — %s" % err)
            return 1
        if login != args.expect_login:
            print("ABORTED — identity is %r, expected %r — nothing written"
                  % (login, args.expect_login))
            return 1

    os.makedirs(args.backup_dir, exist_ok=True)
    ok = failed = 0
    try:
        for n in args.issues:
            bp = os.path.join(args.blocks_dir, "%s.md" % n)
            if not os.path.exists(bp):
                print("#%s: SKIP no block file" % n)
                failed += 1
                continue
            with open(bp, encoding="utf-8") as fh:
                block = fh.read()
            bad = check_block(block, extra)
            if bad:
                print("#%s: REFUSED — %s" % (n, "; ".join(bad[:6])))
                failed += 1
                continue
            cur = _fetch(args.repo, n)
            if cur.get("pull_request"):
                print("#%s: SKIP is a pull request" % n)
                continue
            old = cur.get("body") or ""
            bk = os.path.join(args.backup_dir, "%s.md" % n)
            if not os.path.exists(bk):
                with open(bk, "w", encoding="utf-8", newline="") as fh:
                    fh.write(old)
            new, notes, refusal = plan_body(old, block, ticks.get(n, []))
            if refusal:
                print("#%s: REFUSED — %s" % (n, refusal))
                failed += 1
                continue
            open_new = len(OPEN_BOX_RE.findall(new))
            if args.dry_run:
                print("#%s: DRY state=%s old=%d new=%d boxes=%d open=%d %s" % (
                    n, cur.get("state"), len(old), len(new), count_boxes(new), open_new,
                    "; ".join(notes)))
                ok += 1
                continue
            payload = os.path.join(args.backup_dir, "%s.payload.json" % n)
            with open(payload, "w", encoding="utf-8") as fh:
                fh.write(json.dumps({"body": new}))
            try:
                _gh(["api", "-X", "PATCH", "repos/%s/issues/%s" % (args.repo, n),
                     "--input", payload, "--jq", ".number"])
            finally:
                os.remove(payload)
            back = _fetch(args.repo, n).get("body") or ""
            same = back.replace("\r\n", "\n") == new.replace("\r\n", "\n")
            print("#%s: %s state=%s old=%d new=%d open-boxes=%d %s" % (
                n, "WRITTEN" if same else "READBACK-DIFFERS", cur.get("state"), len(old),
                len(new), open_new, "; ".join(notes)))
            if same:
                ok += 1
            else:
                failed += 1
    except GhError as err:
        print("ABORTED — %s" % err)
        failed += 1
    print("done: %d %s, %d failed, of %d" % (
        ok, "passed dry-run" if args.dry_run else "written", failed, len(args.issues)))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
