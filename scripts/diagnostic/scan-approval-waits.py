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
and reports pairs whose gap exceeds a threshold, classified by command form. Command
excerpts are redacted before output (volet 1b): secret VALUES never leave this script.

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
    python scan-approval-waits.py --hook-log ~/.claude/tool-start-log.jsonl  # volet 3b join
    python scan-approval-waits.py --selftest                       # synthetic fixture validation

Volet 3b (--hook-log): the journal written by the PreToolUse hook log-tool-start.js
carries the instant each shell tool STARTS executing. Joining on (session, tool, raw
command) + time window splits every gap into pre_exec_s (approval wait + client
overhead) and exec_s (execution), labeled approval|exec — the transcript alone
cannot draw that line (a 320s `npx vitest run` is an execution, not a wait).

Exit codes: 0 = no finding, 2 = findings, 1 = error.
"""

import argparse
import json
import re
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

# Secret redaction (volet 1b, dispatch c.26; follow-up c.27): findings carry raw
# command excerpts by design, and a transcript can hold a secret that was legitimate
# in its context — the NAME stays visible, the VALUE becomes [REDACTED] before the
# excerpt reaches any output that can be pasted on a dashboard, issue or PR. The
# c.27 follow-up covers the #4227 review residuals: assignment families are
# case-insensitive and accept flag forms (--token=), quoted values mask whole
# ("k1 k2" -> [REDACTED]), and credentials embedded in URLs lose user:pass.
_SECRET_SUBS = (
    (re.compile(r"\b(sk)-[A-Za-z0-9_\-]{8,}"), r"\1-[REDACTED]"),
    (re.compile(r"\b(ghp|gho|ghu|ghs)_[A-Za-z0-9_]{8,}"), r"\1_[REDACTED]"),
    (re.compile(r"\b(Bearer\s+)\S+"), r"\1[REDACTED]"),
    (re.compile(r"\b(x-(?:proxy|api)-key[=:]\s*)\S+", re.IGNORECASE), r"\1[REDACTED]"),
    (re.compile(r"\b([A-Za-z][a-zA-Z0-9+.\-]*://)([^/\s:@\"]+):([^/\s@\"]+)@"),
     r"\1[REDACTED]@"),
    (re.compile(r"(?<![\w.\-])((?:--?)?[A-Za-z0-9_.\-]*?(?:api_key|token|secret|password)"
                r"[A-Za-z0-9_]*)([=:]\s*)(?:\"[^\"]*\"|'[^']*'|\S+)",
                re.IGNORECASE),
     r"\1\2[REDACTED]"),
)


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


def redact(text):
    """Mask secret VALUES, keep the name — applied BEFORE truncation so a cut-off
    excerpt can never leak a partial value that the pattern would have matched."""
    for pattern, repl in _SECRET_SUBS:
        text = pattern.sub(repl, text)
    return text


def load_hook_log(paths):
    """Index the log-tool-start journal(s) (#4214 volet 3b). Rotation keeps a single
    generation, so both <path> and <path>.1 are read when present. Key is
    (session_id, tool, RAW command) -> sorted execution-start timestamps — the raw
    fingerprint stays in the index and never reaches any output. An entry without
    session_id cannot be scoped to a transcript: counted, not indexed."""
    index = {}
    entries, unscoped = 0, 0
    for path in paths:
        if path is None or not path.exists():
            continue
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                except ValueError:
                    continue
                ts = parse_ts(entry.get("ts"))
                session_id = entry.get("session_id")
                if ts is None or not session_id:
                    unscoped += 1
                    continue
                index.setdefault((session_id, entry.get("tool"), entry.get("command")), []).append(ts)
                entries += 1
    for stamps in index.values():
        stamps.sort()
    return index, entries, unscoped


def adjudicate(finding, hook_index, session, raw_command):
    """Split the finding's gap with its execution-start marker (volet 3b):
    pre_exec_s = tool_use -> hook_ts (approval wait + client overhead),
    exec_s = hook_ts -> tool_result (execution). Adjudication 'exec' when the
    execution holds the majority of the gap, else 'approval' — a marker AFTER
    the result ts (or none in window) leaves the finding unmatched. Window is
    [tool_use, tool_use + gap_s]: the execution start precedes the result by
    contract, so a post-result marker (Hermes repro, po-2025 review: result
    +1.5s -> exec_s < 0) is rejected rather than misjoined — leaving the
    finding unmatched is the fail-safe direction."""
    from datetime import timedelta
    started = parse_ts(finding["ts"])
    if started is None:
        return False
    candidates = hook_index.get((session, finding["tool"], raw_command))
    if not candidates:
        return False
    upper = started + timedelta(seconds=finding["gap_s"])
    for ts in candidates:
        if started <= ts <= upper:
            finding["pre_exec_s"] = round((ts - started).total_seconds(), 1)
            finding["exec_s"] = round(finding["gap_s"] - finding["pre_exec_s"], 1)
            finding["adjudication"] = "exec" if finding["exec_s"] > finding["pre_exec_s"] else "approval"
            return True
    return False


def scan_file(path, min_wait, tools, since_dt=None, hook_index=None):
    """Scan one session JSONL. Returns (findings, stats).

    Nodes sharing a uuid already seen are resume-copy artifacts (verbatim re-append of a
    prior transcript range — see scan-duplicate-tool-use.py ground truth): skipped, counted
    in stats['rewritten_nodes'] so a resumed session never double-reports a wait.

    hook_index (volet 3b): when given, each finding is adjudicated with its
    execution-start marker — joined/unjoined counters in stats.
    """
    tools_lower = {t.lower() for t in tools}
    pending = {}  # tool_use_id -> record (first emission only)
    findings = []
    stats = {"lines": 0, "shell_tool_use": 0, "tool_results": 0,
             "rewritten_nodes": 0, "unterminated": 0, "findings": 0,
             "joined": 0, "unjoined": 0}
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
                    finding = {
                        "tool_use_id": tid,
                        "tool": record["tool"],
                        "form": classify(command),
                        "gap_s": gap,
                        "ts": record["ts"],
                        "line": record["line"],
                        "command": redact(command)[:200],
                        "is_error": bool(block.get("is_error")),
                        "sidechain": record["sidechain"],
                    }
                    if hook_index is not None:
                        if adjudicate(finding, hook_index, path.stem, command):
                            stats["joined"] += 1
                        else:
                            stats["unjoined"] += 1
                    findings.append(finding)

    stats["unterminated"] = len(pending)
    stats["findings"] = len(findings)
    findings.sort(key=lambda f: (-f["gap_s"], f["line"]))
    return findings, stats


def scan_target(target, min_wait, tools, since_hours=None, as_json=False, top=None,
                hook_log=None):
    """target: file or directory. Returns (findings, totals).

    hook_log (volet 3b): path to the log-tool-start journal — both it and its
    rotated `.1` are indexed, and every finding gets its gap split into
    pre_exec_s / exec_s with an adjudication (approval|exec)."""
    paths = [target] if target.is_file() else sorted(target.rglob("*.jsonl"))
    since_dt = None
    if since_hours is not None:
        from datetime import datetime, timedelta, timezone
        since_dt = datetime.now(timezone.utc) - timedelta(hours=since_hours)

    hook_index, hook_entries, hook_unscoped = (None, 0, 0)
    if hook_log is not None:
        hook_index, hook_entries, hook_unscoped = load_hook_log(
            [hook_log, Path(str(hook_log) + ".1")])

    all_findings = []
    totals = {"files": 0, "lines": 0, "shell_tool_use": 0, "tool_results": 0,
              "rewritten_nodes": 0, "unterminated": 0, "findings": 0,
              "joined": 0, "unjoined": 0}
    per_form = {}
    per_adjudication = {}
    started = time.monotonic()

    for path in paths:
        try:
            findings, stats = scan_file(path, min_wait, tools, since_dt,
                                        hook_index=hook_index)
        except OSError as err:
            print(f"ERROR reading {path}: {err}", file=sys.stderr)
            continue
        totals["files"] += 1
        for key in ("lines", "shell_tool_use", "tool_results", "rewritten_nodes",
                    "unterminated", "findings", "joined", "unjoined"):
            totals[key] += stats[key]
        for finding in findings:
            finding["file"] = str(path)
            finding["session"] = path.stem
            per_form[finding["form"]] = per_form.get(finding["form"], 0) + 1
            if "adjudication" in finding:
                per_adjudication[finding["adjudication"]] = \
                    per_adjudication.get(finding["adjudication"], 0) + 1
        all_findings.extend(findings)

    all_findings.sort(key=lambda f: -f["gap_s"])
    if top is not None:
        all_findings = all_findings[:top]
    totals["per_form"] = per_form
    if hook_index is not None:
        totals["hook_log_entries"] = hook_entries
        totals["hook_log_unscoped"] = hook_unscoped
        totals["per_adjudication"] = per_adjudication
    totals["elapsed_s"] = round(time.monotonic() - started, 1)

    if not as_json:
        for finding in all_findings:
            print(f"  [{finding['form']:>11}] {finding['gap_s']:>9.1f}s  {finding['ts']}  "
                  f"{finding['tool']}  {finding['command'][:120]}")
            split = ""
            if "adjudication" in finding:
                split = (f"  pre={finding['pre_exec_s']:.1f}s exec={finding['exec_s']:.1f}s"
                         f" [{finding['adjudication']}]")
            print(f"               session={finding['session']}  line={finding['line']}"
                  f"{split}"
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
        # Secret-bearing command, long wait -> finding whose excerpt must be redacted.
        node("assistant", "u5", "r3", "2026-10-15T09:38:00.000Z",
             [tooluse("t5", "Bash", "export API_KEY=sk-0123456789abcdefgh && "
                                   "GH_TOKEN=ghp_0123456789abcdefghij curl -s "
                                   "-H x-api-key:k0123456789 https://example.com/feed")], "assistant"),
        node("user", "r5", "u5", "2026-10-15T09:41:20.000Z", [toolresult("t5")], "user"),
        # Unterminated tool_use (session cut) -> counted, no finding.
        node("assistant", "u4", "r5", "2026-10-15T09:45:00.000Z",
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
        assert len(findings) == 2, f"expected exactly 2 findings, got {len(findings)}: {findings}"
        longest = findings[0]
        assert longest["form"] == "composed-cd", f"expected composed-cd, got {longest['form']}"
        assert longest["gap_s"] == 4026.0, f"expected 4026.0s gap, got {longest['gap_s']}"
        assert longest["tool"] == "Bash"
        # Volet 1b: the secret-bearing finding keeps the names, never the values.
        assert findings[1]["command"] == (
            "export API_KEY=[REDACTED] && GH_TOKEN=[REDACTED] curl -s "
            "-H x-api-key:[REDACTED] https://example.com/feed"), findings[1]["command"]
        assert stats["shell_tool_use"] == 4, f"expected 4 shell tool_use, got {stats['shell_tool_use']}"
        assert stats["unterminated"] == 1, f"expected 1 unterminated, got {stats['unterminated']}"

        # Redaction unit spot-checks: names stay, values go (Bearer too).
        assert redact("curl -H 'Authorization: Bearer abcdef123456' https://x") == \
            "curl -H 'Authorization: Bearer [REDACTED] https://x"
        assert "sk-0123456789abcdefgh" not in redact("KEY=sk-0123456789abcdefgh")
        assert redact("GH_TOKEN=ghp_0123456789abcdefghij git push") == \
            "GH_TOKEN=[REDACTED] git push"

        # Follow-up (c.27 review residuals): lowercase and flag-form assignments,
        # credentials embedded in URLs, quoted multi-word values.
        assert redact("api_token=abc123xyz git push") == "api_token=[REDACTED] git push"
        assert redact("gh auth login --token=ghp_0123456789abcdefghij") == \
            "gh auth login --token=[REDACTED]"
        assert redact("curl https://user:pass@example.com/feed") == \
            "curl https://[REDACTED]@example.com/feed"
        assert redact('PASSWORD="two words here" run') == 'PASSWORD=[REDACTED] run'

        copy_findings, copy_stats = scan_file(copy_path, min_wait=120, tools=DEFAULT_TOOLS)
        assert len(copy_findings) == 1, f"resume copy must not double-report, got {len(copy_findings)}"
        assert copy_stats["rewritten_nodes"] == 2, \
            f"copy fixture must count 2 rewritten nodes, got {copy_stats['rewritten_nodes']}"

        # Volet 3b: hook-log join. t1 (4026s) gets its marker 20s in — execution
        # holds the bulk -> adjudicated 'exec'; t5 (200s) gets its marker at 170s
        # -> the wait precedes execution -> adjudicated 'approval'. The copy
        # session's command is absent from the journal -> unmatched.
        hook_path = Path(tmp) / "tool-start-log.jsonl"
        hook_path.write_text("\n".join(json.dumps(e) for e in [
            {"ts": "2026-10-15T07:30:20.000Z", "session_id": "wait", "tool": "Bash",
             "command": "cd /d/CoursIA && rm -rf /d/CoursIA-wt-pr20891 && ls"},
            {"ts": "2026-10-15T09:40:50.000Z", "session_id": "wait", "tool": "Bash",
             "command": "export API_KEY=sk-0123456789abcdefgh && "
                        "GH_TOKEN=ghp_0123456789abcdefghij curl -s "
                        "-H x-api-key:k0123456789 https://example.com/feed"},
            {"ts": "2026-10-15T10:00:00.000Z", "session_id": None, "tool": "Bash",
             "command": "session-less entry must be counted, not indexed"},
        ]) + "\n", encoding="utf-8")
        index, entries, unscoped = load_hook_log([hook_path])
        assert entries == 2 and unscoped == 1, \
            f"expected 2 scoped + 1 unscoped entries, got {entries}/{unscoped}"

        joined_findings, joined_stats = scan_file(
            wait_path, min_wait=120, tools=DEFAULT_TOOLS, hook_index=index)
        assert joined_stats["joined"] == 2 and joined_stats["unjoined"] == 0, \
            f"both findings must join, got {joined_stats}"
        assert joined_findings[0]["pre_exec_s"] == 20.0 \
            and joined_findings[0]["exec_s"] == 4006.0 \
            and joined_findings[0]["adjudication"] == "exec", joined_findings[0]
        assert joined_findings[1]["pre_exec_s"] == 170.0 \
            and joined_findings[1]["exec_s"] == 30.0 \
            and joined_findings[1]["adjudication"] == "approval", joined_findings[1]
        # The raw fingerprint never leaks into the finding output.
        assert "sk-0123456789abcdefgh" not in json.dumps(joined_findings)

        # Hermes reserve (po-2025 review repro): a marker landing AFTER the
        # result (result + 1.5s here) must NOT join — the execution start
        # precedes the result by contract, and misjoining it would yield a
        # negative exec_s. Unmatched is the fail-safe direction.
        late_index = {("wait", "Bash", "cmd-late"):
                      [parse_ts("2026-10-15T09:41:21.500Z")]}
        late_finding = {"ts": "2026-10-15T09:38:00.000Z", "tool": "Bash",
                        "gap_s": 200.0, "command": "cmd-late"}
        assert adjudicate(late_finding, late_index, "wait", "cmd-late") is False
        assert "adjudication" not in late_finding and "exec_s" not in late_finding

        unmatched_findings, unmatched_stats = scan_file(
            copy_path, min_wait=120, tools=DEFAULT_TOOLS, hook_index=index)
        assert len(unmatched_findings) == 1 \
            and unmatched_stats["joined"] == 0 and unmatched_stats["unjoined"] == 1, \
            f"copy-session finding must stay unmatched, got {unmatched_stats}"
        assert "adjudication" not in unmatched_findings[0]

        # Classifier spot-checks (mandate suspects).
        assert classify("rm -rf /d/foo") == "rm-rf"
        assert classify("wsl -d Ubuntu -- bash -lc 'echo'") == "wsl"
        assert classify("a && b") == "composed"
        assert classify("git status") == "plain"
        assert classify("echo\necho") == "multiline"

    print("selftest OK: composed-cd wait (4026s) flagged; fast plain, non-shell long gap and")
    print("             resume copies pass clean; unterminated counted; classifier on suspects;")
    print("             secret-bearing excerpt redacted (names kept, values [REDACTED]);")
    print("             lowercase/flag assignments, URL creds and quoted values covered;")
    print("             hook-log join splits pre/exec and adjudicates approval vs exec;")
    print("             post-result markers are rejected (window closes at the result).")
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
    parser.add_argument("--hook-log", type=Path, default=None, metavar="PATH",
                        help="adjudicate findings with the log-tool-start journal "
                             "(#4214 volet 3b): PATH and PATH.1 are indexed, each gap is "
                             "split into pre_exec_s (approval wait + overhead) and exec_s "
                             "(execution), labeled approval|exec")
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
                                   as_json=args.json, top=args.top, hook_log=args.hook_log)

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
