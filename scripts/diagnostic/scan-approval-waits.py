#!/usr/bin/env python3
"""
scan-approval-waits.py — Measure shell tool_use -> tool_result gaps in Claude Code
session transcripts: the transcript-side instrument for approval-despite-bypass waits.

Issue #4214 (mandate user 15/10, dispatched by ai-01 08:47Z): despite `mode: auto-approve`
(bypass), some Bash/PowerShell commands suspend Claude Code on a manual approval prompt —
the session waits silently until the user returns. Measured instance: ai-01:CoursIA cycle
frozen ~1h on a composed command (`rm -rf` on an absolute path + `cd` outside the working
directory + `wsl ... bash -lc`, session 2d17885a).

Complement to claudish#474 (`scripts/tool-gap.py`, hub-traffic side): the hub sees the gap
but cannot tell approval-wait from execution. The transcript CAN adjudicate — between an
assistant node carrying a `tool_use` and the user node carrying its `tool_result` there is
NO model generation (the next API call only happens after the result returns), so the gap
is exactly: approval wait + execution + client overhead. This scanner walks
`~/.claude/projects/**/*.jsonl`, pairs every Bash/PowerShell tool_use with its tool_result,
and reports pairs whose gap exceeds a threshold, classified by command form.

Form classes (the mandate's three suspects + the dominant hub-side shape):
    composed-cd  — compound command (`&&`/`||`/`;`) whose first segment is a `cd`
                   (dominant fleet shape per claudish#474: 49 waits, median 121s)
    composed     — compound command without a leading `cd`
    rm-rf        — contains `rm -rf` (or `Remove-Item -Recurse -Force`)
    wsl          — invokes `wsl`
    elevated     — sudo / -Verb RunAs / Register-ScheduledTask
    multiline    — embedded newline in the command string
    plain        — single simple command

Usage:
    python scan-approval-waits.py                                  # scan ~/.claude/projects
    python scan-approval-waits.py --root <dir>                     # scan another root
    python scan-approval-waits.py --file <session.jsonl>           # single session
    python scan-approval-waits.py --min-wait 120 --top 30          # thresholds
    python scan-approval-waits.py --since-hours 24                 # only recent findings
    python scan-approval-waits.py --json                           # machine-readable output
    python scan-approval-waits.py --selftest                       # synthetic fixture validation

Exit codes: 0 = no finding, 2 = findings, 1 = error.
"""

import argparse
import json
import sys
import tempfile
import time
from pathlib import Path

EXIT_CLEAN = 0
EXIT_ERROR = 1
EXIT_FINDINGS = 2

DEFAULT_TOOLS = ("Bash", "PowerShell")
COMMAND_KEYS = ("command", "script", "cmd")
ELEVATED_MARKERS = ("sudo", "-Verb RunAs", "Register-ScheduledTask", "Start-Process -Verb")


def parse_ts(value):
    if not value or not isinstance(value, str):
        return None
    try:
        from datetime import datetime
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def delta_s(first, second):
    a, b = parse_ts(first), parse_ts(second)
    if a is None or b is None:
        return None
    return round((b - a).total_seconds(), 1)


def command_of(block):
    """Extract the command string from a shell tool_use input, whichever key it uses."""
    payload = block.get("input")
    if not isinstance(payload, dict):
        return None
    for key in COMMAND_KEYS:
        value = payload.get(key)
        if isinstance(value, str) and value.strip():
            return value
    return None


def classify(command):
    """Form class of a shell command — one label, checked in mandate-suspect order."""
    if not command:
        return "plain"
    lowered = command.lower()
    compound = any(sep in command for sep in ("&&", "||", ";"))
    if compound:
        first = command.split("&&")[0].split("||")[0].split(";")[0].strip()
        if first.split(" ", 1)[0] == "cd":
            return "composed-cd"  # dominant fleet shape (claudish#474): checked first
        if "rm -rf" in lowered or "remove-item -recurse -force" in lowered:
            return "rm-rf"
        return "composed"
    if "rm -rf" in lowered or "remove-item -recurse -force" in lowered:
        return "rm-rf"
    if "wsl " in lowered or lowered.startswith("wsl"):
        return "wsl"
    if any(marker.lower() in lowered for marker in ELEVATED_MARKERS):
        return "elevated"
    if "\n" in command:
        return "multiline"
    return "plain"


