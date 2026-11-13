#!/usr/bin/env python3
"""test_apply_issue_state_block.py — unit tests for the issue state block tool.

Coverage:
  - compose: insertion at the top of a body, replacement of an existing marked
    block (idempotent), the original statement kept byte for byte
  - tick: with and without a note, CRLF kept, first OPEN match only, missing target
  - check_block: each forbidden family (IPv4, e-mail, checkbox syntax, token
    fragment, domain name, escalation tokens, profile path, key file name), the
    dated heading, the allowed domains, the local (unversioned) patterns
  - plan_body: the checkbox-count invariant, the missing tick, the 64,000 guard
  - main: exit 0 / 1 contract (refused, missing block, read-back differs, abort),
    the one-time backup, the identity guard, dry-run, pull request skip

No network: the gh seam is patched, and subprocess.run raises if anything else
tries to reach it. Fixtures use documentation-range addresses and `example`
domains; token-shaped strings are built by concatenation.
"""

import argparse
import contextlib
import io
import json
import os
import re
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import apply_issue_state_block as tool  # noqa: E402
from apply_issue_state_block import (  # noqa: E402
    BEGIN,
    END,
    FOOT,
    MAX_BODY,
    check_block,
    compose,
    count_boxes,
    load_local_patterns,
    main,
    parse_tick,
    plan_body,
    tick,
)

CLEAN_BLOCK = (
    "### État au 13/11/2026\n"
    "**Fait** : la sonde tourne sur myia-po-2023 (port 8100), PR #4685 mergée, ms#1743.\n"
    "**Reste à faire**, dans l'ordre :\n"
    "1. Mesurer au prochain redémarrage — critère de fin : une ligne datée — siège : myia-po-2024.\n"
    "**Bloqué par** : rien.\n"
    "**Pour reprendre sans relire le fil** : le commentaire du 12/11, à 15:36Z "
    "(https://github.com/jsboige/roo-extensions/issues/1171).\n"
)
OTHER_BLOCK = "### État au 14/11/2026\n**Fait** : tout.\n**Bloqué par** : rien.\n"
STATEMENT = "Énoncé d'origine.\n\n- [ ] première étape\n- [ ] deuxième étape\n"


def reasons(block, extra=()):
    return [r.split(":", 1)[0] for r in check_block(block, extra)]


def dated(text):
    return "### État au 13/11/2026\n" + text + "\n"


class NoNetwork(unittest.TestCase):
    def setUp(self):
        guard = patch.object(tool.subprocess, "run",
                             side_effect=AssertionError("network access in a unit test"))
        guard.start()
        self.addCleanup(guard.stop)


class ComposeTests(NoNetwork):
    def test_insertion_at_the_top(self):
        new = compose(STATEMENT, CLEAN_BLOCK)
        self.assertTrue(new.startswith(BEGIN + "\n### État au 13/11/2026\n"))
        self.assertTrue(new.endswith("\n\n---\n\n" + STATEMENT))
        self.assertIn(FOOT + "\n" + END, new)
        self.assertEqual(new.count(BEGIN), 1)

    def test_replacement_of_an_existing_marked_block(self):
        first = compose(STATEMENT, CLEAN_BLOCK)
        second = compose(first, OTHER_BLOCK)
        self.assertNotIn("myia-po-2023", second)
        self.assertIn("### État au 14/11/2026", second)
        self.assertTrue(second.endswith("\n\n---\n\n" + STATEMENT))
        self.assertEqual(second.count(BEGIN), 1)
        self.assertEqual(second.count(END), 1)

    def test_refresh_is_idempotent(self):
        once = compose(STATEMENT, CLEAN_BLOCK)
        self.assertEqual(compose(once, CLEAN_BLOCK), once)

    def test_crlf_statement_kept_byte_for_byte(self):
        crlf = STATEMENT.replace("\n", "\r\n")
        self.assertTrue(compose(crlf, CLEAN_BLOCK).endswith(crlf))


