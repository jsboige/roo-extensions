#!/usr/bin/env python3
"""session-view.py — read the Claude Code session registry and classify each session (#4694, step 1 of #3833).

Each running Claude Code session maintains ``~/.claude/sessions/<pid>.json`` with
(among others): ``pid``, ``procStart``, ``cwd``, ``kind``, ``entrypoint``,
``status``, ``startedAt``, ``updatedAt``, ``statusUpdatedAt``. Millisecond dates
are epoch milliseconds; ``procStart`` is the process creation time in the
platform's raw unit (win32: FILETIME 100-ns ticks since 1601-01-01, e.g.
``134389778078512215``). No reader of this registry existed before this script.

Classification (one of four statuses per session):

* ``actif``        — process alive and session reports ``status: busy``
* ``repos-recent`` — process alive, not busy, idle for at most ``--rest-seconds``
* ``repos-ancien`` — process alive, not busy, idle for longer than ``--rest-seconds``
* ``mort``         — process gone, OR the pid now exists with a DIFFERENT start
  time (a pid can be reused; only a matching ``procStart`` proves identity)

A defensive fifth status ``invalide`` covers session files that are not valid
JSON objects (the line still appears; it is never counted as a session state).

Output: one line per session file — machine, workspace (basename of ``cwd``),
status, age. ``--dry-run`` prints without writing (also the default when no
mode flag is given); ``--write`` additionally overwrites, atomically, one JSON
state file per machine under ``$ROOSYNC_SHARED_PATH/<subdir>/<machine>.json``.
No dashboard append: this is a quiet per-machine state file, per #3833.

Only ``*.json`` files directly inside the sessions directory are read — nothing
else in that directory is opened, listed or displayed.
"""

from __future__ import annotations

import argparse
import json
import ntpath
import os
import socket
import sys
import tempfile
import time

DEFAULT_REST_SECONDS = 3600
DEFAULT_SUBDIR = "session-view"

STATUS_ACTIF = "actif"
STATUS_REPOS_RECENT = "repos-recent"
STATUS_REPOS_ANCIEN = "repos-ancien"
STATUS_MORT = "mort"
STATUS_INVALIDE = "invalide"

_ALIVE_UNVERIFIED = "unverified"  # sentinel: process exists, start time unreadable


# ---------------------------------------------------------------------------
# Process liveness probe (win32). Tests replace ``probe_process`` wholesale.
# ---------------------------------------------------------------------------

def _probe_win32(pid):
    """Return FILETIME ticks (int) of the process creation, None if gone,
    or the sentinel ``"unverified"`` when the pid exists but its start time
    cannot be read (e.g. access denied to an elevated process)."""
    import ctypes
    from ctypes import wintypes

    PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
    ERROR_INVALID_PARAMETER = 87  # no such pid on this Windows version
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.GetProcessTimes.argtypes = [
        wintypes.HANDLE,
        ctypes.POINTER(wintypes.FILETIME),
        ctypes.POINTER(wintypes.FILETIME),
        ctypes.POINTER(wintypes.FILETIME),
        ctypes.POINTER(wintypes.FILETIME),
    ]
    handle = kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid)
    if not handle:
        return None if ctypes.get_last_error() == ERROR_INVALID_PARAMETER else _ALIVE_UNVERIFIED
    try:
        creation = wintypes.FILETIME()
        exit_time = wintypes.FILETIME()
        kernel = wintypes.FILETIME()
        user = wintypes.FILETIME()
        if not kernel32.GetProcessTimes(
            handle,
            ctypes.byref(creation),
            ctypes.byref(exit_time),
            ctypes.byref(kernel),
            ctypes.byref(user),
        ):
            return _ALIVE_UNVERIFIED
        return (creation.dwHighDateTime << 32) | creation.dwLowDateTime
    finally:
        kernel32.CloseHandle(handle)


def _probe_unsupported(pid):
    raise NotImplementedError(
        "process start probe is only implemented for win32; every fleet seat is win32"
    )


probe_process = _probe_win32 if os.name == "nt" else _probe_unsupported


# ---------------------------------------------------------------------------
# Registry reading and classification
# ---------------------------------------------------------------------------

