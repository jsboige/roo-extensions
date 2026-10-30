#!/usr/bin/env python3
"""Tests unitaires de scripts/diagnostic/probe-qdrant-ingress.py (#4438).

Couvre :
  - le contrat de sortie (0 healthy / 1 degraded / 2 erreur d'instrument) ;
  - la CLASSIFICATION de la panne (502 = ingress noirhole, timeout, 401/403) ;
  - la PORTEE annoncee (cible locale vs ingress public) ;
  - le secret : la cle d'API part en en-tete et N'APPARAIT JAMAIS dans la sortie.

Stdlib uniquement (unittest + mock) — invoque par
scripts/testing/unit/probe-qdrant-ingress.Tests.ps1 (job CI unit-pester).
"""
import importlib.util
import io
import json
import os
import socket
import sys
import unittest
import urllib.error
from unittest import mock

SCRIPT_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "diagnostic",
    "probe-qdrant-ingress.py",
)


def _load_module():
    spec = importlib.util.spec_from_file_location("probe_qdrant_ingress", SCRIPT_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


probe_mod = _load_module()


class FakeResponse:
    def __init__(self, status=200):
        self.status = status

    def read(self, _n=1):
        return b""

    def getcode(self):
        return self.status

    def __enter__(self):
        return self

    def __exit__(self, *_exc):
        return False


class ProbeContractTests(unittest.TestCase):
    def test_200_is_healthy(self):
        result = probe_mod.probe("https://qdrant.myia.io/collections", None, opener=lambda *a, **k: FakeResponse(200))
        self.assertEqual(result["verdict"], "healthy")
        self.assertEqual(result["status"], 200)
        self.assertEqual(result["reason"], "ok")

    def test_502_is_the_blackholed_ingress_signature(self):
        err = urllib.error.HTTPError("https://qdrant.myia.io/collections", 502, "Bad Gateway", None, None)
        result = probe_mod.probe(
            "https://qdrant.myia.io/collections", None,
            opener=mock.Mock(side_effect=err),
        )
        self.assertEqual(result["verdict"], "degraded")
        self.assertEqual(result["reason"], "ingress_blackholed")
        self.assertEqual(result["status"], 502)

    def test_timeout_is_reported_as_timeout(self):
        result = probe_mod.probe(
            "https://qdrant.myia.io/collections", None,
            opener=mock.Mock(side_effect=socket.timeout("timed out")),
        )
        self.assertEqual(result["verdict"], "degraded")
        self.assertEqual(result["reason"], "timeout")

    def test_401_is_an_auth_rejection_not_an_outage(self):
        err = urllib.error.HTTPError("https://qdrant.myia.io/collections", 401, "Unauthorized", None, None)
        result = probe_mod.probe(
            "https://qdrant.myia.io/collections", None,
            opener=mock.Mock(side_effect=err),
        )
        self.assertEqual(result["reason"], "auth_rejected")

    def test_loopback_target_is_reported_as_local_container(self):
        self.assertEqual(probe_mod.classify_scope("http://localhost:6333/collections"), "local-container")
        self.assertEqual(probe_mod.classify_scope("http://127.0.0.1:6333/collections"), "local-container")
        self.assertEqual(probe_mod.classify_scope("https://qdrant.myia.io/collections"), "public-ingress")

    def test_public_url_is_reported_as_public_ingress(self):
        result = probe_mod.probe("https://qdrant.myia.io/collections", None, opener=lambda *a, **k: FakeResponse(200))
        self.assertEqual(result["scope"], "public-ingress")

    def test_api_key_travels_in_the_header_and_never_in_the_output(self):
        secret = "SECRET-KEY-VALUE-123"
        captured = {}

        def opener(request, timeout=None):
            captured["headers"] = dict(request.header_items())
            return FakeResponse(200)

        result = probe_mod.probe("https://qdrant.myia.io/collections", secret, opener=opener)
        self.assertEqual(result["api_key_present"], True)
        rendered = probe_mod.format_human(result)
        self.assertNotIn(secret, rendered)
        self.assertNotIn(secret, json.dumps(result))
        # urllib capitalise les noms d'en-tetes : 'Api-key'
        header_values = " ".join(captured["headers"].values())
        self.assertIn(secret, header_values)

    def test_env_file_is_read_by_key_name_only(self):
        tmp = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_probe_env_tmp")
        with open(tmp, "w", encoding="utf-8") as handle:
            handle.write("# comment\nQDRANT_URL=https://qdrant.myia.io\nQDRANT_API_KEY=abc123\n")
        try:
            values = probe_mod.read_env_file(tmp)
            self.assertEqual(values["QDRANT_URL"], "https://qdrant.myia.io")
            self.assertEqual(values["QDRANT_API_KEY"], "abc123")
            url, key, source = probe_mod.resolve_target(None, tmp)
            self.assertEqual(url, "https://qdrant.myia.io/collections")
            self.assertEqual(key, "abc123")
            self.assertEqual(source, "env")
        finally:
            os.remove(tmp)

    def test_missing_env_file_degrades_to_the_public_default(self):
        url, key, _source = probe_mod.resolve_target(None, os.path.join(os.path.dirname(SCRIPT_PATH), "does-not-exist.env"))
        self.assertEqual(url, "https://qdrant.myia.io/collections")
        self.assertIn(key, (None, os.environ.get("QDRANT_API_KEY")))

    def test_default_url_is_the_single_source_of_truth(self):
        # #4438: le defaut fonctionnel doit deriver de DEFAULT_URL, sinon le
        # garde est aveugle — un second litteral dans resolve_target suffisait
        # a le satisfaire (mutant « cible locale » : suite verte).
        self.assertEqual(probe_mod.DEFAULT_URL, "https://qdrant.myia.io/collections")
        self.assertEqual(probe_mod.DEFAULT_BASE, "https://qdrant.myia.io")
        with mock.patch.dict(os.environ, {}, clear=True):
            url, _key, source = probe_mod.resolve_target(
                None, os.path.join(os.path.dirname(SCRIPT_PATH), "does-not-exist.env")
            )
        self.assertEqual(url, probe_mod.DEFAULT_URL)
        self.assertEqual(source, "env")

    def test_main_exit_codes(self):
        calls = {"n": 0}

        def opener(request, timeout=None):
            calls["n"] += 1
            if calls["n"] == 1:
                return FakeResponse(200)
            err = urllib.error.HTTPError("https://qdrant.myia.io/collections", 502, "Bad Gateway", None, None)
            raise err

        stdout = io.StringIO()
        with mock.patch("urllib.request.urlopen", side_effect=opener), \
                mock.patch.object(sys, "stdout", stdout):
            code_ok = probe_mod.main(["--json", "--url", "https://qdrant.myia.io/collections"])
        self.assertEqual(code_ok, 0)
        payload = json.loads(stdout.getvalue())
        self.assertEqual(payload["verdict"], "healthy")

        stdout2 = io.StringIO()
        with mock.patch("urllib.request.urlopen", side_effect=opener), \
                mock.patch.object(sys, "stdout", stdout2):
            code_degraded = probe_mod.main(["--json", "--url", "https://qdrant.myia.io/collections"])
        self.assertEqual(code_degraded, 1)


if __name__ == "__main__":
    unittest.main()
