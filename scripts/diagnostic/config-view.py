#!/usr/bin/env python3
"""config-view.py — publish a masked per-machine config snapshot (#3833, step 4 / #603 case 17).

Each seat extracts, from the same local files the MachineConfigCollector reads
(``~/.claude.json`` top-level mcpServers, ``~/.claude/settings.json`` env /
permissions / top-level toggles), ONE small JSON snapshot written atomically to
``$ROOSYNC_SHARED_PATH/config-view/<machine>.json``. The aggregated reader
(config-view-fleet.py) turns those snapshots into the fleet config view and a
consensus drift verdict (#603 cases 17-18).

THE WHITELIST IS THE MASK. Only explicitly allow-listed keys are ever copied,
and a value additionally survives only if its key fails the secret-deny
pattern (KEY/TOKEN/SECRET/PASSWORD/CREDENTIAL/HEADER/AUTH). ``ANTHROPIC_CUSTOM_HEADERS``
or any future ``*_API_KEY`` setting therefore cannot leak even if someone later
widens the whitelist by mistake: the deny pattern runs after it.

What is published (all non-secret by construction):

* ``mcpServers``      — sorted NAMES of the top-level ``~/.claude.json`` servers
* ``env``             — allow-listed settings env keys (model ids, compaction
  window, tool-search flag, timeouts...). ``ANTHROPIC_BASE_URL`` is published
  observe-only (reportable, never canon — #4347).
* ``permissions``     — ``mode`` + ``deny`` tool list (fleet-harmonized, #3657)
* ``model``, ``outputStyle``, ``effortLevel`` — top-level identity keys
* ``flags``           — disableBundledSkills / disableClaudeAiConnectors /
  disableRemoteControl / disableWorkflows booleans

Not published: ``hooks`` (local paths, machine-specific noise), ``modelSettings``
(v2 candidate), anything under project entries of ``~/.claude.json``, every
secret-bearing value. Absence of an allow-listed key is published as absence
(presence/absence IS drift signal: a seat missing ``ENABLE_TOOL_SEARCH`` has
drifted exactly like one with a wrong value).

``--dry-run`` (default) prints the payload, writes nothing; ``--write``
overwrites the one state file atomically (tmp + os.replace, same pattern as
session-view.py). No dashboard append: quiet per-machine channel, per #3833.
"""

from __future__ import annotations

import argparse
import datetime
import json
import os
import re
import socket
import sys
import tempfile

DEFAULT_SUBDIR = "config-view"
SCHEMA_VERSION = "1.0.0"

# --- the whitelist ---------------------------------------------------------
# Values are copied verbatim ONLY for these env keys (harmonization-canon
# adjacent surface, #3545: model ids, windows, flags, timeouts).
ENV_VALUE_WHITELIST = frozenset({
    "ANTHROPIC_DEFAULT_OPUS_MODEL",
    "ANTHROPIC_DEFAULT_SONNET_MODEL",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL",
    "ANTHROPIC_DEFAULT_FABLE_MODEL",
    "ANTHROPIC_CUSTOM_MODEL_OPTION",
    "ANTHROPIC_BASE_URL",  # observe-only (reportable, never canon) — #4347
    "CLAUDE_CODE_AUTO_COMPACT_WINDOW",
    "CLAUDE_CODE_MAX_CONTEXT_TOKENS",
    "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE",
    "CLAUDE_CODE_SUBAGENT_MODEL",
    "ENABLE_TOOL_SEARCH",
})
# Any env key ENDING with one of these is also copied (timeouts are plain
# numbers; harmonization canon allows env.*_TIMEOUT).
ENV_SUFFIX_WHITELIST = ("_TIMEOUT", "_TIMEOUT_MS")

# Belt and braces: after the whitelist, a key matching this pattern is still
# dropped. A future whitelist widening that admits e.g. ANTHROPIC_CUSTOM_HEADERS
# or *_API_KEY stays inert.
SECRET_DENY_PATTERN = re.compile(
    r"KEY|TOKEN|SECRET|PASSWORD|PASSWD|CREDENTIAL|HEADER|AUTH", re.IGNORECASE
)

# Top-level settings booleans published under ``flags``.
FLAG_KEYS = (
    "disableBundledSkills",
    "disableClaudeAiConnectors",
    "disableRemoteControl",
    "disableWorkflows",
)

# Top-level settings scalar identity keys published verbatim.
IDENTITY_KEYS = ("model", "outputStyle", "effortLevel")


def _env_key_allowed(key):
    if not isinstance(key, str) or not key:
        return False
    whitelisted = key in ENV_VALUE_WHITELIST or key.endswith(ENV_SUFFIX_WHITELIST)
    return whitelisted and not SECRET_DENY_PATTERN.search(key)


