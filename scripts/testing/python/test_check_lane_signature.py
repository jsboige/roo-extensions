#!/usr/bin/env python3
"""
test_check_lane_signature.py — scripts/git/check_lane_signature.py (lane trailer guard).

Each case builds a real repository in a temp dir (with a local bare origin so the
default range origin/main..HEAD works), runs the REAL script as a subprocess,
and asserts exit code + stderr naming. The script resolves the fleet manifest
from its own location (the real repo checkout) — myia-po-2024 IS in the real
manifest, myia-zz-99 is NOT, so both manifest paths are exercised without
fixtures.

Cases:
  - OK                 : every non-merge commit signed -> exit 0.
  - UNSIGNED           : one commit missing the trailer -> exit 1, sha named.
  - MERGE_EXCLUDED     : merge commit (2 parents) unsigned + signed commits -> exit 0.
  - BAD_FORMAT         : Lane: po-204 (no myia- prefix) -> exit 1.
  - UNKNOWN_MACHINE    : Lane: myia-zz-99:x -> machine absent from the real
                         fleet-manifest -> exit 1.
  - COMMIT_MSG_OK      : message FILE (commit-msg hook mode) with trailer ->
                         exit 0, template comment lines ignored.
  - COMMIT_MSG_MISSING : message file without trailer -> exit 1.
"""

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / "git" / "check_lane_signature.py"

GIT_ENV = {
    **os.environ,
    "GIT_TERMINAL_PROMPT": "0",
    "GIT_AUTHOR_NAME": "tester",
    "GIT_AUTHOR_EMAIL": "tester@example.invalid",
    "GIT_COMMITTER_NAME": "tester",
    "GIT_COMMITTER_EMAIL": "tester@example.invalid",
    "GIT_CONFIG_NOSYSTEM": "1",
}


def git(cwd, *args, msg=None, extra_env=None):
    env = {**GIT_ENV, **(extra_env or {})}
    proc = subprocess.run(["git", *args], cwd=cwd, env=env, capture_output=True,
                          text=True, encoding="utf-8", errors="replace", input=msg)
    if proc.returncode != 0:
        raise AssertionError(f"git {' '.join(args)} failed in {cwd}: {proc.stderr}")
    return proc.stdout.strip()


def run_guard(cwd, *args):
    proc = subprocess.run([sys.executable, str(SCRIPT), *args], cwd=cwd, env=GIT_ENV,
                          capture_output=True, text=True, encoding="utf-8", errors="replace")
    return proc.returncode, proc.stdout, proc.stderr


class RepoFixture:
    """Temp repo with a bare origin carrying one signed commit on main."""

    def __init__(self):
        self.dir = tempfile.mkdtemp(prefix="lane-sig-")
        self.work = Path(self.dir) / "work"
        self.work.mkdir()
        git(self.work, "init", "-b", "main")
        git(self.work, "config", "user.name", "tester")
        git(self.work, "config", "user.email", "tester@example.invalid")
        self.origin = Path(self.dir) / "origin.git"
        git(self.dir, "init", "--bare", str(self.origin))
        self.commit("base", lane="myia-po-2024:roo-extensions")
        git(self.work, "remote", "add", "origin", str(self.origin))
        git(self.work, "push", "origin", "main")
        git(self.work, "fetch", "origin")

    def commit(self, subject, lane=None, extra_trailer=None, date=None):
        f = self.work / f"{subject.replace(' ', '-')}.txt"
        f.write_text(subject, encoding="utf-8")
        git(self.work, "add", "-A")
        msg = subject
        if lane:
            msg += f"\n\nLane: {lane}"
        if extra_trailer:
            msg += f"\n{extra_trailer}"
        extra_env = {"GIT_COMMITTER_DATE": date} if date else None
        git(self.work, "commit", "-m", msg, extra_env=extra_env)

    def merge_commit(self, subject):
        """A real merge (2 parents) without any Lane trailer."""
        git(self.work, "checkout", "-b", "side")
        self.commit("side work", lane="myia-po-2024:roo-extensions")
        git(self.work, "checkout", "main")
        git(self.work, "merge", "--no-ff", "-m", subject, "side")

    def range(self):
        return "origin/main..HEAD"