class TickTests(NoNetwork):
    BODY = "intro\n- [ ] écrire la doc\n- [ ] livrer\n"

    def test_tick_with_a_note(self):
        new, done = tick(self.BODY, "écrire", "PR #4686")
        self.assertTrue(done)
        self.assertIn("- [x] écrire la doc — PR #4686\n", new)
        self.assertIn("- [ ] livrer\n", new)

    def test_tick_without_a_note(self):
        new, done = tick(self.BODY, "livrer", "")
        self.assertTrue(done)
        self.assertIn("- [x] livrer\n", new)
        self.assertNotIn(" — ", new)

    def test_tick_keeps_crlf(self):
        new, done = tick("a\r\n- [ ] étape une\r\nb", "étape une", "fait")
        self.assertTrue(done)
        self.assertEqual(new, "a\r\n- [x] étape une — fait\r\nb")

    def test_tick_skips_checked_lines(self):
        new, done = tick("- [x] étape\n* [ ] étape\n", "étape", "")
        self.assertTrue(done)
        self.assertEqual(new, "- [x] étape\n* [x] étape\n")

    def test_missing_tick_target_is_reported(self):
        new, done = tick(self.BODY, "absent", "note")
        self.assertFalse(done)
        self.assertEqual(new, self.BODY)
        _, notes, refusal = plan_body(STATEMENT, CLEAN_BLOCK, [("absent", "")])
        self.assertEqual(notes, ["tick MISSING 'absent'"])
        self.assertIn("tick MISSING 'absent'", refusal)


class CheckBlockTests(NoNetwork):
    def test_clean_block_passes(self):
        self.assertEqual(check_block(CLEAN_BLOCK), [])

    def test_ipv4(self):
        self.assertIn("IPv4 address", reasons(dated("hôte 192.0.2.10 joignable")))

    def test_email(self):
        self.assertIn("e-mail address", reasons(dated("écrire à le-user@example.org")))

    def test_checkbox_syntax(self):
        self.assertIn("checkbox syntax", reasons(dated("- [ ] étape")))
        self.assertIn("checkbox syntax", reasons(dated("* [x] étape")))
        self.assertIn("checkbox syntax", reasons(dated("  - [X] étape")))

    def test_inline_checkbox_pattern(self):
        got = reasons(dated("voir - [ ] plus bas"))
        self.assertIn("checkbox pattern", got)
        self.assertNotIn("checkbox syntax", got)

    def test_token_fragments(self):
        for frag in ("g" + "hp_" + "abc123", "g" + "ho_" + "abc123",
                     "s" + "k-" + "abcdef12", "Bea" + "rer " + "abc"):
            with self.subTest(frag=frag[:4]):
                self.assertIn("token fragment", reasons(dated("valeur " + frag)))

    def test_domain_name(self):
        self.assertIn("domain name", reasons(dated("voir example.org et example.net")))

    def test_allowed_domains(self):
        self.assertEqual(check_block(dated("voir https://github.com/jsboige/x et claude.com")), [])

    def test_escalation_tokens(self):
        for word in ("DEGRADED", "REPAIRED"):
            with self.subTest(word=word):
                self.assertIn("escalation token", reasons(dated("poster " + "[" + word + "]")))

    def test_user_profile_path(self):
        self.assertIn("user profile path", reasons(dated("C:" + "\\Users\\" + "quelquun\\x")))

    def test_key_file_name(self):
        self.assertIn("key file name", reasons(dated("clé " + "id_" + "ed25519")))

    def test_dated_heading_required(self):
        self.assertIn("block does not start with the dated heading",
                      check_block("**Fait** : rien.\n"))

    def test_local_patterns(self):
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "forbidden-local.txt")
            with open(p, "w", encoding="utf-8") as fh:
                fh.write("# fleet-specific\n\nzorglub_\\w+\n")
            extra = load_local_patterns(p)
            self.assertEqual(extra, [("zorglub_\\w+", "local pattern")])
            self.assertIn("local pattern", reasons(dated("clé zorglub_one"), extra))
            self.assertEqual(load_local_patterns(os.path.join(d, "absent.txt")), [])
            with open(p, "w", encoding="utf-8") as fh:
                fh.write("(unclosed\n")
            with self.assertRaises(re.error):
                load_local_patterns(p)


