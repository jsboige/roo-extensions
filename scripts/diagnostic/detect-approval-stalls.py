#!/usr/bin/env python3
"""Detect Claude Code sessions currently stalled on an approval wait (#4243, volet 3).

A session frozen on a silent approval wait has a distinctive transcript tail: an
assistant message carrying a shell `tool_use` whose `tool_result` never arrives —
nothing is appended to the JSONL while the client sits on the permission prompt
(measured incidents, issue #4243: ~1 h and ~16 h freezes in bypass mode). The
signature is transcript-only and needs no live process access, so it works on any
seat and on copied transcripts alike:

    last shell tool_use unterminated at EOF + age >= N minutes -> stall report.

Exit codes mirror scan-approval-waits: 0 clean, 1 error, 2 waiting stalls
(with --hook-log, a tail adjudicated executing does not trip 2) -- a
scheduler can use the exit code alone as the signal.

Usage:
    python detect-approval-stalls.py                     # ~/.claude/projects, >= 10 min
    python detect-approval-stalls.py --min-minutes 5     # tighter threshold
    python detect-approval-stalls.py --root <dir>        # copied transcripts (e.g. incident)
    python detect-approval-stalls.py --hook-log PATH     # adjudicate waits vs executions (#4214)
    python detect-approval-stalls.py --dashboard [...]   # WARN note on the lane dashboard
                                                          # when waiting stalls are found (#4243
                                                          # volet 3; bearer via env or arg)
    python detect-approval-stalls.py --json              # machine-readable
    python detect-approval-stalls.py --selftest

The hook-log join (#4214 log-tool-start journal) separates the two states a bare
dangling tool_use cannot: `waiting-suspected` (no execution marker -- the approval
never came) vs `executing` (marker at/after the tool_use -- the command runs or
ran; the transcript tail lags). Without --hook-log every dangling tail reports as
waiting-suspected.

The `abandoned` state (review nit on #4245, real case 2d17885a 12/10) retires a
third shape: a SIDECHAIN tool_use that dangles while the parent session kept
writing after it -- the subagent was orphaned mid-wait, nobody will ever answer,
yet the dangling tail reads "live" until the mtime window rolls it off (days).
Sidechain records live in the parent's JSONL (per-record isSidechain flag), so
the join is same-file: parent activity after the tool_use ts -> abandoned. An
abandoned tail is reported for visibility but does NOT trip exit 2 (like
executing, it is not an approval wait someone could still answer).
"""

import argparse
import hashlib
import http.client
import importlib.util
import json
import os
import sys
import tempfile
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

# Shared helpers live in a hyphen-named sibling -- load it by path so the secret
# redaction families stay single-source (they evolve with review follow-ups, see
# scan-approval-waits.py #4227).
_SIBLING = Path(__file__).resolve().parent / "scan-approval-waits.py"
_spec = importlib.util.spec_from_file_location("scan_approval_waits", _SIBLING)
_saw = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_saw)

EXIT_CLEAN = _saw.EXIT_CLEAN
EXIT_ERROR = _saw.EXIT_ERROR
EXIT_FINDINGS = _saw.EXIT_FINDINGS
DEFAULT_TOOLS = _saw.DEFAULT_TOOLS
parse_ts = _saw.parse_ts
delta_s = _saw.delta_s
command_of = _saw.command_of
redact = _saw.redact

PREVIEW_CHARS = 160


def now_utc():
    return datetime.now(timezone.utc)