def scan_file(path, min_wait, tools, since_dt=None):
    """Scan one session JSONL. Returns (findings, stats).

    Nodes sharing a uuid already seen are resume-copy artifacts (verbatim re-append of a
    prior transcript range — see scan-duplicate-tool-use.py ground truth): skipped, counted
    in stats['rewritten_nodes'] so a resumed session never double-reports a wait.
    """
    tools_lower = {t.lower() for t in tools}
    pending = {}  # tool_use_id -> record (first emission only)
    findings = []
    stats = {"lines": 0, "shell_tool_use": 0, "tool_results": 0,
             "rewritten_nodes": 0, "unterminated": 0, "findings": 0}
    seen_uuids = set()

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
            node_uuid = entry.get("uuid") or f"line:{lineno}"
            if node_uuid in seen_uuids:
                stats["rewritten_nodes"] += 1
                continue
            seen_uuids.add(node_uuid)
            ts = entry.get("timestamp")
            seen_ids = set()

            for block in content:
                if not isinstance(block, dict):
                    continue
                btype = block.get("type")
                if btype == "tool_use" and block.get("id"):
                    if (block.get("name") or "").lower() not in tools_lower:
                        continue
                    tid = block["id"]
                    if tid in seen_ids or tid in pending:
                        continue
                    seen_ids.add(tid)
                    stats["shell_tool_use"] += 1
                    pending[tid] = {
                        "line": lineno,
                        "ts": ts,
                        "tool": block.get("name"),
                        "command": command_of(block),
                        "sidechain": bool(entry.get("isSidechain")),
                    }
                elif btype == "tool_result" and block.get("tool_use_id"):
                    tid = block["tool_use_id"]
                    if tid not in pending:
                        continue
                    stats["tool_results"] += 1
                    record = pending.pop(tid)
                    gap = delta_s(record["ts"], ts)
                    if gap is None or gap < min_wait:
                        continue
                    if since_dt is not None:
                        started = parse_ts(record["ts"])
                        if started is None or started < since_dt:
                            continue
                    command = record["command"] or ""
                    findings.append({
                        "tool_use_id": tid,
                        "tool": record["tool"],
                        "form": classify(command),
                        "gap_s": gap,
                        "ts": record["ts"],
                        "line": record["line"],
                        "command": command[:200],
                        "is_error": bool(block.get("is_error")),
                        "sidechain": record["sidechain"],
                    })

    stats["unterminated"] = len(pending)
    stats["findings"] = len(findings)
    findings.sort(key=lambda f: (-f["gap_s"], f["line"]))
    return findings, stats


