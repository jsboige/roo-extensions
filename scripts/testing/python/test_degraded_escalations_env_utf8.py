#!/usr/bin/env python3
"""#4672 — l'organe lit son fichier d'environnement, et sa sortie survit au cp1252.

Deux defauts mesures sur le siege po-2028 (13/11) :

1. `check-degraded-escalations.py` ne prenait sa config proxy que dans son
   environnement de processus : la « commande canonique » exigeait un sourcing
   manuel du bearer. L'organe lit desormais `--env-file` (defaut :
   ~/.roo-state-manager/stall-detector.env, le fichier deploye par le lanceur
   compagnon) avec la precedence CLI > environnement > fichier > defaut.
2. `report()` imprimait l'extrait d'une escalade ; un caractere hors cp1252
   (fleche U+2192, mesuree) faisait lever UnicodeEncodeError sous la console
   Windows par defaut — le crash rendait exit 1 a la place du verdict 2.

Deux temoins negatifs rendent ces preuves falsifiables : retirer la lecture du
fichier ou la boucle de reconfigure doit faire echouer le test correspondant.
Si le code est refactore et que les ancres regex ne matchent plus, l'assertion
de comptage echoue et force a rearmer ce wrapper — jamais a le contourner.

Aucune valeur reelle n'apparait ici : les bearers de test sont des chaines
factices. Stdlib `unittest` seulement ; aucun acces G:. Un seul serveur : un
loopback ephemere qui capture les en-tetes, pour prouver que le transport
REEL (call_dashboard_tool) recoit le credential du fichier — les temoins
mutants travaillent sur des copies importees et des fixtures locales.
"""

import contextlib
import http.server
import importlib.util
import io
import json
import os
import re
import subprocess
import sys
import tempfile
import threading
import unittest
from pathlib import Path
from unittest import mock

SCRIPT = Path(__file__).resolve().parents[2] / "diagnostic" / "check-degraded-escalations.py"
NOW = "2026-11-03T09:00:00Z"

_PROXY_KEYS = ("MCP_PROXY_BEARER", "MCP_PROXY_URL", "MCP_PROXY_BASE_URL")

# Une escalade ECHUE (13 h avant NOW, defaut 2 x 4 h) dont l'extrait porte la
# fleche U+2192 : c'est elle qui faisait lever report() sous cp1252.
OVERDUE_WITH_ARROW = (
    "### [2026-11-02T20:00:00.000Z] po-x|ws\n"
    "[tags: DEGRADED]\n"
    "\n"
    "[DEGRADED] MCP muet → repli ; toujours en panne\n"
)

# L'ancre du temoin negatif n°1 : l'appel qui branche le fichier d'environnement.
_CALL_SITE = re.compile(
    r"\n    file_values, file_warning = load_organ_env_file\(args\.env_file\)\n")

# L'ancre du temoin negatif n°2 : la boucle de reconfigure des flux, identique
# a celle de probe-semantic-known-answer.py / g6-pass-bound.py.
_RECONFIGURE_LOOP = re.compile(
    r"\n    for stream in \(sys\.stdout, sys\.stderr\):\n"
    r"        if hasattr\(stream, \"reconfigure\"\):\n"
    r"            stream\.reconfigure\(encoding=\"utf-8\", errors=\"replace\"\)\n")


def _load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


cde = _load_module("check_degraded_escalations_4672", SCRIPT)


def _without_proxy_env():
    """Contexte : aucune variable MCP_PROXY_* visible (restauree apres)."""
    return mock.patch.dict(os.environ, {}, clear=False)


def _pop_proxy_env():
    for key in _PROXY_KEYS:
        os.environ.pop(key, None)


def _run_cp1252(script, args):
    """Execute un script en enfant, console cp1252 forcee (comme un redirect
    Windows par defaut), sans aucune variable proxy heritee."""
    env = {k: v for k, v in os.environ.items() if k not in _PROXY_KEYS}
    env["PYTHONIOENCODING"] = "cp1252"
    return subprocess.run([sys.executable, str(script), *args],
                          capture_output=True, text=True, encoding="utf-8",
                          errors="replace", env=env, timeout=180)