def scan_session(path, tools):
    """Parse one session JSONL. Returns (dangling, last_ts, last_parent_ts, stats).

    dangling: list of unterminated shell tool_use records at EOF, in emission
    order (uuid-deduped against resume copies, same rule as scan-approval-waits).
    last_parent_ts: timestamp of the last non-sidechain record -- the parent
    session's own watermark, used to retire orphaned sidechain waits (abandoned).
    """
    tools_lower = {t.lower() for t in tools}
    pending = {}
    stats = {"lines": 0, "rewritten_nodes": 0, "shell_tool_use": 0}
    seen_uuids = set()
    last_ts = None
    last_parent_ts = None
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for lineno, line in enumerate(fh, 1):
            stats["lines"] += 1
            try:
                entry = json.loads(line)
            except ValueError:
                continue
            if not isinstance(entry, dict):
                continue
            if entry.get("timestamp"):
                last_ts = entry["timestamp"]  # tracked on every record: the tail lag
                if not entry.get("isSidechain"):
                    last_parent_ts = entry["timestamp"]
            if '"tool_use"' not in line and '"tool_result"' not in line:
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
            for block in content:
                if not isinstance(block, dict):
                    continue
                btype = block.get("type")
                if btype == "tool_use" and block.get("id"):
                    if (block.get("name") or "").lower() not in tools_lower:
                        continue
                    tid = block["id"]
                    if tid in pending:
                        continue
                    stats["shell_tool_use"] += 1
                    pending[tid] = {
                        "line": lineno,
                        "ts": entry.get("timestamp"),
                        "tool": block.get("name"),
                        "command": command_of(block),
                        "sidechain": bool(entry.get("isSidechain")),
                    }
                elif btype == "tool_result" and block.get("tool_use_id"):
                    pending.pop(block["tool_use_id"], None)
    return list(pending.values()), last_ts, last_parent_ts, stats


def adjudicate_state(record, session_id, hook_index):
    """waiting-suspected / executing, from the #4214 execution-start journal.

    A marker at or after the tool_use ts means execution began: the dangling
    tail is a transcript lag, not an approval wait. No marker -> the command
    never started -> approval wait suspected (or a refusal nobody answered).
    """
    if hook_index is None:
        return "waiting-suspected"
    candidates = hook_index.get((session_id, record["tool"], record["command"])) or []
    started = parse_ts(record["ts"])
    for ts in candidates:
        if started is not None and ts >= started:
            return "executing"
    return "waiting-suspected"


def detect(root, min_minutes, tools, active_hours, hook_log=None, as_json=False):
    """Scan every session JSONL under root whose mtime falls in the active window.

    The active window is what makes this live rather than forensic: a stalled
    session writes nothing (that IS the symptom), so its mtime pins the moment
    the wait began -- a 16 h freeze is still inside a 7-day default window.
    """
    hook_index = _saw.load_hook_log([Path(hook_log)])[0] if hook_log else None
    cutoff = now_utc().timestamp() - active_hours * 3600
    threshold_s = min_minutes * 60

    stalls = []
    files = active = 0
    for path in sorted(root.rglob("*.jsonl")):
        files += 1
        try:
            if path.stat().st_mtime < cutoff:
                continue
        except OSError:
            continue
        active += 1
        try:
            dangling, _last_ts, last_parent_ts, _stats = scan_session(path, tools)
        except OSError as exc:
            print(f"WARNING: unreadable {path}: {exc}", file=sys.stderr)
            continue
        session_id = path.stem
        project = path.parent.name
        for record in dangling:
            started = parse_ts(record["ts"])
            if started is None:
                continue
            age_s = (now_utc() - started).total_seconds()
            if age_s < threshold_s:
                continue
            parent_ts = parse_ts(last_parent_ts) if record["sidechain"] else None
            if parent_ts is not None and parent_ts > started:
                # Orphaned subagent: the parent session wrote on after this
                # tool_use, so the wait will never be answered -- retire it
                # (review nit #4245, real case 2d17885a: false "live" for days).
                state = "abandoned"
            else:
                state = adjudicate_state(record, session_id, hook_index)
            stalls.append({
                "session": session_id,
                "project": project,
                "since": record["ts"],
                "age_min": round(age_s / 60, 1),
                "tool": record["tool"],
                "command": redact(record["command"] or "")[:PREVIEW_CHARS],
                "sidechain": record["sidechain"],
                "state": state,
            })
    stalls.sort(key=lambda s: -s["age_min"])

    totals = {"files": files, "active": active, "stalls": len(stalls),
              "waiting": sum(1 for s in stalls if s["state"] == "waiting-suspected"),
              "executing": sum(1 for s in stalls if s["state"] == "executing"),
              "abandoned": sum(1 for s in stalls if s["state"] == "abandoned")}
    if as_json:
        print(json.dumps({"root": str(root), "min_minutes": min_minutes,
                          "active_hours": active_hours, "totals": totals,
                          "stalls": stalls}, ensure_ascii=False, indent=2))
    else:
        print(f"\n{totals['active']} active session file(s) of {totals['files']} "
              f"(window {active_hours:g} h) -- {totals['stalls']} stall(s) >= {min_minutes:g} min")
        for s in stalls:
            chain = " [sidechain]" if s["sidechain"] else ""
            print(f"  {s['age_min']:>8.1f} min  {s['state']:<18} {s['project']}/{s['session'][:8]}"
                  f"{chain}  {s['tool']}: {s['command']}")
            print(f"            waiting since {s['since']}")
    return totals, stalls


