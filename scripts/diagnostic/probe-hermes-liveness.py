#!/usr/bin/env python3
"""
probe-hermes-liveness.py — Re-measure the "lying liveness" of Hermes cron jobs:
cross-check `last_status` (jobs.json, a last-writer field) against the per-fire
ledger (executions.db).

Issue #4247 (opened 18/10 by the po-2025 meta-analyst; diagnostic handed off by
po-2024 on 20/10, claim released). Action #3 of the issue — "re-mesurer la
proportion de faux ok apres correction" — had no instrument: the runtime lives on
the seat that hosts Hermes (`~/.hermes/cron/`, ai-01), so the measurement stayed a
one-shot hand diagnosis instead of a repeatable probe. This is that probe.

What the 20/10 diagnostic established (read at hermes-agent `16e747a8`):
- the scheduler does NOT swallow the exit code (`cron/scheduler_script.py:527-534`);
- `last_status` is a LAST-WRITER field with no link to the current fire, while
  `executions.db` carries state PER FIRE (`claimed`/`running`/`completed`/
  `failed`/`unknown`; `unknown` is written by the reaper). A probe that reads only
  `last_status` can therefore see `ok` — a stamp from an earlier run — while the
  current fire is wedged, and nothing in that field contradicts it.

Contradiction families this script discriminates (all measured against the job's
most recent ledger row):

    wedged        latest fire still claimed/running past --wedged-minutes
                  (the fire is stuck; the `ok` stamp predates it)
    reaped        latest fire `unknown` (the reaper took ownership away)
    failed        latest fire `failed` while the job says ok
    errored       latest fire carries a non-empty error while the job says ok
    ok-last-error job says ok but `last_error` is set (`cron/jobs.py:2402-2404`
                  renders this possible; no caller exercised it at `16e747a8`,
                  so a hit means the runtime moved)

Families (a)/(b) of the issue — "`no_agent` without proof" and "agent that
reported nothing" — are NOT visible in the ledger: they are silent-`ok` by design.
The anti-pendulum note from 20/10 stands: the silence is wanted for watchdog jobs,
so the fix is to make silence DISTINGUISHABLE from a run that reported, never to
turn silence into an error. This probe deliberately does not invent those families;
it measures the half the ledger can prove and reports how much of the population
stays unexplained.

Usage:
    python probe-hermes-liveness.py                       # defauts ~/.hermes/cron/
    python probe-hermes-liveness.py --jobs <jobs.json> --executions-db <executions.db>
    python probe-hermes-liveness.py --wedged-minutes 60   # seuil de blocage
    python probe-hermes-liveness.py --json                # machine-readable
    python probe-hermes-liveness.py --selftest            # fixture synthetique

Exit codes: 0 = no contradiction, 2 = findings, 1 = instrument error. Fail-closed:
a missing or unreadable input is never reported as "no contradiction".

Security: job payloads (prompts) and error TEXT are never printed — only ids,
names, statuses and an error LENGTH. The runtime belongs to the seat; the database
is opened in SQLite read-only mode, and the selftest asserts that a write fails.
"""

import argparse
import json
import os
import re
import sqlite3
import sys
import tempfile
import time
import urllib.parse
from datetime import datetime, timezone
from pathlib import Path

EXIT_CLEAN = 0
EXIT_ERROR = 1
EXIT_FINDINGS = 2

DEFAULT_WEDGED_MINUTES = 30

# Ledger rows that mean "this fire has not concluded".
IN_FLIGHT = ("claimed", "running")
REAPED = ("unknown",)

JOB_ID_KEYS = ("job_id", "jobid", "job", "jobId", "id")
STATUS_KEYS = ("status", "state")
ERROR_KEYS = ("error", "error_message", "err")
TIME_KEYS = ("finished_at", "updated_at", "heartbeat_at", "started_at", "created_at", "claimed_at")

FAMILIES = ("wedged", "reaped", "failed", "errored", "ok-last-error")


# --------------------------------------------------------------------------- io


def _connect_ro(db_path: str) -> sqlite3.Connection:
    """Open the ledger strictly read-only: the runtime is another seat's state."""
    resolved = Path(db_path).resolve()
    uri_path = resolved.as_posix()
    if not uri_path.startswith("/"):
        uri_path = "/" + uri_path  # Windows drive -> file:///D:/...
    uri = "file://" + urllib.parse.quote(uri_path, safe="/:")
    conn = sqlite3.connect(f"{uri}?mode=ro", uri=True)
    conn.execute("PRAGMA query_only = ON")
    return conn


def _first_key(columns, candidates):
    lowered = {c.lower(): c for c in columns}
    for cand in candidates:
        if cand.lower() in lowered:
            return lowered[cand.lower()]
    return None


