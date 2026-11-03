#!/usr/bin/env python3
"""test_check_degraded_escalations.py — le contrat de sortie de l'organe #4517.

L'escamotage qu'on teste ici est un escamotage de **code de sortie** : un
automatiseur qui sonne le user ne lit que `$?`. Les cas couvrent donc les
quatre valeurs, et surtout les trois facons de rendre un faux « tout va bien » :
une escalade `[DONE]`-e mais non `[REPAIRED]`, une forme voisine
(`[DEGRADED-FIXED]`), et un dashboard illisible.

Stdlib `unittest` seulement, sans G: ni reseau : `unittest discover -s
scripts/testing/python` tourne en CI sur ubuntu.
"""

import importlib.util
import sys
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / "diagnostic" / "check-degraded-escalations.py"


def _load():
    spec = importlib.util.spec_from_file_location("check_degraded_escalations", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


cde = _load()
NOW = "2026-11-03T09:00:00Z"  # 8 h after a 01:00Z post == exactly 2 cycles


class EscalationContract(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)

    def dashboard(self, name, text):
        path = self.root / name
        path.write_text(text, encoding="utf-8")
        return path

    def run_main(self, *paths):
        argv = []
        for path in paths:
            argv += ["--dashboard-file", str(path)]
        return cde.main(argv + ["--now", NOW])

    def test_clean_dashboard_is_zero(self):
        path = self.dashboard("clean.md", """### [2026-11-03T08:00:00.000Z] a|ws
[tags: DONE]

[DONE] rien de degrade
""")
        self.assertEqual(self.run_main(path), 0)

    def test_open_within_deadline_is_three(self):
        path = self.dashboard("waiting.md", """### [2026-11-03T08:00:00.000Z] a|ws

[DEGRADED] mcp muet
""")
        self.assertEqual(self.run_main(path), 3)

    def test_overdue_without_repair_is_two(self):
        path = self.dashboard("overdue.md", """### [2026-11-03T00:00:00.000Z] a|ws

[DEGRADED] mcp muet
""")
        self.assertEqual(self.run_main(path), 2)

    def test_repaired_closes_the_escalation(self):
        path = self.dashboard("repaired.md", """### [2026-11-03T00:00:00.000Z] a|ws

[DEGRADED] mcp muet

### [2026-11-03T01:00:00.000Z] a|ws

[REPAIRED] mcp repond, 18 outils
""")
        self.assertEqual(self.run_main(path), 0)

    def test_a_done_never_consecrates_a_degraded_output(self):
        path = self.dashboard("done.md", """### [2026-11-03T00:00:00.000Z] a|ws

[DEGRADED] mcp muet

### [2026-11-03T01:00:00.000Z] a|ws

[DONE] cycle termine, travail rendu
""")
        self.assertEqual(self.run_main(path), 2)

    def test_repair_from_another_lane_does_not_close(self):
        path = self.dashboard("foreign.md", """### [2026-11-03T00:00:00.000Z] a|ws

[DEGRADED] mcp muet

### [2026-11-03T01:00:00.000Z] b|ws

[REPAIRED] mcp repond
""")
        self.assertEqual(self.run_main(path), 2)

    def test_near_miss_tag_is_ignored(self):
        path = self.dashboard("near.md", """### [2026-11-03T00:00:00.000Z] a|ws

[DEGRADED-FIXED] forme voisine, pas une escalade
""")
        self.assertEqual(self.run_main(path), 0)

    def test_unreadable_dashboard_is_an_instrument_error(self):
        # Un disque qui ne rend rien n'est pas un disque propre.
        self.assertEqual(self.run_main(self.root / "absent.md"), 1)

    def test_deadline_is_derived_from_the_post(self):
        path = self.dashboard("deadline.md", """### [2026-11-03T00:00:00.000Z] a|ws

[DEGRADED] mcp muet
""")
        entries, errors = cde.load_entries([path])
        self.assertEqual(errors, [])
        item = cde.collect_escalations(entries, cde.parse_ts(NOW))[0]
        self.assertEqual(item["deadline"], "2026-11-03T08:00:00Z")

    def test_cycle_length_is_a_parameter(self):
        path = self.dashboard("cycles.md", """### [2026-11-03T00:00:00.000Z] a|ws

[DEGRADED] mcp muet
""")
        entries, _ = cde.load_entries([path])
        item = cde.collect_escalations(entries, cde.parse_ts(NOW),
                                       cycles=1, cycle_hours=4.0)[0]
        self.assertEqual(item["status"], "overdue")

    def test_ring_without_bearer_fails_loudly(self):
        path = self.dashboard("ring.md", """### [2026-11-03T00:00:00.000Z] a|ws

[DEGRADED] mcp muet
""")
        code = cde.main(["--dashboard-file", str(path), "--now", NOW, "--ring",
                         "--ring-bearer", ""])
        # La sonnerie n'est pas partie : 1, jamais un 2 qui laisserait croire
        # que le user a ete prevenu.
        self.assertEqual(code, 1)

    def test_transport_is_reused_not_copied(self):
        # Le transport vit dans detect-approval-stalls.py : un seul organe.
        self.assertTrue(callable(cde._load_transport()))

    def test_ring_id_is_stable_within_a_day(self):
        item = {"lane": "a|ws", "posted": "2026-11-03T00:00:00Z"}
        self.assertEqual(cde.build_ring_id([item], now=1750000000),
                         cde.build_ring_id([item], now=1750000100))
        self.assertNotEqual(cde.build_ring_id([item], now=1750000000),
                            cde.build_ring_id([item], now=1750100000))


if __name__ == "__main__":
    unittest.main()
