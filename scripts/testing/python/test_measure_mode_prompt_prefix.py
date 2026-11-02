#!/usr/bin/env python3
"""
test_measure_mode_prompt_prefix.py — scripts/diagnostic/measure-mode-prompt-prefix.py (#4334).

The instrument read JSON only. But the artifact a seat actually loads is a YAML
`custom_modes.yaml`, and its pre-op backups are named `custom_modes.yaml.backup-<date>`
— no `.yaml` suffix. Four relay cells (29/10–02/11) each hand-rolled the YAML
measurement, and a suffix-based format rule still failed on the backups. Format is
now sniffed from the content.

Cases:
  - JSON      : the tracked `.roomodes` artifact is read and reported.
  - YAML      : the same content as YAML yields the SAME numbers.
  - BACKUP    : a `custom_modes.yaml.backup-<date>` name (YAML content, no .yaml
                suffix) is read as YAML, not fed to json.loads.
  - FORKED    : a per-mode roleDefinition is reported as a fork at the right byte,
                so a SHARED verdict is not produced by a check that never runs.
"""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / "diagnostic" / "measure-mode-prompt-prefix.py"

try:
    import yaml
except ImportError:  # pragma: no cover - the YAML cases are skipped, not faked
    yaml = None

SHARED_ROLE = "Tu es l'agent technique de la flotte MYIA."
COMMON_INSTR_HEAD = "Mode actif : "


def build_modes(shared_role=True):
    modes = []
    for slug in ("code-simple", "code-complex", "ask-simple"):
        modes.append({
            "slug": slug,
            "name": slug,
            "roleDefinition": SHARED_ROLE if shared_role else f"Tu es Roo en mode {slug}",
            "customInstructions": COMMON_INSTR_HEAD + slug,
            "groups": ["read"],
        })
    return {"customModes": modes}


def run(*paths):
    proc = subprocess.run(
        [sys.executable, str(SCRIPT), *map(str, paths), "--json"],
        capture_output=True, text=True, encoding="utf-8",
    )
    if proc.returncode != 0:
        raise AssertionError(f"instrument failed: {proc.stderr}")
    return json.loads(proc.stdout)


class MeasureModePromptPrefixTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def write_json(self, modes):
        p = self.dir / "generated.roomodes"
        p.write_text(json.dumps(modes), encoding="utf-8")
        return p

    def write_yaml(self, modes, name="custom_modes.yaml"):
        p = self.dir / name
        p.write_text(yaml.safe_dump(modes, allow_unicode=True), encoding="utf-8")
        return p

    def test_json_artifact_is_measured(self):
        report, = run(self.write_json(build_modes()))
        self.assertEqual(report["mode_count"], 3)
        self.assertEqual(report["role_definition_lcp_bytes"], len(SHARED_ROLE.encode()))
        self.assertTrue(report["role_definition_all_identical"])

    @unittest.skipUnless(yaml, "PyYAML not installed")
    def test_yaml_matches_json_on_identical_content(self):
        modes = build_modes()
        from_json, = run(self.write_json(modes))
        from_yaml, = run(self.write_yaml(modes))
        for key in ("mode_count", "role_definition_lcp_bytes", "role_definition_length_bytes",
                    "custom_instructions_lcp_bytes", "composed_lcp_bytes"):
            self.assertEqual(from_json[key], from_yaml[key], f"{key} differs between formats")

    @unittest.skipUnless(yaml, "PyYAML not installed")
    def test_backup_filename_is_sniffed_as_yaml(self):
        p = self.write_yaml(build_modes(), name="custom_modes.yaml.backup-20261102-prefix")
        report, = run(p)  # before the fix: json.loads on YAML -> non-zero exit
        self.assertEqual(report["mode_count"], 3)
        self.assertEqual(report["custom_instructions_lcp_bytes"], len(COMMON_INSTR_HEAD.encode()))

    def test_per_mode_role_is_reported_as_forked(self):
        report, = run(self.write_json(build_modes(shared_role=False)))
        self.assertFalse(report["role_definition_all_identical"])
        self.assertEqual(report["role_definition_lcp_bytes"], len("Tu es Roo en mode ".encode()))

    def test_composed_counts_role_then_instructions(self):
        report, = run(self.write_json(build_modes()))
        expected = len(SHARED_ROLE.encode()) + len(b"\n\n") + len(COMMON_INSTR_HEAD.encode())
        self.assertEqual(report["composed_lcp_bytes"], expected)


if __name__ == "__main__":
    unittest.main()