def _extract_jobs(data):
    """Tolerate the shapes jobs.json has taken (list, {"jobs": [...]}, {"jobs": {id: {...}}})."""
    if isinstance(data, list):
        return [j for j in data if isinstance(j, dict)]
    if isinstance(data, dict):
        inner = data.get("jobs", data)
        if isinstance(inner, list):
            return [j for j in inner if isinstance(j, dict)]
        if isinstance(inner, dict):
            out = []
            for key, val in inner.items():
                if isinstance(val, dict):
                    job = dict(val)
                    job.setdefault("id", key)
                    out.append(job)
            return out
    return []


def _job_id(job):
    for key in JOB_ID_KEYS:
        val = job.get(key)
        if val not in (None, ""):
            return str(val)
    return None


def _job_label(job):
    """Name only — never the prompt payload, which is what jobs.json mostly holds."""
    for key in ("name", "title", "slug"):
        val = job.get(key)
        if isinstance(val, str) and val.strip():
            return val.strip()[:60]
    return ""


def _parse_epoch(value):
    """Accept epoch seconds, epoch milliseconds, or ISO-8601 (naive = UTC)."""
    if value is None:
        return None
    if isinstance(value, (int, float)):
        num = float(value)
        if num > 1e11:  # milliseconds
            num /= 1000.0
        return num
    text = str(value).strip()
    if not text:
        return None
    if re.fullmatch(r"\d+(\.\d+)?", text):
        return _parse_epoch(float(text))
    cleaned = text.replace("Z", "+00:00")
    try:
        stamp = datetime.fromisoformat(cleaned)
    except ValueError:
        return None
    if stamp.tzinfo is None:
        stamp = stamp.replace(tzinfo=timezone.utc)
    return stamp.timestamp()


def _row_timestamp(row, time_cols):
    stamps = [_parse_epoch(row.get(col)) for col in time_cols if col]
    stamps = [s for s in stamps if s is not None]
    return max(stamps) if stamps else None


def _status_of(row, status_col):
    return str(row.get(status_col) or "").strip().lower()


def _error_len_of(row, error_col):
    if not error_col:
        return 0
    val = row.get(error_col)
    if val is None:
        return 0
    return len(str(val).strip())


# ---------------------------------------------------------------------- probing


