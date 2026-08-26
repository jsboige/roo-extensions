#!/usr/bin/env python3
"""Vibe ACP headless driver — drives vibe-acp.exe (Mistral Vibe VS Code extension
bundle) over the Zed agent-client-protocol (ndjson JSON-RPC on stdio).

Lane #3202 (GO user 2026-08-22 via ai-01). No `mistral` one-shot CLI exists; the
extension bundles vibe-acp.exe, an ACP *server*. This driver is the missing
client: initialize -> session/new -> session/prompt -> report.

Auth model: vibe-acp.exe consumes the credential store established once by
interactive browser-auth in VS Code (verified 2026-08-22: full prompt round-trip
headless, stopReason end_turn).

Usage:
  python vibe-acp-driver.py --cwd D:/CoursIA --prompt "do the thing"
  python vibe-acp-driver.py --cwd D:/CoursIA --prompt-file task.txt --timeout 300
  # WAKE path: dashboard-listener writes the trigger message to a JSON file and
  # start-vibe-worker.ps1 injects its CONTENT into VIBE_WAKE_PAYLOAD (env var
  # avoids quoting issues with markdown). --wake parses that JSON ({content|prompt}).
  python vibe-acp-driver.py --cwd D:/CoursIA --wake

Exit codes:
  0  PROMPT_OK            (LLM round-trip complete)
  2  INITIALIZE_FAILED
  3  SESSION_NEW_FAILED
  4  PROMPT_ERROR         (auth or server error — see stderr)
  5  PROMPT_TIMEOUT
  6  BAD_ARGS / NO_EXE
"""

import argparse
import collections
import glob
import json
import os
import queue
import subprocess
import sys
import threading
import time

DEFAULT_TIMEOUT = 300  # 5 min per phase budget for the prompt


def timeout_diagnostics(notifications, t_prompt, timeout):
    """Chronology of session/update notifications for the timeout path.

    One timed-out run must distinguish three causes (TASK ai-01 2026-08-26,
    Vibe volet B): agent still working at the deadline (streaming), API stall
    (long silence before the deadline), or session that never started (zero
    activity). The hint labels the pattern; the measured lines are the evidence.
    """
    counts = collections.Counter()
    last_usage = None
    t_first = t_last = None
    longest_silence = 0.0
    silence_from = silence_to = None
    prev = None
    for t_recv, msg in notifications:
        update = (msg.get("params") or {}).get("update") or {}
        kind = update.get("sessionUpdate") or "non_update"
        counts[kind] += 1
        if kind == "usage_update":
            last_usage = update
        if t_first is None:
            t_first = t_recv
        if prev is not None and t_recv - prev > longest_silence:
            longest_silence = t_recv - prev
            silence_from, silence_to = prev, t_recv
        prev = t_recv
        t_last = t_recv

    activity_total = sum(n for k, n in counts.items() if k != "non_update")
    activity_detail = " ".join(f"{k}={n}" for k, n in counts.most_common())
    deadline = t_prompt + timeout
    lines = [f"=== TIMEOUT DIAGNOSTICS (budget {timeout}s) ==="]
    lines.append(f"activity: {activity_detail or '(none)'}")
    if t_last is None:
        lines.append("timeline: NO session/update ever received")
        hint = ("NO_ACTIVITY — session never started: check auth, MCP connection, "
                "session/new (latency hypothesis is moot)")
    else:
        silence_final = max(0.0, deadline - t_last)
        lines.append(
            f"timeline: first_update=+{t_first - t_prompt:.1f}s "
            f"last_update=+{t_last - t_prompt:.1f}s silence_final={silence_final:.1f}s "
            f"longest_silence={longest_silence:.1f}s"
            + (f" (from +{silence_from - t_prompt:.1f}s to +{silence_to - t_prompt:.1f}s)"
               if silence_to is not None else "")
        )
        if silence_final < min(60.0, timeout * 0.1):
            hint = (f"STREAMING_TO_DEADLINE — activity within {silence_final:.0f}s of "
                    "the deadline: the agent was working; budget/prompt size, not API")
        else:
            hint = (f"STALLED_BEFORE_DEADLINE — no update for {silence_final:.0f}s "
                    "before the deadline: API stall pattern")
    if last_usage is not None:
        lines.append(f"last_usage_update: {json.dumps(last_usage)[:300]}")
    lines.append(f"verdict_hint={hint}")
    return "\n".join(lines)


