#!/usr/bin/env python3
"""
verify-fleet-manifest.py — Verify the live Claude Code MCP config of this machine
against the declarative fleet manifest (.claude/configs/fleet-manifest.json).

Prototype of the "fleet extension manifest" adaptation lead (pi-agent comparative
study §7 lead #2, issue #2416; pattern source: devstack pi-packages.json).
READ-ONLY: this tool never writes, to the config or anywhere else.

Checks the three MCP state locations of ~/.claude.json (#3137), plus the
project-scoped <project>/.mcp.json file (#4904):
  1. user-scope `mcpServers`                    -> the installed set
  2. `projects[<path>].mcpServers`              -> workspace-scoped installs
  3. `projects[<path>].disabledMcpServers`      -> per-workspace disables (PRIMES
     over locations 1/2; indexed by ABSOLUTE workspace path — a relocated
     workspace turns its disable into a ghost, #4195)
  4. `<project>/.mcp.json`.mcpServers           -> project-file installs, NAMES
     only (the mapping's values can contain credentials; never read or report them)

Findings:
  MANIFEST_UNKNOWN       (error)  machine not described in the manifest
  MISSING_REQUIRED       (error)  required server absent from USER-SCOPE installs
                                  (location 1 — the contract of semantics.required;
                                  a workspace-scoped install under another project
                                  does not satisfy it, reserve (A) of PR #4338)
  REQUIRED_DISABLED      (error)  required server disabled for the verified workspace
  RETIRED_PRESENT        (error)  retired server present (installed anywhere)
  UNEXPECTED_SERVER      (warn)   installed server unknown to the manifest,
                                  user scope + the checked workspace (#4917)
  GHOST_DISABLE_PATH     (warn)   disables under a path that no longer exists (#4195)
  DISABLE_OF_UNINSTALLED (warn)   disable naming a server absent from installs
                                  (claude.ai CONNECTORS excluded: they are never
                                  in mcpServers — roster is claudeAiMcpEverConnected)

`required` is checked against location 1 only. `retired` (RETIRED_PRESENT) and
the residue disable check scan the union of locations 1, 2 and 4 over EVERY
project the config knows about — a server installed workspace- or project-scope
is "present" for those classes. `allowed` (UNEXPECTED_SERVER) is checked
against location 1 plus locations 2 and 4 of the VERIFIED workspace only: a
server wired by a neighbour project is another lane's state, not this
workspace's finding (#4917).

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


def connector_names(cfg):
    """Names of claude.ai connectors this seat knows about.

    Connectors are disabled per workspace exactly like MCP servers (location 3)
    but are never installed into `mcpServers` — their roster is
    `claudeAiMcpEverConnected`. A disable naming one is a real workspace
    choice, not a residue entry (#4336 rollout measure, myia-ai-01).
    """
    raw = cfg.get("claudeAiMcpEverConnected") or []
    if isinstance(raw, dict):
        raw = raw.keys()
    return {n for n in raw if isinstance(n, str)}


def project_server_names(path):
    """Server names a workspace declares in its own `<workspace>/.mcp.json` (#4904).

    Claude Code's project scope is a FILE next to the project, not an entry in
    `~/.claude.json` — and it is exactly how the notebook fallback must be wired
    (harnais-tightening.md §2, #4340). Ignoring it made the disable of such a
    server read as residue on every session start (po-2023 FRICTION 23/11).

    Only NAMES are read: `mcpServers` values can carry `env` secrets, so the
    parsed mapping is never returned, logged or interpolated. An absent,
    unreadable, malformed or wrongly-shaped file declares nothing — silently,
    because this probe runs at every session start.
    """
    if not isinstance(path, str) or not path:
        return set()
    try:
        with open(os.path.join(path, ".mcp.json"), encoding="utf-8-sig") as f:
            data = json.load(f)
        servers = data.get("mcpServers", {}) if isinstance(data, dict) else {}
        if not isinstance(servers, dict):
            return set()
        return {name for name in servers if isinstance(name, str)}
    except (OSError, ValueError):
        return set()


def scan_config(cfg, workspace_norm):
    """Extract effective MCP state from a parsed ~/.claude.json.

    Returns (installs, scoped_installs, workspace_disables, ghost_disable_paths,
    disables_of_uninstalled, user_installs). Three install sets, one per
    question asked of them:

    - `installs` — location 1 and 2 plus the project-scoped `<path>/.mcp.json`
      (location 4) of EVERY project the config knows about (#4904). It answers
      "does this server exist anywhere on this seat": RETIRED_PRESENT (a
      retired server must not exist anywhere) and the residue disable check
      (DISABLE_OF_UNINSTALLED) are judged on it.
    - `scoped_installs` — location 1 (user scope) plus locations 2 and 4 of
      the VERIFIED workspace only. It answers "what is installed for the
      workspace being checked": UNEXPECTED_SERVER is judged on it (#4917).
      The union carried servers wired by NEIGHBOUR projects, and the probe
      advised this workspace to "add to allowed, or remove" a server that is
      another lane's state.
    - `user_installs` — location 1 alone, the set semantics.required is
      checked against (PR #4338 reserve (A)).
    """
    user_installs = set(cfg.get("mcpServers", {}).keys())
    installs = set(user_installs)
    scoped_installs = set(user_installs)
    workspace_disables = set()
    ghost_paths = []
    all_disables = set()

    for path, entry in (cfg.get("projects", {}) or {}).items():
        checked = norm_path(path) == workspace_norm
        ws_servers = set((entry.get("mcpServers") or {}).keys())
        project_servers = project_server_names(path)
        installs |= ws_servers | project_servers
        if checked:
            scoped_installs |= ws_servers | project_servers
        dis = parse_disables(entry)
        if not dis:
            continue
        all_disables.update(dis)
        if not (os.path.isdir(path) or os.path.isfile(path)):
            ghost_paths.append(path)
        if checked:
            workspace_disables = set(dis)

    disables_of_uninstalled = sorted(all_disables - installs)
    return (installs, scoped_installs, workspace_disables, ghost_paths,
            disables_of_uninstalled, user_installs)


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
    installs, scoped_installs, ws_disables, ghosts, stale_dis, user_installs = scan_config(
        cfg, workspace_norm)
    # A connector disabled for a workspace appears in `disabledMcpServers` but
    # never in `mcpServers`, so without this exclusion every seat that turned a
    # connector off carries a permanent warn (and `--strict` an error) — the
    # class would be measuring the connector registry, not residue (#4336).
    connectors = connector_names(cfg)
    stale_dis = [n for n in stale_dis if n not in connectors]

    # `required` is checked against location 1 alone (semantics.required:
    # "must be installed user-scope") — a workspace-scoped install under
    # another project used to satisfy this via the union and under-report
    # in silence (PR #4338 reserve (A), demonstrated by execution).
    for name in exp["required"]:
        if name not in user_installs:
            add("MISSING_REQUIRED", "error",
                f"required server '{name}' not installed user-scope (location 1)")
    for name in exp["required"]:
        if name in user_installs and name in ws_disables:
            add("REQUIRED_DISABLED", "error",
                f"required server '{name}' disabled for workspace (location 3 primes, #3137)")
    for name in exp["retired"]:
        if name in installs:
            add("RETIRED_PRESENT", "error", f"retired server '{name}' present (#3423)")
    known = set(exp["required"]) | set(exp["allowed"]) | set(exp["retired"])
    # Judged on the checked workspace's own installs, not on the union: the
    # advice below ("add to allowed, or remove") must never point at a server
    # wired by a neighbour project — that is another lane's state (#4917).
    for name in sorted(scoped_installs - known):
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
            "allowed": ["searxng", "jupyter-papermill"],
            "retired": ["quickfiles"],
        },
        "machines": {
            "myia-test": {"roles": ["executor"]},
            # override OMITS the fleet-allowed "searxng" on purpose: with the
            # fleet member installed, REPLACE must flag it UNEXPECTED_SERVER
            # while MERGE would stay clean — the fixture discriminates the
            # two semantics (PR #4338 reserve (B)).
            "myia-override": {"allowed": ["extra-one"]},
        },
    }
    with tempfile.TemporaryDirectory() as tmp:
        live_ws = os.path.join(tmp, "live").replace("\\", "/")
        os.makedirs(live_ws)
        gone_ws = os.path.join(tmp, "gone").replace("\\", "/")  # never created
        # A NEIGHBOUR project: another workspace on the same seat, with its own
        # .mcp.json (#4917). It exists on disk, so it raises no ghost finding.
        neighbour_ws = os.path.join(tmp, "neighbour").replace("\\", "/")
        os.makedirs(neighbour_ws)

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
             ["UNEXPECTED_SERVER"]),
            # reserve (A): roo-state-manager installed ONLY workspace-scope
            # under another project — the union used to satisfy required and
            # this exited CLEAN; the contract is location 1.
            ("required-userscope-only (reserve A)",
             {"mcpServers": {},
              "projects": {"D:/some/other/repo": {"mcpServers": {"roo-state-manager": {}}}}},
             "myia-test", live_ws, False,
             ["MISSING_REQUIRED"]),
            ("unknown-machine",
             {"mcpServers": {"roo-state-manager": {}}, "projects": {}},
             "someone-else", live_ws, False,
             ["MANIFEST_UNKNOWN"]),
            ("strict-promotes-warn",
             {"mcpServers": {"roo-state-manager": {}, "mystery-mcp": {}}, "projects": {}},
             "myia-test", live_ws, True,
             ["UNEXPECTED_SERVER"]),
            # A claude.ai connector disabled for a workspace lives in
            # disabledMcpServers but never in mcpServers (roster:
            # claudeAiMcpEverConnected). Before the exclusion this exited with
            # DISABLE_OF_UNINSTALLED on every seat that disabled a connector —
            # measured firsthand on myia-ai-01, 2026-10-26 (#4336).
            ("connector-disable-is-not-residue",
             {"mcpServers": {"roo-state-manager": {}},
              "projects": {live_ws: {"disabledMcpServers": ["Some Connector"]}},
              "claudeAiMcpEverConnected": ["Some Connector"]},
             "myia-test", live_ws, False, []),
            # ...and the control that keeps the class alive: the SAME disable
            # with no registry entry is still a residue.
            ("unregistered-disable-is-residue",
             {"mcpServers": {"roo-state-manager": {}},
              "projects": {live_ws: {"disabledMcpServers": ["Some Connector"]}}},
             "myia-test", live_ws, False, ["DISABLE_OF_UNINSTALLED"]),
            # Control for the project .mcp.json cases below: the SAME disable under
            # the SAME workspace, with no .mcp.json there — still a residue. It
            # keeps the class alive once the next case stops flagging it (#4904).
            ("disable-of-uninstalled-without-project-mcp-json",
             {"mcpServers": {"roo-state-manager": {}},
              "projects": {live_ws: {"disabledMcpServers": ["X"]}}},
             "myia-test", live_ws, False, ["DISABLE_OF_UNINSTALLED"]),
            # A server installed ONLY by the project's .mcp.json is installed. That
            # is the canonical wiring of the notebook fallback (harnais-tightening
            # §2, #4340), and it was reported as residue on every session start
            # (po-2023 FRICTION 23/11; #4904). Fixture uses the real server name —
            # it is manifest-allowed by this synthetic manifest — and the control below
            # uses a name that is NOT allowed, so the residue class stays discriminating.
            ("project-mcp-json-server-is-installed",
             {"mcpServers": {"roo-state-manager": {}},
              "projects": {live_ws: {"disabledMcpServers": ["jupyter-papermill"]}}},
             "myia-test", live_ws, False, []),
            # Control, same file: a server the manifest does not allow is still
            # UNEXPECTED_SERVER. The fix must not mute that class.
            ("project-mcp-json-unknown-server-still-flagged",
             {"mcpServers": {"roo-state-manager": {}},
              "projects": {live_ws: {"disabledMcpServers": ["mystery-mcp"]}}},
             "myia-test", live_ws, False, ["UNEXPECTED_SERVER"]),
            # `required` keeps meaning location 1 (PR #4338 reserve (A)): a server
            # wired only through .mcp.json does not satisfy it.
            ("required-still-user-scope-only",
             {"mcpServers": {}, "projects": {live_ws: {}}},
             "myia-test", live_ws, False, ["MISSING_REQUIRED"]),
            # The union feeds RETIRED_PRESENT too: a retired server wired through
            # .mcp.json is present, and used to be invisible to this probe.
            ("retired-server-via-project-mcp-json",
             {"mcpServers": {"roo-state-manager": {}}, "projects": {live_ws: {}}},
             "myia-test", live_ws, False, ["RETIRED_PRESENT"]),
            # Tolerant read: an unreadable file (here a DIRECTORY where the file
            # should be — the only unreadable shape portable across OSes and
            # root), invalid JSON, or a `mcpServers` of the wrong shape must not
            # crash the probe, and leave the disable a residue.
            ("unreadable-project-mcp-json-is-ignored",
             {"mcpServers": {"roo-state-manager": {}},
              "projects": {live_ws: {"disabledMcpServers": ["X"]}}},
             "myia-test", live_ws, False, ["DISABLE_OF_UNINSTALLED"]),
            ("invalid-json-project-mcp-json-is-ignored",
             {"mcpServers": {"roo-state-manager": {}},
              "projects": {live_ws: {"disabledMcpServers": ["X"]}}},
             "myia-test", live_ws, False, ["DISABLE_OF_UNINSTALLED"]),
            ("wrong-shape-project-mcp-json-is-ignored",
             {"mcpServers": {"roo-state-manager": {}},
              "projects": {live_ws: {"disabledMcpServers": ["X"]}}},
             "myia-test", live_ws, False, ["DISABLE_OF_UNINSTALLED"]),
            # --- scope of UNEXPECTED_SERVER (#4917) ---------------------------------
            # A server the manifest does not know, wired ONLY by a NEIGHBOUR
            # project (another workspace on the same seat), is not the checked
            # workspace's finding: the probe advises "add to allowed, or
            # remove", and removing it is a gesture on another lane's state.
            # The checked workspace (live_ws) is registered throughout, as it
            # is on a real seat — location 4 is read through the `projects`
            # keys — and declares nothing of its own in the two cases below.
            # Location 4 first (the neighbour's .mcp.json) ...
            ("neighbour-project-mcp-json-unknown-server-is-not-flagged",
             {"mcpServers": {"roo-state-manager": {}},
              "projects": {live_ws: {}, neighbour_ws: {}}},
             "myia-test", live_ws, False, []),
            # ... then location 2 (a workspace-scoped install of the neighbour).
            ("neighbour-workspace-install-unknown-server-is-not-flagged",
             {"mcpServers": {"roo-state-manager": {}},
              "projects": {live_ws: {},
                           neighbour_ws: {"mcpServers": {"mystery-mcp": {}}}}},
             "myia-test", live_ws, False, []),
            # Controls: the checked workspace keeps raising the class through
            # its own locations — location 2 ...
            ("checked-workspace-install-unknown-server-is-flagged",
             {"mcpServers": {"roo-state-manager": {}},
              "projects": {live_ws: {"mcpServers": {"mystery-mcp": {}}}}},
             "myia-test", live_ws, False, ["UNEXPECTED_SERVER"]),
            # ... and location 4, with the neighbour declaring the SAME server:
            # exactly one finding — neither zero (muted) nor two (union). The
            # checked workspace is a registered project here, as it is on a
            # real seat: location 4 is read through the `projects` keys.
            ("checked-and-neighbour-declare-the-same-unknown-server",
             {"mcpServers": {"roo-state-manager": {}},
              "projects": {live_ws: {}, neighbour_ws: {}}},
             "myia-test", live_ws, False, ["UNEXPECTED_SERVER"]),
            # The union is what RETIRED_PRESENT is judged on, wherever the
            # server is wired: a retired server in a neighbour's .mcp.json is
            # still present ("must not exist anywhere").
            ("retired-server-via-neighbour-project-mcp-json",
             {"mcpServers": {"roo-state-manager": {}},
              "projects": {live_ws: {}, neighbour_ws: {}}},
             "myia-test", live_ws, False, ["RETIRED_PRESENT"]),
            # ... and it is what the residue check is judged on (#4904): a
            # server installed only by the neighbour is not a residue.
            ("disable-of-server-installed-by-neighbour-project-mcp-json",
             {"mcpServers": {"roo-state-manager": {}},
              "projects": {live_ws: {"disabledMcpServers": ["jupyter-papermill"]},
                           neighbour_ws: {}}},
             "myia-test", live_ws, False, []),
        ]

        # Project .mcp.json state per case (#4904): what live_ws/.mcp.json holds
        # when the case runs. A label absent from this table means NO file.
        # "DIR" = a directory where the file should be (unreadable on every OS).
        mcp_json_by_label = {
            "project-mcp-json-server-is-installed": b'{"mcpServers": {"jupyter-papermill": {"command": "x"}}}',
            "project-mcp-json-unknown-server-still-flagged": b'{"mcpServers": {"mystery-mcp": {"command": "x"}}}',
            "required-still-user-scope-only": b'{"mcpServers": {"roo-state-manager": {}}}',
            "retired-server-via-project-mcp-json": b'{"mcpServers": {"quickfiles": {}}}',
            "unreadable-project-mcp-json-is-ignored": "DIR",
            "invalid-json-project-mcp-json-is-ignored": b'{"mcpServers": {',
            "wrong-shape-project-mcp-json-is-ignored": b'{"mcpServers": ["X"]}',
            "checked-and-neighbour-declare-the-same-unknown-server":
                b'{"mcpServers": {"mystery-mcp": {"command": "x"}}}',
        }
        # Same file, in the NEIGHBOUR project (#4917): no "DIR" / invalid /
        # wrong-shape shape here — the tolerant read is covered above, and the
        # reading function is the same for both roots.
        neighbour_mcp_json_by_label = {
            "neighbour-project-mcp-json-unknown-server-is-not-flagged":
                b'{"mcpServers": {"mystery-mcp": {"command": "x"}}}',
            "checked-and-neighbour-declare-the-same-unknown-server":
                b'{"mcpServers": {"mystery-mcp": {"command": "x"}}}',
            "retired-server-via-neighbour-project-mcp-json": b'{"mcpServers": {"quickfiles": {}}}',
            "disable-of-server-installed-by-neighbour-project-mcp-json":
                b'{"mcpServers": {"jupyter-papermill": {"command": "x"}}}',
        }

        def stage_mcp_json(state, root):
            path = os.path.join(root, ".mcp.json")
            if os.path.isdir(path):
                os.rmdir(path)
            elif os.path.exists(path):
                os.remove(path)
            if state == "DIR":
                os.mkdir(path)
            elif state is not None:
                with open(path, "wb") as f:
                    f.write(state)

        passed = 0
        for label, cfg, machine, workspace, strict, expected in cases:
            stage_mcp_json(mcp_json_by_label.get(label), live_ws)
            stage_mcp_json(neighbour_mcp_json_by_label.get(label), neighbour_ws)
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

        # workspace path normalization: backslashes + case must match the config key.
        # The directory is created at the KEY's case, not the probe's: on a
        # case-sensitive filesystem the key must exist verbatim or the ghost
        # check fires and buries the assertion being probed.
        backslash_key = os.path.join(tmp, "Back", "WS")
        os.makedirs(backslash_key)
        cfg = {"mcpServers": {"roo-state-manager": {}},
               "projects": {backslash_key: {"disabledMcpServers": ["roo-state-manager"]}}}
        probe = os.path.join(tmp, "back", "ws")
        got = [f["code"] for f in verify(cfg, manifest, "myia-test", norm_path(probe), False)]
        if got != ["REQUIRED_DISABLED"]:
            print(f"[SELFTEST] FAIL path-normalization: expected [REQUIRED_DISABLED], got {got}")
            return EXIT_ERROR
        passed += 1

    print(f"[SELFTEST] PASS ({passed} cases: all finding classes, override, strict, "
          f"path normalization, UNEXPECTED_SERVER scope)")
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