def _machine_of(record):
    domain = record.get("pidDomain")
    if isinstance(domain, str) and ":" in domain:
        candidate = domain.split(":", 1)[1].strip()
        if candidate:
            return candidate.lower()
    return os.environ.get("COMPUTERNAME", socket.gethostname() or "unknown").lower()


def _workspace_of(record):
    cwd = record.get("cwd")
    if not isinstance(cwd, str) or not cwd:
        return "?"
    # ``cwd`` enregistre un chemin Windows (separateurs ``\``) : ``ntpath.basename``
    # sait le couper sur les deux separateurs quel que soit l'OS hote (CI Linux
    # comprise), la ou ``os.path.basename`` (posixpath sous Linux) laisserait la
    # chaine entiere.
    return ntpath.basename(cwd.rstrip("/\\")) or cwd


def _age_reference_ms(record):
    for key in ("statusUpdatedAt", "updatedAt", "startedAt"):
        value = record.get(key)
        if isinstance(value, (int, float)) and value > 0:
            return value
    return None


def classify(record, start, now_ms, rest_ms):
    """Map one parsed session record to (status, age_ms).

    ``start`` is the probe result for the record's pid: ``None`` (gone),
    ``"unverified"`` (alive, start unreadable) or int ticks (verified).
    """
    pid = record.get("pid")
    if not isinstance(pid, int):
        return STATUS_INVALIDE, None

    proc_start = record.get("procStart")
    recorded = None
    if isinstance(proc_start, str) and proc_start.strip().isdigit():
        recorded = int(proc_start.strip())
    elif isinstance(proc_start, int):
        recorded = proc_start

    if start is None:
        return STATUS_MORT, _age_ms(record, now_ms)
    if recorded is not None and isinstance(start, int):
        tolerance = classify.tolerance_ticks  # injected by main() (default 0 = exact)
        if abs(start - recorded) > tolerance:
            # pid reused by a different process: the recorded session is dead
            return STATUS_MORT, _age_ms(record, now_ms)
    # alive (verified match, or unverifiable start treated as alive)
    if record.get("status") == "busy":
        return STATUS_ACTIF, _age_ms(record, now_ms)
    reference = _age_reference_ms(record)
    if reference is None:
        return STATUS_REPOS_ANCIEN, None
    age = now_ms - reference
    if age <= rest_ms:
        return STATUS_REPOS_RECENT, age
    return STATUS_REPOS_ANCIEN, age


classify.tolerance_ticks = 0


def _age_ms(record, now_ms):
    reference = _age_reference_ms(record)
    return None if reference is None else now_ms - reference


def _format_age(age_ms):
    if age_ms is None:
        return "?"
    seconds = max(0, age_ms) / 1000.0
    if seconds < 60:
        return f"{seconds:.0f}s"
    if seconds < 3600:
        return f"{seconds / 60:.1f}m"
    if seconds < 86400:
        return f"{seconds / 3600:.1f}h"
    return f"{seconds / 86400:.1f}d"


def load_sessions(sessions_dir):
    """Return parsed records for every *.json file directly inside
    ``sessions_dir`` (no recursion, no other file type)."""
    records = []
    try:
        names = sorted(os.listdir(sessions_dir))
    except OSError as exc:
        raise SystemExit(f"cannot read sessions directory {sessions_dir!r}: {exc}")
    for name in names:
        if not name.endswith(".json"):
            continue
        path = os.path.join(sessions_dir, name)
        if not os.path.isfile(path):
            continue
        try:
            with open(path, "r", encoding="utf-8") as handle:
                data = json.load(handle)
        except (OSError, ValueError) as exc:
            records.append({"__file__": name, "__error__": str(exc), "pid": None})
            continue
        if not isinstance(data, dict):
            records.append({"__file__": name, "__error__": "not a JSON object", "pid": None})
            continue
        data["__file__"] = name
        records.append(data)
    return records


# ---------------------------------------------------------------------------
# State file writing (atomic, one file per machine)
# ---------------------------------------------------------------------------

