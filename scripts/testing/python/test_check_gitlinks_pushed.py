#!/usr/bin/env python3
"""
test_check_gitlinks_pushed.py — scripts/git/check_gitlinks_pushed.py (#4098 guard).

The guard had no test at all. Each case builds real repositories in a temp dir
(a bare origin for the submodule, a bare origin for the parent, and a parent
clone that carries the submodule), then runs the REAL script as a subprocess
from the cwd under test. Offline: every remote is a local bare repository.

Cases:
  - OK            : the bumped gitlink is on a remote branch of the submodule -> exit 0.
  - ORPHAN        : the bumped gitlink was never pushed -> exit 1.
  - WRONG_REPO    : run with no argument from INSIDE the submodule checkout. Before
                    the fix, git answered for the submodule repository (HEAD,
                    origin/main and the diff all valid, no gitlink in it) and the
                    guard printed "OK — aucun gitlink modifie", exit 0. Measured on
                    ai-01, 2026-11-01, from mcps/internal. It must stop (exit 2).
  - FIRST_SUBMODULE : a branch adding the first submodule (no .gitmodules at the
                    base) is checked, not refused by that stop.
  - UNKNOWN_REF   : a branch that only exists on the remote. The error names the
                    repository that was asked and points at origin/<ref>.
"""

import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / "git" / "check_gitlinks_pushed.py"

GIT_ENV = {
    **os.environ,
    "GIT_TERMINAL_PROMPT": "0",
    "GIT_AUTHOR_NAME": "tester",
    "GIT_AUTHOR_EMAIL": "tester@example.invalid",
    "GIT_COMMITTER_NAME": "tester",
    "GIT_COMMITTER_EMAIL": "tester@example.invalid",
    "GIT_CONFIG_NOSYSTEM": "1",
}


def git(cwd, *args):
    proc = subprocess.run(["git", *args], cwd=cwd, env=GIT_ENV, capture_output=True,
                          text=True, encoding="utf-8", errors="replace")
    if proc.returncode != 0:
        raise AssertionError(f"git {' '.join(args)} failed in {cwd}: {proc.stderr}")
    return proc.stdout.strip()


def run_guard(cwd, *args):
    proc = subprocess.run([sys.executable, str(SCRIPT), *args], cwd=cwd, env=GIT_ENV,
                          capture_output=True, text=True, encoding="utf-8", errors="replace")
    return proc.returncode, proc.stdout, proc.stderr


class GitlinkGuardTest(unittest.TestCase):

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="gitlink-guard-"))
        self.sub_origin = self.tmp / "sub-origin.git"
        self.parent_origin = self.tmp / "parent-origin.git"
        git(self.tmp, "init", "-q", "--bare", "-b", "main", str(self.sub_origin))
        git(self.tmp, "init", "-q", "--bare", "-b", "main", str(self.parent_origin))

        seed = self.tmp / "sub-seed"
        git(self.tmp, "init", "-q", "-b", "main", str(seed))
        (seed / "lib.txt").write_text("v1\n", encoding="utf-8")
        git(seed, "add", "lib.txt")
        git(seed, "commit", "-q", "-m", "sub v1")
        git(seed, "push", "-q", self.sub_origin.as_posix(), "main")

        self.parent = self.tmp / "parent"
        git(self.tmp, "init", "-q", "-b", "main", str(self.parent))
        git(self.parent, "remote", "add", "origin", self.parent_origin.as_posix())
        git(self.parent, "-c", "protocol.file.allow=always", "submodule", "add", "-q",
            self.sub_origin.as_posix(), "lib")
        git(self.parent, "commit", "-q", "-m", "add lib")
        git(self.parent, "push", "-q", "-u", "origin", "main")
        self.sub = self.parent / "lib"

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def _bump_gitlink(self, push_submodule):
        (self.sub / "lib.txt").write_text("v2\n", encoding="utf-8")
        git(self.sub, "commit", "-q", "-am", "sub v2")
        if push_submodule:
            git(self.sub, "push", "-q", "origin", "HEAD:main")
        git(self.parent, "checkout", "-q", "-b", "wt/bump")
        git(self.parent, "add", "lib")
        git(self.parent, "commit", "-q", "-m", "bump lib")

    def test_ok_when_bumped_gitlink_is_pushed(self):
        self._bump_gitlink(push_submodule=True)
        rc, out, err = run_guard(self.parent, "wt/bump")
        self.assertEqual(rc, 0, out + err)
        self.assertIn("[OK] lib", out)

    def test_orphan_when_bumped_gitlink_is_not_pushed(self):
        self._bump_gitlink(push_submodule=False)
        rc, out, err = run_guard(self.parent, "wt/bump")
        self.assertEqual(rc, 1, out + err)
        self.assertIn("[ORPHAN] lib", out)

    def test_run_from_inside_the_submodule_stops_instead_of_ok(self):
        # The submodule repository is a valid repo with HEAD and origin/main, and
        # no gitlink of its own: without the guard, the check is vacuous there.
        rc, out, err = run_guard(self.sub)
        self.assertEqual(rc, 2, out + err)
        self.assertNotIn("OK", out)
        self.assertIn(".gitmodules", err)

    def test_run_from_the_parent_with_no_bump_is_still_ok(self):
        # The new guard must not refuse the parent: it declares its submodules.
        rc, out, err = run_guard(self.parent)
        self.assertEqual(rc, 0, out + err)
        self.assertIn("aucun gitlink modifie", out)

    def test_first_submodule_added_on_a_branch_is_checked_not_refused(self):
        # Base without .gitmodules, ref with it: the guard must check the added
        # gitlink (the `:000000 160000` case of changed_gitlinks), not stop.
        plain_origin = self.tmp / "plain-origin.git"
        git(self.tmp, "init", "-q", "--bare", "-b", "main", str(plain_origin))
        plain = self.tmp / "plain"
        git(self.tmp, "init", "-q", "-b", "main", str(plain))
        git(plain, "remote", "add", "origin", plain_origin.as_posix())
        (plain / "README").write_text("no submodule yet\n", encoding="utf-8")
        git(plain, "add", "README")
        git(plain, "commit", "-q", "-m", "plain")
        git(plain, "push", "-q", "-u", "origin", "main")
        git(plain, "checkout", "-q", "-b", "wt/add-lib")
        git(plain, "-c", "protocol.file.allow=always", "submodule", "add", "-q",
            self.sub_origin.as_posix(), "lib")
        git(plain, "commit", "-q", "-m", "add lib")
        rc, out, err = run_guard(plain, "wt/add-lib")
        self.assertEqual(rc, 0, out + err)
        self.assertIn("[OK] lib", out)

    def test_unknown_ref_names_the_repository_and_the_remote_spelling(self):
        git(self.parent, "push", "-q", "origin", "HEAD:refs/heads/wt/remote-only")
        git(self.parent, "fetch", "-q", "origin")
        rc, out, err = run_guard(self.parent, "wt/remote-only")
        self.assertEqual(rc, 2, out + err)
        self.assertIn("ref inconnue", err)
        self.assertIn("origin/wt/remote-only", err)
        self.assertIn(self.parent.resolve().as_posix().lower(), err.replace("\\", "/").lower())


if __name__ == "__main__":
    unittest.main()
