#!/usr/bin/env python3
"""session-view-fleet.py — aggregated freshness view over the per-seat session
state files (#3833, step 3; producer: session-view.py, step 1 of #4694).

Each seat publishes, every 5 minutes, ``<shared>/<subdir>/<machine>.json``
(``session-view/`` by default) with its machine x workspace x status table and
a ``generatedAt`` stamp. This reader prints ONE table, one line per expected
machine, with its freshness and a late marker:

    MACHINE          ETAT        FRAICHEUR  SESSIONS      WORKSPACES

``ETAT`` is one of:

* ``frais``     — state file younger than ``--max-age-minutes`` (default 15 =
  3 missed 5-minute ticks: one slow or failed tick is not "late").
* ``en-retard`` — file older than the threshold: the publisher is not running.
* ``absent``    — no state file at all.
* ``illisible`` — file present but unreadable, not JSON, without a
  parseable ``generatedAt``, or with counts that fail to parse (a bad
  count value marks only ITS machine unreadable — the rest of the
  table still prints).

Roster: the fleet manifest (``.claude/configs/fleet-manifest.json``, which
CLAUDE.md declares authoritative) unless ``--machines`` overrides it. A
machine in the roster with no file is ``absent`` — the view shows the hole
instead of hiding it.

Exit codes, fail-closed (same discipline as the degraded-escalation organ:
an instrument that cannot measure never reports "all green"):

* ``0`` — every expected machine is ``frais``.
* ``1`` — at least one machine is ``en-retard``, ``absent`` or ``illisible``.
* ``2`` — the instrument itself cannot measure: no shared path, unreadable
  directory, or no usable roster.

``--json`` emits the same data machine-readable; ``--now`` (ISO 8601) freezes
the clock for tests.
"""

from __future__ import annotations

import argparse
import datetime
import importlib.util
import json
import os
import sys

_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
_REPO_ROOT = os.path.abspath(os.path.join(_SCRIPT_DIR, "..", ".."))
DEFAULT_MANIFEST = os.path.join(_REPO_ROOT, ".claude", "configs", "fleet-manifest.json")

# Reuse the producer's constants and age formatter: one source of truth for
# the subfolder name and the human-readable age. The dash in session-view.py
# forbids a plain import, so load it by path (same pattern as its tests).
_PRODUCER_SPEC = importlib.util.spec_from_file_location(
    "session_view", os.path.join(_SCRIPT_DIR, "session-view.py")
)
session_view = importlib.util.module_from_spec(_PRODUCER_SPEC)
_PRODUCER_SPEC.loader.exec_module(session_view)

DEFAULT_SUBDIR = session_view.DEFAULT_SUBDIR
DEFAULT_MAX_AGE_MINUTES = 15.0

STATE_FRAIS = "frais"
STATE_EN_RETARD = "en-retard"
STATE_ABSENT = "absent"
STATE_ILLISIBLE = "illisible"

_STATUS_KEYS = (
    session_view.STATUS_ACTIF,
    session_view.STATUS_REPOS_RECENT,
    session_view.STATUS_REPOS_ANCIEN,
    session_view.STATUS_MORT,
)


# ---------------------------------------------------------------------------
# Roster
# ---------------------------------------------------------------------------

def load_roster(manifest_path, machines_arg):
    """Return the ordered, deduplicated roster of expected machine ids.

    ``--machines`` (comma-separated) wins; otherwise the manifest's
    ``machines`` object provides the order. Raises SystemExit(2) when
    neither source yields a roster: a view of zero machines is not a
    measurement.
    """
    if machines_arg:
        roster = [m.strip().lower() for m in machines_arg.split(",") if m.strip()]
    else:
        try:
            with open(manifest_path, "r", encoding="utf-8-sig") as handle:
                manifest = json.load(handle)
        except (OSError, ValueError) as exc:
            print(
                f"error: cannot read fleet manifest {manifest_path!r}: {exc} "
                "(pass --machines or --manifest)",
                file=sys.stderr,
            )
            raise SystemExit(2)
        machines = manifest.get("machines")
        if isinstance(machines, dict):
            roster = [str(name).lower() for name in machines.keys()]
        elif isinstance(machines, list):
            roster = [
                str(item.get("id") or item.get("machine") or "").lower()
                for item in machines
                if isinstance(item, dict)
            ]
        else:
            roster = []
        roster = [name for name in roster if name]
    seen = set()
    ordered = []
    for name in roster:
        if name not in seen:
            seen.add(name)
            ordered.append(name)
    if not ordered:
        print("error: empty roster (manifest has no machines and no --machines)",
              file=sys.stderr)
        raise SystemExit(2)
    return ordered


# ---------------------------------------------------------------------------
# One machine's state file
# ---------------------------------------------------------------------------

def _parse_generated_at(value):
    """Parse the producer's ``generatedAt`` (UTC ISO 8601). Naive timestamps
    are treated as UTC. Returns epoch seconds, or None when unparseable."""
    if not isinstance(value, str) or not value.strip():
        return None
    text = value.strip()
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        stamp = datetime.datetime.fromisoformat(text)
    except ValueError:
        return None
    if stamp.tzinfo is None:
        stamp = stamp.replace(tzinfo=datetime.timezone.utc)
    return stamp.timestamp()