def probe(jobs_path, db_path, wedged_minutes=DEFAULT_WEDGED_MINUTES, now=None):
    """Return the cross-check report. Raises on any unreadable input (fail-closed)."""
    now = time.time() if now is None else now
    wedged_seconds = wedged_minutes * 60

    raw = json.loads(Path(jobs_path).read_text(encoding="utf-8"))
    jobs = _extract_jobs(raw)
    if not jobs:
        raise ValueError(f"no job dict found in {jobs_path}")

    ok_jobs = [j for j in jobs if str(j.get("last_status") or "").strip().lower() == "ok"]
    ids = {_job_id(j) for j in ok_jobs if _job_id(j)}

    rows_by_job = {}
    table_name = None
    if ids:
        conn = _connect_ro(db_path)
        try:
            tables = [
                r[0]
                for r in conn.execute(
                    "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
                )
            ]
            if not tables:
                raise ValueError(f"no table in {db_path}")
            # Prefer a table that actually carries a job id and a status.
            chosen = None
            for candidate in sorted(tables, key=lambda t: (t.lower() != "executions", t)):
                cols = [r[1] for r in conn.execute(f"PRAGMA table_info({candidate})")]
                if _first_key(cols, JOB_ID_KEYS) and _first_key(cols, STATUS_KEYS):
                    chosen = candidate
                    break
            if chosen is None:
                raise ValueError(f"no executions-like table in {db_path} (tables: {tables})")
            table_name = chosen
            cols = [r[1] for r in conn.execute(f"PRAGMA table_info({chosen})")]
            id_col = _first_key(cols, JOB_ID_KEYS)
            status_col = _first_key(cols, STATUS_KEYS)
            error_col = _first_key(cols, ERROR_KEYS)
            time_cols = [c for c in (_first_key(cols, (k,)) for k in TIME_KEYS) if c]

            cursor = conn.execute(f"SELECT * FROM {chosen}")
            names = [d[0] for d in cursor.description]
            for raw_row in cursor:
                row = dict(zip(names, raw_row))
                job_id = str(row.get(id_col) or "")
                if job_id not in ids:
                    continue
                rows_by_job.setdefault(job_id, []).append(
                    {
                        "status": _status_of(row, status_col),
                        "error_len": _error_len_of(row, error_col),
                        "ts": _row_timestamp(row, time_cols),
                    }
                )
        finally:
            conn.close()

    findings = []
    without_ledger = []
    for job in ok_jobs:
        job_id = _job_id(job)
        label = _job_label(job)
        last_error_len = 0
        for key in ("last_error", "lastError"):
            val = job.get(key)
            if val:
                last_error_len = len(str(val).strip())

        if last_error_len:
            findings.append(
                {
                    "job_id": job_id,
                    "name": label,
                    "family": "ok-last-error",
                    "detail": f"last_status=ok with last_error of {last_error_len} chars",
                }
            )

        rows = rows_by_job.get(job_id) if job_id else None
        if not rows:
            without_ledger.append({"job_id": job_id, "name": label})
            continue

        latest = max(rows, key=lambda r: ((r["ts"] or 0), r["status"]))
        status = latest["status"]
        age = (now - latest["ts"]) if latest["ts"] else None

        if status in IN_FLIGHT:
            if age is not None and age > wedged_seconds:
                findings.append(
                    {
                        "job_id": job_id,
                        "name": label,
                        "family": "wedged",
                        "detail": f"latest fire still {status} for {int(age // 60)}m (threshold {wedged_minutes}m)",
                    }
                )
            # else: a fire in flight right now — normal, says nothing about `ok`.
            continue
        if status in REAPED:
            findings.append(
                {
                    "job_id": job_id,
                    "name": label,
                    "family": "reaped",
                    "detail": "latest fire is 'unknown' (reaper took ownership) while job says ok",
                }
            )
        elif status == "failed":
            findings.append(
                {
                    "job_id": job_id,
                    "name": label,
                    "family": "failed",
                    "detail": "latest fire failed while job says ok",
                }
            )
        elif latest["error_len"]:
            findings.append(
                {
                    "job_id": job_id,
                    "name": label,
                    "family": "errored",
                    "detail": f"latest fire carries an error of {latest['error_len']} chars while job says ok",
                }
            )

    # A job can appear once per family; count job-level false-ok once.
    false_ok_ids = {f["job_id"] for f in findings if f["job_id"]}
    by_family = {fam: sum(1 for f in findings if f["family"] == fam) for fam in FAMILIES}
    checked = len(ok_jobs) - len(without_ledger)

    return {
        "jobs_file": str(jobs_path),
        "executions_db": str(db_path),
        "executions_table": table_name,
        "jobs_total": len(jobs),
        "ok_jobs": len(ok_jobs),
        "ok_jobs_with_ledger": checked,
        "ok_jobs_without_ledger": without_ledger,
        "findings": findings,
        "by_family": by_family,
        "false_ok_jobs": len(false_ok_ids),
        "false_ok_pct": round(100.0 * len(false_ok_ids) / checked, 1) if checked else 0.0,
        "explained_pct": round(100.0 * len(false_ok_ids) / len(ok_jobs), 1) if ok_jobs else 0.0,
        "wedged_minutes": wedged_minutes,
    }


# --------------------------------------------------------------------- selftest


def selftest() -> int:
    """Synthetic ledger: one job per contradiction family plus the clean controls."""
    tmp = Path(tempfile.mkdtemp(prefix="probe-hermes-selftest-"))
    now = time.time()
    db_path = tmp / "executions.db"
    jobs_path = tmp / "jobs.json"

    conn = sqlite3.connect(str(db_path))
    conn.execute(
        "CREATE TABLE executions ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT, job_id TEXT NOT NULL, status TEXT NOT NULL,"
        " error TEXT, started_at TEXT, finished_at TEXT)"
    )
    def iso(seconds_ago):
        return datetime.fromtimestamp(now - seconds_ago, tz=timezone.utc).isoformat()

    rows = [
        # wedged: still 'running' 2h after it started
        ("job-wedged", "running", None, iso(7200), None),
        # reaped
        ("job-reaped", "unknown", None, iso(3600), None),
        # failed
        ("job-failed", "failed", "boom", iso(600), iso(590)),
        # errored but status completed
        ("job-errored", "completed", "partial failure", iso(600), iso(500)),
        # clean, and an older failed fire that must NOT be blamed (only the latest counts)
        ("job-clean", "failed", "old boom", iso(9000), iso(8900)),
        ("job-clean", "completed", None, iso(600), iso(590)),
        # in flight RIGHT NOW: not a finding
        ("job-inflight", "running", None, iso(30), None),
        # 'ok-last-error' job: ledger is clean, the job field is not
        ("job-last-error", "completed", None, iso(600), iso(590)),
    ]
    conn.executemany(
        "INSERT INTO executions (job_id, status, error, started_at, finished_at) VALUES (?,?,?,?,?)",
        rows,
    )
    conn.commit()
    conn.close()

    def job(job_id, status="ok", error=None):
        entry = {"id": job_id, "name": f"name-{job_id}", "last_status": status}
        if error:
            entry["last_error"] = error
        return entry

    jobs_path.write_text(
        json.dumps(
            {
                "jobs": [
                    job("job-wedged"),
                    job("job-reaped"),
                    job("job-failed"),
                    job("job-errored"),
                    job("job-clean"),
                    job("job-inflight"),
                    job("job-last-error", error="stale error text"),
                    job("job-noledger"),
                    job("job-ok-real", status="error"),  # not part of the ok population
                ]
            }
        ),
        encoding="utf-8",
    )

    report = probe(jobs_path, db_path, wedged_minutes=30, now=now)

    assert report["jobs_total"] == 9, report["jobs_total"]
    assert report["ok_jobs"] == 8, report["ok_jobs"]
    families = report["by_family"]
    assert families == {
        "wedged": 1,
        "reaped": 1,
        "failed": 1,
        "errored": 1,
        "ok-last-error": 1,
    }, families
    assert report["false_ok_jobs"] == 5, report["false_ok_jobs"]
    assert report["ok_jobs_with_ledger"] == 7, report["ok_jobs_with_ledger"]
    assert [w["job_id"] for w in report["ok_jobs_without_ledger"]] == ["job-noledger"]
    # job-clean's older failed fire must not be blamed, and an in-flight fire is normal
    blamed = {f["job_id"] for f in report["findings"]}
    assert "job-clean" not in blamed, blamed
    assert "job-inflight" not in blamed, blamed

    # Control: the ledger must be opened read-only (a write attempt has to fail).
    ro = _connect_ro(str(db_path))
    try:
        try:
            ro.execute("INSERT INTO executions (job_id, status) VALUES ('x','failed')")
        except sqlite3.OperationalError:
            pass
        else:
            raise AssertionError("ledger accepted a write: read-only guard is not effective")
    finally:
        ro.close()

    # Control: error TEXT is never echoed, only its length.
    assert "boom" not in json.dumps(report), "error text leaked into the report"
    assert "partial failure" not in json.dumps(report), "error text leaked into the report"

    # Cleanup: named files only, never a wild rmtree.
    jobs_path.unlink()
    db_path.unlink()
    try:
        tmp.rmdir()
    except OSError:
        pass

    print("[SELFTEST] PASS (5 families discriminated, in-flight normal, older fires ignored, "
          "read-only enforced, error text withheld)")
    return EXIT_CLEAN


