#!/usr/bin/env python3
"""test_collect_open_user_questions.py — le contrat de l'organe #4821 (volet b).

Ce qui est testé ici est le contrat de la directive owner 17/11 : chaque
question de chaque lane, avec son âge, et le signalement de celles qui vivent
hors du global. Les cas couvrent les trois façons de rendre un faux « tout est
consolidé » : une question hors global non signalée, une entrée consolidée
remplacée par une plus ancienne, et un dashboard muet lu comme « zéro
question » (fail-closed, exit 2).

Stdlib `unittest` seulement, sans G: ni réseau : `unittest discover -s
scripts/testing/python` tourne en CI sur ubuntu (même famille que
test_check_degraded_escalations.py).
"""

import contextlib
import importlib.util
import io
import json
import sys
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / "diagnostic" / "collect_open_user_questions.py"


def _load():
    spec = importlib.util.spec_from_file_location("collect_open_user_questions", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


couq = _load()
NOW = "2026-11-18T06:00:00Z"


class QuestionsContract(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)

    def dashboard(self, name, text):
        path = self.root / name
        path.write_text(text, encoding="utf-8")
        return path

    def run_main(self, *paths, extra=()):
        argv = []
        for path in paths:
            argv += ["--dashboard-file", str(path)]
        with contextlib.redirect_stdout(io.StringIO()) as out:
            code = couq.main(argv + ["--now", NOW, *extra])
        return code, out.getvalue()

    # --- vue global -------------------------------------------------------

    def test_latest_entry_per_lane_wins(self):
        path = self.dashboard("global.md", """### [2026-11-15T06:00:00.000Z] a|ws
[tags: ASK-USER]

- **Q1** (20 j, x) — ancienne

### [2026-11-17T18:23:00.000Z] a|ws
[tags: ASK-USER]

- **Q4** (26 j, EPIC) — recente
""")
        code, out = self.run_main(path)
        self.assertEqual(code, 0)
        self.assertIn("Q4", out)
        self.assertNotIn("Q1", out)
        self.assertIn("remplacées par une plus récente de la même lane : 1", out)

    def test_question_ages_parsed(self):
        path = self.dashboard("global.md", """### [2026-11-17T18:23:00.000Z] a|ws
[tags: ASK-USER]

- **Q4** (26 j, EPIC #19571) — architecture
- **Q15** (3 days) — numérotation
- **Q-P2023-9** (plafond WSL) — pas d'âge numérique
""")
        code, out = self.run_main(path)
        self.assertEqual(code, 0)
        self.assertIn("**Q4** — 26 j", out)
        self.assertIn("**Q15** — 3 j", out)
        self.assertIn("âge non porté", out)

    def test_declaration_dual_form(self):
        path = self.dashboard("global.md", """### [2026-11-17T10:00:00.000Z] a|ws

[ASK USER] question au propriétaire (premier token, pas de tags)

### [2026-11-17T11:00:00.000Z] b|ws

prose qui mentionne ASK-USER sans le déclarer — pas une question

### [2026-11-17T12:00:00.000Z] c|ws
[tags: DONE]

[DONE] un rapport qui raconte une ancienne question ASK-USER — pas une question
""")
        code, out = self.run_main(path)
        self.assertEqual(code, 0)
        self.assertIn("a|ws", out)
        self.assertNotIn("b|ws", out)
        self.assertNotIn("c|ws", out)

    def test_msg_metadata_line_not_body(self):
        path = self.dashboard("global.md", """### [2026-11-17T10:00:00.000Z] a|ws
[tags: ASK-USER]
[msg: abc123]

- **Q1** (2 j, y) — question réelle
""")
        code, out = self.run_main(path)
        self.assertEqual(code, 0)
        self.assertIn("**Q1** — 2 j", out)

    def test_unparsed_entry_not_fabricated(self):
        path = self.dashboard("global.md", """### [2026-11-17T10:00:00.000Z] a|ws
[tags: ASK-USER]

Deux questions en texte libre sans format Qxx.
""")
        code, out = self.run_main(path)
        self.assertEqual(code, 0)
        self.assertIn("format non parsé", out)
        self.assertIn("0 question(s)", out)

    def test_entry_age_reported(self):
        path = self.dashboard("global.md", """### [2026-11-16T06:00:00.000Z] a|ws
[tags: ASK-USER]

- **Q1** (2 j, y) — question
""")
        code, out = self.run_main(path)
        self.assertEqual(code, 0)
        self.assertIn("entrée âgée de 2 j", out)

    # --- hors global ------------------------------------------------------

    def test_off_global_flagged_when_not_consolidated(self):
        workspace = self.dashboard("workspace-cia.md", """### [2026-11-15T08:00:00.000Z] m|cia

[ASK USER] plafond WSL pour le déploiement — sans vue global depuis
""")
        code, out = self.run_main(workspace)
        self.assertEqual(code, 0)
        self.assertIn("Hors global", out)
        self.assertIn("m|cia", out)
        self.assertIn("workspace-cia.md", out)

    def test_off_global_covered_by_later_global_view(self):
        workspace = self.dashboard("workspace-cia.md", """### [2026-11-15T08:00:00.000Z] m|cia

[ASK USER] plafond WSL — consolidée depuis
""")
        later = self.dashboard("global.md", """### [2026-11-17T18:23:00.000Z] m|cia
[tags: ASK-USER]

- **Q-P2023-9** (3 j) — plafond WSL
""")
        code, out = self.run_main(workspace, later)
        self.assertEqual(code, 0)
        self.assertIn("(aucune)", out)
        self.assertIn("Q-P2023-9", out)

    def test_off_global_not_covered_by_older_global_view(self):
        workspace = self.dashboard("workspace-cia.md", """### [2026-11-17T08:00:00.000Z] m|cia

[ASK USER] question posée APRÈS la dernière consolidation
""")
        older = self.dashboard("global.md", """### [2026-11-15T18:23:00.000Z] m|cia
[tags: ASK-USER]

- **Q1** (2 j) — ancienne
""")
        code, out = self.run_main(workspace, older)
        self.assertEqual(code, 0)
        self.assertIn("question posée APRÈS", out)

    def test_plain_interagent_ask_ignored(self):
        workspace = self.dashboard("workspace-x.md", """### [2026-11-17T08:00:00.000Z] m|ws
[tags: ASK]

[ASK] à la lane voisine — pas une question au user
""")
        code, out = self.run_main(workspace)
        self.assertEqual(code, 0)
        self.assertIn("(aucune)", out)
        self.assertNotIn("m|ws", out)

    # --- contrat de sortie ------------------------------------------------

    def test_clean_zero_questions(self):
        path = self.dashboard("global.md", """### [2026-11-17T08:00:00.000Z] a|ws
[tags: DONE]

[DONE] cycle clos
""")
        code, out = self.run_main(path)
        self.assertEqual(code, 0)
        self.assertIn("0 question(s)", out)
        self.assertIn("aucune entrée ASK-USER", out)

    def test_unreadable_dashboard_is_two(self):
        code, out = self.run_main(self.root / "absent.md")
        self.assertEqual(code, 2)
        self.assertEqual(out, "")

    def test_json_output(self):
        path = self.dashboard("global.md", """### [2026-11-17T18:23:00.000Z] a|ws
[tags: ASK-USER]

- **Q4** (26 j, EPIC) — architecture
""")
        code, out = self.run_main(path, extra=("--json",))
        self.assertEqual(code, 0)
        data = json.loads(out)
        self.assertEqual(data["lanes"][0]["lane"], "a|ws")
        self.assertEqual(data["lanes"][0]["questions"][0]["qid"], "Q4")
        self.assertEqual(data["lanes"][0]["questions"][0]["age_days"], 26)

    # --- découverte par défaut (unitaire) ---------------------------------

    def test_default_files_exclude_conflict_copies(self):
        self.dashboard("global.md", "x")
        self.dashboard("workspace-x (1).md", "x")
        self.dashboard("mcp-dashboard.md", "x")
        self.dashboard("machine-po.md", "x")
        names = [p.name for p in couq.default_dashboard_files(self.root)]
        self.assertEqual(names, ["global.md", "machine-po.md"])

    # --- review #4826 : source absente = exit 2, jamais « zero question » ----

    def test_missing_mirror_dir_is_two(self):
        """--mirror sur un répertoire inexistant : la découverte rend [], sans
        erreur de chargement — le défaut exact de la review. Doit rendre 2."""
        with contextlib.redirect_stdout(io.StringIO()) as out, \
                contextlib.redirect_stderr(io.StringIO()) as err:
            code = couq.main(["--mirror", "--dashboards-dir",
                              str(self.root / "absent"), "--now", NOW])
        self.assertEqual(code, 2)
        self.assertEqual(out.getvalue(), "")
        self.assertIn("absente ou sans dashboard", err.getvalue())

    def test_empty_mirror_dir_is_two(self):
        """Répertoire présent mais sans dashboard : idem, pas un 0 confiant."""
        with contextlib.redirect_stdout(io.StringIO()) as out, \
                contextlib.redirect_stderr(io.StringIO()):
            code = couq.main(["--mirror", "--dashboards-dir",
                              str(self.root), "--now", NOW])
        self.assertEqual(code, 2)
        self.assertEqual(out.getvalue(), "")

    def test_default_source_is_store_not_mirror(self):
        """Sans --mirror ni --dashboard-file, la source par défaut est le store
        PG : une panne de transport ne doit PAS être silencieusement absorbée
        en « zero question » par un miroir absent."""
        def fake_store(url, bearer, timeout=10.0, intercom_limit=500):
            return [], ["store injoignable (test)"]
        original = couq.load_dashboards_from_store
        couq.load_dashboards_from_store = fake_store
        try:
            with contextlib.redirect_stdout(io.StringIO()) as out, \
                    contextlib.redirect_stderr(io.StringIO()) as err:
                code = couq.main(["--dashboards-dir",
                                  str(self.root / "absent"), "--now", NOW])
            self.assertEqual(code, 2)
            self.assertEqual(out.getvalue(), "")
            self.assertIn("repli miroir", err.getvalue())
        finally:
            couq.load_dashboards_from_store = original


if __name__ == "__main__":
    unittest.main()