class PlanBodyTests(NoNetwork):
    def test_checkbox_count_invariant(self):
        legacy = (BEGIN + "\n### État au 01/11/2026\n- [ ] ancienne case\n" + END
                  + "\n\n---\n\n" + STATEMENT)
        self.assertEqual(count_boxes(legacy), 3)
        _, _, refusal = plan_body(legacy, CLEAN_BLOCK)
        self.assertEqual(refusal, "checkbox count changed 3 -> 2")

    def test_tick_keeps_the_count(self):
        new, notes, refusal = plan_body(STATEMENT, CLEAN_BLOCK, [("première", "fait")])
        self.assertIsNone(refusal)
        self.assertEqual(notes, ["tick OK 'première'"])
        self.assertEqual(count_boxes(new), count_boxes(STATEMENT))

    def test_length_guard(self):
        _, _, refusal = plan_body("x" * MAX_BODY, CLEAN_BLOCK)
        self.assertTrue(refusal.startswith("body would be "))

    def test_parse_tick(self):
        self.assertEqual(parse_tick("4685:écrire la doc::PR #1"), ("4685", "écrire la doc", "PR #1"))
        self.assertEqual(parse_tick("4685:écrire"), ("4685", "écrire", ""))
        for bad in ("abc:x", "4685", "4685:"):
            with self.subTest(bad=bad), self.assertRaises(argparse.ArgumentTypeError):
                parse_tick(bad)


class FakeGh:
    """Stands in for `gh`: answers `api user`, GET and PATCH of issues."""

    def __init__(self, issues, login="myia-ai-01", mangle=False, fail_get=False):
        self.issues = issues
        self.login = login
        self.mangle = mangle
        self.fail_get = fail_get
        self.calls = []

    def __call__(self, args):
        self.calls.append(args)
        if args[:2] == ["api", "user"]:
            return self.login + "\n"
        if args[:3] == ["api", "-X", "PATCH"]:
            n = args[3].rsplit("/", 1)[1]
            with open(args[args.index("--input") + 1], encoding="utf-8") as fh:
                body = json.load(fh)["body"]
            self.issues[n]["body"] = body + ("\nchanged" if self.mangle else "")
            return n + "\n"
        if self.fail_get:
            raise tool.GhError("gh api failed: HTTP 502")
        return json.dumps(self.issues[args[1].rsplit("/", 1)[1]])

    def patches(self):
        return [c for c in self.calls if c[:3] == ["api", "-X", "PATCH"]]


