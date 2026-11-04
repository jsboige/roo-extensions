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

import importlib.util
import json
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


if __name__ == "__main__":
    unittest.main()
