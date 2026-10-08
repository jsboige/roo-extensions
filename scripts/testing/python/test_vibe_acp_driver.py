#!/usr/bin/env python3
"""Unit tests for vibe-acp-driver.py binary discovery (CLI migration 08/10).

Pins the precedence of find_vibe_acp: explicit --exe > standalone CLI
(PATH, then uv default dir) > VS Code extension bundle. The extension is
the legacy fallback — machines without the standalone CLI must keep
working (zero-breakage migration). Path fakes compare on a normalized
(backslash->slash, lowercased) suffix so the suite runs on Windows AND
on the Linux CI runner, where %USERPROFILE% stays literal.
"""

import importlib.util
import os
import unittest
from unittest import mock

_SPEC = importlib.util.spec_from_file_location(
    "vibe_acp_driver",
    os.path.join(os.path.dirname(os.path.abspath(__file__)),
                 "..", "..", "scheduling", "vibe-acp-driver.py"))
drv = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(drv)

UV_SUFFIX = ".local/bin/vibe-acp.exe"
EXT_SUFFIX = (".vscode/extensions/mistralai.mistral-vibe-code-1.23.0"
              "/bin/vibe-acp.exe")
WHICH_VAL = "X:/fakehome/.local/bin/vibe-acp.EXE"


def _norm(p):
    return p.replace("\\", "/").lower()


class TestFindVibeAcp(unittest.TestCase):
    def discover(self, which=None, uv=False, ext=False):
        """Patch the three sources, return find_vibe_acp('')."""
        def fake_isfile(p):
            n = _norm(p)
            if n.endswith(UV_SUFFIX):
                return uv
            if n.endswith(EXT_SUFFIX):
                return ext
            return False
        with mock.patch.object(drv.shutil, "which", return_value=which), \
             mock.patch.object(drv.os.path, "isfile", side_effect=fake_isfile), \
             mock.patch.object(drv.os.path, "getmtime", return_value=1234.0), \
             mock.patch.object(drv.glob, "glob",
                               return_value=["X:/fakehome/.vscode/extensions/"
                                             "mistralai.mistral-vibe-code-1.23.0"]):
            return drv.find_vibe_acp("")

    def test_explicit_beats_everything(self):
        with mock.patch.object(drv.os.path, "isfile", return_value=True):
            self.assertEqual(drv.find_vibe_acp("D:/custom/vibe-acp.exe"),
                             "D:/custom/vibe-acp.exe")

    def test_cli_on_path_beats_extension(self):
        # which()'s value revient VERBATIM — le chemin PATH gagne sur l'extension
        self.assertEqual(self.discover(which=WHICH_VAL, uv=True, ext=True),
                         WHICH_VAL)

    def test_uv_default_when_not_on_path(self):
        found = self.discover(which=None, uv=True, ext=True)
        self.assertTrue(_norm(found).endswith(UV_SUFFIX),
                        "défaut uv doit gagner sans PATH: %s" % found)

    def test_extension_fallback_when_no_cli(self):
        found = self.discover(which=None, uv=False, ext=True)
        self.assertTrue(_norm(found).endswith(EXT_SUFFIX),
                        "extension = fallback: %s" % found)

    def test_nothing_found_returns_empty(self):
        self.assertEqual(self.discover(which=None, uv=False, ext=False), "")


if __name__ == "__main__":
    unittest.main()