class OrganEnvFile(unittest.TestCase):
    """Lecture du fichier d'environnement + precedence de resolution."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)

    def envfile(self, name, text, encoding="utf-8"):
        path = self.root / name
        path.write_text(text, encoding=encoding)
        return path

    # --- lecture du fichier ------------------------------------------------

    def test_missing_file_is_not_an_error(self):
        values, warning = cde.load_organ_env_file(self.root / "absent.env")
        self.assertEqual(values, {})
        self.assertIsNone(warning)

    def test_empty_path_means_no_file(self):
        for flag in ("", "   ", None):
            values, warning = cde.load_organ_env_file(flag)
            self.assertEqual(values, {}, flag)
            self.assertIsNone(warning, flag)

    def test_named_keys_only_and_quotes_stripped(self):
        path = self.envfile("ok.env", "\n".join([
            "# commentaire",
            "OTHER_SECRET=must-not-be-materialised",
            "MCP_PROXY_BEARER='quote-filetoken'",
            'MCP_PROXY_BASE_URL="http://127.0.0.1:3999"',
            "MCP_PROXY_URL=http://127.0.0.1:3998",
        ]) + "\n")
        values, warning = cde.load_organ_env_file(path)
        self.assertIsNone(warning)
        self.assertEqual(values["MCP_PROXY_BEARER"], "quote-filetoken")
        self.assertEqual(values["MCP_PROXY_BASE_URL"], "http://127.0.0.1:3999")
        self.assertEqual(values["MCP_PROXY_URL"], "http://127.0.0.1:3998")
        self.assertNotIn("OTHER_SECRET", values)

    def test_undecodable_file_warns_and_leaks_nothing(self):
        path = self.root / "binary.env"
        path.write_bytes(b"MCP_PROXY_BEARER=leaked-token-4672\n\xff\xfe")
        values, warning = cde.load_organ_env_file(path)
        self.assertEqual(values, {})
        self.assertIsNotNone(warning)
        self.assertNotIn("leaked-token-4672", warning)

    def test_malformed_lines_warn_without_leaking_values(self):
        path = self.envfile("partial.env", "\n".join([
            "MCP_PROXY_BEARER=kept-secret-4672",
            "this line is not a KEY=value assignment",
        ]) + "\n")
        values, warning = cde.load_organ_env_file(path)
        self.assertEqual(values["MCP_PROXY_BEARER"], "kept-secret-4672")
        self.assertIsNotNone(warning)
        self.assertNotIn("kept-secret-4672", warning)

    # --- precedence --------------------------------------------------------

    def test_precedence_cli_over_env_over_file(self):
        file_values = {"MCP_PROXY_BEARER": "file-bearer",
                       "MCP_PROXY_BASE_URL": "http://file-url"}
        with _without_proxy_env():
            _pop_proxy_env()
            os.environ["MCP_PROXY_BEARER"] = "env-bearer"
            os.environ["MCP_PROXY_URL"] = "http://env-url"
            url, bearer = cde.resolve_proxy_config(
                "http://cli-url", "cli-bearer", file_values)
            self.assertEqual((url, bearer), ("http://cli-url", "cli-bearer"))
            url, bearer = cde.resolve_proxy_config(None, None, file_values)
            self.assertEqual((url, bearer), ("http://env-url", "env-bearer"))
        with _without_proxy_env():
            _pop_proxy_env()
            url, bearer = cde.resolve_proxy_config(None, None, file_values)
            self.assertEqual((url, bearer), ("http://file-url", "file-bearer"))

    def test_base_url_accepted_at_every_layer(self):
        with _without_proxy_env():
            _pop_proxy_env()
            os.environ["MCP_PROXY_BASE_URL"] = "http://env-base"
            url, _ = cde.resolve_proxy_config(None, None, {})
            self.assertEqual(url, "http://env-base")
        with _without_proxy_env():
            _pop_proxy_env()
            url, _ = cde.resolve_proxy_config(
                None, None, {"MCP_PROXY_BASE_URL": "http://file-base"})
            self.assertEqual(url, "http://file-base")
            url, bearer = cde.resolve_proxy_config(None, None, {})
            self.assertEqual(url, "https://mcp-tools.myia.io")
            self.assertIsNone(bearer)

    # --- main reel branche par le fichier ---------------------------------

    def test_main_reads_env_file_for_the_store(self):
        envfile = self.envfile("seat.env",
                               "MCP_PROXY_BEARER=file-bearer-4672\n"
                               "MCP_PROXY_BASE_URL=http://127.0.0.1:9\n")
        seen = {}

        def fake_store(url, bearer, **kwargs):
            seen["url"], seen["bearer"] = url, bearer
            return [], [], []

        original = cde._store_loader
        cde._store_loader = fake_store
        self.addCleanup(setattr, cde, "_store_loader", original)
        with _without_proxy_env():
            _pop_proxy_env()
            with contextlib.redirect_stdout(io.StringIO()):
                code = cde.main(["--now", NOW, "--env-file", str(envfile)])
        self.assertEqual(code, 0)
        self.assertEqual(seen["bearer"], "file-bearer-4672")
        self.assertEqual(seen["url"], "http://127.0.0.1:9")

    def test_negative_control_env_file_loading_removed(self):
        # Temoin negatif n°1 : sans l'appel de chargement, le bearer du fichier
        # n'atteint jamais le store ; l'organe doit alors rester fail-closed
        # (sortie 1, loader non appele) — la preuve que c'est bien ce branchement
        # qui fait lire le fichier.
        envfile = self.envfile("seat.env", "MCP_PROXY_BEARER=file-bearer-4672\n")
        src = SCRIPT.read_text(encoding="utf-8")
        mutated, count = _CALL_SITE.subn(
            "\n    file_values, file_warning = {}, None\n", src)
        self.assertEqual(
            count, 1,
            "l'appel a load_organ_env_file est introuvable ou ambigu "
            f"({count} occurrence(s)) — le temoin negatif #4672 ne peut pas "
            "etre arme ; mettre a jour la regex de ce wrapper")
        mutant_path = self.root / "organ-mutant-envfile.py"
        mutant_path.write_text(mutated, encoding="utf-8")
        mutant = _load_module("check_degraded_escalations_4672_mutant", mutant_path)
        calls = []
        mutant._store_loader = lambda *a, **k: calls.append(a) or ([], [], [])
        with _without_proxy_env():
            _pop_proxy_env()
            with contextlib.redirect_stdout(io.StringIO()), \
                    contextlib.redirect_stderr(io.StringIO()) as err:
                code = mutant.main(["--now", NOW, "--env-file", str(envfile)])
        self.assertEqual(code, 1, "le mutant doit rester fail-closed")
        self.assertEqual(calls, [], "le mutant ne doit pas lire le store")
        self.assertIn("MCP_PROXY_BEARER absent", err.getvalue())


class RealTransportReceivesFileCredential(unittest.TestCase):
    """AC1 #4672 — le transport REEL recoit credential et URL du fichier.

    Un vrai serveur HTTP loopback (port ephemere) tient lieu de store PG : les
    requetes qu'il recoit sont la preuve firsthand que `call_dashboard_tool`
    — pas un faux loader — a porte le bearer du fichier et frappe l'URL
    configuree. Le bearer ne doit apparaitre ni sur stdout ni sur stderr.
    """

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.requests = []
        requests = self.requests

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_POST(self):
                length = int(self.headers.get("Content-Length") or 0)
                raw = self.rfile.read(length)
                requests.append({
                    "path": self.path,
                    "authorization": self.headers.get("Authorization"),
                    "body": raw,
                })
                try:
                    payload = json.loads(raw or b"{}")
                except ValueError:
                    payload = {}
                if payload.get("method") == "initialize":
                    result = {}
                else:
                    arguments = (payload.get("params") or {}).get("arguments") or {}
                    if arguments.get("action") == "list":
                        text = json.dumps({
                            "success": True,
                            "dashboards": [{"key": "workspace-test-4672"}],
                        })
                    else:
                        text = json.dumps({
                            "success": True,
                            "data": {"intercom": {"messages": []}},
                        })
                    result = {"content": [{"type": "text", "text": text}]}
                body = json.dumps({"jsonrpc": "2.0",
                                   "id": payload.get("id"),
                                   "result": result}).encode()
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

            def log_message(self, *args):
                pass

        self.server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
        self.addCleanup(self.server.server_close)
        self.addCleanup(self.server.shutdown)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.port = self.server.server_address[1]

    def test_main_sends_fixture_credential_and_configured_url(self):
        envfile = self.root / "seat.env"
        envfile.write_text(
            "MCP_PROXY_BEARER=file-bearer-4672\n"
            f"MCP_PROXY_BASE_URL=http://127.0.0.1:{self.port}\n",
            encoding="utf-8")
        with _without_proxy_env():
            _pop_proxy_env()
            out, err = io.StringIO(), io.StringIO()
            with contextlib.redirect_stdout(out), \
                    contextlib.redirect_stderr(err):
                code = cde.main(["--now", NOW, "--env-file", str(envfile),
                                 "--archive-window-hours", "0"])
        combined = out.getvalue() + err.getvalue()
        self.assertEqual(code, 0, f"stdout:\n{out.getvalue()}\n"
                                  f"stderr:\n{err.getvalue()}")
        self.assertGreaterEqual(len(self.requests), 2,
                                "le transport reel n'a pas frappe le store local")
        actions = []
        for request in self.requests:
            self.assertEqual(request["authorization"],
                             "Bearer file-bearer-4672",
                             "le transport reel n'a pas recu le credential du "
                             "fichier d'environnement")
            self.assertTrue(request["path"].startswith("/roo-state-manager/mcp"),
                            f"chemin inattendu : {request['path']}")
            payload = json.loads(request["body"] or b"{}")
            arguments = (payload.get("params") or {}).get("arguments") or {}
            if arguments.get("action"):
                actions.append(arguments["action"])
        self.assertIn("list", actions)
        self.assertIn("read", actions)
        self.assertNotIn("file-bearer-4672", combined,
                         "le bearer du fichier a fuite dans la sortie de l'organe")


class Cp1252Output(unittest.TestCase):
    """Le verdict semantique survit a une console cp1252 (enfant reel)."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.dashboard = self.root / "overdue.md"
        self.dashboard.write_text(OVERDUE_WITH_ARROW, encoding="utf-8")

    def args(self, *extra):
        return ["--dashboard-file", str(self.dashboard), "--now", NOW,
                "--env-file", "", *extra]

    def test_verdict_2_survives_a_cp1252_console(self):
        proc = _run_cp1252(SCRIPT, self.args())
        self.assertEqual(
            proc.returncode, 2,
            "le verdict 2 est perdu sous cp1252 (c'etait le bug #4672 : "
            f"crash => 1)\nstdout:\n{proc.stdout}\nstderr:\n{proc.stderr}")
        self.assertIn("SONNERIE", proc.stdout)
        self.assertNotIn("UnicodeEncodeError", proc.stderr)

    def test_json_verdict_2_survives_a_cp1252_console(self):
        proc = _run_cp1252(SCRIPT, self.args("--json"))
        self.assertEqual(proc.returncode, 2,
                         f"stdout:\n{proc.stdout}\nstderr:\n{proc.stderr}")
        self.assertEqual(json.loads(proc.stdout)["exit"], 2)

    def test_negative_control_cp1252_without_the_reconfigure_loop_fails(self):
        # Temoin negatif n°2 : retire la boucle de reconfigure et le meme run
        # cp1252 DOIT perdre le verdict (crash UnicodeEncodeError).
        src = SCRIPT.read_text(encoding="utf-8")
        mutated, count = _RECONFIGURE_LOOP.subn("\n", src)
        self.assertEqual(
            count, 1,
            "la boucle de reconfigure stdout/stderr est introuvable ou ambigue "
            f"({count} occurrence(s)) — le temoin negatif cp1252 ne peut pas "
            "etre arme ; mettre a jour la regex de ce wrapper")
        mutant_path = self.root / "organ-mutant-encoding.py"
        mutant_path.write_text(mutated, encoding="utf-8")
        proc = _run_cp1252(mutant_path, self.args())
        self.assertNotEqual(proc.returncode, 2,
                            "le verdict survit a la suppression de la boucle de "
                            "reconfigure — le mutant survit, la garde ne garde rien")
        self.assertIn("UnicodeEncodeError", proc.stderr,
                      "le mutant echoue pour une RAISON autre que l'encodage — "
                      "verifier que la mutation n'a pas casse le script autrement")


if __name__ == "__main__":
    unittest.main()