# --- dashboard signal (#4243 attendu 3) --------------------------------------
#
# The detector's product is stdout + exit code; a scheduler watching them needs
# nothing else. What was missing (volet 3) is a signal that reaches the FLEET:
# a frozen lane sits silent, so the detector itself must raise the flag on the
# lane's dashboard. Transport = the bots' canonical path (mcp-chain-watchdog
# Publish-FleetNote): HTTP JSON-RPC against the mcp-proxy, initialize ->
# notifications/initialized -> tools/call roosync_dashboard append. Best-effort
# ONLY -- a signaling failure never changes the exit code (the detection result
# is the product; the note is telemetry). Activation (scheduler, bearer wiring)
# stays with the coordinator, out of this file.

DASHBOARD_PATH = "/roo-state-manager/mcp"
DEFAULT_DASHBOARD_URL = "https://mcp-tools.myia.io"
NOTE_STALL_LINES = 5


def _host():
    return os.environ.get("COMPUTERNAME") or os.environ.get("HOSTNAME") or "unknown-host"


def build_note_id(stalls, now=None):
    """Idempotency key (#3276 doctrine): host + content digest + 15-min bucket.

    A scheduler ticking inside one incident converges to ONE note per bucket
    instead of one per tick -- an append whose messageId already exists is
    skipped server-side (deduplicated: true). The digest covers the stall set,
    so a NEW stall (or a gone one) produces a fresh id and a fresh note.
    """
    now = now or time.time()
    bucket = int(now // 900)
    payload = "|".join(f"{s['session']}:{s['since']}" for s in stalls)
    digest = hashlib.md5(payload.encode("utf-8")).hexdigest()[:12]
    return f"stall-detector-{_host()}-{digest}-{bucket}"


def build_note_content(stalls, workspace):
    lines = [f"[WARN][STALL-DETECTOR] {_host()}:{workspace} -- "
             f"{len(stalls)} session(s) gellee(s) sur attente d'approbation "
             f"(plus ancienne: {stalls[0]['age_min']:.0f} min)"]
    for s in stalls[:NOTE_STALL_LINES]:
        chain = " [sidechain]" if s["sidechain"] else ""
        lines.append(f"- {s['project']}/{s['session'][:8]}{chain} {s['tool']} "
                     f"depuis {s['since']}: {s['command']}")
    if len(stalls) > NOTE_STALL_LINES:
        lines.append(f"- ... +{len(stalls) - NOTE_STALL_LINES} autre(s)")
    lines.append("Signal best-effort detect-approval-stalls.py (#4243 volet 3) -- "
                 "detail: --json ; verdicts executing/abandoned non signales.")
    return "\n".join(lines)


def publish_dashboard_note(stalls, workspace, url, bearer, dash_type="workspace",
                           timeout=10.0, now=None):
    """Append the stall note to the lane dashboard. Returns True on success.

    Only the CALLER decides what is worth a note (waiting stalls); this
    function is a dumb transport. Any failure -> False + stderr warning, never
    an exception: signaling is telemetry, not the product.

    The tools/call response body IS read: an MCP tool result can carry
    `result.isError: true` (rejected append, server-side error) behind an HTTP
    200 -- without this check a dead note would report success (gap flagged by
    ai-01 on PR #4251, 22:34Z). A body that is not parseable JSON-RPC does NOT
    fail the note (some transports answer SSE or empty on accepted calls), but
    an explicit isError does.
    """
    arguments = {
        "action": "append",
        "type": dash_type,
        "tags": ["WARN", "stall-detector"],
        "content": build_note_content(stalls, workspace),
        "messageId": build_note_id(stalls, now=now),
    }
    if dash_type == "workspace":
        arguments["workspace"] = workspace

    init_body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "initialize",
                            "params": {"protocolVersion": "2024-11-05",
                                       "capabilities": {},
                                       "clientInfo": {"name": "stall-detector",
                                                      "version": "1.1"}}}).encode()
    call_body = json.dumps({"jsonrpc": "2.0", "id": 3, "method": "tools/call",
                            "params": {"name": "roosync_dashboard",
                                       "arguments": arguments}}).encode()
    headers = {"Authorization": f"Bearer {bearer}",
               "Content-Type": "application/json",
               "Accept": "application/json, text/event-stream"}
    base = url.rstrip("/")
    if not base.endswith(DASHBOARD_PATH):
        base += DASHBOARD_PATH

    def post(body, extra=None):
        req_headers = dict(headers)
        if extra:
            req_headers.update(extra)
        req = urllib.request.Request(base, data=body, headers=req_headers, method="POST")
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.headers, resp.read()

    def result_payload(raw):
        """First JSON-RPC result in the body, or None. Tolerates SSE framing
        (event: message\\ndata: {...}) and a non-JSON body (returns None --
        the note stands; only an explicit isError kills it)."""
        text = raw.decode("utf-8", "replace").strip()
        candidates = [text]
        candidates += [ln[len("data:"):].strip() for ln in text.splitlines()
                       if ln.startswith("data:")]
        for cand in candidates:
            try:
                decoded = json.loads(cand)
            except ValueError:
                continue
            if isinstance(decoded, dict) and isinstance(decoded.get("result"), dict):
                return decoded["result"]
        return None

    try:
        init_headers, _init_raw = post(init_body)
        session_header = init_headers.get("mcp-session-id")
        extra = {"mcp-session-id": session_header} if session_header else None
        if extra:
            # notification -- no id, no response expected
            post(b'{"jsonrpc":"2.0","method":"notifications/initialized"}', extra)
        _call_headers, call_raw = post(call_body, extra)
        result = result_payload(call_raw)
        if result is not None and result.get("isError"):
            print(f"WARNING: dashboard append rejected server-side (isError) -- "
                  f"note NOT confirmed: {str(result)[:200]}", file=sys.stderr)
            return False
        return True
    except (urllib.error.URLError, OSError, ValueError, http.client.HTTPException) as exc:
        # HTTPException: a body cut mid-read (IncompleteRead) on a slow proxy
        # must stay a warning, not a traceback that replaces the exit code.
        print(f"WARNING: dashboard note NOT posted ({exc}) -- signal is "
              f"best-effort, detection result above stands", file=sys.stderr)
        return False


