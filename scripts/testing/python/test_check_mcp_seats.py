#!/usr/bin/env python3
"""test_check_mcp_seats.py — le contrat de sortie de la sonde #4518.

Review ai-01 04/11 : « for an organ whose whole thesis is declared != present,
`$?` must never read as \"all good\" when nothing was measured ». Quatre codes
de sortie, un temoin chacun, plus la precedence et le `STALE-DISABLE` = 0
documente au docstring.

Stdlib `unittest` seulement, ni reseau ni spawn : le handshake et le chemin de
la config utilisateur sont INJECTES. Lire le vrai `~/.claude.json` de la
machine rendrait la CI rouge pour une raison d'environnement — c'est
precisement ce que le docstring de `test_check_deny_fallback.py` interdit.
"""

import contextlib
import importlib.util
import io
import json
import os
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / "diagnostic" / "check-mcp-seats.py"


def _load():
    spec = importlib.util.spec_from_file_location("check_mcp_seats", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


cms = _load()


class SeatContract(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.ws = self.root / "ws"
        self.ws.mkdir()
        self.user_config = self.root / "claude.json"

    def install(self, workspace_servers=None, user_config=None,
                user_config_raw=None, handshake=None):
        """Fixtures sur disque + injection des deux frontieres (config, spawn)."""
        if workspace_servers is not None:
            (self.ws / ".mcp.json").write_text(
                json.dumps({"mcpServers": workspace_servers}), encoding="utf-8")
        if user_config_raw is not None:
            self.user_config.write_text(user_config_raw, encoding="utf-8")
        elif user_config is not None:
            self.user_config.write_text(json.dumps(user_config), encoding="utf-8")
        original_cfg = cms.user_config_path
        cms.user_config_path = lambda: self.user_config
        self.addCleanup(setattr, cms, "user_config_path", original_cfg)
        if handshake is not None:
            original_hs = cms._load_handshake
            cms._load_handshake = lambda: handshake
            self.addCleanup(setattr, cms, "_load_handshake", original_hs)

    def run_main(self, *extra):
        return cms.main(["--workspace", str(self.ws), *extra])

    # --- un temoin par code de sortie ------------------------------------

    def test_all_live_or_disabled_is_zero(self):
        self.install(
            workspace_servers={"live-one": {"command": "node", "args": []}},
            user_config={
                "projects": {str(self.ws): {"disabledMcpServers": ["off-one"]}},
                "mcpServers": {"off-one": {"command": "node", "args": []}},
            },
            handshake=lambda entry, timeout: (True, "18 outil(s)"),
        )
        self.assertEqual(self.run_main(), 0)

    def test_a_measured_dead_is_two(self):
        self.install(
            workspace_servers={"dead-one": {"command": "node", "args": []}},
            user_config={},
            handshake=lambda entry, timeout: (False, "initialize: eof"),
        )
        self.assertEqual(self.run_main(), 2)

    def test_partial_read_error_is_one_even_with_records(self):
        # Le trou reproche : `errors and not records`. Un ~/.claude.json
        # corrompu + un .mcp.json lisible rendait 0 avec un tally confiant.
        self.install(
            workspace_servers={"live-one": {"command": "node", "args": []}},
            user_config_raw="{ not json",
            handshake=lambda entry, timeout: (True, "18 outil(s)"),
        )
        self.assertEqual(self.run_main(), 1)

    def test_no_handshake_is_three_not_zero(self):
        # 0 est reserve a une mesure reelle (forme maison `exit 3`).
        self.install(
            workspace_servers={"live-one": {"command": "node", "args": []}},
            user_config={},
        )
        self.assertEqual(self.run_main("--no-handshake"), 3)

    # --- precedence du contrat -------------------------------------------

    def test_read_error_outranks_not_measured(self):
        self.install(
            workspace_servers={"live-one": {"command": "node", "args": []}},
            user_config_raw="{ not json",
        )
        self.assertEqual(self.run_main("--no-handshake"), 1)

    def test_a_measured_dead_surfaces_even_with_a_read_error(self):
        self.install(
            workspace_servers={"dead-one": {"command": "node", "args": []}},
            user_config_raw="{ not json",
            handshake=lambda entry, timeout: (False, "initialize: eof"),
        )
        self.assertEqual(self.run_main(), 2)

    # --- `--server` : un nom introuvable n'est pas un siege sain ---------

    def test_unknown_server_is_three_not_zero(self):
        # Review ai-01 04/11 (SHOULD) : `--server <mal orthographie>` rendait
        # LIVE=0 DEAD=0 en exit 0 -- indistinguable d'un siege sans serveur.
        self.install(
            workspace_servers={"live-one": {"command": "node", "args": []}},
            user_config={},
            handshake=lambda entry, timeout: (True, "18 outil(s)"),
        )
        self.assertEqual(self.run_main("--server", "live-one-typo"), 3)

    def test_a_named_declared_server_still_measures(self):
        # Temoin positif : restreindre a un serveur DECLARE mesure pour de bon.
        self.install(
            workspace_servers={"live-one": {"command": "node", "args": []}},
            user_config={},
            handshake=lambda entry, timeout: (True, "18 outil(s)"),
        )
        self.assertEqual(self.run_main("--server", "live-one"), 0)

    def test_unknown_server_does_not_mask_a_dead_one(self):
        # Un nom introuvable ne doit pas absorber un DEAD reellement mesure.
        self.install(
            workspace_servers={"dead-one": {"command": "node", "args": []}},
            user_config={},
            handshake=lambda entry, timeout: (False, "initialize: eof"),
        )
        self.assertEqual(self.run_main("--server", "dead-one",
                                       "--server", "nope"), 2)

    # --- comportement documente, epingle --------------------------------

    def test_a_stale_disable_is_zero_but_still_reported(self):
        # Une desactivation perimee n'est pas un serveur mort : 0, par
        # docstring (exit table), pas par accident.
        self.install(
            workspace_servers={},
            user_config={"projects": {
                str(self.ws): {"disabledMcpServers": ["ghost"]}}},
        )
        self.assertEqual(self.run_main(), 0)

    # --- plusieurs ecritures du meme chemin (#4963) -----------------------

    def spellings(self):
        """Deux écritures du chemin du siège, égales après normalisation.

        Windows : la casse du lecteur (`C:\\…` et `c:/…`), l'écart mesuré le
        2026-11-03 et sur les deux sièges de #4963 — la sonde résout en
        majuscule, Claude Code écrit en minuscule. Ailleurs `normcase` ne plie
        rien : un segment `.` joue le même rôle pour `normpath`.
        """
        base = str(self.ws)
        if os.name == "nt":
            return base, base[0].lower() + base[1:].replace("\\", "/")
        return base, base + "/./"

    def run_probe(self, projects, *extra):
        """Sonde sur un `off-one` déclaré, avec ces entrées `projects`."""
        self.install(
            workspace_servers={"off-one": {"command": "node", "args": []}},
            user_config={"projects": projects},
            handshake=lambda entry, timeout: (True, "18 outil(s)"),
        )
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = self.run_main(*extra)
        return code, out.getvalue()

    def test_two_spellings_that_disagree_are_never_disabled(self):
        # #4963 : Claude Code ne lit qu'UNE des deux clés, et la sonde ne sait
        # pas laquelle. Rendre DISABLED tenait pour autoritaire une entrée que
        # la session peut ne pas lire.
        probe_key, other = self.spellings()
        code, out = self.run_probe(
            {probe_key: {}, other: {"disabledMcpServers": ["off-one"]}}, "--json")
        report = json.loads(out)
        self.assertEqual(code, 0)
        self.assertEqual(report["disabled"], [])
        self.assertEqual(report["ambiguous_disables"], ["off-one"])
        record = report["records"][0]
        self.assertEqual(record["verdict"], "AMBIGUOUS-DISABLE")
        # Les deux écritures sont nommées, chacune telle qu'elle est écrite.
        self.assertIn(cms._shown([probe_key]), record["detail"])
        self.assertIn(cms._shown([other]), record["detail"])

    def test_reported_keys_abbreviate_the_home_directory(self):
        # ai-01 : lister les clés « with `~` for the home path ».
        home = os.path.expanduser("~")
        under = os.path.join(home, "Projects", "x")
        self.assertEqual(cms._shown([under]), "~" + under[len(home):])
        self.assertEqual(cms._shown([os.path.join(os.sep, "elsewhere", "x")]),
                         os.path.join(os.sep, "elsewhere", "x"))

    def test_an_ambiguous_disable_is_shown_in_the_tally(self):
        probe_key, other = self.spellings()
        code, out = self.run_probe(
            {probe_key: {}, other: {"disabledMcpServers": ["off-one"]}})
        self.assertEqual(code, 0)
        self.assertIn("DISABLED=0 AMBIGUOUS-DISABLE=1", out)
        self.assertIn("AMBIGUOUS-DISABLE off-one", out)

    def test_two_spellings_that_agree_are_disabled(self):
        # Quelle que soit la clé lue, la désactivation tient : pas d'ambiguïté.
        first, second = self.spellings()
        code, out = self.run_probe({
            first: {"disabledMcpServers": ["off-one"]},
            second: {"disabledMcpServers": ["off-one"]},
        }, "--json")
        report = json.loads(out)
        self.assertEqual(code, 0)
        self.assertEqual(report["disabled"], ["off-one"])
        self.assertEqual(report["ambiguous_disables"], [])

    def test_a_stale_disable_still_names_the_writings_that_diverge(self):
        # Revue ai-01 27/11 : divergent ET déclaré nulle part. Les deux faits
        # tiennent ensemble — un seul verdict ne peut pas les porter, mais le
        # détail le peut. Sans lui, l'opérateur purge une entrée périmée sans
        # apprendre qu'une autre écriture du siège prétend désactiver ce nom.
        silent, disabling = self.spellings()
        code, out = self.run_probe(
            {silent: {}, disabling: {"disabledMcpServers": ["ghost"]}}, "--json")
        report = json.loads(out)
        self.assertEqual(code, 0)
        # Le geste principal ne change pas : le nom est à purger, et ce n'est
        # pas une ambiguïté sur un serveur déclaré.
        self.assertEqual(report["stale_disables"], ["ghost"])
        self.assertEqual(report["ambiguous_disables"], [])
        record = next(r for r in report["records"] if r["server"] == "ghost")
        self.assertEqual(record["verdict"], "STALE-DISABLE")
        # Chaîne exacte : chaque écriture dans SON camp. Un détail qui échangerait
        # « désactivé sous » et « pas sous » dirait l'inverse du siège.
        self.assertEqual(
            record["detail"],
            "desactive mais declare nulle part (configuration perimee)"
            f" ; desactive sous {cms._shown([disabling])}, "
            f"pas sous {cms._shown([silent])}")

    def test_a_stale_disable_without_divergence_keeps_its_plain_detail(self):
        # Témoin inverse : une seule écriture du chemin, rien à signaler — le
        # détail d'origine doit rester mot pour mot.
        _, single = self.spellings()
        code, out = self.run_probe({single: {"disabledMcpServers": ["ghost"]}}, "--json")
        report = json.loads(out)
        self.assertEqual(code, 0)
        record = next(r for r in report["records"] if r["server"] == "ghost")
        self.assertEqual(record["detail"],
                         "desactive mais declare nulle part (configuration perimee)")

    def test_a_single_spelling_disables_whichever_way_it_is_written(self):
        # Témoin du 2026-11-03 : la correspondance normalisée ne recule pas.
        # Une seule écriture, même autrement que la sonde ne résout, est lue.
        _, other = self.spellings()
        code, out = self.run_probe({other: {"disabledMcpServers": ["off-one"]}}, "--json")
        report = json.loads(out)
        self.assertEqual(code, 0)
        self.assertEqual(report["disabled"], ["off-one"])
        self.assertEqual(report["ambiguous_disables"], [])


if __name__ == "__main__":
    unittest.main()
