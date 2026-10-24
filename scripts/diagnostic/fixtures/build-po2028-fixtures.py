#!/usr/bin/env python3
"""Build the po-2028 replay fixtures from the Maintenance lane's raw extract (#4327).

The replay data is NOT hand-typed: it is the 44-row compact CSV that
`myia-ai-01:Maintenance` read from po-2028's own System log on 23/10 and posted in
the #4327 spec comment (24/10 12:05Z). This script turns that CSV into the JSON
timelines `classify-machine-usability.ps1 -ReplayFile` eats, so the replay exercises
the SAME burst detector the live path runs, on the same rows.

Only the probe samples are synthesized: the System log says nothing about TCP ports,
WinRM round trips or the listener heartbeat, and the spec's own healthy baseline
(249-445 ms, measured 24/10 12:04Z) is what the sample values sit in. That synthesis
is declared here rather than buried in the fixture.

Usage (from the repo root):
    python scripts/diagnostic/fixtures/build-po2028-fixtures.py
"""

from __future__ import annotations

import csv
import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
CSV_PATH = HERE / "po2028-events-20261023.csv"
WEDGE_FIXTURE = HERE / "po2028-20261023.json"
CONTROL_FIXTURE = HERE / "po2028-20261023-control.json"

# The two boots of 23/10 that matter. 07:45:13Z is the morning wedge the user hit
# ("coincé au login", 08:23Z); 22:12:04Z is a negative control (no burst in the
# 20 min after it, and it follows a physical power cut, not the logon death).
WEDGE_BOOT = "2026-10-23T07:45:13Z"
CONTROL_BOOT = "2026-10-23T22:12:04Z"

# Healthy-baseline latency samples (spec section 2: po-2028 391-445 ms on 24/10).
# A wedged machine answers ~10 s; none of these samples are in that range, because
# the wedge episode's DECISIVE input is the burst, and the point of the first two
# samples is that latency alone never decides.
HEALTHY_LATENCY = [391, 412, 445]


# Burst sizes, from the spec's own section-1 table ("Burst size" column: ×6 each
# time it was measured). The archived CSV carries ONE row per second -- the spec says
# "duplicate burst lines per second collapsed" -- so the multiplicity lives here
# instead of being invented as repeated rows. A second absent from this map counts 1.
BURST_SIZES = {
    "2026-10-23T07:48:41Z": 6,
    "2026-10-23T21:50:47Z": 6,
    "2026-10-23T23:06:36Z": 6,
}


def load_events() -> list[dict]:
    if not CSV_PATH.exists():
        sys.exit(f"missing {CSV_PATH}; extract the CSV block from the #4327 spec comment first")
    rows: list[dict] = []
    with CSV_PATH.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            utc = row["utc"].strip()
            rows.append(
                {
                    "utc": utc,
                    "id": int(row["id"]),
                    "provider": row["provider"].strip(),
                    "message": row["detail"].strip(),
                    "count": BURST_SIZES.get(utc, 1),
                }
            )
    if not rows:
        sys.exit("the CSV parsed to zero rows")
    return rows


def sample(at_utc: str, heartbeat_age: int) -> dict:
    return {
        "atUtc": at_utc,
        "machine": "myia-po-2028",
        "openPorts": [5985, 22, 445],
        "drivingChannelAnswered": True,
        "drivingStatusCode": 401,
        "drivingLatencyMs": 4,
        "latencySamplesMs": HEALTHY_LATENCY,
        "heartbeatAgeSeconds": heartbeat_age,
    }


def write_fixture(path: pathlib.Path, events: list[dict], boot: str, samples: list[dict], note: str) -> None:
    payload = {
        "machine": "myia-po-2028",
        "note": note,
        "lastBootUtc": boot,
        "events": events,
        "samples": samples,
    }
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {path} ({len(events)} events, {len(samples)} samples)")


def main() -> None:
    events = load_events()

    # Wedge episode. The burst fires 07:48:41Z, T+3m28s after the 07:45:13Z boot.
    # - 07:47:00Z: before the burst -> healthy, and the fresh heartbeat proves the
    #   episode is not a stale-listener story.
    # - 07:50:00Z: 79 s AFTER the burst, heartbeat still FRESH (79 s < 1800 s) and
    #   latency in the healthy band. This is the sample that proves the burst decides
    #   on its own: nothing else in it is abnormal.
    # - 07:55:00Z: still unusable, one polling cycle later.
    wedge_samples = [
        sample("2026-10-23T07:47:00Z", 107),
        sample("2026-10-23T07:50:00Z", 79),
        sample("2026-10-23T07:55:00Z", 379),
    ]
    write_fixture(
        WEDGE_FIXTURE,
        events,
        WEDGE_BOOT,
        wedge_samples,
        "po-2028 morning wedge of 23/10: burst at 07:48:41Z (x6, _ab668), T+3m28s. "
        "Probe samples are synthesized inside the spec's healthy baseline; the events are verbatim.",
    )

    # Negative control: the 22:12:04Z boot after a physical power cut. No burst in
    # [boot+2, boot+20], so a reachable, fast, fresh machine stays healthy.
    control_samples = [sample("2026-10-23T22:14:00Z", 116)]
    write_fixture(
        CONTROL_FIXTURE,
        events,
        CONTROL_BOOT,
        control_samples,
        "po-2028 negative control: boot at 22:12:04Z after a physical power cut, no logon-death burst in the window.",
    )


if __name__ == "__main__":
    main()
