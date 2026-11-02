#!/usr/bin/env python3
"""Measure the system-prompt prefix shared by every mode of a generated `.roomodes`.

Why (#4334): Zoo/Roo puts a mode's `roleDefinition` FIRST in the system prompt
(`zoo-code/src/core/prompts/system.ts`: `basePrompt = `${roleDefinition}\\n\\n...``)
and its `customInstructions` LAST (via `addCustomInstructions`). Provider prefix
caching -- vLLM KV blocks, Anthropic prompt cache (0.1x reads), OpenAI automatic
prefix caching -- only shares the bytes BEFORE the first divergence. So any
per-mode text inside `roleDefinition` costs the whole downstream socle (tools,
rules, global instructions) for every other mode.

Lower is worse. `roleDefinition` LCP == full roleDefinition length means the
entire fixed middle sits inside the shared prefix.

A `.roomodes` file is JSON; the artifact a seat actually loads is a YAML
`custom_modes.yaml` in the extension's globalStorage. Both are accepted -- the
relay measures the deployed file, and hand-rolling that measurement on each seat
is how four of them diverged in method (#4334 relay cells, 29/10-02/11).

Usage:
    python scripts/diagnostic/measure-mode-prompt-prefix.py [FILE ...] [--json]
    python scripts/diagnostic/measure-mode-prompt-prefix.py old.roomodes new.roomodes
    python scripts/diagnostic/measure-mode-prompt-prefix.py \
        "%APPDATA%/Code/User/globalStorage/zoocodeorganization.zoo-code/settings/custom_modes.yaml"

Default FILE: roo-config/modes/generated/simple-complex.roomodes
Format is sniffed from the content (JSON first, YAML on failure), so backups
named `custom_modes.yaml.backup-<date>` work as well as the live file.
Exit code: 0 always (this is an instrument, not a gate -- the gate is
scripts/testing/unit/mode-role-definition-prefix.Tests.ps1).
"""

import json
import sys
from pathlib import Path

DEFAULT = "roo-config/modes/generated/simple-complex.roomodes"


def longest_common_prefix(strings):
    if not strings:
        return 0
    shortest = min(strings)
    longest = max(strings)
    i = 0
    while i < len(shortest) and shortest[i] == longest[i]:
        i += 1
    return len(shortest[:i].encode("utf-8"))


def load_modes(path):
    text = Path(path).read_text(encoding="utf-8")
    try:
        return json.loads(text)["customModes"]
    except json.JSONDecodeError:
        try:
            import yaml
        except ImportError:
            sys.exit(f"PyYAML is required to read {path} (pip install pyyaml)")
        return yaml.safe_load(text)["customModes"]


def measure(path):
    modes = load_modes(path)
    roles = [m.get("roleDefinition", "") for m in modes]
    instr = [m.get("customInstructions", "") for m in modes]
    # Proxy, not a real prompt: the fixed middle sits between the two in
    # production. Reported because every relay cell quotes it. Upper bound:
    # the middle differs across modes (`groups` do, po-2023 on #4496), so
    # the customInstructions bytes rarely reach the real shared prefix.
    composed = [r + "\n\n" + c for r, c in zip(roles, instr)]
    return {
        "file": str(path),
        "mode_count": len(modes),
        "role_definition_lcp_bytes": longest_common_prefix(roles),
        "role_definition_length_bytes": len(roles[0].encode("utf-8")) if roles else 0,
        "role_definition_all_identical": len(set(roles)) == 1,
        "custom_instructions_lcp_bytes": longest_common_prefix(instr),
        "composed_lcp_bytes": longest_common_prefix(composed),
        "modes": [m.get("slug") for m in modes],
    }


def render(report):
    first_fork = report["role_definition_lcp_bytes"]
    total = report["role_definition_length_bytes"]
    lines = [
        f'{report["file"]}',
        f'  modes                          : {report["mode_count"]}',
        f'  roleDefinition LCP             : {first_fork} bytes',
        f'  roleDefinition length          : {total} bytes',
        f'  roleDefinition all identical   : {report["role_definition_all_identical"]}',
        f'  customInstructions LCP         : {report["custom_instructions_lcp_bytes"]} bytes',
        f'  composed LCP (upper bound)     : {report["composed_lcp_bytes"]} bytes',
    ]
    if report["role_definition_all_identical"]:
        lines.append(
            f"  verdict                        : SHARED -- every mode enters the"
            f" fixed middle (tools/rules/global instructions) with an identical {total}-byte head"
        )
    else:
        lines.append(
            f"  verdict                        : FORKED at byte {first_fork} -- nothing after"
            f" this point can be shared between modes"
        )
    return "\n".join(lines)


def main(argv):
    args = [a for a in argv[1:] if a != "--json"]
    as_json = "--json" in argv[1:]
    paths = args or [DEFAULT]
    reports = [measure(p) for p in paths]
    if as_json:
        print(json.dumps(reports, indent=2, ensure_ascii=False))
    else:
        print("\n\n".join(render(r) for r in reports))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
