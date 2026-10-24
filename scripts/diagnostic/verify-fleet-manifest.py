#!/usr/bin/env python3
"""
verify-fleet-manifest.py — Verify the live Claude Code MCP config of this machine
against the declarative fleet manifest (.claude/configs/fleet-manifest.json).

Prototype of the "fleet extension manifest" adaptation lead (pi-agent comparative
study §7 lead #2, issue #2416; pattern source: devstack pi-packages.json).
READ-ONLY: this tool never writes, to the config or anywhere else.

Checks the three MCP state locations of ~/.claude.json (#3137):
  1. user-scope `mcpServers`                    -> the installed set
  2. `projects[<path>].mcpServers`              -> workspace-scoped installs
  3. `projects[<path>].disabledMcpServers`      -> per-workspace disables (PRIMES
     over locations 1/2; indexed by ABSOLUTE workspace path — a relocated
     workspace turns its disable into a ghost, #4195)

Findings:
  MANIFEST_UNKNOWN       (error)  machine not described in the manifest
  MISSING_REQUIRED       (error)  required server absent from the installed set
  REQUIRED_DISABLED      (error)  required server disabled for the verified workspace
  RETIRED_PRESENT        (error)  retired server present (installed anywhere)
  UNEXPECTED_SERVER      (warn)   installed server unknown to the manifest
  GHOST_DISABLE_PATH     (warn)   disables under a path that no longer exists (#4195)
  DISABLE_OF_UNINSTALLED (warn)   disable naming a server absent from installs

Only server NAMES and booleans are ever printed — no config values.

Usage:
    python scripts/diagnostic/verify-fleet-manifest.py                    # live config, machine from COMPUTERNAME
    python scripts/diagnostic/verify-fleet-manifest.py --machine myia-po-2024
    python scripts/diagnostic/verify-fleet-manifest.py --workspace <path> # default: cwd
    python scripts/diagnostic/verify-fleet-manifest.py --config <file>    # alternate config
    python scripts/diagnostic/verify-fleet-manifest.py --manifest <file>  # alternate manifest
    python scripts/diagnostic/verify-fleet-manifest.py --strict           # warns count as findings
    python scripts/diagnostic/verify-fleet-manifest.py --json             # machine-readable
    python scripts/diagnostic/verify-fleet-manifest.py --selftest

Exit codes: 0 = clean, 2 = >=1 finding, 1 = error.
"""

import argparse
import json
import os
import sys
import tempfile

EXIT_CLEAN = 0
EXIT_ERROR = 1
EXIT_FINDINGS = 2

DEFAULT_MANIFEST = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    ".claude", "configs", "fleet-manifest.json",
)


def norm_path(path):
    """Normalize a workspace path for comparison: forward slashes, lowercase, no trailing slash."""
    return path.replace("\\", "/").lower().rstrip("/")


def load_json(path):
    with open(path, encoding="utf-8-sig") as f:
        return json.load(f)


def resolve_machine(manifest, machine):
    """Return the per-machine entry, or None when the machine is not in the manifest."""
    machines = manifest.get("machines", {})
    return machines.get(machine) or machines.get(machine.lower())


def resolve_expectations(manifest, machine_entry):
    """Merge fleet_common with per-machine overrides (a list present at machine level
    REPLACES the fleet_common list — keep machine entries explicit)."""
    common = manifest.get("fleet_common", {})
    merged = {}
    for key in ("required", "allowed", "retired"):
        base = list(common.get(key, []))
        if machine_entry and key in machine_entry:
            base = list(machine_entry[key] or [])
        merged[key] = base
    return merged


def parse_disables(entry):
    """disabledMcpServers is a list in the wild; tolerate a dict (name -> reason)."""
    dis = entry.get("disabledMcpServers") or []
    if isinstance(dis, dict):
        return list(dis.keys())
    return list(dis)