def read_machine(state_dir, machine, now_s, max_age_s):
    """Classify one machine's state file. Never raises for a missing or
    broken file: those ARE the states the view exists to show."""
    path = os.path.join(state_dir, f"{machine}.json")
    row = {
        "machine": machine,
        "path": path,
        "state": STATE_ABSENT,
        "ageSeconds": None,
        "generatedAt": None,
        "counts": None,
        "workspaces": [],
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

    stamp = _parse_generated_at(payload.get("generatedAt"))
    if stamp is None:
        row["state"] = STATE_ILLISIBLE
        row["error"] = "missing or unparseable generatedAt"
        return row
    age_s = max(0.0, now_s - stamp)
    row["ageSeconds"] = age_s
    row["generatedAt"] = payload.get("generatedAt")
    row["state"] = STATE_FRAIS if age_s <= max_age_s else STATE_EN_RETARD

    counts = payload.get("counts")
    if isinstance(counts, dict):
        try:
            row["counts"] = {
                key: int(counts.get(key, 0) or 0) for key in _STATUS_KEYS
            }
        except (TypeError, ValueError) as exc:
            # A non-numeric count value (e.g. "n/a") must mark only THIS
            # machine unreadable. Before this guard the ValueError escaped
            # the per-machine loop and killed the whole table (#3833).
            row["state"] = STATE_ILLISIBLE
            row["error"] = str(exc)
            return row
    sessions = payload.get("sessions")
    if isinstance(sessions, list):
        workspaces = []
        for entry in sessions:
            if isinstance(entry, dict):
                name = entry.get("workspace")
                if isinstance(name, str) and name and name not in workspaces:
                    workspaces.append(name)
        row["workspaces"] = sorted(workspaces)
    return row


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

def _format_sessions(counts):
    if not counts:
        return "?"
    return "/".join(str(counts[key]) for key in _STATUS_KEYS)


def _format_workspaces(workspaces, limit=3):
    if not workspaces:
        return "-"
    shown = workspaces[:limit]
    text = ", ".join(shown)
    if len(workspaces) > limit:
        text += f" +{len(workspaces) - limit}"
    return text


def render_table(rows, max_age_minutes):
    header = (
        f"{'MACHINE':<16} {'ETAT':<10} {'FRAICHEUR':>9}  "
        f"{'SESSIONS a/rr/ra/m':<18} WORKSPACES"
    )
    lines = [header, "-" * len(header)]
    for row in rows:
        age_ms = None if row["ageSeconds"] is None else row["ageSeconds"] * 1000.0
        freshness = session_view._format_age(age_ms)
        lines.append(
            f"{row['machine']:<16} {row['state']:<10} {freshness:>9}  "
            f"{_format_sessions(row['counts']):<18} {_format_workspaces(row['workspaces'])}"
        )
    late = sum(
        1 for row in rows if row["state"] in (STATE_EN_RETARD, STATE_ABSENT, STATE_ILLISIBLE)
    )
    fresh = sum(1 for row in rows if row["state"] == STATE_FRAIS)
    lines.append(
        f"\n{len(rows)} machines: {fresh} frais, {late} en retard/absent/illisible "
        f"(seuil de fraicheur: {max_age_minutes:g} min)"
    )
    return "\n".join(lines)


def build_json(rows, max_age_minutes, now_iso):
    summary = {
        "machines": len(rows),
        "frais": sum(1 for row in rows if row["state"] == STATE_FRAIS),
        "enRetard": sum(1 for row in rows if row["state"] == STATE_EN_RETARD),
        "absent": sum(1 for row in rows if row["state"] == STATE_ABSENT),
        "illisible": sum(1 for row in rows if row["state"] == STATE_ILLISIBLE),
    }
    return {
        "view": "session-view-fleet",
        "generatedAt": now_iso,
        "maxAgeMinutes": max_age_minutes,
        "summary": summary,
        "machines": [
            {key: value for key, value in row.items() if key != "path"} for row in rows
        ],
    }


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def _parse_now(text):
    stamp = _parse_generated_at(text)
    if stamp is None:
        raise SystemExit(f"error: --now is not an ISO 8601 timestamp: {text!r}")
    return stamp


def build_parser():
    parser = argparse.ArgumentParser(
        prog="session-view-fleet.py",
        description=(
            "Aggregated freshness view over the per-seat session state files "
            "(<shared>/%s/<machine>.json, written every 5 min by session-view.py "
            "--write). One line per expected machine; late machines are marked; "
            "exit 1 when any machine is late, absent or unreadable." % DEFAULT_SUBDIR
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
                             "3 missed 5-minute publishing ticks)")
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

    roster = load_roster(args.manifest, args.machines)
    now_s = _parse_now(args.now) if args.now else datetime.datetime.now(
        datetime.timezone.utc
    ).timestamp()
    max_age_s = args.max_age_minutes * 60.0

    rows = [read_machine(state_dir, machine, now_s, max_age_s) for machine in roster]

    if args.json_output:
        now_iso = datetime.datetime.fromtimestamp(
            now_s, tz=datetime.timezone.utc
        ).isoformat(timespec="seconds")
        print(json.dumps(build_json(rows, args.max_age_minutes, now_iso),
                         indent=2, ensure_ascii=False))
    else:
        print(render_table(rows, args.max_age_minutes))

    return 0 if all(row["state"] == STATE_FRAIS for row in rows) else 1


if __name__ == "__main__":
    sys.exit(main())