def scan_target(target, min_wait, tools, since_hours=None, as_json=False, top=None):
    """target: file or directory. Returns (findings, totals)."""
    paths = [target] if target.is_file() else sorted(target.rglob("*.jsonl"))
    since_dt = None
    if since_hours is not None:
        from datetime import datetime, timedelta, timezone
        since_dt = datetime.now(timezone.utc) - timedelta(hours=since_hours)

    all_findings = []
    totals = {"files": 0, "lines": 0, "shell_tool_use": 0, "tool_results": 0,
              "rewritten_nodes": 0, "unterminated": 0, "findings": 0}
    per_form = {}
    started = time.monotonic()

    for path in paths:
        try:
            findings, stats = scan_file(path, min_wait, tools, since_dt)
        except OSError as err:
            print(f"ERROR reading {path}: {err}", file=sys.stderr)
            continue
        totals["files"] += 1
        for key in ("lines", "shell_tool_use", "tool_results", "rewritten_nodes",
                    "unterminated", "findings"):
            totals[key] += stats[key]
        for finding in findings:
            finding["file"] = str(path)
            finding["session"] = path.stem
            per_form[finding["form"]] = per_form.get(finding["form"], 0) + 1
        all_findings.extend(findings)

    all_findings.sort(key=lambda f: -f["gap_s"])
    if top is not None:
        all_findings = all_findings[:top]
    totals["per_form"] = per_form
    totals["elapsed_s"] = round(time.monotonic() - started, 1)

    if not as_json:
        for finding in all_findings:
            print(f"  [{finding['form']:>11}] {finding['gap_s']:>9.1f}s  {finding['ts']}  "
                  f"{finding['tool']}  {finding['command'][:120]}")
            print(f"               session={finding['session']}  line={finding['line']}"
                  f"{'  sidechain' if finding['sidechain'] else ''}"
                  f"{'  ERROR' if finding['is_error'] else ''}")
    return all_findings, totals


def selftest():
    """Synthetic fixtures: long composed-cd wait (flag), plain fast (pass), non-shell tool
    with long gap (pass), resume copy (no double count), unterminated (counted, no finding)."""
    def node(node_type, uuid, parent, ts, blocks, role):
        return json.dumps({"type": node_type, "uuid": uuid, "parentUuid": parent,
                           "timestamp": ts, "message": {"role": role, "content": blocks}})

    u1, r1 = "uuid-a1", "uuid-r1"

    def tooluse(tid, name, command):
        return {"type": "tool_use", "id": tid, "name": name, "input": {"command": command}}

    def toolresult(tid, error=False):
        return {"type": "tool_result", "tool_use_id": tid, "is_error": error, "content": "ok"}

    wait_session = "\n".join([
        node("assistant", u1, "u0", "2026-10-15T07:30:00.000Z",
             [tooluse("t1", "Bash", "cd /d/CoursIA && rm -rf /d/CoursIA-wt-pr20891 && ls")], "assistant"),
        node("user", r1, u1, "2026-10-15T08:37:06.000Z", [toolresult("t1")], "user"),
        # Plain fast command -> never a finding at any sane threshold.
        node("assistant", "u2", r1, "2026-10-15T08:37:10.000Z",
             [tooluse("t2", "Bash", "git status")], "assistant"),
        node("user", "r2", "u2", "2026-10-15T08:37:12.000Z", [toolresult("t2")], "user"),
        # Non-shell tool with a huge gap -> out of scope by default.
        node("assistant", "u3", "r2", "2026-10-15T08:37:20.000Z",
             [tooluse("t3", "Read", {"file_path": "/x"})], "assistant"),
        node("user", "r3", "u3", "2026-10-15T09:37:20.000Z", [toolresult("t3")], "user"),
        # Unterminated tool_use (session cut) -> counted, no finding.
        node("assistant", "u4", "r3", "2026-10-15T09:40:00.000Z",
             [tooluse("t4", "Bash", "echo hi")], "assistant"),
    ])
    copy_session = "\n".join([
        node("assistant", u1, "u0", "2026-10-15T07:30:00.000Z",
             [tooluse("t1", "Bash", "cd /x && rm -rf y")], "assistant"),
        node("user", r1, u1, "2026-10-15T08:37:06.000Z", [toolresult("t1")], "user"),
        # Resume re-append: same uuids verbatim -> skipped, no second finding.
        node("assistant", u1, "u0", "2026-10-15T07:30:00.000Z",
             [tooluse("t1", "Bash", "cd /x && rm -rf y")], "assistant"),
        node("user", r1, u1, "2026-10-15T08:37:06.000Z", [toolresult("t1")], "user"),
    ])

    with tempfile.TemporaryDirectory() as tmp:
        wait_path = Path(tmp) / "wait.jsonl"
        copy_path = Path(tmp) / "copy.jsonl"
        wait_path.write_text(wait_session + "\n", encoding="utf-8")
        copy_path.write_text(copy_session + "\n", encoding="utf-8")

        findings, stats = scan_file(wait_path, min_wait=120, tools=DEFAULT_TOOLS)
        assert len(findings) == 1, f"expected exactly 1 finding, got {len(findings)}: {findings}"
        only = findings[0]
        assert only["form"] == "composed-cd", f"expected composed-cd, got {only['form']}"
        assert only["gap_s"] == 4026.0, f"expected 4026.0s gap, got {only['gap_s']}"
        assert only["tool"] == "Bash"
        assert stats["shell_tool_use"] == 3, f"expected 3 shell tool_use, got {stats['shell_tool_use']}"
        assert stats["unterminated"] == 1, f"expected 1 unterminated, got {stats['unterminated']}"

        copy_findings, copy_stats = scan_file(copy_path, min_wait=120, tools=DEFAULT_TOOLS)
        assert len(copy_findings) == 1, f"resume copy must not double-report, got {len(copy_findings)}"
        assert copy_stats["rewritten_nodes"] == 2, \
            f"copy fixture must count 2 rewritten nodes, got {copy_stats['rewritten_nodes']}"

        # Classifier spot-checks (mandate suspects).
        assert classify("rm -rf /d/foo") == "rm-rf"
        assert classify("wsl -d Ubuntu -- bash -lc 'echo'") == "wsl"
        assert classify("a && b") == "composed"
        assert classify("git status") == "plain"
        assert classify("echo\necho") == "multiline"

    print("selftest OK: composed-cd wait (4026s) flagged; fast plain, non-shell long gap and")
    print("             resume copies pass clean; unterminated counted; classifier on suspects.")
    return EXIT_CLEAN