def scan_config(cfg, workspace_norm):
    """Extract effective MCP state from a parsed ~/.claude.json.

    Returns (installs, workspace_disables, ghost_disable_paths, disables_of_uninstalled).
    """
    installs = set(cfg.get("mcpServers", {}).keys())
    workspace_disables = set()
    ghost_paths = []
    all_disables = set()

    for path, entry in (cfg.get("projects", {}) or {}).items():
        ws_servers = set((entry.get("mcpServers") or {}).keys())
        installs |= ws_servers
        dis = parse_disables(entry)
        if not dis:
            continue
        all_disables.update(dis)
        if not (os.path.isdir(path) or os.path.isfile(path)):
            ghost_paths.append(path)
        if norm_path(path) == workspace_norm:
            workspace_disables = set(dis)

    disables_of_uninstalled = sorted(all_disables - installs)
    return installs, workspace_disables, ghost_paths, disables_of_uninstalled


def verify(cfg, manifest, machine, workspace_norm, strict=False):
    """Run all checks. Returns a list of findings: {code, severity, detail}."""
    findings = []

    def add(code, severity, detail):
        findings.append({"code": code, "severity": severity, "detail": detail})

    entry = resolve_machine(manifest, machine)
    if entry is None:
        add("MANIFEST_UNKNOWN", "error",
            f"machine '{machine}' has no entry in the manifest "
            f"(known: {', '.join(sorted(manifest.get('machines', {}))) or 'none'})")
        return findings

    exp = resolve_expectations(manifest, entry)
    installs, ws_disables, ghosts, stale_dis = scan_config(cfg, workspace_norm)

    for name in exp["required"]:
        if name not in installs:
            add("MISSING_REQUIRED", "error", f"required server '{name}' not installed")
    for name in exp["required"]:
        if name in installs and name in ws_disables:
            add("REQUIRED_DISABLED", "error",
                f"required server '{name}' disabled for workspace (location 3 primes, #3137)")
    for name in exp["retired"]:
        if name in installs:
            add("RETIRED_PRESENT", "error", f"retired server '{name}' present (#3423)")
    known = set(exp["required"]) | set(exp["allowed"]) | set(exp["retired"])
    for name in sorted(installs - known):
        add("UNEXPECTED_SERVER", "warn",
            f"installed server '{name}' unknown to the manifest (add to allowed, or remove)")
    for path in ghosts:
        add("GHOST_DISABLE_PATH", "warn",
            f"disables under non-existent path '{path}' — stale disable, run "
            f"audit-stale-mcp-disables.py for the detail (#4195)")
    for name in stale_dis:
        add("DISABLE_OF_UNINSTALLED", "warn",
            f"a disable names server '{name}' which is not installed anywhere — residue entry")

    if strict:
        for f in findings:
            if f["severity"] == "warn":
                f["severity"] = "error"
    return findings


