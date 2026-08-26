#!/usr/bin/env python3
"""
scan-duplicate-tool-use.py — Detect real double-execution of a single tool_use in Claude Code session transcripts.

Issue #3276: the same tool_use block gets recorded as two DISTINCT transcript nodes
(different uuid, second is child of the first, same message.id) ~1s apart, and BOTH get
executed by the runtime — producing duplicate side effects (e.g. `gh issue create`
firing twice: CoursIA #13089/#13090, recurrence #13108/#13109).

Structural ground truth (verified on real transcripts, 2026-08-26):
- One assistant API response is normally decomposed into ONE NODE PER CONTENT BLOCK,
  all sharing the same message.id (thinking -> text -> tool_use...). "Two nodes with the
  same message.id" is therefore the NORM, not the bug signature.
- Session resume/fork re-appends prior transcript ranges VERBATIM: the same nodes
  (same uuid) appear twice in the file. Same-uuid rewrites are copy artifacts, not
  re-executions.

The operative signatures are:
  EMIT_FORK   — the same tool_use block id emitted on >= 2 nodes with DISTINCT uuids
               (the transcript fork). Parent-child link between the two nodes reported.
  EXEC_DOUBLE — >= 2 tool_result nodes with DISTINCT uuids for one tool_use id, with
               DIFFERENT result content (real double execution). Identical-content
               distinct-uuid results are reported as EXEC_COPY (probable copy artifact).

The root fix is Claude Code runtime-side; this script is the detection instrumentation.
While #3276 is open, any lane publishing issues from a Claude Code harness must
post-verify every `gh issue create` (re-list the title ~15s later, delete the
byte-identical clean copy).

Usage:
    python scan-duplicate-tool-use.py                          # scan ~/.claude/projects
    python scan-duplicate-tool-use.py --root <dir>             # scan another root
    python scan-duplicate-tool-use.py --file <session.jsonl>   # single session
    python scan-duplicate-tool-use.py --json                   # machine-readable output
    python scan-duplicate-tool-use.py --selftest               # synthetic fixture validation

Exit codes: 0 = clean, 2 = findings (EMIT_FORK/EXEC_DOUBLE always; EXEC_COPY only with --strict), 1 = error.
"""

import argparse
import hashlib
import json
import sys
import tempfile
import time
from pathlib import Path

EXIT_CLEAN = 0
EXIT_ERROR = 1
EXIT_FINDINGS = 2


def parse_ts(value):
    if not value or not isinstance(value, str):
        return None
    try:
        from datetime import datetime
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def delta_ms(first, second):
    a, b = parse_ts(first), parse_ts(second)
    if a is None or b is None:
        return None
    return round((b - a).total_seconds() * 1000)


def block_fingerprint(block):
    """Stable fingerprint of a tool_result block, ignoring volatile wrapper fields."""
    payload = {
        "content": block.get("content"),
        "is_error": bool(block.get("is_error")),
    }
    return hashlib.sha1(json.dumps(payload, sort_keys=True, default=str).encode()).hexdigest()[:12]


def scan_file(path):
    """Scan one session JSONL. Returns (findings, stats).

    Nodes sharing the same uuid are the SAME node re-written (resume copy artifact):
    collapsed to their first occurrence, counted in stats['rewritten_nodes'].
    """
    emissions = {}  # tool_use_id -> {uuid -> node}
    results = {}    # tool_use_id -> {uuid -> node}
    stats = {"lines": 0, "tool_use": 0, "tool_results": 0, "rewritten_nodes": 0}

    def register(table, tid, uuid, record):
        bucket = table.setdefault(tid, {})
        if uuid in bucket:
            stats["rewritten_nodes"] += 1
            return
        bucket[uuid] = record

    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for lineno, line in enumerate(fh, 1):
            stats["lines"] += 1
            if '"tool_use"' not in line and '"tool_result"' not in line:
                continue
            try:
                entry = json.loads(line)
            except ValueError:
                continue
            if not isinstance(entry, dict):
                continue
            msg = entry.get("message")
            if not isinstance(msg, dict):
                continue
            content = msg.get("content")
            if not isinstance(content, list):
                continue
            ts = entry.get("timestamp")
            node_uuid = entry.get("uuid") or f"line:{lineno}"
            seen_in_node = set()

            for block in content:
                if not isinstance(block, dict):
                    continue
                btype = block.get("type")
                if btype == "tool_use" and block.get("id"):
                    tid = block["id"]
                    if tid in seen_in_node:
                        continue
                    seen_in_node.add(tid)
                    stats["tool_use"] += 1
                    register(emissions, tid, node_uuid, {
                        "line": lineno,
                        "message_id": msg.get("id"),
                        "uuid": node_uuid,
                        "parent": entry.get("parentUuid"),
                        "ts": ts,
                        "tool": block.get("name"),
                        "role": msg.get("role"),
                        "sidechain": bool(entry.get("isSidechain")),
                    })
                elif btype == "tool_result" and block.get("tool_use_id"):
                    stats["tool_results"] += 1
                    register(results, block["tool_use_id"], node_uuid, {
                        "line": lineno,
                        "uuid": node_uuid,
                        "ts": ts,
                        "is_error": bool(block.get("is_error")),
                        "fingerprint": block_fingerprint(block),
                    })

    findings = []

    for tid, nodes in sorted(emissions.items()):
        if len(nodes) < 2:
            continue
        ordered = sorted(nodes.values(), key=lambda n: n["line"])
        first = ordered[0]
        child_of_first = any(
            n["parent"] is not None and n["parent"] == first["uuid"] for n in ordered[1:]
        )
        findings.append({
            "class": "EMIT_FORK",
            "tool_use_id": tid,
            "tool": first.get("tool"),
            "nodes": ordered,
            "child_of_first": child_of_first,
            "delta_ms": delta_ms(ordered[0]["ts"], ordered[-1]["ts"]),
        })

    for tid, nodes in sorted(results.items()):
        if len(nodes) < 2:
            continue
        ordered = sorted(nodes.values(), key=lambda n: n["line"])
        fingerprints = {n["fingerprint"] for n in ordered}
        findings.append({
            "class": "EXEC_DOUBLE" if len(fingerprints) > 1 else "EXEC_COPY",
            "tool_use_id": tid,
            "results": ordered,
            "identical_content": len(fingerprints) == 1,
            "delta_ms": delta_ms(ordered[0]["ts"], ordered[-1]["ts"]),
        })

    findings.sort(key=lambda f: (f.get("nodes") or f.get("results"))[0]["line"])
    return findings, stats


