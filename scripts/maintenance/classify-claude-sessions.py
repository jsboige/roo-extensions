#!/usr/bin/env python3
"""
classify-claude-sessions.py — Identify thrashing vs legitimate Claude Code sessions.

Usage:
    python scripts/maintenance/classify-claude-sessions.py [--top N] [--delete-thrashing]

Modes:
    Default   : Analyze all sessions > 100KB, classify, report top N
    --delete  : Also delete thrashing session files (USE WITH CAUTION)

Classification is based on:
    1. Tool call diversity and patterns
    2. Error retry loops (502, CLI failures, unrecognized arguments)
    3. File edit count (real work = actual file changes)
    4. Compaction count (legitimate long sessions compact frequently)
    5. Empty response ratio (thrashing = high empty ratio)
"""

import json
import sys
import os
import argparse
from pathlib import Path
from collections import Counter
from datetime import datetime


def parse_session(jsonl_path: Path) -> dict | None:
    """Parse a Claude Code JSONL session and extract classification signals."""
    size_mb = jsonl_path.stat().st_size / (1024 * 1024)
    if size_mb < 0.05:  # Skip < 50KB
        return None

    tool_uses = []
    bash_commands = []
    edit_targets = []
    user_msgs = []
    compact_count = 0
    thinking_blocks = 0
    empty_text_count = 0
    total_text_len = 0
    error_events = []
    total_lines = 0

    with open(jsonl_path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            total_lines += 1
            try:
                msg = json.loads(line.strip())
            except Exception:
                continue

            message = msg.get("message", {})
            is_compact = msg.get("isCompactSummary", False)
            if not isinstance(message, dict):
                continue

            role = message.get("role", "")
            content = message.get("content", "")

            if is_compact:
                compact_count += 1

            if role == "user":
                if isinstance(content, str) and content.strip():
                    user_msgs.append(content[:500])
                elif isinstance(content, list):
                    for b in content:
                        if isinstance(b, dict) and b.get("type") == "text" and b.get("text", "").strip():
                            user_msgs.append(b["text"][:500])
                            break

            elif role == "assistant":
                if isinstance(content, list):
                    for block in content:
                        if not isinstance(block, dict):
                            continue
                        btype = block.get("type", "")

                        if btype == "thinking":
                            thinking_blocks += 1

                        elif btype == "text":
                            txt = block.get("text", "")
                            total_text_len += len(txt)
                            if not txt.strip():
                                empty_text_count += 1

                        elif btype == "tool_use":
                            tname = block.get("name", "")
                            tinput = block.get("input", {})
                            tool_uses.append({"name": tname, "input": tinput})

                            if tname == "Bash":
                                cmd = tinput.get("command", "")
                                bash_commands.append(cmd[:300])
                            elif tname in ("Edit", "Write"):
                                fp = tinput.get("file_path", "")
                                if fp:
                                    edit_targets.append(fp)

            # Detect errors in tool results
            if isinstance(content, list):
                for block in content:
                    if isinstance(block, dict) and block.get("type") == "tool_result":
                        rc = block.get("content", "")
                        rc_text = ""
                        if isinstance(rc, str):
                            rc_text = rc
                        elif isinstance(rc, list):
                            rc_text = " ".join(
                                rb.get("text", "") for rb in rc
                                if isinstance(rb, dict) and rb.get("type") == "text"
                            )
                        # Check for CLI errors (not JSON responses containing "error" as key)
                        cli_errors = [
                            "unrecognized arguments:",
                            "command not found",
                            "No such file or directory",
                            "Exit code 1",
                            "usage: ",
                            "error: ",
                        ]
                        for sig in cli_errors:
                            if sig in rc_text and "success" not in rc_text[:50]:
                                error_events.append(rc_text[:200])
                                break

    if not tool_uses and not user_msgs:
        return None

    # Build result
    tool_counter = Counter(t["name"] for t in tool_uses)
    unique_tools = len(tool_counter)
    total_tools = len(tool_uses)
    unique_files = len(set(os.path.basename(f) for f in edit_targets)) if edit_targets else 0
    total_edits = len(edit_targets)
    error_ratio = len(error_events) / max(total_tools, 1)

    # First user message for context
    first_msg = ""
    if user_msgs:
        first_msg = user_msgs[0].replace("\n", " ").strip()[:150]

    return {
        "path": str(jsonl_path),
        "size_mb": round(size_mb, 2),
        "total_lines": total_lines,
        "user_msgs": len(user_msgs),
        "compactions": compact_count,
        "thinking_blocks": thinking_blocks,
        "total_tools": total_tools,
        "unique_tools": unique_tools,
        "total_edits": total_edits,
        "unique_files": unique_files,
        "error_count": len(error_events),
        "error_ratio": round(error_ratio, 3),
        "empty_text": empty_text_count,
        "text_output_chars": total_text_len,
        "top_tools": tool_counter.most_common(5),
        "first_msg": first_msg,
        "bash_commands": bash_commands[:10],
    }


def classify(session: dict) -> tuple[str, list[str]]:
    """Classify a session. Returns (verdict, reasons)."""
    signals = []

    # THRASHING: high CLI error rate with low file output
    if session["error_count"] > 10 and session["error_ratio"] > 0.3 and session["unique_files"] <= 1:
        signals.append(f"high CLI errors ({session['error_count']}, ratio={session['error_ratio']:.0%}) with {session['unique_files']} files")

    # THRASHING: many tool calls, zero file edits, zero compactions
    if session["total_tools"] > 30 and session["total_edits"] == 0 and session["compactions"] == 0:
        signals.append(f"{session['total_tools']} tools, 0 edits, 0 compactions")

    # THRASHING: very few user messages and many empty text blocks
    if session["user_msgs"] <= 3 and session["empty_text"] > session["total_tools"] * 0.5:
        signals.append(f"low user interaction ({session['user_msgs']} msgs), high empty responses")

    if signals:
        return "THRASHING", signals

    # LEGITIMATE-HEAVY: many compactions + diverse tools + file edits
    if session["compactions"] >= 5 and session["unique_tools"] >= 8 and session["unique_files"] >= 2:
        return "LEGITIMATE-HEAVY", [f"{session['compactions']} compactions, {session['total_tools']} tools, {session['unique_files']} files"]

    # LEGITIMATE: reasonable tool count and file edits
    if session["total_tools"] >= 15 and session["unique_files"] >= 1:
        return "LEGITIMATE", [f"{session['total_tools']} tools, {session['unique_files']} files"]

    # STUCK: tools but no progress
    if session["total_tools"] >= 15 and session["total_edits"] == 0:
        return "STUCK", [f"{session['total_tools']} tools but 0 file edits"]

    # SCHEDULER-EPHEMERAL
    if session["user_msgs"] <= 2 and session["total_tools"] <= 3:
        return "SCHEDULER-EPHEMERAL", [f"{session['user_msgs']} msgs, {session['total_tools']} tools"]

    # LIGHT
    return "LIGHT", [f"{session['total_tools']} tools"]


def main():
    parser = argparse.ArgumentParser(description="Classify Claude Code sessions: thrashing vs legitimate")
    parser.add_argument("--top", type=int, default=30, help="Number of top sessions to detail")
    parser.add_argument("--delete-thrashing", action="store_true", help="Delete thrashing session files")
    parser.add_argument("--min-size", type=float, default=0.1, help="Minimum session size in MB to analyze (default: 0.1)")
    args = parser.parse_args()

    claude_projects = Path.home() / ".claude" / "projects"
    if not claude_projects.exists():
        print(f"ERROR: {claude_projects} does not exist")
        sys.exit(1)

    # Scan all sessions
    print("Scanning sessions...")
    sessions = []
    for jsonl_file in claude_projects.rglob("*.jsonl"):
        try:
            result = parse_session(jsonl_file)
            if result:
                sessions.append(result)
        except Exception as e:
            print(f"  ERROR: {jsonl_file.name}: {e}", file=sys.stderr)

    sessions.sort(key=lambda x: -x["size_mb"])
    print(f"Found {len(sessions)} sessions > {args.min_size} MB\n")

    # Classify all
    classified = []
    for s in sessions:
        verdict, reasons = classify(s)
        s["verdict"] = verdict
        s["reasons"] = reasons
        classified.append(s)

    # Summary
    by_verdict = Counter(s["verdict"] for s in classified)
    size_by_verdict = {}
    for v in by_verdict:
        size_by_verdict[v] = sum(s["size_mb"] for s in classified if s["verdict"] == v)
    total_mb = sum(s["size_mb"] for s in classified)

    print("=" * 80)
    print(f"SESSION CLASSIFICATION — {os.environ.get('COMPUTERNAME', 'unknown')}")
    print("=" * 80)
    print(f"Total: {len(classified)} sessions, {total_mb:.0f} MB\n")

    fmt = "  {:<25} {:>5} {:>10} {:>8} {:>10}"
    print(fmt.format("Verdict", "Count", "Size(MB)", "%Size", "Avg Tools"))
    print("-" * 80)
    for v in ["THRASHING", "LEGITIMATE-HEAVY", "LEGITIMATE", "STUCK", "LIGHT", "SCHEDULER-EPHEMERAL"]:
        cnt = by_verdict.get(v, 0)
        sz = size_by_verdict.get(v, 0)
        pct = sz / total_mb * 100 if total_mb else 0
        avg_tools = sum(s["total_tools"] for s in classified if s["verdict"] == v) / max(cnt, 1)
        print(fmt.format(v, cnt, f"{sz:.0f}", f"{pct:.1f}%", f"{avg_tools:.0f}"))

    # Detail top sessions
    print(f"\n{'=' * 80}")
    print(f"TOP {args.top} SESSIONS (by size)")
    print(f"{'=' * 80}")

    for s in classified[: args.top]:
        verdict_mark = {"THRASHING": "⚠", "LEGITIMATE-HEAVY": "✓", "LEGITIMATE": "✓", "STUCK": "◇", "LIGHT": "·", "SCHEDULER-EPHEMERAL": "·"}.get(s["verdict"], "?")
        print(f"\n  {verdict_mark} {s['verdict']} | {s['size_mb']:.1f} MB | tools={s['total_tools']} ({s['unique_tools']} uniq) | edits={s['total_edits']} ({s['unique_files']} files) | compactions={s['compactions']}")
        print(f"    Reason: {'; '.join(s['reasons'])}")
        rel = s["path"].replace(str(claude_projects), "").lstrip("/\\")
        print(f"    File: ...{rel[-70:]}")
        if s["first_msg"]:
            print(f"    Start: {s['first_msg'][:120]}")

    # Thrashing sessions detail
    thrashing = [s for s in classified if s["verdict"] == "THRASHING"]
    if thrashing:
        thrashing_mb = sum(s["size_mb"] for s in thrashing)
        print(f"\n{'=' * 80}")
        print(f"THRASHING SESSIONS — {len(thrashing)} sessions, {thrashing_mb:.1f} MB")
        print(f"{'=' * 80}")
        for s in thrashing:
            rel = s["path"].replace(str(claude_projects), "").lstrip("/\\")
            print(f"  {s['size_mb']:>7.1f} MB | {s['total_tools']:>4} tools | {s['unique_files']} files | {'; '.join(s['reasons'])}")
            print(f"           {rel}")

        if args.delete_thrashing:
            print(f"\n  DELETING {len(thrashing)} thrashing session files...")
            for s in thrashing:
                try:
                    os.remove(s["path"])
                    print(f"    DELETED: {s['size_mb']:.1f} MB — {os.path.basename(s['path'])}")
                except Exception as e:
                    print(f"    ERROR: {s['path']}: {e}")
            print(f"  Freed {thrashing_mb:.1f} MB")
        else:
            print(f"\n  To delete these sessions, re-run with --delete-thrashing")

    # Cleanup recommendation
    waste_mb = size_by_verdict.get("THRASHING", 0)
    print(f"\n{'=' * 80}")
    print("CLEANUP RECOMMENDATION")
    print(f"{'=' * 80}")
    print(f"  Thrashing: {waste_mb:.0f} MB ({len(thrashing)} sessions) → DELETE")
    print(f"  Stuck:     {size_by_verdict.get('STUCK', 0):.0f} MB → REVIEW (may be legitimate stalled work)")
    print(f"  Legitimate: {total_mb - waste_mb:.0f} MB → KEEP (real work with compactions)")

    if not args.delete_thrashing and thrashing:
        print(f"\n  Run again with --delete-thrashing to clean up {waste_mb:.0f} MB of thrashing sessions.")


if __name__ == "__main__":
    main()