def find_vibe_acp(explicit: str) -> str:
    """Locate vibe-acp.exe: explicit path, else newest mistral extension."""
    if explicit:
        if os.path.isfile(explicit):
            return explicit
        return ""
    pattern = os.path.expandvars(
        r"%USERPROFILE%\.vscode\extensions\mistralai.mistral-vibe-code-*"
    )
    candidates = []
    for ext_dir in glob.glob(pattern):
        exe = os.path.join(ext_dir, "bin", "vibe-acp.exe")
        if os.path.isfile(exe):
            candidates.append(exe)
    # getmtime, not lexicographic max: "0.9.0" > "0.10.0" as strings.
    return max(candidates, key=os.path.getmtime) if candidates else ""


def main() -> int:
    ap = argparse.ArgumentParser(description="Drive Mistral Vibe headless via ACP")
    ap.add_argument("--exe", default="", help="Path to vibe-acp.exe (auto-discovered if empty)")
    ap.add_argument("--cwd", required=True, help="Working directory for the session")
    ap.add_argument("--prompt", default="", help="Prompt text")
    ap.add_argument("--prompt-file", default="", help="Read prompt from file")
    ap.add_argument("--wake", action="store_true",
                    help="Take the prompt from VIBE_WAKE_PAYLOAD (set by start-vibe-worker.ps1 on a [WAKE-VIBE])")
    ap.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT, help="Prompt budget in seconds")
    ap.add_argument("--dry-run", action="store_true", help="Print the invocation, do not run")
    args = ap.parse_args()

    exe = find_vibe_acp(args.exe)
    if not exe:
        print("ERROR: vibe-acp.exe not found (no --exe, no extension match)", file=sys.stderr)
        return 6
    if not os.path.isdir(args.cwd):
        print(f"ERROR: --cwd does not exist: {args.cwd}", file=sys.stderr)
        return 6

    if args.prompt_file:
        with open(args.prompt_file, encoding="utf-8") as f:
            prompt_text = f.read().strip()
    else:
        prompt_text = args.prompt.strip()
    wake_payload = os.environ.get("VIBE_WAKE_PAYLOAD", "")
    # Contract (start-vibe-worker.ps1:180): the env var holds the payload CONTENT
    # (not its path). A path is tolerated as a secondary contract for manual runs.
    if not prompt_text and args.wake and wake_payload:
        raw = ""
        if os.path.isfile(wake_payload):
            with open(wake_payload, encoding="utf-8") as f:
                raw = f.read()
        elif wake_payload.lstrip().startswith("{"):
            raw = wake_payload
        if raw:
            try:
                payload = json.loads(raw)
                prompt_text = payload.get("content", payload.get("prompt", "")).strip()
            except (json.JSONDecodeError, AttributeError):
                prompt_text = ""
    if not prompt_text:
        if args.wake:
            print(f"ERROR: --wake but VIBE_WAKE_PAYLOAD unusable: {wake_payload!r}", file=sys.stderr)
        print("ERROR: no prompt (--prompt, --prompt-file, or VIBE_WAKE_PAYLOAD)", file=sys.stderr)
        return 6

    if args.dry_run:
        print(f"DRY-RUN exe={exe}")
        print(f"DRY-RUN cwd={args.cwd}")
        print(f"DRY-RUN timeout={args.timeout}s")
        print(f"DRY-RUN prompt ({len(prompt_text)} chars): {prompt_text[:200]}")
        return 0

    proc = subprocess.Popen(
        [exe],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        cwd=args.cwd,
    )
    lines = queue.Queue()
    stderr_tail = collections.deque(maxlen=40)

    def reader():
        for line in proc.stdout:
            lines.put(line.rstrip())

    def stderr_reader():
        # Drain stderr or the child blocks once the OS pipe buffer fills.
        for line in proc.stderr:
            stderr_tail.append(line.rstrip())

    threading.Thread(target=reader, daemon=True).start()
    threading.Thread(target=stderr_reader, daemon=True).start()

    def send(obj):
        proc.stdin.write(json.dumps(obj) + "\n")
        proc.stdin.flush()

    def recv_response(rid, timeout):
        deadline = time.time() + timeout
        notifications = []
        while time.time() < deadline:
            try:
                line = lines.get(timeout=0.3)
            except queue.Empty:
                continue
            try:
                msg = json.loads(line)
            except json.JSONDecodeError:
                continue
            if msg.get("id") == rid:
                return msg, notifications
            notifications.append((time.time(), msg))
        return None, notifications

    t0 = time.time()

    send({
        "jsonrpc": "2.0", "id": 1, "method": "initialize",
        "params": {
            "protocolVersion": 1,
            "clientCapabilities": {"fs": {"readTextFile": True, "writeTextFile": True}},
        },
    })
    init, _ = recv_response(1, 30)
    if not init or "result" not in init:
        print(f"INITIALIZE_FAILED: {json.dumps(init)[:400]}", file=sys.stderr)
        proc.kill()
        return 2

    # mcpServers is a required field (pydantic); empty list lets the user-level
    # config.toml servers load (verified behavior 2026-08-22).
    send({
        "jsonrpc": "2.0", "id": 2, "method": "session/new",
        "params": {"cwd": args.cwd, "mcpServers": []},
    })
    sess, _ = recv_response(2, 30)
    if not sess or "result" not in sess:
        print(f"SESSION_NEW_FAILED: {json.dumps(sess)[:400]}", file=sys.stderr)
        proc.kill()
        return 3
    session_id = sess["result"].get("sessionId", "?")
    print(f"session: {session_id} mode={sess['result'].get('modes', {}).get('currentModeId', '?')}")

    t_prompt = time.time()
    send({
        "jsonrpc": "2.0", "id": 3, "method": "session/prompt",
        "params": {"sessionId": session_id,
                   "prompt": [{"type": "text", "text": prompt_text}]},
    })
    resp, notifications = recv_response(3, args.timeout)
    elapsed = time.time() - t0

    mcp_failures = []
    final_text = []
    for _ts, msg in notifications:
        update = (msg.get("params") or {}).get("update") or {}
        content = update.get("content") or {}
        if isinstance(content, list):
            # ACP session/update may send content as a list of typed blocks
            # (e.g. [{"type": "text", "text": "..."}]) instead of a plain dict.
            text = "".join(
                block.get("text", "") for block in content if isinstance(block, dict)
            )
        else:
            text = content.get("text", "")
        if "failed to connect" in text:
            mcp_failures.append(text[:200])
        if update.get("sessionUpdate") == "agent_message_chunk" and text:
            final_text.append(text)
    last_usage = None
    for _ts, msg in notifications:
        upd = (msg.get("params") or {}).get("update") or {}
        if upd.get("sessionUpdate") == "usage_update":
            last_usage = upd

    verdict_extra = ""
    if mcp_failures:
        verdict_extra = f" mcp_failures={len(mcp_failures)}"
        for failure in mcp_failures:
            print(f"mcp failure: {failure}", file=sys.stderr)

    try:
        send({"jsonrpc": "2.0", "id": 4, "method": "session/close",
              "params": {"sessionId": session_id}})
        time.sleep(0.5)
    except (BrokenPipeError, OSError):
        pass
    proc.kill()

    if resp is None:
        print(f"PROMPT_TIMEOUT after {args.timeout}s", file=sys.stderr)
        print(timeout_diagnostics(notifications, t_prompt, args.timeout), file=sys.stderr)
        for line in stderr_tail:
            print(f"stderr: {line[:200]}", file=sys.stderr)
        return 5
    error = resp.get("error")
    if error:
        print(f"PROMPT_ERROR code={error.get('code')} message={error.get('message')} "
              f"data={json.dumps(error.get('data'))[:400]}", file=sys.stderr)
        for line in stderr_tail:
            print(f"stderr: {line[:200]}", file=sys.stderr)
        return 4

    usage = (resp.get("result") or {}).get("usage") or {}
    cost = (last_usage or {}).get("cost") or {}
    print(f"PROMPT_OK elapsed={elapsed:.1f}s stop={resp['result'].get('stopReason')} "
          f"tokens_in={usage.get('inputTokens')} tokens_out={usage.get('outputTokens')} "
          f"cost={cost.get('amount')} {cost.get('currency')}{verdict_extra}")
    answer = "".join(final_text).strip()
    if answer:
        print(f"answer: {answer[:500]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