def scan_target(target, as_json=False, strict=False):
    """target: file or directory. Returns (report_sessions, totals)."""
    paths = [target] if target.is_file() else sorted(target.rglob("*.jsonl"))
    report_sessions = []
    totals = {"files": 0, "lines": 0, "tool_use": 0, "tool_results": 0,
              "rewritten_nodes": 0, "findings": 0}
    started = time.monotonic()

    for path in paths:
        try:
            findings, stats = scan_file(path)
        except OSError as err:
            print(f"ERROR reading {path}: {err}", file=sys.stderr)
            continue
        totals["files"] += 1
        for key in ("lines", "tool_use", "tool_results", "rewritten_nodes"):
            totals[key] += stats[key]
        reported = [f for f in findings if strict or f["class"] != "EXEC_COPY"]
        if reported:
            totals["findings"] += len(reported)
            report_sessions.append({"file": str(path), "findings": reported})
            if not as_json:
                print(f"\n== {path}")
                for f in reported:
                    render_finding(f)

    totals["elapsed_s"] = round(time.monotonic() - started, 1)
    return report_sessions, totals


def render_finding(f):
    if f["class"] == "EMIT_FORK":
        rel = "second node is CHILD of first (#3276 fork shape)" if f["child_of_first"] else "no parent link"
        print(f"  [EMIT_FORK] {f['tool_use_id']}  tool={f.get('tool')}  ({rel})")
        for i, n in enumerate(f["nodes"], 1):
            print(f"    #{i} line {n['line']}  msg={n['message_id']}  uuid={str(n['uuid'])[:8]}  "
                  f"parent={str(n['parent'])[:8]}  ts={n['ts']}")
    else:
        label = "EXEC_DOUBLE" if f["class"] == "EXEC_DOUBLE" else "EXEC_COPY"
        note = "identical content (copy artifact)" if f["identical_content"] else "DIFFERENT content (real double execution)"
        print(f"  [{label}] {f['tool_use_id']}  x{len(f['results'])}  {note}")
        for i, r in enumerate(f["results"], 1):
            err = " ERROR" if r["is_error"] else ""
            print(f"    #{i} line {r['line']}  uuid={str(r['uuid'])[:8]}  ts={r['ts']}{err}")


