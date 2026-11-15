#!/usr/bin/env python3
"""Tests for config-view.py (#3833, step 4 / #603 case 17).

unittest style so the static CI job (``python3 -m unittest discover -s
scripts/testing/python``) picks it up.

Everything runs against temporary fixture files: no real ~/.claude.json or
~/.claude/settings.json is ever read, and nothing is written outside a temp
directory. The mask rules (whitelist + secret-deny) are asserted with a
fixture that PLANTS secrets where a whitelist widening mistake would copy
them: if the guards regress, these tests fail before any leak ships.
"""

import importlib.util
import io
import json
import os
import tempfile
import unittest
from contextlib import redirect_stdout, redirect_stderr

_SCRIPT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..", "..", "diagnostic", "config-view.py",
)
_SPEC = importlib.util.spec_from_file_location("config_view", _SCRIPT)
config_view = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(config_view)

SETTINGS = {
    "env": {
        "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-5-5[1m]",
        "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-5-5[1m]",
        "ANTHROPIC_BASE_URL": "http://127.0.0.1:3000",
        "ANTHROPIC_CUSTOM_HEADERS": "X-Claudish-Machine: x\nx-proxy-key: LEAKED",
        "VLLM_API_KEY": "sk-leaked",
        "EMBEDDING_API_KEY": "sk-leaked",
        "API_TIMEOUT_MS": "600000",
        "MCP_TIMEOUT": "300000",
        "CLAUDE_CODE_AUTO_COMPACT_WINDOW": "230000",
        "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "95",
        "ENABLE_TOOL_SEARCH": "true",
        "CLAUDE_CODE_SUBAGENT_MODEL": "sonnet",
        "SOME_UNRELATED_THING": "not-published",
    },
    "permissions": {
        "mode": "auto-approve",
        "deny": ["AskUserQuestion", "NotebookEdit", "EnterPlanMode"],
    },
    "model": "sonnet",
    "outputStyle": "Proactive",
    "effortLevel": "xhigh",
    "disableBundledSkills": True,
    "disableRemoteControl": True,
    "hooks": {"PreToolUse": [{"hooks": [{"command": "node C:\\machine\\specific.js"}]}]},
    "modelSettings": {"claude-sonnet-5-5": {"effortLevel": "xhigh"}},
}

CLAUDE_JSON = {
    "mcpServers": {
        "roo-state-manager": {"command": "node"},
        "sk-agent": {"command": "powershell"},
        "playwright": {"command": "node"},
    },
    "projects": {
        "d:\\dev\\roo-extensions": {
            "mcpServers": {"project-only": {"command": "node"}},
        },
    },
}


class CollectConfigTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = self._tmp.name
        self.claude_json = os.path.join(self.root, "claude.json")
        self.settings = os.path.join(self.root, "settings.json")
        with open(self.claude_json, "w", encoding="utf-8") as handle:
            json.dump(CLAUDE_JSON, handle)
        with open(self.settings, "w", encoding="utf-8") as handle:
            json.dump(SETTINGS, handle)

    def tearDown(self):
        self._tmp.cleanup()

    def _collect(self):
        return config_view.collect_config(self.claude_json, self.settings)

    def test_whitelist_extraction(self):
        config = self._collect()
        self.assertEqual(
            config["env"]["ANTHROPIC_DEFAULT_OPUS_MODEL"], "claude-opus-5-5[1m]"
        )
        self.assertEqual(config["env"]["CLAUDE_CODE_AUTO_COMPACT_WINDOW"], "230000")
        self.assertEqual(config["env"]["ENABLE_TOOL_SEARCH"], "true")
        self.assertEqual(config["env"]["API_TIMEOUT_MS"], "600000")
        self.assertEqual(config["env"]["MCP_TIMEOUT"], "300000")

    def test_secrets_never_copied(self):
        """Whitelist + secret-deny double guard: planted secrets stay out."""
        config = self._collect()
        joined = json.dumps(config)
        for forbidden in ("LEAKED", "CUSTOM_HEADERS", "VLLM_API_KEY",
                          "EMBEDDING_API_KEY", "x-proxy-key"):
            self.assertNotIn(forbidden, joined)

    def test_unrelated_env_not_copied(self):
        config = self._collect()
        self.assertNotIn("SOME_UNRELATED_THING", config["env"])

    def test_mcp_names_sorted_project_entries_excluded(self):
        config = self._collect()
        self.assertEqual(
            config["mcpServers"], ["playwright", "roo-state-manager", "sk-agent"]
        )

    def test_permissions_identity_flags(self):
        config = self._collect()
        self.assertEqual(config["permissions"]["mode"], "auto-approve")
        self.assertEqual(
            config["permissions"]["deny"],
            ["AskUserQuestion", "EnterPlanMode", "NotebookEdit"],
        )
        self.assertEqual(config["model"], "sonnet")
        self.assertEqual(config["outputStyle"], "Proactive")
        self.assertEqual(config["flags"]["disableBundledSkills"], True)
        self.assertNotIn("hooks", config)
        self.assertNotIn("modelSettings", config)

    def test_missing_files_yield_absence_not_error(self):
        config = config_view.collect_config(
            os.path.join(self.root, "nope.json"),
            os.path.join(self.root, "nope-settings.json"),
        )
        self.assertEqual(config["mcpServers"], [])
        self.assertEqual(config["env"], {})
        self.assertIsNone(config["model"])


class MainTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = self._tmp.name
        self.claude_json = os.path.join(self.root, "claude.json")
        self.settings = os.path.join(self.root, "settings.json")
        with open(self.claude_json, "w", encoding="utf-8") as handle:
            json.dump(CLAUDE_JSON, handle)
        with open(self.settings, "w", encoding="utf-8") as handle:
            json.dump(SETTINGS, handle)
        self.shared = os.path.join(self.root, "shared")

    def tearDown(self):
        self._tmp.cleanup()

    def _run(self, *extra):
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = config_view.main(list(extra))
        return code, out.getvalue(), err.getvalue()

    def test_default_is_dry_run_writes_nothing(self):
        code, out, err = self._run(
            "--claude-json", self.claude_json, "--settings", self.settings
        )
        self.assertEqual(code, 0)
        self.assertEqual(err, "")
        self.assertFalse(os.path.exists(self.shared))
        payload = json.loads(out)
        self.assertIn("generatedAt", payload)
        self.assertIn("config", payload)

    def test_write_creates_snapshot(self):
        code, out, err = self._run(
            "--write", "--shared-path", self.shared,
            "--claude-json", self.claude_json, "--settings", self.settings,
        )
        self.assertEqual(code, 0)
        target_dir = os.path.join(self.shared, "config-view")
        names = [n for n in os.listdir(target_dir) if n.endswith(".json")]
        self.assertEqual(len(names), 1)
        with open(os.path.join(target_dir, names[0]), "r", encoding="utf-8") as handle:
            payload = json.load(handle)
        self.assertEqual(payload["schemaVersion"], "1.0.0")
        self.assertIn("ANTHROPIC_DEFAULT_OPUS_MODEL", payload["config"]["env"])
        self.assertNotIn("ANTHROPIC_CUSTOM_HEADERS", payload["config"]["env"])

    def test_write_requires_shared_path(self):
        os.environ.pop("ROOSYNC_SHARED_PATH", None)
        code, out, err = self._run(
            "--write", "--claude-json", self.claude_json, "--settings", self.settings
        )
        self.assertEqual(code, 1)
        self.assertIn("requires --shared-path", err)


if __name__ == "__main__":
    unittest.main()