# ------------------------------------------------------------------------- main


def main() -> int:
    defaults = Path(os.path.expanduser("~/.hermes/cron"))
    parser = argparse.ArgumentParser(
        description="Cross-check Hermes last_status against the per-fire ledger (#4247)"
    )
    parser.add_argument("--jobs", default=str(defaults / "jobs.json"), help="chemin jobs.json (defaut ~/.hermes/cron/jobs.json)")
    parser.add_argument("--executions-db", default=str(defaults / "executions.db"), help="chemin executions.db (defaut ~/.hermes/cron/executions.db)")
    parser.add_argument("--wedged-minutes", type=int, default=DEFAULT_WEDGED_MINUTES, help="age au-dela duquel un fire claimed/running est bloque (defaut 30)")
    parser.add_argument("--json", action="store_true", help="sortie machine-readable")
    parser.add_argument("--selftest", action="store_true", help="validation sur fixture synthetique")
    args = parser.parse_args()

    if args.selftest:
        return selftest()

    try:
        report = probe(args.jobs, args.executions_db, args.wedged_minutes)
    except Exception as exc:  # noqa: BLE001 - instrument fail-closed
        print(f"[ERROR] {exc}")
        return EXIT_ERROR

    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print(f"jobs: {report['jobs_file']} ({report['jobs_total']} jobs, {report['ok_jobs']} en ok)")
        print(f"ledger: {report['executions_db']} (table {report['executions_table']})")
        for finding in report["findings"]:
            name = f" ({finding['name']})" if finding["name"] else ""
            print(f"[{finding['family'].upper()}] job {finding['job_id']}{name}: {finding['detail']}")
        for gap in report["ok_jobs_without_ledger"]:
            print(f"[NO-LEDGER] job {gap['job_id']} dit ok mais n'a aucune execution (non comptabilise)")
        if report["false_ok_jobs"]:
            print(
                f"[SUMMARY] {report['false_ok_jobs']}/{report['ok_jobs_with_ledger']} jobs ok contredits "
                f"par le ledger ({report['false_ok_pct']}% des jobs ok verifiables, "
                f"{report['explained_pct']}% de la population ok)"
            )
            print(
                "[NOTE] familles (a) no_agent-sans-preuve et (b) agent-muet ne sont pas mesurables "
                "par le ledger: silence voulu, a rendre DISTINGUABLE, pas une erreur."
            )

    if report["findings"]:
        print(f"[FINDINGS] {len(report['findings'])} contradiction(s) last_status/ledger")
        return EXIT_FINDINGS
    print("[CLEAN] aucune contradiction entre last_status et le ledger")
    return EXIT_CLEAN


if __name__ == "__main__":
    sys.exit(main())