def selftest():
    """Synthetic fixtures: #3276 fork (must flag), resume copy (must NOT flag), clean (must NOT flag)."""
    tooluse = {"type": "tool_use", "id": "toolu_7z1zmK38bzLdfWow6bRYkCe1", "name": "PowerShell", "input": {}}

    def node(node_type, uuid, parent, ts, msg_id, blocks, role="assistant"):
        return json.dumps({"type": node_type, "uuid": uuid, "parentUuid": parent, "timestamp": ts,
                           "message": {"id": msg_id, "role": role, "content": blocks}})

    u1, u2, r1, r2 = ("aaaaaaaa-0000-0000-0000-00000000000%d" % i for i in (1, 2, 3, 4))
    fork_session = "\n".join([
        node("assistant", u1, "user-node", "2026-08-26T08:50:11.148Z", "msg_1787734193541",
             [{"type": "text", "text": "creating issue"}, tooluse]),
        node("assistant", u2, u1, "2026-08-26T08:50:11.373Z", "msg_1787734193541", [tooluse]),
        node("user", r1, u2, "2026-08-26T08:50:13.861Z", None,
             [{"type": "tool_result", "tool_use_id": tooluse["id"], "content": "issue 13089"}], role="user"),
        node("user", r2, r1, "2026-08-26T08:50:15.779Z", None,
             [{"type": "tool_result", "tool_use_id": tooluse["id"], "content": "issue 13090"}], role="user"),
    ])
    # Resume copy artifact: same nodes (same uuids) re-appended verbatim -> must NOT flag.
    copy_session = "\n".join([
        node("assistant", u1, "user-node", "2026-08-26T08:50:11.148Z", "msg_1", [tooluse]),
        node("user", r1, u1, "2026-08-26T08:50:13.861Z", None,
             [{"type": "tool_result", "tool_use_id": tooluse["id"], "content": "ok"}], role="user"),
        node("assistant", u1, "user-node", "2026-08-26T08:50:11.148Z", "msg_1", [tooluse]),
        node("user", r1, u1, "2026-08-26T08:50:13.861Z", None,
             [{"type": "tool_result", "tool_use_id": tooluse["id"], "content": "ok"}], role="user"),
    ])
    # Normal multi-block decomposition (one node per block, same message.id) -> must NOT flag.
    clean_session = "\n".join([
        node("assistant", u1, "user-node", "2026-08-26T09:00:00.000Z", "msg_clean",
             [{"type": "thinking", "thinking": "..."}]),
        node("assistant", u2, u1, "2026-08-26T09:00:01.000Z", "msg_clean",
             [{"type": "tool_use", "id": "toolu_normal1", "name": "Read", "input": {}}]),
        node("user", r1, u2, "2026-08-26T09:00:02.000Z", None,
             [{"type": "tool_result", "tool_use_id": "toolu_normal1", "content": "ok"}], role="user"),
    ])

    with tempfile.TemporaryDirectory() as tmp:
        paths = {
            "fork": Path(tmp) / "fork.jsonl",
            "copy": Path(tmp) / "copy.jsonl",
            "clean": Path(tmp) / "clean.jsonl",
        }
        paths["fork"].write_text(fork_session + "\n", encoding="utf-8")
        paths["copy"].write_text(copy_session + "\n", encoding="utf-8")
        paths["clean"].write_text(clean_session + "\n", encoding="utf-8")

        fork_findings, fork_stats = scan_file(paths["fork"])
        copy_findings, copy_stats = scan_file(paths["copy"])
        clean_findings, _ = scan_file(paths["clean"])

        classes = {f["class"] for f in fork_findings}
        assert clean_findings == [], f"clean fixture must yield no findings, got: {clean_findings}"
        assert copy_findings == [], f"resume-copy fixture must yield no findings, got: {copy_findings}"
        assert copy_stats["rewritten_nodes"] == 2, f"copy fixture must count 2 rewritten nodes, got {copy_stats['rewritten_nodes']}"
        assert "EMIT_FORK" in classes, f"EMIT_FORK not detected: {classes}"
        assert "EXEC_DOUBLE" in classes, f"EXEC_DOUBLE not detected: {classes}"
        fork = next(f for f in fork_findings if f["class"] == "EMIT_FORK")
        assert fork["child_of_first"] is True, "second node must be detected as child of first"
        assert fork["delta_ms"] == 225, f"expected 225 ms delta, got {fork['delta_ms']}"
        dbl = next(f for f in fork_findings if f["class"] == "EXEC_DOUBLE")
        assert dbl["identical_content"] is False, "double execution must be detected as DIFFERENT content"

    print("selftest OK: EMIT_FORK (child link, 225ms) + EXEC_DOUBLE (different content) detected on #3276 signature;")
    print("             resume-copy artifact (same uuids) and normal per-block decomposition pass clean")
    return EXIT_CLEAN


def main():
    parser = argparse.ArgumentParser(description="Detect duplicated tool_use emission/execution in Claude Code transcripts (issue #3276).")
    parser.add_argument("--root", type=Path, help="scan this directory recursively (default: ~/.claude/projects)")
    parser.add_argument("--file", type=Path, help="scan a single session JSONL")
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    parser.add_argument("--strict", action="store_true", help="also report EXEC_COPY (identical-content distinct-uuid results)")
    parser.add_argument("--selftest", action="store_true", help="run synthetic fixture validation and exit")
    args = parser.parse_args()

    if args.selftest:
        sys.exit(selftest())

    if args.file:
        target = args.file.resolve()
    else:
        target = (args.root or Path.home() / ".claude" / "projects").resolve()
    if not target.exists():
        print(f"ERROR: target not found: {target}", file=sys.stderr)
        sys.exit(EXIT_ERROR)

    findings, totals = scan_target(target, as_json=args.json, strict=args.strict)

    if args.json:
        print(json.dumps({"target": str(target), "totals": totals, "findings": findings},
                         ensure_ascii=False, indent=2))
    else:
        print(f"\nscanned {totals['files']} file(s), {totals['lines']} lines, "
              f"{totals['tool_use']} tool_use, {totals['tool_results']} tool_results, "
              f"{totals['rewritten_nodes']} rewritten nodes (resume copies) "
              f"in {totals['elapsed_s']}s")
        if findings:
            print(f"RESULT: {totals['findings']} finding(s) across {len(findings)} session(s) — see above")
        else:
            print("RESULT: clean — no duplicated tool_use signature")

    sys.exit(EXIT_FINDINGS if findings else EXIT_CLEAN)


if __name__ == "__main__":
    main()