def selftest():
    """Synthetic fixtures covering every finding class and the clean case.

    Ghost-path detection depends on real filesystem state, so the workspace
    paths used in fixtures live inside a temp dir (existing) or are referenced
    only in the config (non-existing).
    """
    manifest = {
        "fleet_common": {
            "required": ["roo-state-manager"],
            "allowed": ["searxng"],
            "retired": ["quickfiles"],
        },
        "machines": {
            "myia-test": {"roles": ["executor"]},
            "myia-override": {"allowed": ["searxng", "extra-one"]},
        },
    }
    with tempfile.TemporaryDirectory() as tmp:
        live_ws = os.path.join(tmp, "live").replace("\\", "/")
        os.makedirs(live_ws)
        gone_ws = os.path.join(tmp, "gone").replace("\\", "/")  # never created

        cases = [
            # (label, cfg, machine, workspace, strict, expected codes)
            ("clean",
             {"mcpServers": {"roo-state-manager": {}, "searxng": {}}, "projects": {}},
             "myia-test", live_ws, False, []),
            ("missing+unexpected",
             {"mcpServers": {"searxng": {}, "mystery-mcp": {}}, "projects": {}},
             "myia-test", live_ws, False,
             ["MISSING_REQUIRED", "UNEXPECTED_SERVER"]),
            ("required-disabled + ghost + stale-disable",
             {"mcpServers": {"roo-state-manager": {}, "searxng": {}},
              "projects": {
                  gone_ws: {"disabledMcpServers": ["roo-state-manager", "ghosted-one"]},
                  live_ws: {"disabledMcpServers": ["roo-state-manager"]},
              }},
             "myia-test", live_ws, False,
             ["REQUIRED_DISABLED", "GHOST_DISABLE_PATH", "DISABLE_OF_UNINSTALLED"]),
            ("retired-present",
             {"mcpServers": {"roo-state-manager": {}, "quickfiles": {}}, "projects": {}},
             "myia-test", live_ws, False,
             ["RETIRED_PRESENT"]),
            ("machine-override-replaces-allowed",
             {"mcpServers": {"roo-state-manager": {}, "extra-one": {}, "searxng": {}}, "projects": {}},
             "myia-override", live_ws, False,
             []),
            ("unknown-machine",
             {"mcpServers": {"roo-state-manager": {}}, "projects": {}},
             "someone-else", live_ws, False,
             ["MANIFEST_UNKNOWN"]),
            ("strict-promotes-warn",
             {"mcpServers": {"roo-state-manager": {}, "mystery-mcp": {}}, "projects": {}},
             "myia-test", live_ws, True,
             ["UNEXPECTED_SERVER"]),
        ]

        passed = 0
        for label, cfg, machine, workspace, strict, expected in cases:
            got = [f["code"] for f in verify(cfg, manifest, machine, norm_path(workspace), strict)]
            ok = sorted(got) == sorted(expected)
            if label == "strict-promotes-warn":
                sev = [f["severity"] for f in verify(cfg, manifest, machine, norm_path(workspace), strict)]
                ok = ok and sev == ["error"]
            if ok:
                passed += 1
            else:
                print(f"[SELFTEST] FAIL {label}: expected {expected}, got {got}")
                return EXIT_ERROR

        # workspace path normalization: backslashes + case must match the config key
        backslash_key = os.path.join(tmp, "Back", "WS")
        cfg = {"mcpServers": {"roo-state-manager": {}},
               "projects": {backslash_key: {"disabledMcpServers": ["roo-state-manager"]}}}
        probe = os.path.join(tmp, "back", "ws")
        os.makedirs(probe)
        got = [f["code"] for f in verify(cfg, manifest, "myia-test", norm_path(probe), False)]
        if got != ["REQUIRED_DISABLED"]:
            print(f"[SELFTEST] FAIL path-normalization: expected [REQUIRED_DISABLED], got {got}")
            return EXIT_ERROR
        passed += 1

    print(f"[SELFTEST] PASS ({passed} cases: all finding classes, override, strict, path normalization)")
    return EXIT_CLEAN


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    parser.add_argument("--config", default=os.path.expanduser("~/.claude.json"))
    parser.add_argument("--manifest", default=DEFAULT_MANIFEST)
    parser.add_argument("--machine", default=os.environ.get("COMPUTERNAME", "").lower())
    parser.add_argument("--workspace", default=os.getcwd())
    parser.add_argument("--strict", action="store_true",
                        help="promote warn-severity findings to errors")
    parser.add_argument("--json", action="store_true", dest="as_json")
    parser.add_argument("--selftest", action="store_true")
    args = parser.parse_args()

    if args.selftest:
        return selftest()

    try:
        cfg = load_json(args.config)
        manifest = load_json(args.manifest)
    except (OSError, ValueError) as exc:
        print(f"ERROR: cannot load input — {exc}")
        return EXIT_ERROR

    workspace_norm = norm_path(args.workspace)
    findings = verify(cfg, manifest, args.machine, workspace_norm, args.strict)

    if args.as_json:
        print(json.dumps({
            "machine": args.machine,
            "workspace": workspace_norm,
            "config": norm_path(args.config),
            "manifest": norm_path(args.manifest),
            "findings": findings,
            "errors": sum(1 for f in findings if f["severity"] == "error"),
            "warns": sum(1 for f in findings if f["severity"] == "warn"),
        }, indent=2))
    else:
        print(f"machine={args.machine} workspace={workspace_norm}")
        if not findings:
            print("CLEAN — live config matches the fleet manifest")
        for f in findings:
            print(f"[{f['severity'].upper()}] {f['code']}: {f['detail']}")

    has_findings = any(f["severity"] == "error" for f in findings)
    return EXIT_FINDINGS if has_findings else EXIT_CLEAN


if __name__ == "__main__":
    sys.exit(main())