class MainTests(NoNetwork):
    def setUp(self):
        super().setUp()
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.blocks = os.path.join(tmp.name, "blocks")
        self.backup = os.path.join(tmp.name, "backup")
        os.makedirs(self.blocks)
        self.base = ["--blocks-dir", self.blocks, "--backup-dir", self.backup,
                     "--local-patterns", os.path.join(tmp.name, "absent.txt")]

    def block(self, n, text=CLEAN_BLOCK):
        with open(os.path.join(self.blocks, "%s.md" % n), "w", encoding="utf-8") as fh:
            fh.write(text)

    def issue(self, n, body=STATEMENT, **extra):
        d = {"number": int(n), "state": "open", "body": body}
        d.update(extra)
        return d

    def run_main(self, fake, args):
        buf = io.StringIO()
        with patch.object(tool, "_gh", fake), contextlib.redirect_stdout(buf):
            code = main(self.base + args)
        return code, buf.getvalue()

    def test_written_exit_0_and_backup_once(self):
        self.block("1171")
        fake = FakeGh({"1171": self.issue("1171")})
        code, out = self.run_main(fake, ["--tick", "1171:première::PR #4686", "1171"])
        self.assertEqual(code, 0, out)
        self.assertIn("#1171: WRITTEN", out)
        body = fake.issues["1171"]["body"]
        self.assertTrue(body.startswith(BEGIN))
        self.assertIn("- [x] première étape — PR #4686", body)
        with open(os.path.join(self.backup, "1171.md"), encoding="utf-8", newline="") as fh:
            self.assertEqual(fh.read(), STATEMENT)
        self.assertEqual(sorted(os.listdir(self.backup)), ["1171.md"])
        # second run: the backup keeps the FIRST body seen
        code, out = self.run_main(fake, ["1171"])
        self.assertEqual(code, 0, out)
        with open(os.path.join(self.backup, "1171.md"), encoding="utf-8", newline="") as fh:
            self.assertEqual(fh.read(), STATEMENT)

    def test_missing_block_exit_1(self):
        fake = FakeGh({"1171": self.issue("1171")})
        code, out = self.run_main(fake, ["1171"])
        self.assertEqual(code, 1)
        self.assertIn("#1171: SKIP no block file", out)
        self.assertEqual(fake.patches(), [])

    def test_refused_block_exit_1(self):
        self.block("1171", dated("hôte 192.0.2.10"))
        fake = FakeGh({"1171": self.issue("1171")})
        code, out = self.run_main(fake, ["1171"])
        self.assertEqual(code, 1)
        self.assertIn("#1171: REFUSED — IPv4 address", out)
        self.assertEqual(fake.patches(), [])

    def test_missing_tick_exit_1(self):
        self.block("1171")
        fake = FakeGh({"1171": self.issue("1171")})
        code, out = self.run_main(fake, ["--tick", "1171:absent", "1171"])
        self.assertEqual(code, 1)
        self.assertIn("REFUSED — tick MISSING 'absent'", out)
        self.assertEqual(fake.patches(), [])

    def test_readback_differs_exit_1(self):
        self.block("1171")
        fake = FakeGh({"1171": self.issue("1171")}, mangle=True)
        code, out = self.run_main(fake, ["1171"])
        self.assertEqual(code, 1)
        self.assertIn("#1171: READBACK-DIFFERS", out)

    def test_identity_guard(self):
        self.block("1171")
        fake = FakeGh({"1171": self.issue("1171")}, login="someone-else")
        code, out = self.run_main(fake, ["1171"])
        self.assertEqual(code, 1)
        self.assertIn("ABORTED — identity is 'someone-else'", out)
        self.assertEqual(fake.calls, [["api", "user", "--jq", ".login"]])

    def test_expect_login_override(self):
        self.block("1171")
        fake = FakeGh({"1171": self.issue("1171")}, login="jsboige")
        code, out = self.run_main(fake, ["--expect-login", "jsboige", "1171"])
        self.assertEqual(code, 0, out)

    def test_dry_run_writes_nothing(self):
        self.block("1171")
        fake = FakeGh({"1171": self.issue("1171")}, login="someone-else")
        code, out = self.run_main(fake, ["--dry-run", "1171"])
        self.assertEqual(code, 0, out)
        self.assertIn("#1171: DRY state=open", out)
        self.assertEqual(fake.patches(), [])
        self.assertEqual(fake.issues["1171"]["body"], STATEMENT)

    def test_pull_request_is_skipped(self):
        self.block("4686")
        fake = FakeGh({"4686": self.issue("4686", pull_request={"url": "x"})})
        code, out = self.run_main(fake, ["4686"])
        self.assertEqual(code, 0, out)
        self.assertIn("#4686: SKIP is a pull request", out)

    def test_one_failure_among_several_exit_1(self):
        self.block("1171")
        fake = FakeGh({"1171": self.issue("1171"), "1297": self.issue("1297")})
        code, out = self.run_main(fake, ["1171", "1297"])
        self.assertEqual(code, 1)
        self.assertIn("#1171: WRITTEN", out)
        self.assertIn("#1297: SKIP no block file", out)
        self.assertIn("done: 1 written, 1 failed, of 2", out)

    def test_gh_failure_aborts_exit_1(self):
        self.block("1171")
        fake = FakeGh({"1171": self.issue("1171")}, fail_get=True)
        code, out = self.run_main(fake, ["1171"])
        self.assertEqual(code, 1)
        self.assertIn("ABORTED — gh api failed", out)
        self.assertEqual(fake.patches(), [])


if __name__ == "__main__":
    unittest.main()