def collect_config(claude_json_path, settings_path):
    """Read the two local files and build the masked ``config`` payload.
    Missing files yield empty sections (an absence the fleet reader can see),
    never an error: a seat without ~/.claude.json still publishes its state."""
    config = {
        "mcpServers": [],
        "env": {},
        "permissions": {},
        "flags": {},
    }
    for key in IDENTITY_KEYS:
        config[key] = None

    try:
        with open(claude_json_path, "r", encoding="utf-8-sig") as handle:
            claude_json = json.load(handle)
        if isinstance(claude_json, dict):
            servers = claude_json.get("mcpServers")
            if isinstance(servers, dict):
                config["mcpServers"] = sorted(
                    str(name) for name in servers.keys()
                )
    except (OSError, ValueError):
        pass  # absent or unreadable: publish the absence

    try:
        with open(settings_path, "r", encoding="utf-8-sig") as handle:
            settings = json.load(handle)
    except (OSError, ValueError):
        settings = None
    if isinstance(settings, dict):
        env = settings.get("env")
        if isinstance(env, dict):
            for key, value in env.items():
                if _env_key_allowed(key) and isinstance(value, (str, int, float, bool)):
                    config["env"][key] = value
        permissions = settings.get("permissions")
        if isinstance(permissions, dict):
            mode = permissions.get("mode")
            if isinstance(mode, str):
                config["permissions"]["mode"] = mode
            deny = permissions.get("deny")
            if isinstance(deny, list):
                config["permissions"]["deny"] = sorted(
                    str(item) for item in deny if isinstance(item, (str, int))
                )
        for key in IDENTITY_KEYS:
            value = settings.get(key)
            if isinstance(value, str):
                config[key] = value
        for key in FLAG_KEYS:
            value = settings.get(key)
            if isinstance(value, bool):
                config["flags"][key] = value
    return config


def build_payload(machine, config, now_iso):
    return {
        "machine": machine,
        "generatedAt": now_iso,
        "schemaVersion": SCHEMA_VERSION,
        "config": config,
    }


def write_state_file(shared_path, subdir, machine, payload):
    """Atomically overwrite ``<shared_path>/<subdir>/<machine>.json``.
    Returns the written path."""
    target_dir = os.path.join(shared_path, subdir)
    os.makedirs(target_dir, exist_ok=True)
    target = os.path.join(target_dir, f"{machine}.json")
    fd, tmp_path = tempfile.mkstemp(dir=target_dir, prefix=".config-view-", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, indent=2, ensure_ascii=False)
            handle.write("\n")
        os.replace(tmp_path, target)  # atomic on the same volume
    except BaseException:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise
    return target


def build_parser():
    parser = argparse.ArgumentParser(
        prog="config-view.py",
        description=(
            "Publish a masked per-machine config snapshot (mcp server names, "
            "allow-listed settings env keys, permissions, identity keys, "
            "feature flags) to $ROOSYNC_SHARED_PATH/%s/<machine>.json. "
            "The whitelist is the mask: no secret-bearing value is ever "
            "copied, and a secret-deny pattern runs after the whitelist." % DEFAULT_SUBDIR
        ),
        epilog="Default mode without --dry-run/--write is dry-run: print only.",
    )
    parser.add_argument("--claude-json",
                        default=os.path.expanduser("~/.claude.json"),
                        help="Claude Code config (default: ~/.claude.json)")
    parser.add_argument("--settings",
                        default=os.path.expanduser("~/.claude/settings.json"),
                        help="Claude Code settings (default: ~/.claude/settings.json)")
    parser.add_argument("--dry-run", action="store_true",
                        help="print the payload, write nothing (default behaviour)")
    parser.add_argument("--write", action="store_true",
                        help="overwrite the per-machine state file under the shared path")
    parser.add_argument("--shared-path",
                        default=os.environ.get("ROOSYNC_SHARED_PATH"),
                        help="shared state root (default: $ROOSYNC_SHARED_PATH)")
    parser.add_argument("--subdir", default=DEFAULT_SUBDIR,
                        help="subfolder under the shared path (default: %(default)s)")
    return parser


def main(argv=None):
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.dry_run and args.write:
        parser.error("--dry-run and --write are mutually exclusive")
    if not args.dry_run and not args.write:
        args.dry_run = True  # default: print only

    if args.write and not args.shared_path:
        print("error: --write requires --shared-path or $ROOSYNC_SHARED_PATH", file=sys.stderr)
        return 1

    machine = os.environ.get("COMPUTERNAME",
                             socket.gethostname() or "unknown").lower()
    config = collect_config(args.claude_json, args.settings)
    now_iso = datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds")
    payload = build_payload(machine, config, now_iso)

    print(json.dumps(payload, indent=2, ensure_ascii=False))

    if args.write:
        target = write_state_file(args.shared_path, args.subdir, machine, payload)
        print(f"wrote {target}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
