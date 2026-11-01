#!/usr/bin/env python3
"""
test_issue_picker_selector_parity.py — every copy of an issue-picker selector
carries the exclusions all pickers share (#622 follow-up).

The selectors are not code: they live as `gh issue list --search '...'` lines in
Markdown workflows, a slash command and a README, beside the one that runs in
start-claude-worker.ps1, and each copy drifts on its own. Measured 2026-11-01:
the `-label:copilot-target` exclusion (#622, decision ai-01 of 01/11) had
reached the executor workflow, the worker and pick_idle_grain.py, but not the
coordinator workflow (reported by web1, dashboard c.736), nor the two pool
counts of /coordinate, nor the README of scripts/scheduling.

A selector is a line whose `--search` query carries `no:assignee`: the
server-side filter every picker needs, which a keyword lookup does not carry.
"""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]

# Known homes of a selector. Each must still yield one, so a moved or renamed
# file fails here instead of passing on an empty scan.
SOURCES = (
    ".roo/scheduler-workflow-coordinator.md",
    ".roo/scheduler-workflow-executor.md",
    ".claude/commands/coordinate.md",
    "scripts/scheduling/README.md",
    "scripts/scheduling/start-claude-worker.ps1",
)
# Swept for copies not listed above.
SWEPT = (".roo", ".claude/commands", ".claude/skills", "scripts/scheduling")
SUFFIXES = {".md", ".ps1", ".py"}

SHARED_EXCLUSIONS = ("-label:epic", "-label:frozen", "-label:copilot-target")


def selectors(path):
    lines = path.read_text(encoding="utf-8").splitlines()
    return [(n, line) for n, line in enumerate(lines, 1)
            if "--search" in line and "no:assignee" in line]


def missing_exclusions(line):
    # Whole label only: `-label:epic` must not be satisfied by `-label:epic-x`.
    return [label for label in SHARED_EXCLUSIONS
            if not re.search(re.escape(label) + r"(?![\w-])", line)]


class IssuePickerSelectorParity(unittest.TestCase):

    def test_each_known_source_still_holds_a_selector(self):
        empty = [src for src in SOURCES if not selectors(ROOT / src)]
        self.assertEqual(empty, [], "no `--search ... no:assignee` line left in these files")

    def test_every_selector_carries_the_shared_exclusions(self):
        failures, seen = [], 0
        for base in SWEPT:
            for path in sorted((ROOT / base).rglob("*")):
                if path.suffix not in SUFFIXES or not path.is_file():
                    continue
                for n, line in selectors(path):
                    seen += 1
                    missing = missing_exclusions(line)
                    if missing:
                        failures.append(f"{path.relative_to(ROOT).as_posix()}:{n} lacks {' '.join(missing)}")
        self.assertGreaterEqual(seen, len(SOURCES), "the sweep found fewer selectors than the known sources")
        self.assertEqual(failures, [])

    def test_a_longer_label_does_not_satisfy_the_exclusion(self):
        line = "--search 'is:open no:assignee -label:epic-x -label:frozen -label:copilot-targets'"
        self.assertEqual(missing_exclusions(line), ["-label:epic", "-label:copilot-target"])


if __name__ == "__main__":
    unittest.main()