def maybe_publish_dashboard_note(totals, stalls, workspace, url, bearer,
                                 dash_type="workspace", timeout=10.0, now=None):
    """Gate: only WAITING stalls are a signal. Returns True/False/None.

    `executing` is a transcript lag and `abandoned` a dead sidechain -- neither
    is something a human or a coordinator could still answer, so neither earns
    a note. Returns None when there is nothing to signal (no request made).
    """
    waiting = [s for s in stalls if s["state"] == "waiting-suspected"]
    if not waiting:
        return None
    return publish_dashboard_note(waiting, workspace, url, bearer, dash_type=dash_type,
                                  timeout=timeout, now=now)


# --- selftest ---------------------------------------------------------------

def _rec(role, blocks, ts, uuid, sidechain=False):
    entry = {"type": role, "uuid": uuid, "timestamp": ts,
             "message": {"role": role, "content": blocks}}
    if sidechain:
        entry["isSidechain"] = True
    return json.dumps(entry, ensure_ascii=False)


def _tool_use(tid, tool, command):
    return {"type": "tool_use", "id": tid, "name": tool, "input": {"command": command}}


def _tool_result(tid):
    return {"type": "tool_result", "tool_use_id": tid, "content": "ok"}


def selftest():
    """Synthetic fixtures covering the live signatures (exit 0 = pass)."""
    from datetime import timedelta
    base = now_utc()
    iso = lambda dt: dt.strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"

    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)

        def write(name, records):
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("\n".join(records) + "\n", encoding="utf-8")
            return path

        # 1. The measured incident shape: dangling Bash tool_use 30 min old -> flagged.
        write("proj-a/stalled.jsonl", [
            _rec("user", [{"type": "text", "text": "go"}], iso(base - timedelta(minutes=35)), "u1"),
            _rec("assistant", [_tool_use("t1", "Bash",
                "cd ../other && rm -f file; git status --short")],
                iso(base - timedelta(minutes=30)), "a1"),
        ])

        # 2. Fresh dangling tail (2 min) -- below the default 10 min threshold.
        write("proj-a/fresh.jsonl", [
            _rec("assistant", [_tool_use("t2", "Bash", "echo hi")],
                 iso(base - timedelta(minutes=2)), "a2"),
        ])

        # 3. Closed tool_use -> clean, whatever the age.
        write("proj-b/closed.jsonl", [
            _rec("assistant", [_tool_use("t3", "Bash", "echo done")],
                 iso(base - timedelta(hours=2)), "a3"),
            _rec("user", [_tool_result("t3")],
                 iso(base - timedelta(hours=2)), "u3"),
            _rec("assistant", [{"type": "text", "text": "finished"}],
                 iso(base - timedelta(hours=2)), "a4"),
        ])

        # 4. Session that simply ended on prose -> not a stall.
        write("proj-b/idle.jsonl", [
            _rec("assistant", [{"type": "text", "text": "au revoir"}],
                 iso(base - timedelta(hours=20)), "a5"),
        ])

        # 5. Sidechain dangling PowerShell -> flagged, sidechain marked.
        write("proj-c/side.jsonl", [
            _rec("assistant", [_tool_use("t5", "PowerShell", "Get-Thing -Verbose")],
                 iso(base - timedelta(minutes=45)), "a6", sidechain=True),
        ])

        # 6. Secret in the dangling command -> preview carries [REDACTED], never the value.
        write("proj-c/secret.jsonl", [
            _rec("assistant", [_tool_use("t6", "Bash",
                "curl -H 'Authorization: Bearer abcdef1234567890' https://x")],
                 iso(base - timedelta(minutes=25)), "a7"),
        ])

        # 7. Resume copy: the same uuid re-appended must not double-report.
        dup = _rec("assistant", [_tool_use("t7", "Bash", "echo dup")],
                   iso(base - timedelta(minutes=50)), "a8")
        write("proj-d/resumed.jsonl", [dup, dup])

        # 8. Abandoned sidechain: parent wrote AFTER the dangling tool_use -- the
        #    subagent was orphaned mid-wait (nit #4245, case 2d17885a): reported
        #    as abandoned, not as an answerable approval wait.
        write("proj-e/orphan.jsonl", [
            _rec("assistant", [_tool_use("t8", "Bash", "cd ../x && rm -f y")],
                 iso(base - timedelta(hours=3)), "a9", sidechain=True),
            _rec("assistant", [{"type": "text", "text": "parent moved on"}],
                 iso(base - timedelta(hours=2)), "a10"),
        ])

        totals, stalls = detect(root, 10.0, list(DEFAULT_TOOLS), 168.0)

        assert totals["stalls"] == 5, f"expected 5 stalls, got {totals['stalls']}: {stalls}"
        assert totals["abandoned"] == 1, totals
        by_key = {(s["project"], s["session"]): s for s in stalls}
        stuck = by_key[("proj-a", "stalled")]
        assert stuck["state"] == "waiting-suspected" and stuck["sidechain"] is False
        assert 29 <= stuck["age_min"] <= 31, stuck["age_min"]
        assert "cd ../other" in stuck["command"]
        assert ("proj-a", "fresh") not in by_key, "under-threshold tail must not report"
        assert ("proj-b", "closed") not in by_key and ("proj-b", "idle") not in by_key
        side = by_key[("proj-c", "side")]
        assert side["sidechain"] is True and side["tool"] == "PowerShell"
        assert side["state"] == "waiting-suspected", side  # no parent after: still answerable
        orphan = by_key[("proj-e", "orphan")]
        assert orphan["state"] == "abandoned" and orphan["sidechain"] is True, orphan
        secret = by_key[("proj-c", "secret")]
        assert "abcdef1234567890" not in secret["command"], secret["command"]
        assert "[REDACTED]" in secret["command"]
        # 7. Resume copy: the re-appended uuid is skipped -- one report, not two.
        assert len([s for s in stalls if s["session"] == "resumed"]) == 1

        # 9. Hook-log join: a marker at/after the tool_use flips the verdict to executing.
        hook_dir = Path(tmp) / "hook"
        hook_dir.mkdir()
        hook_path = hook_dir / "tool-starts.jsonl"
        marker = {"ts": iso(base - timedelta(minutes=29, seconds=30)), "session_id": "stalled",
                  "tool": "Bash", "command": "cd ../other && rm -f file; git status --short"}
        hook_path.write_text(json.dumps(marker) + "\n", encoding="utf-8")
        _totals2, stalls2 = detect(root, 10.0, list(DEFAULT_TOOLS), 168.0, hook_log=hook_path)
        stuck2 = [s for s in stalls2 if s["session"] == "stalled"][0]
        assert stuck2["state"] == "executing", stuck2
        # Totals carry the adjudication split alongside the exit-code driver.
        assert _totals2["executing"] == 1 and _totals2["waiting"] == 3, _totals2
        assert _totals2["abandoned"] == 1, _totals2  # retired sidechain is not re-adjudicated

        # 10. Dashboard signal (#4243 attendu 3): waiting stalls reach the lane
        #     dashboard through the bots' JSON-RPC path -- initialize ->
        #     initialized -> tools/call, idempotent messageId, redacted content.
        #     Non-waiting verdicts earn no note; transport failure is swallowed.
        import threading
        from http.server import BaseHTTPRequestHandler, HTTPServer

        requests_seen = []
        call_response = {"body": '{"jsonrpc":"2.0","id":3,"result":{}}',
                         "sse": False, "truncate": False}

        class _Handler(BaseHTTPRequestHandler):
            def do_POST(self):
                length = int(self.headers.get("Content-Length", 0))
                body = self.rfile.read(length).decode("utf-8")
                requests_seen.append((self.path, dict(self.headers), body))
                is_call = '"tools/call"' in body
                self.send_response(200)
                self.send_header("mcp-session-id", "sess-1")
                if is_call and call_response["sse"]:
                    self.send_header("Content-Type", "text/event-stream")
                else:
                    self.send_header("Content-Type", "application/json")
                if is_call:
                    if call_response["sse"]:
                        payload = ("event: message\r\ndata: "
                                   + call_response["body"] + "\r\n\r\n").encode()
                    else:
                        payload = call_response["body"].encode()
                else:
                    payload = b'{"jsonrpc":"2.0","id":1,"result":{}}'
                if is_call and call_response["truncate"]:
                    # Announce more bytes than sent: the client read raises IncompleteRead.
                    self.send_header("Content-Length", str(len(payload) + 100))
                self.end_headers()
                self.wfile.write(payload)

            def log_message(self, *_a):
                pass

        srv = HTTPServer(("127.0.0.1", 0), _Handler)
        threading.Thread(target=srv.serve_forever, daemon=True).start()
        base_url = f"http://127.0.0.1:{srv.server_port}"

        # Gate: nothing waiting-only -> no request at all.
        assert maybe_publish_dashboard_note({"waiting": 0}, [], "roo-extensions",
                                            base_url, "tok") is None
        assert len(requests_seen) == 0
        # Gate: executing/abandoned entries in the set earn no note line.
        assert maybe_publish_dashboard_note(_totals2, stalls2, "roo-extensions",
                                            base_url, "tok") is True
        assert len(requests_seen) == 3, [r[0] for r in requests_seen]
        init_path, init_headers, _init_body = requests_seen[0]
        assert init_path.endswith(DASHBOARD_PATH), init_path
        assert init_headers.get("Authorization") == "Bearer tok"
        assert json.loads(requests_seen[1][2])["method"] == "notifications/initialized"
        call = json.loads(requests_seen[2][2])
        assert call["params"]["name"] == "roosync_dashboard"
        args = call["params"]["arguments"]
        assert args["action"] == "append" and args["type"] == "workspace"
        assert args.get("workspace") == "roo-extensions"
        assert "WARN" in args["tags"] and "stall-detector" in args["tags"]
        assert args["messageId"].startswith(f"stall-detector-{_host()}-"), args["messageId"]
        # Only waiting stalls earn note lines: executing (stalled, flipped by the
        # hook-log join) and abandoned (orphan) are excluded; secret stays redacted.
        assert "proj-d/resumed" in args["content"] and "proj-c/secret" in args["content"]
        assert "[REDACTED]" in args["content"]
        assert "proj-a/stalled" not in args["content"]  # executing -> not a signal
        assert "proj-e/orphan" not in args["content"]    # abandoned -> not a signal
        # HTTP headers are case-insensitive (urllib capitalizes keys on send):
        # the initialize session id must propagate to the tools/call request.
        call_headers = {k.lower(): v for k, v in requests_seen[2][1].items()}
        assert call_headers.get("mcp-session-id") == "sess-1", call_headers.get("mcp-session-id")
        # 10b. An isError tool result behind HTTP 200 must fail the note
        #      (gap flagged by ai-01 on PR #4251: the body was never read).
        call_response["body"] = json.dumps({"jsonrpc": "2.0", "id": 3,
                                            "result": {"isError": True,
                                                       "content": [{"type": "text",
                                                                    "text": "append denied"}]}})
        assert maybe_publish_dashboard_note(_totals2, stalls2, "roo-extensions",
                                            base_url, "tok") is False
        # 10c. SSE framing: the result rides a data: line -- still parsed,
        #      and a non-error SSE result confirms the note.
        call_response["body"] = '{"jsonrpc":"2.0","id":3,"result":{}}'
        call_response["sse"] = True
        assert maybe_publish_dashboard_note(_totals2, stalls2, "roo-extensions",
                                            base_url, "tok") is True
        # 10d. A body cut mid-read (IncompleteRead, an http.client.HTTPException)
        #      stays best-effort: False, no traceback over the exit code.
        call_response["sse"] = False
        call_response["truncate"] = True
        assert maybe_publish_dashboard_note(_totals2, stalls2, "roo-extensions",
                                            base_url, "tok") is False
        call_response["truncate"] = False
        # Transport failure: best-effort -> False, no raise.
        srv.shutdown()
        srv.server_close()
        assert maybe_publish_dashboard_note(_totals2, stalls2, "roo-extensions",
                                            "http://127.0.0.1:1", "tok",
                                            timeout=2.0) is False

    print("selftest OK: dangling shell tool_use flags a stall; fresh tail and closed")
    print("             tool_use stay silent; prose-ending session ignored; sidechain")
    print("             marked; secret values redacted in previews; resume copies")
    print("             deduped; orphaned sidechain retired as abandoned; hook-log")
    print("             marker adjudicates waiting vs executing; dashboard signal")
    print("             gated to waiting stalls, best-effort, and failed by a")
    print("             server-side isError (SSE framing tolerated).")
    return EXIT_CLEAN


