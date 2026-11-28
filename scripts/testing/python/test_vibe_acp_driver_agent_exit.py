#!/usr/bin/env python3
"""vibe-acp-driver.py must stop waiting as soon as the agent process is gone.

Incident po-2025 2026-11-28 (g4-gametheory-2): vibe-acp died during the prompt
and the driver kept polling an empty queue until its 6000 s budget, holding the
feeder's single worker slot. These tests run main() against a fake ACP agent
(a Python script, spawned through a patched Popen so the suite runs on Windows
and on the Linux CI runner alike).

- the agent dies during session/prompt -> AGENT_EXITED, exit 7, long before the budget;
- the agent answers then exits at once -> the answer still wins (PROMPT_OK, exit 0);
- same, with a reader that hands the line over late (SlowQueue): the exit check
  must not drop lines the reader has not handed over yet.
"""

import importlib.util
import os
import queue
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

_SPEC = importlib.util.spec_from_file_location(
    "vibe_acp_driver",
    os.path.join(os.path.dirname(os.path.abspath(__file__)),
                 "..", "..", "scheduling", "vibe-acp-driver.py"))
drv = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(drv)

FAKE_AGENT = r'''
import json, sys
mode = sys.argv[1]
for raw in sys.stdin:
    msg = json.loads(raw)
    rid, method = msg.get("id"), msg.get("method")
    def reply(result):
        sys.stdout.write(json.dumps({"jsonrpc": "2.0", "id": rid, "result": result}) + "\n")
        sys.stdout.flush()
    if method == "initialize":
        reply({"protocolVersion": 1})
    elif method == "session/new":
        reply({"sessionId": "s-test", "modes": {"currentModeId": "default"}})
    elif method == "session/prompt":
        if mode == "die":
            sys.exit(9)
        reply({"stopReason": "end_turn", "usage": {"inputTokens": 1, "outputTokens": 1}})
        sys.exit(0)
'''

BUDGET = 20


class SlowQueue(queue.Queue):
    """A reader scheduled late: the line lands after the agent is already dead.

    This is the window the exit check must not close too early -- without the
    drain, the driver sees an empty queue and a dead process, and drops a reply
    the agent did send."""

    def put(self, item, block=True, timeout=None):
        time.sleep(0.8)
        super().put(item, block, timeout)


class TestAgentExit(unittest.TestCase):
    def run_driver(self, mode, queue_cls=queue.Queue):
        with tempfile.TemporaryDirectory() as tmp:
            agent = os.path.join(tmp, "fake_agent.py")
            with open(agent, "w", encoding="utf-8") as fh:
                fh.write(FAKE_AGENT)
            real_popen = subprocess.Popen

            def popen(args, **kw):
                return real_popen([sys.executable, "-u", agent, mode], **kw)

            argv = ["vibe-acp-driver.py", "--exe", agent, "--cwd", tmp,
                    "--prompt", "hello", "--timeout", str(BUDGET)]
            with mock.patch.object(drv.subprocess, "Popen", side_effect=popen), \
                 mock.patch.object(drv.queue, "Queue", queue_cls), \
                 mock.patch.object(sys, "argv", argv):
                t0 = time.time()
                rc = drv.main()
                return rc, time.time() - t0

    def test_agent_dying_mid_prompt_ends_the_wait(self):
        rc, elapsed = self.run_driver("die")
        self.assertEqual(rc, 7, "a dead agent must be reported as AGENT_EXITED (7), not a timeout")
        self.assertLess(elapsed, BUDGET / 2, f"driver waited {elapsed:.1f}s for a dead agent")

    def test_answer_sent_just_before_exit_is_kept(self):
        rc, _ = self.run_driver("answer")
        self.assertEqual(rc, 0, "the reply written before exit must be read (PROMPT_OK)")

    def test_answer_still_kept_when_the_reader_lags(self):
        rc, _ = self.run_driver("answer", queue_cls=SlowQueue)
        self.assertEqual(rc, 0, "a reply still in the reader's hands when the agent exits must be read")


if __name__ == "__main__":
    unittest.main()