class LaneSignatureGuardTest(unittest.TestCase):
    def setUp(self):
        self.fx = RepoFixture()

    def test_ok_all_signed(self):
        self.fx.commit("second", lane="myia-ai-01:CoursIA-2")
        self.fx.commit("third", lane="myia-web1")
        rc, out, _ = run_guard(self.fx.work, self.fx.range())
        self.assertEqual(rc, 0, out)
        self.assertIn("OK", out)

    def test_unsigned_commit_refused(self):
        self.fx.commit("signed", lane="myia-po-2024:roo-extensions")
        self.fx.commit("unsigned one")
        rc, _, err = run_guard(self.fx.work, self.fx.range())
        self.assertEqual(rc, 1)
        self.assertIn("UNSIGNED", err)
        self.assertIn("unsigned one", err)

    def test_merge_commit_excluded(self):
        self.fx.commit("signed", lane="myia-po-2024:roo-extensions")
        self.fx.merge_commit("Merge branch 'side'")
        rc, out, _ = run_guard(self.fx.work, self.fx.range())
        self.assertEqual(rc, 0, out)

    def test_bad_format_refused(self):
        self.fx.commit("bad lane", lane="po-204")  # no myia- prefix
        rc, _, err = run_guard(self.fx.work, self.fx.range())
        self.assertEqual(rc, 1)
        self.assertIn("format invalide", err)

    def test_unknown_machine_refused(self):
        # The real fleet-manifest (resolved from the script's own location) does
        # not know myia-zz-99.
        self.fx.commit("ghost machine", lane="myia-zz-99:roo-extensions")
        rc, _, err = run_guard(self.fx.work, self.fx.range())
        self.assertEqual(rc, 1)
        self.assertIn("fleet-manifest", err)

    def test_commit_msg_mode_ok_with_template_comments(self):
        msgfile = Path(self.fx.dir) / "COMMIT_EDITMSG"
        msgfile.write_text(
            "subject line\n\nBody paragraph.\n\n"
            "Lane: myia-po-2024:roo-extensions\n"
            "Co-Authored-By: Someone <x@y>\n"
            "# ------------------------ >8 ------------------------\n"
            "# Please enter the commit message...\n",
            encoding="utf-8",
        )
        rc, out, err = run_guard(self.fx.work, "--commit-msg", str(msgfile))
        self.assertEqual(rc, 0, err)

    def test_commit_msg_mode_missing(self):
        msgfile = Path(self.fx.dir) / "COMMIT_EDITMSG"
        msgfile.write_text("subject line\n\nno trailer here\n", encoding="utf-8")
        rc, _, err = run_guard(self.fx.work, "--commit-msg", str(msgfile))
        self.assertEqual(rc, 1)
        self.assertIn("Lane:", err)

    def test_default_range_uses_origin_main(self):
        # No explicit range: script must resolve origin/main..HEAD by itself.
        self.fx.commit("on top", lane="myia-po-2024:roo-extensions")
        rc, out, _ = run_guard(self.fx.work)
        self.assertEqual(rc, 0, out)

    def test_since_exempts_pre_rule_commits(self):
        # An UNSIGNED commit dated before the rule (--since) is exempt; a
        # signed one after it still counts. Rollout buffer for open PRs.
        import time
        self.fx.commit("legacy unsigned", lane=None, date="2026-01-01T00:00:00")
        self.fx.commit("fresh signed", lane="myia-po-2024:roo-extensions")
        rc, out, _ = run_guard(self.fx.work, self.fx.range(), "--since", "2026-11-01T00:00:00")
        self.assertEqual(rc, 0, out)
        # Without --since the legacy commit is still refused.
        rc, _, err = run_guard(self.fx.work, self.fx.range())
        self.assertEqual(rc, 1)
        self.assertIn("legacy unsigned", err)


if __name__ == "__main__":
    unittest.main()