def main():
    parser = argparse.ArgumentParser(
        description="Measure shell tool_use -> tool_result gaps in Claude Code transcripts (issue #4214).")
    parser.add_argument("--root", type=Path, help="scan this directory recursively (default: ~/.claude/projects)")
    parser.add_argument("--file", type=Path, help="scan a single session JSONL")
    parser.add_argument("--min-wait", type=float, default=120.0,
                        help="report gaps >= this many seconds (default: 120)")
    parser.add_argument("--tools", default=",".join(DEFAULT_TOOLS),
                        help="comma-separated tool names to watch (default: Bash,PowerShell)")
    parser.add_argument("--since-hours", type=float, default=None,
                        help="only report tool_use emitted within this window")
    parser.add_argument("--top", type=int, default=None, help="keep only the N longest gaps")
    parser.add_argument("--json", action="store_true", help="machine-readable output")
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

    tools = [t.strip() for t in args.tools.split(",") if t.strip()] or list(DEFAULT_TOOLS)
    findings, totals = scan_target(target, args.min_wait, tools, args.since_hours,
                                   as_json=args.json, top=args.top)

    if args.json:
        print(json.dumps({"target": str(target), "tools": tools,
                          "min_wait_s": args.min_wait, "totals": totals, "findings": findings},
                         ensure_ascii=False, indent=2))
    else:
        print(f"\nscanned {totals['files']} file(s), {totals['lines']} lines, "
              f"{totals['shell_tool_use']} shell tool_use, {totals['tool_results']} results, "
              f"{totals['rewritten_nodes']} rewritten nodes (resume copies), "
              f"{totals['unterminated']} unterminated, in {totals['elapsed_s']}s")
        if findings:
            forms = ", ".join(f"{k}={v}" for k, v in sorted(totals["per_form"].items()))
            print(f"RESULT: {totals['findings']} wait(s) >= {args.min_wait:.0f}s  [{forms}] — longest first")
        else:
            print(f"RESULT: clean — no shell tool gap >= {args.min_wait:.0f}s")

    sys.exit(EXIT_FINDINGS if findings else EXIT_CLEAN)


if __name__ == "__main__":
    main()
