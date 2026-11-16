#!/usr/bin/env python3
"""config-view-fleet.py — aggregated fleet config view + consensus drift verdict
(#3833 step 4 / #603 cases 17-18).

Each seat publishes, on its own cadence (hourly by default, installer
``install-config-view-publisher-schtask.ps1``), ``<shared>/config-view/
<machine>.json`` (producer: config-view.py — whitelist-masked: mcp server
names, allow-listed settings env keys, permissions, identity keys, flags).
This reader prints ONE table, one line per expected machine:

    MACHINE          ETAT        FRAICHEUR  MCP  DERIVE

``ETAT`` follows the session-view-fleet vocabulary (``frais`` / ``en-retard`` /
``absent`` / ``illisible``). ``MCP`` is the published server count
(informational: server sets legitimately vary per seat). ``DERIVE`` lists the
keys on which the machine disagrees with the fleet consensus.

Consensus drift (case 18): among FRAIS machines only — a stale snapshot does
not vote — each judged key's fleet value is the value held by a strict
majority of fresh machines, requiring at least 2 holders. With fewer than 2
fresh machines there is no witness quorum and NO drift verdict is emitted
(the summary says so; exit reflects freshness only). A key on which NO value
reaches a strict majority (2 seats disagreeing, a 2-2 tie, any split fleet)
is reported as ``SANS MAJORITE`` with its value counts — never silently
skipped (review B1 on PR #4764: a split fleet must not be certified as a
healthy one). Judged keys:

* every published ``env`` key except the observe-only set (``ANTHROPIC_BASE_URL``
  is reported per machine but never drift-judged — #4347);
* ``permissions.deny`` (as a sorted set) and ``permissions.mode``;
* ``model``, ``outputStyle``, ``effortLevel``;
* each ``flags`` boolean.

A key absent on one machine and present on the others IS drift (absence is a
value). Roster and freshness threshold behave exactly like session-view-fleet.

Exit codes, fail-closed (same discipline):

* ``0`` — every expected machine is ``frais`` AND no drift was detected AND
  no key is split (without majority).
* ``1`` — at least one machine is ``en-retard``/``absent``/``illisible``, OR at
  least one drift was detected, OR at least one key is split without majority.
* ``2`` — the instrument itself cannot measure: no shared path, no state
  directory, or no usable roster.

``--json`` emits the same data machine-readable; ``--now`` freezes the clock
for tests. Case 19 (scheduled check) wires this exit code into an existing
cadence — the reader never posts to the dashboard itself (quiet channel).
The case-19 consumer distinguishes the three exit-1 causes via ``--json``:
``summary.driftingMachines`` > 0 → config drift (machines contradicting the
majority; names in ``machines[].driftKeys``), ``summary.splitKeys`` non-empty
→ fleet-wide disagreement with no majority and no machine to blame, and
``summary`` freshness fields (``enRetard``/``absent``/``illisible``) → seats
not publishing (not installed yet, or the publisher died).
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import sys

_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
_REPO_ROOT = os.path.abspath(os.path.join(_SCRIPT_DIR, "..", ".."))
DEFAULT_MANIFEST = os.path.join(_REPO_ROOT, ".claude", "configs", "fleet-manifest.json")

# Reuse session-view-fleet.py (roster + timestamp parsing) and, through it,
# session-view.py (age formatter). Dashes in filenames forbid plain imports;
# load by path, same pattern as the tests.
_FLEET_SPEC = importlib.util.spec_from_file_location(
    "session_view_fleet", os.path.join(_SCRIPT_DIR, "session-view-fleet.py")
)
session_view_fleet = importlib.util.module_from_spec(_FLEET_SPEC)
_FLEET_SPEC.loader.exec_module(session_view_fleet)

DEFAULT_SUBDIR = "config-view"
DEFAULT_MAX_AGE_MINUTES = 120.0  # hourly cadence: 2 missed ticks

STATE_FRAIS = session_view_fleet.STATE_FRAIS
STATE_EN_RETARD = session_view_fleet.STATE_EN_RETARD
STATE_ABSENT = session_view_fleet.STATE_ABSENT
STATE_ILLISIBLE = session_view_fleet.STATE_ILLISIBLE

# Published but never drift-judged (legitimate per-seat variance).
OBSERVE_ONLY_ENV_KEYS = frozenset({"ANTHROPIC_BASE_URL"})


# ---------------------------------------------------------------------------
# One machine's snapshot
# ---------------------------------------------------------------------------

def read_machine(state_dir, machine, now_s, max_age_s):
    """Classify one machine's snapshot. Never raises for a missing or broken
    file: those ARE the states the view exists to show."""
    path = os.path.join(state_dir, f"{machine}.json")
    row = {
        "machine": machine,
        "path": path,
        "state": STATE_ABSENT,
        "ageSeconds": None,
        "generatedAt": None,
        "config": None,
        "error": None,
    }
    try:
        with open(path, "r", encoding="utf-8") as handle:
            payload = json.load(handle)
    except FileNotFoundError:
        return row
    except (OSError, ValueError) as exc:
        row["state"] = STATE_ILLISIBLE
        row["error"] = str(exc)
        return row
    if not isinstance(payload, dict):
        row["state"] = STATE_ILLISIBLE
        row["error"] = "not a JSON object"
        return row

    stamp = session_view_fleet._parse_generated_at(payload.get("generatedAt"))
    if stamp is None:
        row["state"] = STATE_ILLISIBLE
        row["error"] = "missing or unparseable generatedAt"
        return row
    age_s = max(0.0, now_s - stamp)
    row["ageSeconds"] = age_s
    row["generatedAt"] = payload.get("generatedAt")
    row["state"] = STATE_FRAIS if age_s <= max_age_s else STATE_EN_RETARD

    config = payload.get("config")
    if isinstance(config, dict):
        row["config"] = config
    else:
        row["state"] = STATE_ILLISIBLE
        row["error"] = "missing config object"
    return row


# ---------------------------------------------------------------------------
# Consensus drift (case 18)
# ---------------------------------------------------------------------------

def _judged_values(config):
    """Flatten one snapshot's config into {judged key: hashable value}.
    Absence of a key the OTHER machines hold is produced by the flatten loop
    itself (get with default), so every snapshot votes on every key seen
    anywhere in the fleet."""
    values = {}
    env = config.get("env")
    if isinstance(env, dict):
        for key, value in env.items():
            if isinstance(key, str) and key not in OBSERVE_ONLY_ENV_KEYS:
                values[f"env:{key}"] = _hashable(value)
    permissions = config.get("permissions")
    if isinstance(permissions, dict):
        mode = permissions.get("mode")
        values["permissions:mode"] = _hashable(mode)
        deny = permissions.get("deny")
        values["permissions:deny"] = _hashable(tuple(sorted(deny)) if isinstance(deny, list) else deny)
    for key in ("model", "outputStyle", "effortLevel"):
        values[key] = _hashable(config.get(key))
    flags = config.get("flags")
    if isinstance(flags, dict):
        for key, value in flags.items():
            if isinstance(key, str):
                values[f"flag:{key}"] = _hashable(value)
    return values


def _hashable(value):
    if isinstance(value, list):
        return tuple(value)
    if isinstance(value, dict):
        return tuple(sorted((k, _hashable(v)) for k, v in value.items()))
    return value


ABSENT = "<<absent>>"


def _display_value(value):
    """One-line rendering of a judged value (for the split detail line and
    JSON, where tuple keys are not representable)."""
    if isinstance(value, tuple):
        return "[" + ", ".join(_display_value(v) for v in value) + "]"
    return str(value)


def detect_drift(rows):
    """Consensus drift among FRAIS machines. Returns (drift, split, quorum):

    * ``drift`` — {machine: [key, ...]}: machines contradicting a strict
      majority value;
    * ``split`` — {key: [(value, holders), ...] sorted most-held first}: keys
      on which NO value reaches a strict majority (a fleet in open
      disagreement). Reported, never silently skipped (review B1 on PR #4764);
    * ``quorum`` — True when at least 2 fresh machines voted (without quorum
      there is no verdict at all).
    """
    fresh = [row for row in rows if row["state"] == STATE_FRAIS and row["config"]]
    if len(fresh) < 2:
        return {}, {}, False

    # Union of judged keys across fresh snapshots.
    all_keys = set()
    per_machine = {}
    for row in fresh:
        values = _judged_values(row["config"])
        per_machine[row["machine"]] = values
        all_keys.update(values.keys())

    drift = {row["machine"]: [] for row in fresh}
    split = {}
    for key in sorted(all_keys):
        counts = {}
        for row in fresh:
            value = per_machine[row["machine"]].get(key, ABSENT)
            counts[value] = counts.get(value, 0) + 1
        fleet_value, holders = max(counts.items(), key=lambda item: item[1])
        if holders < 2 or holders <= len(fresh) / 2:
            # No strict majority: the fleet is in open disagreement on this
            # key. There is no majority to contradict, so no machine is
            # blamed — but the disagreement itself is the alert (B1).
            split[key] = sorted(counts.items(), key=lambda kv: (-kv[1], str(kv[0])))
            continue
        for row in fresh:
            value = per_machine[row["machine"]].get(key, ABSENT)
            if value != fleet_value:
                drift[row["machine"]].append(key)
    return {m: keys for m, keys in drift.items() if keys}, split, True


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

def _format_drift(keys, limit=3):
    if not keys:
        return "-"
    shown = keys[:limit]
    text = ", ".join(shown)
    if len(keys) > limit:
        text += f" +{len(keys) - limit}"
    return text


def render_table(rows, drift, split, quorum, max_age_minutes):
    header = (
        f"{'MACHINE':<16} {'ETAT':<10} {'FRAICHEUR':>9}  "
        f"{'MCP':>3}  DERIVE"
    )
    lines = [header, "-" * len(header)]
    for row in rows:
        age_ms = None if row["ageSeconds"] is None else row["ageSeconds"] * 1000.0
        freshness = session_view_fleet.session_view._format_age(age_ms)
        config = row["config"] or {}
        servers = config.get("mcpServers")
        mcp = str(len(servers)) if isinstance(servers, list) else "?"
        keys = drift.get(row["machine"], [])
        lines.append(
            f"{row['machine']:<16} {row['state']:<10} {freshness:>9}  "
            f"{mcp:>3}  {_format_drift(keys)}"
        )
    fresh = sum(1 for row in rows if row["state"] == STATE_FRAIS)
    late = sum(
        1 for row in rows if row["state"] in (STATE_EN_RETARD, STATE_ABSENT, STATE_ILLISIBLE)
    )
    lines.append(
        f"\n{len(rows)} machines: {fresh} frais, {late} en retard/absent/illisible "
        f"(seuil de fraicheur: {max_age_minutes:g} min)"
    )
    if quorum:
        drifting = len(drift)
        if split:
            # Never let a split fleet read as "0 en derive" (B1): lead with
            # the disagreement itself.
            lines.append(
                f"consensus ({fresh} temoins): {len(split)} cle(s) SANS majorite "
                f"(flotte en desaccord ouvert) ; {drifting} machine(s) en derive "
                f"sur les autres cles"
            )
            for key in sorted(split):
                detail = " / ".join(
                    f"{_display_value(value)} ({holders})"
                    for value, holders in split[key]
                )
                lines.append(f"  sans majorite: {key}: {detail}")
        else:
            total_keys = sum(len(keys) for keys in drift.values())
            lines.append(
                f"consensus ({fresh} temoins): {drifting} machine(s) en derive, "
                f"{total_keys} key(s) en desaccord"
            )
    else:
        lines.append(
            f"consensus: PAS de verdict ({fresh} temoin(s) frais — quorum 2 requis)"
        )
    return "\n".join(lines)


def build_json(rows, drift, split, quorum, max_age_minutes, now_iso):
    summary = {
        "machines": len(rows),
        "frais": sum(1 for row in rows if row["state"] == STATE_FRAIS),
        "enRetard": sum(1 for row in rows if row["state"] == STATE_EN_RETARD),
        "absent": sum(1 for row in rows if row["state"] == STATE_ABSENT),
        "illisible": sum(1 for row in rows if row["state"] == STATE_ILLISIBLE),
        "driftQuorum": quorum,
        "driftingMachines": len(drift),
        # Keys with NO strict majority: fleet-wide disagreement, no machine to
        # blame. The case-19 alert consumer reads this field (see docstring).
        "splitKeys": sorted(split.keys()),
    }
    machines = []
    for row in rows:
        entry = {key: value for key, value in row.items() if key != "path"}
        entry["driftKeys"] = drift.get(row["machine"], [])
        machines.append(entry)
    splits = {
        key: [
            {"value": _display_value(value), "machines": holders}
            for value, holders in split[key]
        ]
        for key in sorted(split)
    }
    return {
        "view": "config-view-fleet",
        "generatedAt": now_iso,
        "maxAgeMinutes": max_age_minutes,
        "summary": summary,
        "splits": splits,
        "machines": machines,
    }


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def build_parser():
    parser = argparse.ArgumentParser(
        prog="config-view-fleet.py",
        description=(
            "Aggregated fleet config view + consensus drift verdict over the "
            "per-seat snapshots (<shared>/%s/<machine>.json, producer "
            "config-view.py). One line per expected machine; drifting keys are "
            "listed; keys with no strict majority are reported SANS MAJORITE; "
            "exit 1 when any machine is late/absent/unreadable OR any drift is "
            "detected OR any key is split without majority." % DEFAULT_SUBDIR
        ),
    )
    parser.add_argument("--shared-path", default=os.environ.get("ROOSYNC_SHARED_PATH"),
                        help="shared state root (default: $ROOSYNC_SHARED_PATH)")
    parser.add_argument("--subdir", default=DEFAULT_SUBDIR,
                        help="subfolder under the shared path (default: %(default)s)")
    parser.add_argument("--manifest", default=DEFAULT_MANIFEST,
                        help="fleet manifest providing the roster "
                             "(default: .claude/configs/fleet-manifest.json)")
    parser.add_argument("--machines",
                        help="comma-separated roster overriding the manifest")
    parser.add_argument("--max-age-minutes", type=float, default=DEFAULT_MAX_AGE_MINUTES,
                        help="freshness threshold in minutes (default: %(default)s = "
                             "2 missed hourly publishing ticks)")
    parser.add_argument("--json", action="store_true", dest="json_output",
                        help="emit the view as JSON instead of the table")
    parser.add_argument("--now", help="freeze the clock (ISO 8601, tests only)")
    return parser


def main(argv=None):
    parser = build_parser()
    args = parser.parse_args(argv)

    if not args.shared_path:
        print("error: --shared-path or $ROOSYNC_SHARED_PATH is required", file=sys.stderr)
        return 2
    state_dir = os.path.join(args.shared_path, args.subdir)
    if not os.path.isdir(state_dir):
        print(f"error: state directory not found: {state_dir!r} "
              "(no seat is publishing yet?)", file=sys.stderr)
        return 2

    roster = session_view_fleet.load_roster(args.manifest, args.machines)
    now_s = session_view_fleet._parse_now(args.now) if args.now else session_view_fleet.datetime.datetime.now(
        session_view_fleet.datetime.timezone.utc
    ).timestamp()
    max_age_s = args.max_age_minutes * 60.0

    rows = [read_machine(state_dir, machine, now_s, max_age_s) for machine in roster]
    drift, split, quorum = detect_drift(rows)

    if args.json_output:
        now_iso = session_view_fleet.datetime.datetime.fromtimestamp(
            now_s, tz=session_view_fleet.datetime.timezone.utc
        ).isoformat(timespec="seconds")
        print(json.dumps(build_json(rows, drift, split, quorum, args.max_age_minutes, now_iso),
                         indent=2, ensure_ascii=False))
    else:
        print(render_table(rows, drift, split, quorum, args.max_age_minutes))

    all_fresh = all(row["state"] == STATE_FRAIS for row in rows)
    return 0 if (all_fresh and not drift and not split) else 1


if __name__ == "__main__":
    sys.exit(main())
