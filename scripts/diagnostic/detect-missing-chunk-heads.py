#!/usr/bin/env python3
"""
detect-missing-chunk-heads.py — #4352 g7: split messages whose HEAD pages are
missing from the Qdrant collection.

What the defect looks like (measured on ai-01, 27/10): for one
`original_chunk_id`, pages 1-3 were absent from Qdrant while pages 4->63 were
present. The message is indexed, searchable, drillable — and its beginning,
which is where the question and the decision usually are, was never written.

Why a head-only detector is enough
----------------------------------
`ChunkExtractor.splitChunk` numbers split parts from 1 (`chunk_index`, 1-based,
bounded by `total_chunks`). A group is complete on its head iff `chunk_index 1`
exists. So the exact test is `min(chunk_index) > 1` over each
`original_chunk_id` — no heuristics, no sampling.

What it deliberately does NOT claim
-----------------------------------
A split chunk that was never written at all has NO points, so it is invisible to
any collection-side query. This detector therefore reports heads that are
missing *while the rest of the message is present* — the measured defect. It is
not a completeness audit of the source corpus.

Phases
------
  --detect    read-only scan, exits 1 when heads are missing
  --verify    re-reads the SAME groups after a requeue and reports what appeared
  (requeue is actuated through the MCP entry point; --detect prints the calls)

Exit codes
----------
  0  clean (no head missing in scope) / verify: every head reappeared
  1  heads missing / verify: heads still missing
  2  instrument failure (config unreadable, Qdrant unreachable, bad scope)

Scope
-----
A full scan reads ~2.47 M split points (measured 2026-10-28 on po-2027:
1 093 s, i.e. ~18 min). That is why `--all` must be asked for explicitly:
`--task` and `--since` are the normal scopes, and a scope-less run is refused
rather than started.

Usage
-----
  python scripts/diagnostic/detect-missing-chunk-heads.py --detect --all
  python scripts/diagnostic/detect-missing-chunk-heads.py --detect --task claude-...
  python scripts/diagnostic/detect-missing-chunk-heads.py --detect --since 2026-10-20
  python scripts/diagnostic/detect-missing-chunk-heads.py --verify --groups <detect.json>
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from typing import Any, NoReturn

CALL_TIMEOUT = 60
PAGE = 1000
DEFAULT_ENV = os.path.join("mcps", "internal", "servers", "roo-state-manager", ".env")


def die(msg: str) -> NoReturn:
    print(f"[INSTRUMENT] {msg}", file=sys.stderr)
    sys.exit(2)


def load_env(path: str) -> dict[str, str]:
    """Read KEY=VALUE pairs. Values are never printed — only their presence."""
    if not os.path.isfile(path):
        die(f"env file not found: {path} (pass --env)")
    env: dict[str, str] = {}
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            env[key.strip()] = value.strip().strip('"').strip("'")
    for required in ("QDRANT_URL", "QDRANT_API_KEY", "QDRANT_COLLECTION_NAME"):
        if not env.get(required):
            die(f"{required} missing from {path}")
    return env


class Qdrant:
    def __init__(self, env: dict[str, str]) -> None:
        self.base = env["QDRANT_URL"].rstrip("/")
        self.collection = env["QDRANT_COLLECTION_NAME"]
        self.headers = {"api-key": env["QDRANT_API_KEY"], "content-type": "application/json"}

    def post(self, path: str, body: dict[str, Any]) -> dict[str, Any]:
        url = f"{self.base}/collections/{self.collection}{path}"
        request = urllib.request.Request(
            url, data=json.dumps(body).encode("utf-8"), headers=self.headers, method="POST"
        )
        try:
            with urllib.request.urlopen(request, timeout=CALL_TIMEOUT) as response:
                return json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:  # a 4xx/5xx is an instrument failure, not "nothing there"
            die(f"Qdrant {path} -> HTTP {exc.code}: {exc.read()[:300]!r}")
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
            die(f"Qdrant {path} unreachable: {exc}")
        raise AssertionError("unreachable")

    def scroll_split_points(
        self, scope_filter: dict[str, Any], groups: dict[str, dict[str, Any]], progress: bool
    ) -> int:
        """Fold every SPLIT point (one carrying original_chunk_id) into `groups`, page by page.

        Folding per page instead of accumulating a list matters at full scale: the
        collection holds ~1.8 M split points, which is ~1.3 GB of dicts if buffered.
        """
        seen = 0
        offset = None
        started = time.time()
        while True:
            body: dict[str, Any] = {
                "limit": PAGE,
                "with_payload": ["original_chunk_id", "chunk_index", "total_chunks", "task_id"],
                "with_vector": False,
                "filter": scope_filter,
            }
            if offset is not None:
                body["offset"] = offset
            page = self.post("/points/scroll", body).get("result") or {}
            batch = page.get("points") or []
            if not batch:
                break
            fold_points(batch, groups)
            seen += len(batch)
            offset = page.get("next_page_offset")
            if offset is None:
                break
            if progress and seen % (PAGE * 20) == 0:
                print(f"  ... {seen} points, {len(groups)} groups, {time.time() - started:.0f}s", file=sys.stderr)
        return seen


def split_filter(scope: dict[str, Any]) -> dict[str, Any]:
    must: list[dict[str, Any]] = [{"key": "chunk_index", "range": {"gte": 1}}]
    if scope.get("task"):
        must.append({"key": "task_id", "match": {"value": scope["task"]}})
    if scope.get("since"):
        must.append({"key": "timestamp", "range": {"gte": scope["since"]}})
    # Only split chunks carry original_chunk_id; nothing else has a head to be missing.
    must_not = [{"is_empty": {"key": "original_chunk_id"}}]
    return {"must": must, "must_not": must_not}


def fold_points(points: list[dict[str, Any]], groups: dict[str, dict[str, Any]]) -> dict[str, dict[str, Any]]:
    """Fold a page of points into one record per original_chunk_id (in place)."""
    for point in points:
        payload = point.get("payload") or {}
        ocid = payload.get("original_chunk_id")
        index = payload.get("chunk_index")
        if not isinstance(ocid, str) or not isinstance(index, int):
            continue
        record = groups.get(ocid)
        if record is None:
            groups[ocid] = {
                "original_chunk_id": ocid,
                "task_id": payload.get("task_id"),
                "total_chunks": payload.get("total_chunks"),
                "min_index": index,
                "max_index": index,
                "present": 1,
            }
        else:
            record["min_index"] = min(record["min_index"], index)
            record["max_index"] = max(record["max_index"], index)
            record["present"] += 1
            if record.get("task_id") is None:
                record["task_id"] = payload.get("task_id")
            if record.get("total_chunks") is None:
                record["total_chunks"] = payload.get("total_chunks")
    return groups


def group_points(points: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    """Reduce a bounded page of points to one record per original_chunk_id."""
    return fold_points(points, {})


def classify(groups: dict[str, dict[str, Any]]) -> dict[str, list[dict[str, Any]]]:
    missing_head: list[dict[str, Any]] = []
    truncated_tail: list[dict[str, Any]] = []
    for record in groups.values():
        if record["min_index"] > 1:
            missing_head.append(record)
        total = record.get("total_chunks")
        if isinstance(total, int) and record["max_index"] < total:
            truncated_tail.append(record)
    missing_head.sort(key=lambda r: (-r["present"], r["original_chunk_id"]))
    truncated_tail.sort(key=lambda r: (-(r.get("total_chunks") or 0), r["original_chunk_id"]))
    return {"missing_head": missing_head, "truncated_tail": truncated_tail}


def summarise(scope: dict[str, Any], groups: dict[str, dict[str, Any]], report: dict[str, list[dict[str, Any]]]) -> dict[str, Any]:
    affected_tasks = sorted({r["task_id"] for r in report["missing_head"] if r.get("task_id")})
    return {
        "scope": scope,
        "groups_scanned": len(groups),
        "groups_missing_head": len(report["missing_head"]),
        "groups_truncated_tail": len(report["truncated_tail"]),
        "affected_tasks": len(affected_tasks),
        "missing_head": report["missing_head"],
        "truncated_tail": report["truncated_tail"][:200],
        "task_ids": affected_tasks,
    }


def print_report(summary: dict[str, Any]) -> None:
    scope = summary["scope"]
    print("=== #4352 g7 — split messages whose head pages are missing ===")
    print(f"scope: {json.dumps(scope, ensure_ascii=False)}")
    print(f"split points scanned               : {summary.get('points_scanned', '?')}")
    print(f"split groups scanned              : {summary['groups_scanned']}")
    print(f"groups with NO chunk_index 1       : {summary['groups_missing_head']}")
    print(f"groups whose tail exceeds present  : {summary['groups_truncated_tail']}")
    print(f"distinct task_ids affected         : {summary['affected_tasks']}")
    if summary["missing_head"]:
        print("\n-- heads missing (first 20) --")
        for record in summary["missing_head"][:20]:
            print(
                f"  task={record.get('task_id')} ocid={record['original_chunk_id']} "
                f"present={record['present']} indices {record['min_index']}..{record['max_index']} "
                f"of {record.get('total_chunks')}"
            )
    if summary["task_ids"]:
        print("\n-- requeue (MCP entry point, one call per task) --")
        for task in summary["task_ids"]:
            print(f"  roosync_indexing(action:\"index\", task_id:\"{task}\", source:\"claude-code\")")


def cmd_detect(qdrant: Qdrant, scope: dict[str, Any], as_json: bool, out_path: str | None) -> int:
    started = time.time()
    groups: dict[str, dict[str, Any]] = {}
    scanned = qdrant.scroll_split_points(split_filter(scope), groups, progress=not as_json)
    if not groups:
        # An empty scan is never "clean" — it is "nothing measured". A filter on a
        # field Qdrant does not index as a datetime (e.g. `timestamp`) returns zero
        # points with HTTP 200, which would read as a green result.
        die(
            f"scope {json.dumps(scope)} matched 0 split points: nothing measured, not 'clean'. "
            "Widen the scope (a --since on an unindexed field can match nothing)."
        )
    summary = summarise(scope, groups, classify(groups))
    summary["points_scanned"] = scanned
    summary["elapsed_s"] = round(time.time() - started, 1)
    if as_json:
        print(json.dumps(summary, ensure_ascii=False, indent=2))
    else:
        print_report(summary)
    if out_path:
        with open(out_path, "w", encoding="utf-8") as fh:
            json.dump(summary, fh, ensure_ascii=False, indent=2)
        print(f"\nwritten: {out_path}")
    return 1 if summary["groups_missing_head"] else 0


def cmd_verify(qdrant: Qdrant, groups_path: str, as_json: bool) -> int:
    """Re-read the SAME original_chunk_ids and report which heads appeared."""
    with open(groups_path, "r", encoding="utf-8") as fh:
        previous = json.load(fh)
    targets = [r["original_chunk_id"] for r in previous.get("missing_head") or []]
    if not targets:
        print("verify: nothing to verify (the detect report listed no missing head)")
        return 0

    # One filtered scroll over just the suspect ids: exact and bounded.
    still_missing: list[dict[str, Any]] = []
    recovered: list[dict[str, Any]] = []
    for start in range(0, len(targets), 200):
        chunk = targets[start : start + 200]
        body = {
            "limit": PAGE,
            "with_payload": ["original_chunk_id", "chunk_index", "total_chunks", "task_id"],
            "with_vector": False,
            "filter": {"must": [{"key": "original_chunk_id", "match": {"any": chunk}}]},
        }
        points = qdrant.post("/points/scroll", body).get("result", {}).get("points") or []
        found = group_points(points)
        for ocid in chunk:
            record = found.get(ocid)
            if record and record["min_index"] == 1:
                recovered.append(record)
            else:
                still_missing.append(record or {"original_chunk_id": ocid, "present": 0, "min_index": None})

    result = {
        "verified_groups": len(targets),
        "recovered": len(recovered),
        "still_missing": len(still_missing),
        "recovered_sample": recovered[:20],
        "still_missing_sample": still_missing[:20],
    }
    if as_json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print("=== #4352 g7 — verify after requeue ===")
        print(f"groups verified  : {result['verified_groups']}")
        print(f"head recovered   : {result['recovered']}")
        print(f"still missing    : {result['still_missing']}")
        for record in still_missing[:20]:
            print(f"  STILL MISSING task={record.get('task_id')} ocid={record['original_chunk_id']} min_index={record.get('min_index')}")
    return 0 if not still_missing else 1


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="#4352 g7 — missing chunk heads detector")
    parser.add_argument("--detect", action="store_true", help="read-only scan")
    parser.add_argument("--verify", action="store_true", help="re-read the groups of a previous --detect report")
    parser.add_argument("--groups", help="--detect JSON report to verify")
    parser.add_argument("--all", action="store_true", help="scan the whole collection (slow: ~1.8 M points)")
    parser.add_argument("--task", help="restrict to one task_id")
    parser.add_argument("--since", help="restrict to timestamp >= this ISO instant")
    parser.add_argument("--env", default=DEFAULT_ENV, help=f".env holding QDRANT_* (default: {DEFAULT_ENV})")
    parser.add_argument("--json", action="store_true", dest="as_json", help="machine-readable output")
    parser.add_argument("--out", help="write the detect report to this path")
    args = parser.parse_args(argv)

    if args.verify:
        if not args.groups:
            die("--verify needs --groups <detect report>")
        return cmd_verify(Qdrant(load_env(args.env)), args.groups, args.as_json)

    if not args.detect:
        parser.print_help()
        return 0

    scope = {"task": args.task, "since": args.since, "all": bool(args.all)}
    if not (args.task or args.since or args.all):
        die(
            "refusing to scan the whole collection by accident: pass --task, --since, or --all "
            "(a full scan reads ~2.47 M split points, ~18 min)"
        )
    return cmd_detect(Qdrant(load_env(args.env)), scope, args.as_json, args.out)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
