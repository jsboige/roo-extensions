#!/usr/bin/env python3
"""g6-pass-bound.py — #4352 g6: judge an indexing pass against the pacer, not a flat clock.

Why this exists
---------------
The original g6 criterion was "a pass must not exceed 10 minutes, 5/5". Measured on
po-2028 (2026-10-28): a pass took 655 s while indexing ~1 750 sub-chunks. That is not a
stall — it is the paceur doing its job: `EMBEDDING_OPS_PER_MINUTE` defaults to 10, i.e.
one embedding request every 6 s, and 655 s / 6 s ≈ 109 requests. A flat ceiling measures
the throttle, not the health of the worker.

The bound is therefore derived, not asserted:

    allowed_ms = Δcalled × (60 000 / EMBEDDING_OPS_PER_MINUTE) × marge

`Δcalled` is the delta of the `called=` counter in `[EMB-METRICS]` across a window that
contains the whole pass, and `marge` (default 1.5) covers per-request HTTP latency and
dedup resumes. A pass inside that bound is healthy by construction.

Liveness is judged separately, because a bounded pass could still starve the tick:
`[EMB-METRICS]` is emitted on EVERY interval, including empty/blocked cycles, so a pass
that lasts N intervals must still show ~N of those lines. More than `--max-missing`
absent intervals is a violation, not a rounding error.

What this does NOT claim
------------------------
- It does not judge *content*: a pass that indexes the wrong chunks can be within bound.
- Overlapping callbacks are summed, not separated: the pacer window is per process, so
  when a pass outlives the 300 s interval the next callback's requests come out of the
  same ceiling. `Δcalled` is then the ceiling for the wall clock as a whole — which is
  exactly the quantity the bound is about. This tool judges "was the worker held back
  only by its own throttle", never "was this single task slow".
- A counter reset (process restart) inside the window is an INSTRUMENT failure, never a
  pass: the delta would be meaningless. Fail-closed, like the rest of the corpus.

Input
-----
A text log holding the RSM stdout lines, each carrying a timestamp prefix
(`2026-10-29T07:44:47.328Z`, `[2026-10-29 07:44:47]`, `2026-10-29 07:44:47,123`).
Lines without a timestamp are counted (`untimed=` in the report) and, when one of them is
needed to close a window, that pass is INSTRUMENT — the tool does not guess a clock.

  [EMB-METRICS] called=... cached=... ... rate_limited=... cache_size=...
  ⏱️ [Qdrant-Worker] pass done: 5 task(s) in 655123ms

Usage
-----
  python scripts/diagnostic/g6-pass-bound.py --log <fichier.log>
  python scripts/diagnostic/g6-pass-bound.py --log <f> --json
  python scripts/diagnostic/g6-pass-bound.py --selftest

Exit codes
----------
  0  every pass within the pacer bound and cadence preserved
  1  at least one violation (over bound, or tick starved)
  2  instrument failure (unreadable log, unclosed window, counter reset)
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone

DEFAULT_OPS_PER_MINUTE = 10.0   # background-services.ts: parseInt(process.env.EMBEDDING_OPS_PER_MINUTE || '10')
DEFAULT_INTERVAL_S = 300.0      # ANTI_LEAK_CONFIG.MAX_BACKGROUND_INTERVAL
DEFAULT_MARGIN = 1.5
DEFAULT_MAX_MISSING = 2

# 2026-10-29T07:44:47.328Z | [2026-10-29 07:44:47] | 2026-10-29 07:44:47,123 | [07:44:47]
TS_FULL = re.compile(
    r"(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2}:\d{2})(?:[.,](\d{1,6}))?(Z|[+-]\d{2}:?\d{2})?"
)
TS_TIME_ONLY = re.compile(r"\[?(\d{2}:\d{2}:\d{2})(?:[.,](\d{1,6}))?\]?")
METRICS = re.compile(r"\[EMB-METRICS\](.*)$")
CALLED = re.compile(r"\bcalled=(\d+)")
PASS_DONE = re.compile(r"pass done:\s*(\d+)\s*task\(s\)\s*in\s*(\d+)\s*ms")


@dataclass
class Metrics:
    time: float
    called: int
    raw: str


@dataclass
class Pass:
    time: float          # pass end (the line is printed after the batch)
    tasks: int
    duration_ms: int


@dataclass
class Verdict:
    index: int
    tasks: int
    duration_ms: int
    status: str          # PASS | VIOLATION | INSTRUMENT
    ops: int | None = None
    allowed_ms: float | None = None
    intervals_expected: int = 0
    intervals_seen: int = 0
    reasons: list[str] = field(default_factory=list)


def parse_time(text: str, base_date: str | None) -> float | None:
    """Epoch seconds, or None when the line carries no usable timestamp."""
    m = TS_FULL.search(text)
    if m:
        date_part, clock, frac, tz = m.groups()
        micro = int((frac or "0").ljust(6, "0"))
        if tz in (None, "Z"):
            offset = timezone.utc
        else:
            sign = 1 if tz[0] == "+" else -1
            digits = tz[1:].replace(":", "")
            offset = timezone(sign * timedelta(hours=int(digits[:2]), minutes=int(digits[2:4])))
        dt = datetime.strptime(f"{date_part} {clock}", "%Y-%m-%d %H:%M:%S").replace(
            microsecond=micro, tzinfo=offset)
        return dt.timestamp()
    m = TS_TIME_ONLY.search(text)
    if m and base_date:
        clock, frac = m.groups()
        micro = int((frac or "0").ljust(6, "0"))
        dt = datetime.strptime(f"{base_date} {clock}", "%Y-%m-%d %H:%M:%S").replace(
            microsecond=micro, tzinfo=timezone.utc)
        return dt.timestamp()
    return None


def scan(path: str) -> tuple[list[Metrics], list[Pass], int]:
    """Return (metrics, passes, untimed_line_count) preserving file order."""
    metrics: list[Metrics] = []
    passes: list[Pass] = []
    untimed = 0
    base_date: str | None = None
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            m = TS_FULL.search(line)
            if m:
                base_date = m.group(1)
            stamp = parse_time(line, base_date)
            body = METRICS.search(line)
            if body:
                called = CALLED.search(body.group(1))
                if called:
                    if stamp is None:
                        untimed += 1
                    else:
                        metrics.append(Metrics(stamp, int(called.group(1)), line.strip()))
                    continue
            done = PASS_DONE.search(line)
            if done:
                if stamp is None:
                    untimed += 1
                else:
                    passes.append(Pass(stamp, int(done.group(1)), int(done.group(2))))
    return metrics, passes, untimed


def judge(passes: list[Pass], metrics: list[Metrics], ops_per_minute: float, margin: float,
          interval_s: float, max_missing: int) -> list[Verdict]:
    verdicts: list[Verdict] = []
    for idx, p in enumerate(passes):
        v = Verdict(index=idx, tasks=p.tasks, duration_ms=p.duration_ms, status="PASS")
        start = p.time - p.duration_ms / 1000.0

        prev = None
        for m in metrics:
            if m.time <= start:
                prev = m
            else:
                break
        nxt = next((m for m in metrics if m.time >= p.time), None)

        # Cadence: [EMB-METRICS] must keep landing inside the pass.
        window = [m for m in metrics if start <= m.time <= p.time]
        v.intervals_seen = len(window)
        v.intervals_expected = int(p.duration_ms // (interval_s * 1000))
        if v.intervals_seen < v.intervals_expected - max_missing:
            v.status = "VIOLATION"
            v.reasons.append(
                f"tick starved: {v.intervals_seen} EMB-METRICS inside the pass, "
                f"{v.intervals_expected} expected (±{max_missing})")

        if prev is None or nxt is None:
            v.status = "INSTRUMENT"
            v.reasons.append("window not closed: no EMB-METRICS before the pass start "
                             "or after the pass end in this log")
            verdicts.append(v)
            continue

        for a, b in zip([prev, *window], [*window, nxt]):
            if b.called < a.called:
                v.status = "INSTRUMENT"
                v.reasons.append("counter reset inside the window (process restart) — "
                                 "the delta cannot be attributed to this pass")
                break
        if v.status == "INSTRUMENT":
            verdicts.append(v)
            continue

        ops = nxt.called - prev.called
        v.ops = ops
        v.allowed_ms = ops * (60_000.0 / ops_per_minute) * margin if ops_per_minute > 0 else float("inf")
        if p.duration_ms > v.allowed_ms:
            v.status = "VIOLATION"
            v.reasons.append(
                f"over pacer bound: {p.duration_ms} ms > {v.allowed_ms:.0f} ms "
                f"({ops} ops × {60_000.0 / ops_per_minute:.0f} ms × {margin})")
        verdicts.append(v)
    return verdicts


def report(verdicts: list[Verdict], ops_per_minute: float, margin: float, interval_s: float,
           untimed: int, as_json: bool) -> int:
    for v in verdicts:
        print(f"pass #{v.index + 1}: {v.tasks} task(s) in {v.duration_ms} ms -> {v.status}"
              f"  (ops={v.ops} allowed={('%.0f' % v.allowed_ms) if v.allowed_ms is not None else 'n/a'} ms, "
              f"ticks {v.intervals_seen}/{v.intervals_expected})")
        for reason in v.reasons:
            print(f"   ! {reason}")
    statuses = [v.status for v in verdicts]
    overall = ("INSTRUMENT" if "INSTRUMENT" in statuses
               else "VIOLATION" if "VIOLATION" in statuses
               else "PASS")
    if as_json:
        print(json.dumps({
            "verdict": overall,
            "passes": len(verdicts),
            "untimed_lines": untimed,
            "ops_per_minute": ops_per_minute,
            "margin": margin,
            "interval_seconds": interval_s,
            "results": [v.__dict__ for v in verdicts],
        }, indent=2))
    else:
        print(f"verdict={overall} passes={len(verdicts)} untimed_lines={untimed} "
              f"ops_per_minute={ops_per_minute:g} margin={margin:g} interval={interval_s:g}s")
    if overall == "INSTRUMENT":
        return 2
    return 1 if overall == "VIOLATION" else 0


# --- selftest ---------------------------------------------------------------

def _log(passes: list[tuple[float, int, int]], metrics: list[tuple[float, int]],
         timed: bool = True) -> str:
    """Compose a synthetic log; `t0` epoch 2026-10-29T00:00:00Z."""
    import tempfile

    def stamp(t: float) -> str:
        return datetime.fromtimestamp(t, timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"

    rows: list[tuple[float, str, str]] = []
    for t, called in metrics:
        rows.append((t, "M", f"[EMB-METRICS] called={called} rate_limited=0 cache_size=0"))
    for t, tasks, dur in passes:
        rows.append((t, "P", f"⏱️ [Qdrant-Worker] pass done: {tasks} task(s) in {dur}ms"))
    rows.sort(key=lambda r: r[0])
    body = "\n".join(f"{stamp(t)} {line}" if timed else line for t, _, line in rows)
    path = tempfile.mkstemp(prefix="g6-selftest-", suffix=".log")[1]
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(body + "\n")
    return path


def selftest() -> int:
    t0 = 1_764_720_000.0  # 2026-10-29T00:00:00Z
    failures: list[str] = []

    def run(name: str, path: str, expect: str) -> None:
        metrics, passes, untimed = scan(path)
        verdicts = judge(passes, metrics, DEFAULT_OPS_PER_MINUTE, DEFAULT_MARGIN,
                         DEFAULT_INTERVAL_S, DEFAULT_MAX_MISSING)
        statuses = [v.status for v in verdicts]
        got = ("INSTRUMENT" if "INSTRUMENT" in statuses
               else "VIOLATION" if "VIOLATION" in statuses
               else "PASS" if statuses else "EMPTY")
        mark = "ok" if got == expect else "FAIL"
        print(f"[selftest] {name}: {got} (expected {expect}) {mark}")
        if got != expect:
            failures.append(name)

    # (a) the real shape measured on po-2028: 655 s pass, 109 ops over the window, ticks on time.
    run("pacer bound respected", _log(
        [(t0 + 655, 5, 655_000)],
        [(t0 + 0, 0), (t0 + 300, 50), (t0 + 600, 100), (t0 + 900, 109)]), "PASS")

    # (b) same duration, a fraction of the ops: the worker was not throttled, it stalled.
    run("stall misread as a pass", _log(
        [(t0 + 655, 5, 655_000)],
        [(t0 + 0, 0), (t0 + 300, 10), (t0 + 600, 18), (t0 + 900, 20)]), "VIOLATION")

    # (c) bound respected but the tick went silent inside the pass -> starvation, still a violation.
    run("tick starved inside a bounded pass", _log(
        [(t0 + 1_200, 5, 900_000)],
        [(t0 + 0, 0), (t0 + 1_250, 150)]), "VIOLATION")

    # (d) no closing EMB-METRICS: the window cannot be closed, so nothing is claimed.
    run("unclosed window", _log(
        [(t0 + 655, 5, 655_000)],
        [(t0 + 0, 0), (t0 + 300, 50)]), "INSTRUMENT")

    # (e) counter reset (process restart) inside the window.
    run("counter reset", _log(
        [(t0 + 655, 5, 655_000)],
        [(t0 + 0, 0), (t0 + 300, 90), (t0 + 600, 3), (t0 + 900, 12)]), "INSTRUMENT")

    # (f) untimed lines -> no clock, so nothing is judged at all (untimed_lines > 0).
    run("untimed log", _log(
        [(t0 + 655, 5, 655_000)],
        [(t0 + 0, 0), (t0 + 900, 109)], timed=False), "EMPTY")

    print(f"[selftest] {'PASS' if not failures else 'FAIL'} "
          f"({6 - len(failures)}/6{' — ' + ', '.join(failures) if failures else ''})")
    return 0 if not failures else 1


def main() -> int:
    parser = argparse.ArgumentParser(
        description="#4352 g6 — judge indexing passes against the embedding pacer bound")
    parser.add_argument("--log", help="log file holding [EMB-METRICS] and 'pass done' lines")
    parser.add_argument("--ops-per-minute", type=float,
                        default=float(os.environ.get("EMBEDDING_OPS_PER_MINUTE",
                                                     DEFAULT_OPS_PER_MINUTE)),
                        help=f"pacer ceiling (default: env or {DEFAULT_OPS_PER_MINUTE:g})")
    parser.add_argument("--margin", type=float, default=DEFAULT_MARGIN,
                        help=f"allowance over the pacer floor (default {DEFAULT_MARGIN})")
    parser.add_argument("--interval-seconds", type=float, default=DEFAULT_INTERVAL_S,
                        help=f"tick interval (default {DEFAULT_INTERVAL_S:g}s)")
    parser.add_argument("--max-missing", type=int, default=DEFAULT_MAX_MISSING,
                        help=f"tolerated absent EMB-METRICS inside a pass (default {DEFAULT_MAX_MISSING})")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--selftest", action="store_true")
    args = parser.parse_args()

    if args.selftest:
        return selftest()
    if not args.log:
        parser.error("--log is required (or --selftest)")

    try:
        metrics, passes, untimed = scan(args.log)
    except OSError as exc:
        print(f"[INSTRUMENT] cannot read {args.log}: {exc}", file=sys.stderr)
        return 2
    if not passes:
        print(f"[INSTRUMENT] no 'pass done' line in {args.log} — nothing judged", file=sys.stderr)
        return 2

    verdicts = judge(passes, metrics, args.ops_per_minute, args.margin,
                     args.interval_seconds, args.max_missing)
    return report(verdicts, args.ops_per_minute, args.margin, args.interval_seconds,
                  untimed, args.json)


if __name__ == "__main__":
    sys.exit(main())