def write_state_files(shared_path, subdir, machines, now_ms):
    """Atomically overwrite ``<shared_path>/<subdir>/<machine>.json`` for each
    machine. Returns the list of written paths."""
    import datetime

    target_dir = os.path.join(shared_path, subdir)
    os.makedirs(target_dir, exist_ok=True)
    written = []
    for machine, payload in machines.items():
        payload = dict(payload)
        payload["machine"] = machine
        payload["generatedAt"] = datetime.datetime.fromtimestamp(
            now_ms / 1000.0, tz=datetime.timezone.utc
        ).isoformat(timespec="seconds")
        target = os.path.join(target_dir, f"{machine}.json")
        fd, tmp_path = tempfile.mkstemp(dir=target_dir, prefix=".session-view-", suffix=".tmp")
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
        written.append(target)
    return written


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def build_parser():
    parser = argparse.ArgumentParser(
        prog="session-view.py",
        description=(
            "Read the Claude Code session registry (~/.claude/sessions/*.json), "
            "classify each session (actif / repos-recent / repos-ancien / mort) "
            "and optionally write one per-machine state file under "
            "$ROOSYNC_SHARED_PATH/%s/<machine>.json (atomic overwrite)." % DEFAULT_SUBDIR
        ),
        epilog=(
            "A session is mort when its pid no longer exists, or when the pid "
            "exists with a different process start time (pid reuse). "
            "Default mode without --dry-run/--write is dry-run: print only."
        ),
    )
    parser.add_argument("--sessions-dir", default=os.path.expanduser("~/.claude/sessions"),
                        help="session registry directory (default: ~/.claude/sessions)")
    parser.add_argument("--dry-run", action="store_true",
                        help="print one line per session, write nothing (default behaviour)")
    parser.add_argument("--write", action="store_true",
                        help="overwrite the per-machine state file under the shared path")
    parser.add_argument("--rest-seconds", type=int, default=DEFAULT_REST_SECONDS,
                        help="idle boundary between repos-recent and repos-ancien "
                             "(default: %(default)s s)")
    parser.add_argument("--start-tolerance-seconds", type=float, default=0.0,
                        help="tolerance when comparing recorded procStart with the live "
                             "process start (default: %(default)s s = exact match)")
    parser.add_argument("--shared-path",
                        default=os.environ.get("ROOSYNC_SHARED_PATH"),
                        help="shared state root (default: $ROOSYNC_SHARED_PATH)")
    parser.add_argument("--subdir", default=DEFAULT_SUBDIR,
                        help="subfolder under the shared path for state files "
                             "(default: %(default)s)")
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

    now_ms = int(time.time() * 1000)
    rest_ms = args.rest_seconds * 1000
    classify.tolerance_ticks = int(args.start_tolerance_seconds * 1e7)  # s -> 100-ns ticks

    records = load_sessions(args.sessions_dir)
    machines = {}
    lines = []
    for record in records:
        pid = record.get("pid")
        if "__error__" in record or not isinstance(pid, int):
            status, age_ms = STATUS_INVALIDE, None
            machine = _machine_of({}) if "__error__" in record else _machine_of(record)
            workspace, kind, entrypoint = "?", "?", "?"
            start = None
        else:
            start = probe_process(pid)
            status, age_ms = classify(record, start, now_ms, rest_ms)
            machine = _machine_of(record)
            workspace = _workspace_of(record)
            kind = str(record.get("kind", "?"))
            entrypoint = str(record.get("entrypoint", "?"))
        lines.append(
            f"{machine:<16} {workspace:<24} {status:<13} {_format_age(age_ms):>7}"
        )
        bucket = machines.setdefault(
            machine,
            {
                "restSeconds": args.rest_seconds,
                # deterministic shape: every canonical status present, 0 when unseen
                "counts": {
                    STATUS_ACTIF: 0,
                    STATUS_REPOS_RECENT: 0,
                    STATUS_REPOS_ANCIEN: 0,
                    STATUS_MORT: 0,
                },
                "sessions": [],
            },
        )
        bucket["counts"][status] = bucket["counts"].get(status, 0) + 1
        bucket["sessions"].append({
            "file": record.get("__file__"),
            "pid": pid,
            "workspace": workspace,
            "status": status,
            "ageMs": age_ms,
            "kind": kind,
            "entrypoint": entrypoint,
        })

    for line in lines:
        print(line)

    if args.write:
        written = write_state_files(args.shared_path, args.subdir, machines, now_ms)
        for path in written:
            print(f"wrote {path}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
