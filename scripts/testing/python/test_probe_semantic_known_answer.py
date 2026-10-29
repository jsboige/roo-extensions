#!/usr/bin/env python3
"""CI wrapper for probe-semantic-known-answer.py (#4352, mandat ai-01 29/10).

The probe carries its own fixture selftest (`--selftest`, argparse style — not
discoverable); this wrapper pins it to the unittest discovery the static CI
job runs (`python3 -m unittest discover -s scripts/testing/python`), same
pattern as test_check_deny_fallback.py (#4340). Offline only: the selftest
builds its fixtures in tempdirs and spawns no MCP server, no network, no live
index — a bare CLI run WITHOUT --selftest is forbidden here on purpose (it
would spawn the real RSM child and hit live sessions).

The NEGATIVE CONTROL is the point of the mandate: a copy of the probe with the
InstrumentLimit global-abort clause deleted (`except InstrumentLimit: raise`
in phase_index) must make the selftest FAIL. Without it, a green selftest run
proves nothing about the abort — the historical bug (InstrumentLimit inherits
RuntimeError, so the per-candidate handler swallowed it: the next candidate
re-scanned the corpus and re-paid an index call) made the probe SLOWER and its
exit code mislabelled, while every selftest stayed green. If the clause is
refactored away or renamed so the mutation regex no longer matches, the
substitution-count assertion fails red and forces this wrapper to be re-armed.
"""

import os
import re
import subprocess
import sys
import tempfile
import unittest

_SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       "..", "..", "diagnostic", "probe-semantic-known-answer.py")

# The clause the mutation removes. `except InstrumentLimit:` WITHOUT a binder
# exists only in phase_index (the selftest catches use `as exc`), and the body
# is comments + a bare `raise`.
_ABORT_CLAUSE = re.compile(
    r"\n        except InstrumentLimit:\n(?:            .*\n)*?            raise\n")


class ProbeSemanticKnownAnswerSelftest(unittest.TestCase):

    def test_selftest_passes(self):
        proc = subprocess.run([sys.executable, _SCRIPT, "--selftest"],
                              capture_output=True, text=True, timeout=300)
        self.assertEqual(proc.returncode, 0,
                         f"selftest failed:\n{proc.stdout}\n{proc.stderr}")
        self.assertIn("[SELFTEST] PASS", proc.stdout)

    def test_negative_control_abort_clause_removed_fails(self):
        # Temoin negatif : retire la clause d'abort global, exige que le
        # selftest DEVienne rouge. Un selftest qui reste vert sur le mutant
        # ne prouve rien sur l'abort — c'est exactement le trou du 29/10.
        with open(_SCRIPT, "r", encoding="utf-8") as fh:
            src = fh.read()
        mutated, n = _ABORT_CLAUSE.subn("\n", src)
        self.assertEqual(
            n, 1,
            "la clause d'abort global `except InstrumentLimit: raise` est "
            f"introuvable ou ambigue ({n} occurrence(s)) — le temoin negatif ne "
            "peut pas etre arme ; mets a jour la regex de ce wrapper")
        with tempfile.TemporaryDirectory() as td:
            mutant = os.path.join(td, "probe-mutant.py")
            with open(mutant, "w", encoding="utf-8") as fh:
                fh.write(mutated)
            proc = subprocess.run([sys.executable, mutant, "--selftest"],
                                  capture_output=True, text=True, timeout=300)
        self.assertNotEqual(
            proc.returncode, 0,
            "le selftest reste VERT apres suppression de l'abort global "
            "InstrumentLimit — le mutant survit, la garde ne garde rien")
        self.assertIn("[SELFTEST] FAIL", proc.stdout)
        self.assertIn(
            "InstrumentLimit", proc.stdout,
            "le mutant echoue pour une RAISON autre que l'abort InstrumentLimit "
            "— verifier que la mutation n'a pas casse le script autrement")

    def test_cli_help_smoke(self):
        # The fleet's cross-seat chain invokes the probe with these flags;
        # argparse must keep documenting them.
        proc = subprocess.run([sys.executable, _SCRIPT, "--help"],
                              capture_output=True, text=True, timeout=60)
        self.assertEqual(proc.returncode, 0)
        for flag in ("--selftest", "--index", "--verify", "--corpus-dir", "--json"):
            self.assertIn(flag, proc.stdout)


if __name__ == "__main__":
    unittest.main()