def main():
    parser = argparse.ArgumentParser(
        description="Detect sessions stalled on an approval wait (issue #4243, volet 3).")
    parser.add_argument("--root", type=Path, default=Path.home() / ".claude" / "projects",
                        help="scan this directory recursively (default: ~/.claude/projects)")
    parser.add_argument("--min-minutes", type=float, default=10.0,
                        help="report stalls older than this many minutes (default: 10)")
    parser.add_argument("--tools", default=",".join(DEFAULT_TOOLS),
                        help="comma-separated tool names to watch (default: Bash,PowerShell)")
    parser.add_argument("--active-hours", type=float, default=168.0,
                        help="only read session files modified within this window "
                             "(default: 168 -- a stalled session writes nothing, its "
                             "mtime pins when the wait began)")
    parser.add_argument("--hook-log", type=Path, default=None, metavar="PATH",
                        help="adjudicate each stall with the log-tool-start journal "
                             "(#4214): PATH and PATH.1 are indexed, a marker at/after "
                             "the tool_use means the command executes (transcript lag), "
                             "no marker means approval wait suspected")
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    parser.add_argument("--dashboard", action="store_true",
                        help="append a WARN note to the lane dashboard when WAITING "
                             "stalls are found (#4243 volet 3) -- needs a bearer "
                             "(--dashboard-bearer or MCP_PROXY_BEARER env); best-effort, "
                             "never changes the exit code")
    parser.add_argument("--dashboard-url", default=None, metavar="URL",
                        help="mcp-proxy base URL for the dashboard signal (default: "
                             "MCP_PROXY_BASE_URL env or https://mcp-tools.myia.io)")
    parser.add_argument("--dashboard-bearer", default=None, metavar="TOKEN",
                        help="bearer token for the mcp-proxy (default: MCP_PROXY_BEARER env)")
    parser.add_argument("--dashboard-type", choices=["workspace", "machine", "global"],
                        default="workspace",
                        help="dashboard the signal lands on (default: workspace)")
    parser.add_argument("--dashboard-workspace", default="roo-extensions", metavar="NAME",
                        help="workspace dashboard name (default: roo-extensions)")
    parser.add_argument("--dashboard-timeout", type=float, default=10.0, metavar="SECONDS",
                        help="per-request timeout of the dashboard signal (default: 10); "
                             "a scheduled tick can afford more -- on the proxied path a "
                             "dashboard call above 5 s had a 23 s median on 19/10")
    parser.add_argument("--selftest", action="store_true", help="run synthetic fixture validation and exit")
    args = parser.parse_args()

    if args.selftest:
        sys.exit(selftest())

    root = args.root.resolve()
    if not root.exists():
        print(f"ERROR: target not found: {root}", file=sys.stderr)
        sys.exit(EXIT_ERROR)
    tools = [t.strip() for t in args.tools.split(",") if t.strip()] or list(DEFAULT_TOOLS)
    totals, stalls = detect(root, args.min_minutes, tools, args.active_hours,
                            hook_log=args.hook_log, as_json=args.json)
    if args.dashboard:
        bearer = args.dashboard_bearer or os.environ.get("MCP_PROXY_BEARER")
        if not bearer:
            print("WARNING: --dashboard without bearer (--dashboard-bearer or "
                  "MCP_PROXY_BEARER env) -- dashboard signal skipped", file=sys.stderr)
        else:
            url = (args.dashboard_url or os.environ.get("MCP_PROXY_BASE_URL")
                   or DEFAULT_DASHBOARD_URL)
            maybe_publish_dashboard_note(totals, stalls, args.dashboard_workspace, url,
                                         bearer, dash_type=args.dashboard_type,
                                         timeout=args.dashboard_timeout)
    if totals["waiting"] > 0:
        sys.exit(EXIT_FINDINGS)
    sys.exit(EXIT_CLEAN)


if __name__ == "__main__":
    main()
