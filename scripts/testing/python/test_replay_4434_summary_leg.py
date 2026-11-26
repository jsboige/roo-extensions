#!/usr/bin/env python3
"""test_replay_4434_summary_leg.py — the --leg summary contract of replay-4434.py.

The summary leg is the second condensation pass (generateLLMSummary): the
instrument must rebuild the PRODUCTION feed (raw messages, no [SERA ARCHIVÉ]
annotation), extract the summary templates mechanically, join the production
comparator (the CONDENSATION-SUMMARY message archived in T+1, footer naming
archive T), and score the three imposed FORMAT sections exactly like the
production guard validateSummaryCompleteness (accent- and case-folded).

Stdlib unittest only, no G: and no network: fixtures are synthetic archives
and a synthetic dashboard.ts. `unittest discover -s scripts/testing/python`
runs in CI on ubuntu.
"""

import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

SCRIPT = Path(__file__).resolve().parents[2] / "analysis" / "replay-4434.py"

# Synthetic dashboard.ts: both pass functions with realistic template literals.
# generateLLMSummary must come with ${messages.length} (system FORMAT heading +
# user prefix) and ${messagesContent} (user body); generateStatusUpdate with the
# placeholders fill_prompts substitutes; STATUS_SECTION_WORD_BUDGETS feeds the
# status-leg budget lines.
DASHBOARD_TS = """export const STATUS_SECTION_WORD_BUDGETS = [
  { name: 'Résumé', budget: 120, hint: 'en tête' },
  { name: 'Blocages structurels', budget: 80 },
] as const;

async function generateLLMSummary(messages: IntercomMessage[]): Promise<LLMCallResult> {
  const messagesContent = messages.map(msg => msg.content).join('\\n\\n---\\n\\n');
  const systemPrompt = `Tu es un expert en synthèse.

FORMAT :
## Résumé des ${messages.length} messages archivés

### Thèmes principaux
### Actions et résultats
### Décisions et métriques`;
  const userPrompt = `${messages.length} messages retirés du dashboard à synthétiser :

${messagesContent}

Résume ces messages archivés.`;
  return { content: null, stats: null };
}

async function generateStatusUpdate(key: string, status: string, msgs: Msg[]): Promise<LLMCallResult> {
  const systemPrompt = `Statut du dashboard ${dashboardKey} au ${lastDate}.
${statusBudgetPromptLines().join('\\n')}`;
  const userPrompt = `Messages: ${allMessages.length} dont ${archivedCount} archivés au ${lastDate}

${previousStatus}

${messagesContent}`;
  return { content: null, stats: null };
}
"""


def _load():
    spec = importlib.util.spec_from_file_location("replay_4434", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _write(path: Path, text: str) -> None:
    path.write_text(text, encoding="utf-8")


def make_archive(
    directory: Path,
    filename: str,
    key: str,
    archived_at: str,
    msgs: list,
    summary_outcome: str = "ok",
    status_outcome: str = "ok-with-fallback",
    status_block: str = "## Résumé\n- ancien statut\n## Blocages structurels\n- aucun",
    extra_msgs: list = None,
) -> str:
    """Write one synthetic archive; returns its filename."""
    body_msgs = extra_msgs if extra_msgs is not None else msgs
    msg_lines = "\n\n".join(
        f"### [{ts}] {author}\n\n{content}" for ts, author, content in body_msgs
    )
    text = (
        "---\n"
        f"type: archive\noriginalKey: {key}\narchivedAt: '{archived_at}'\n"
        f"messageCount: {len(body_msgs)}\nllmGenerated: true\nstatusUpdated: true\n"
        f"statusOutcome: {status_outcome}\nsummaryOutcome: {summary_outcome}\n"
        f"statusFallbackModel: deepseek-v4-flash\nsummaryFallbackModel: deepseek-v4-flash\n"
        "---\n\n"
        f"# Archive : {key}\n\n---\n\n"
        f"## Statut avant condensation (#3962)\n\n{status_block}\n\n---\n\n"
        f"{msg_lines}\n"
    )
    _write(directory / filename, text)
    return filename


def condense_summary_msg(posted_ts: str, names_archive: str, n: int) -> tuple:
    """A CONDENSATION-SUMMARY system message as archived in T+1."""
    content = (
        f"[msg: system:system:ic-x]\n\n**CONDENSATION-SUMMARY** - {posted_ts}\n\n"
        f"## Résumé des {n} messages archivés\n\n"
        "### Thèmes principaux\n- thème factice\n\n"
        "### Actions et résultats\n- [DONE] action factice\n\n"
        "### Décisions et métriques\n- métrique factice\n\n"
        f"{n} messages archivés dans `archive/{names_archive}`\n"
        f"{n} messages conservés (plus récents)\n"
    )
    return posted_ts, "system|system", content


class TestExtractAndFill(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mod = _load()

    def test_extract_summary_templates_mechanical(self):
        sys_tpl, usr_tpl = self.mod.extract_summary_templates(DASHBOARD_TS)
        self.assertIn("expert en synthèse", sys_tpl)
        self.assertIn("${messages.length}", sys_tpl)  # substituted at fill time
        self.assertTrue(usr_tpl.startswith("${messages.length} messages retirés"))
        self.assertIn("${messagesContent}", usr_tpl)

    def test_extract_status_templates_unchanged(self):
        sys_tpl, usr_tpl = self.mod.extract_templates(DASHBOARD_TS)
        self.assertIn("Statut du dashboard", sys_tpl)
        self.assertIn("${previousStatus}", usr_tpl)

    def test_fill_summary_prompts_feed_format(self):
        sys_tpl, usr_tpl = self.mod.extract_summary_templates(DASHBOARD_TS)
        msgs = [
            ("2026-11-17T01:00:00.000Z", "myia-po-2023|roo-extensions", "message un"),
            ("2026-11-17T01:05:00.000Z", "myia-ai-01|roo-extensions", "message deux"),
        ]
        system, user = self.mod.fill_summary_prompts(sys_tpl, usr_tpl, msgs)
        # production feed: [ts] machineId|workspace + content, --- separators,
        # NO [SERA ARCHIVÉ] annotation (status-leg approximation only)
        self.assertIn("[2026-11-17T01:00:00.000Z] myia-po-2023|roo-extensions\nmessage un", user)
        self.assertIn("\n\n---\n\n[2026-11-17T01:05:00.000Z] myia-ai-01|roo-extensions\nmessage deux", user)
        self.assertNotIn("[SERA ARCHIVÉ]", user)
        self.assertIn("Résumé des 2 messages archivés", system)
        self.assertTrue(user.startswith("2 messages retirés"))

    def test_summary_sections_fold(self):
        text = "### Thèmes principaux\nx\n### Actions et résultats\ny\n### Décisions et métriques\nz"
        self.assertEqual(len(self.mod.summary_sections_present(text)), 3)
        # case + accent folding, like the production guard
        text_upper = "## THÈMES PRINCIPAUX\n### ACTIONS ET RÉSULTATS\n### Décisions et métriques"
        self.assertEqual(len(self.mod.summary_sections_present(text_upper)), 3)
        # one missing
        partial = "Thèmes principaux\nActions et résultats"
        self.assertEqual(self.mod.summary_sections_present(partial),
                         ["themes principaux", "actions et resultats"])


class TestComparatorJoin(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mod = _load()

    def _text_with_msgs(self, msgs):
        return "## Statut avant condensation (#3962)\ns\n---\n\n" + "\n\n".join(
            f"### [{ts}] {author}\n{content}" for ts, author, content in msgs
        )

    def test_exact_join_by_archive_name(self):
        summary = condense_summary_msg("2026-11-17T01:00:00.000Z", "global-2026-11-17T01-00-00.md", 5)
        other = condense_summary_msg("2026-11-17T23:00:00.000Z", "global-2026-11-17T23-00-00.md", 9)
        text_next = self._text_with_msgs([other, summary])
        content, ts = self.mod.find_summary_comparator(
            text_next, "global-2026-11-17T01-00-00.md", "2026-11-17T01:00:05.000Z"
        )
        self.assertEqual(ts, "2026-11-17T01:00:00.000Z")
        self.assertIn("thème factice", content)

    def test_fallback_nearest_timestamp(self):
        far = condense_summary_msg("2026-11-17T23:00:00.000Z", "autre.md", 9)
        near = condense_summary_msg("2026-11-17T01:00:10.000Z", "autre-encore.md", 3)
        text_next = self._text_with_msgs([far, near])
        content, ts = self.mod.find_summary_comparator(
            text_next, "global-2026-11-17T01-00-00.md", "2026-11-17T01:00:05.000Z"
        )
        self.assertEqual(ts, "2026-11-17T01:00:10.000Z")

    def test_no_candidate_returns_none(self):
        text_next = self._text_with_msgs([("2026-11-17T02:00:00.000Z", "myia-po-2023|roo-extensions", "rien")])
        content, ts = self.mod.find_summary_comparator(
            text_next, "global-x.md", "2026-11-17T01:00:05.000Z"
        )
        self.assertIsNone(content)
        self.assertIsNone(ts)


class TestBuildPairsSummaryLeg(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mod = _load()
        cls.tmp = tempfile.TemporaryDirectory()
        base = Path(cls.tmp.name)
        cls.archive_dir = base / "dashboards" / "archive"
        cls.archive_dir.mkdir(parents=True)
        msgs_t = [
            ("2026-11-16T22:00:00.000Z", "myia-po-2023|roo-extensions", "contenu un assez long pour passer le filtre de taille minimale du flux"),
            ("2026-11-16T22:30:00.000Z", "myia-ai-01|roo-extensions", "contenu deux assez long pour passer le filtre de taille minimale du flux"),
        ]
        cls.fn_t = make_archive(
            cls.archive_dir, "global-2026-11-17T01-00-00.md", "global",
            "2026-11-17T01:00:05.000Z", msgs_t, summary_outcome="ok",
        )
        # T+1: its own messages include the CONDENSATION-SUMMARY naming archive T
        summary_msg = condense_summary_msg("2026-11-17T01:00:06.000Z", cls.fn_t, 2)
        cls.fn_t1 = make_archive(
            cls.archive_dir, "global-2026-11-18T01-00-00.md", "global",
            "2026-11-18T01:00:05.000Z", msgs_t, summary_outcome="ok",
            extra_msgs=[summary_msg, ("2026-11-17T12:00:00.000Z", "myia-web1|roo-extensions", "suite")],
        )
        # a husk archive (circuit-open summary) must be excluded
        make_archive(
            cls.archive_dir, "global-2026-11-19T01-00-00.md", "global",
            "2026-11-19T01:00:05.000Z", msgs_t, summary_outcome="circuit-open",
            extra_msgs=[("2026-11-18T12:00:00.000Z", "myia-web1|roo-extensions", "suite")],
        )

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def _args(self, **kw):
        return SimpleNamespace(
            leg="summary", since="2026-10-04T00:00:00", min_bytes=0, max_bytes=10**9,
            min_sections=0, require_comparator_fallback=True,
        )

    def test_pairs_join_comparator_and_filter_outcome(self):
        pairs = self.mod.build_pairs(str(self.archive_dir), self._args())
        self.assertEqual(len(pairs), 1)
        p = pairs[0]
        self.assertEqual(p["archive_in"], self.fn_t)
        self.assertEqual(p["comparator_ts"], "2026-11-17T01:00:06.000Z")
        self.assertIn("thème factice", p["comparator"])
        self.assertEqual(p["comparator_model"], "deepseek-v4-flash")
        self.assertEqual(len(p["msgs"]), 2)
        # the circuit-open archive produced no pair (not LLM-written comparator)
        ins = [q["archive_in"] for q in pairs]
        self.assertNotIn("global-2026-11-19T01-00-00.md", ins)

    def test_main_dry_run_summary_leg(self):
        base = Path(self.tmp.name)
        ts_path = base / "dashboard.ts"
        _write(ts_path, DASHBOARD_TS)
        out_path = base / "out.json"
        argv = [
            "replay-4434.py", "2", "--leg", "summary", "--dry-run",
            "--shared-state", str(base),
            "--dashboard-ts", str(ts_path),
            "--out", str(out_path),
            "--min-bytes", "0", "--max-bytes", "999999",
        ]
        saved = sys.argv
        try:
            sys.argv = argv
            rc = self.mod.main()
        finally:
            sys.argv = saved
        self.assertEqual(rc, 0)
        data = json.loads(out_path.read_text(encoding="utf-8"))
        self.assertEqual(data["leg"], "summary")
        self.assertEqual(len(data["pairs"]), 1)
        row = data["pairs"][0]
        self.assertEqual(row["msg_count"], 2)
        self.assertEqual(row["mode"], "dry-run")
        self.assertEqual(len(row["sections_comparator"]), 3)
        self.assertIn("summary leg added 2026-11-17", data["instrument"])

    def test_main_dry_run_status_leg_regression(self):
        base = Path(self.tmp.name)
        ts_path = base / "dashboard.ts"
        _write(ts_path, DASHBOARD_TS)
        out_path = base / "out-status.json"
        argv = [
            "replay-4434.py", "2", "--dry-run",
            "--shared-state", str(base),
            "--dashboard-ts", str(ts_path),
            "--out", str(out_path),
            "--min-bytes", "0", "--max-bytes", "999999",
            "--min-sections", "0",
        ]
        saved = sys.argv
        try:
            sys.argv = argv
            rc = self.mod.main()
        finally:
            sys.argv = saved
        self.assertEqual(rc, 0)
        data = json.loads(out_path.read_text(encoding="utf-8"))
        self.assertEqual(data["leg"], "status")
        # status leg still parses sections of the input status
        self.assertIn("Résumé", data["pairs"][0]["sections_in"])


class SummaryVariantTest(unittest.TestCase):
    """#4434 l.143 — registered --summary-variant pairs must keep the fresh-vs-
    fresh A/B comparable: same gate-checked FORMAT headings as production, the
    two placeholders fill_summary_prompts replaces, and the <5 Ko budget
    wording. Everything above the FORMAT block is the factor that varies."""

    @classmethod
    def setUpClass(cls):
        cls.mod = _load()

    def test_variant_keeps_gate_sections_and_placeholders(self):
        prod_sys, prod_usr = self.mod.extract_summary_templates(DASHBOARD_TS)
        for name, (v_sys, v_usr) in self.mod.SUMMARY_PROMPT_VARIANTS.items():
            with self.subTest(variant=name):
                self.assertEqual(
                    self.mod.summary_sections_present(v_sys),
                    self.mod.SUMMARY_REQUIRED_SECTIONS,
                )
                self.assertIn("5 Ko", v_sys)  # size budget requirement kept
                self.assertIn("${messages.length}", v_sys)  # FORMAT heading fill
                self.assertIn("${messages.length}", v_usr)
                self.assertIn("${messagesContent}", v_usr)
                self.assertNotEqual(v_sys, prod_sys)  # it IS a wording variation
                self.assertNotEqual(v_usr, prod_usr)

    def test_variant_fills_like_production(self):
        msgs = [
            ("2026-11-22T10:00:00.000Z", "myia-po-2027|roo-extensions", "message un"),
            ("2026-11-22T11:00:00.000Z", "myia-ai-01|roo-extensions", "message deux"),
        ]
        v_sys, v_usr = self.mod.SUMMARY_PROMPT_VARIANTS["reworded"]
        system, user = self.mod.fill_summary_prompts(v_sys, v_usr, msgs)
        self.assertNotIn("${", system)
        self.assertNotIn("${", user)
        self.assertIn("Résumé des 2 messages archivés", system)
        self.assertIn("[2026-11-22T11:00:00.000Z] myia-ai-01|roo-extensions\nmessage deux", user)


class CallPrimaryPayloadParityTest(unittest.TestCase):
    """#4434 G7b — call_primary must mirror the production fallback payload
    (dashboard.ts l.816-833): non-vLLM route sends BOTH the /no_think prefix
    AND top-level enable_thinking:false. Measured 22/11 on the hub fallback
    leg: without the field the thinking backend burns the whole 7200-token
    budget on hidden reasoning (0-byte content x2/6, truncated x1/6)."""

    def setUp(self):
        self.mod = _load()
        self.captured = {}

    def _fake_urlopen(self, req, timeout=None):
        self.captured = {
            "url": req.full_url,
            "body": json.loads(req.data.decode("utf-8")),
        }

        class _Resp:
            def read(self):
                return json.dumps({
                    "choices": [{"message": {"content": "ok"},
                                 "finish_reason": "stop"}],
                    "usage": {"prompt_tokens": 1, "completion_tokens": 1},
                }).encode("utf-8")

            def __enter__(self):
                return self

            def __exit__(self, *a):
                return False

        return _Resp()

    def _call(self, is_vllm):
        args = SimpleNamespace(model="deepseek-v4-flash",
                               base_url="https://hub.example/v1",
                               api_key="k-test", budget=5)
        real_urlopen = self.mod.urllib.request.urlopen
        self.mod.urllib.request.urlopen = self._fake_urlopen
        try:
            return self.mod.call_primary("sys", "user-body", args, is_vllm)
        finally:
            self.mod.urllib.request.urlopen = real_urlopen

    def test_non_vllm_route_sends_no_think_and_enable_thinking_false(self):
        self._call(is_vllm=False)
        body = self.captured["body"]
        user = body["messages"][1]["content"]
        self.assertTrue(user.startswith("/no_think\n"), "prefix missing")
        self.assertIn("user-body", user)
        self.assertIs(body["enable_thinking"], False,
                      "top-level enable_thinking:false missing (#4434 G7b)")

    def test_vllm_route_keeps_chat_template_kwargs_only(self):
        self._call(is_vllm=True)
        body = self.captured["body"]
        self.assertEqual(body["chat_template_kwargs"], {"enable_thinking": False})
        self.assertNotIn("enable_thinking", body)
        self.assertFalse(body["messages"][1]["content"].startswith("/no_think"))


class LoadDashboardTsEncodingTest(unittest.TestCase):
    """#4434 instrument defect (po-2027 c.7102517109): the git subprocesses of
    load_dashboard_ts decoded `git show` with the preferred locale encoding.
    On a French Windows seat (cp1252) the real dashboard.ts carries byte 0x8f
    and the whole replay died on UnicodeDecodeError; PYTHONUTF8=1 was the only
    workaround. The fix decodes UTF-8 explicitly, so the locale no longer
    matters — this test forces the cp1252 reading and must stay green."""

    @classmethod
    def setUpClass(cls):
        cls.mod = _load()
        cls.tmp = tempfile.TemporaryDirectory()
        cls.repo = Path(cls.tmp.name) / "sub"
        cls.repo.mkdir()
        # U+270F encodes to E2 9C 8F: byte 0x8f is undefined in cp1252
        cls.text = "export const s = 'a✏b';\n"
        (cls.repo / "dashboard.ts").write_text(cls.text, encoding="utf-8")
        for cmd in (
            ["git", "init", "-q"],
            ["git", "config", "user.email", "t@example.invalid"],
            ["git", "config", "user.name", "t"],
            ["git", "add", "dashboard.ts"],
            ["git", "-c", "commit.gpgsign=false", "commit", "-qm", "init"],
        ):
            subprocess.run(cmd, cwd=cls.repo, check=True, capture_output=True)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_git_calls_decode_utf8_explicitly(self):
        # The defect was `text=True` WITHOUT encoding: the decode then follows the
        # locale (cp1252 on a French Windows seat) and dashboard.ts carries byte
        # 0x8f -> UnicodeDecodeError. UTF-8 mode hides it, so this asserts the
        # contract (explicit encoding) rather than a locale we cannot force
        # portably on a UTF-8 CI runner.
        calls = []
        real_run = self.mod.subprocess.run

        def spy(cmd, **kw):
            calls.append((list(cmd), kw))
            out = "" if "--show-prefix" in cmd else self.text
            return subprocess.CompletedProcess(cmd, 0, stdout=out, stderr="")

        self.mod.subprocess.run = spy
        try:
            blob, prov = self.mod.load_dashboard_ts(str(self.repo / "dashboard.ts"), "HEAD")
        finally:
            self.mod.subprocess.run = real_run
        self.assertEqual(blob, self.text)
        self.assertEqual(prov["git_ref"], "HEAD")
        self.assertEqual(len(calls), 2)
        for cmd, kw in calls:
            self.assertEqual(kw.get("encoding"), "utf-8", f"{cmd} would decode with the locale")

    def test_git_show_round_trips_utf8_bytes(self):
        blob, prov = self.mod.load_dashboard_ts(str(self.repo / "dashboard.ts"), "HEAD")
        self.assertIn("✏", blob)
        self.assertEqual(blob, self.text)


if __name__ == "__main__":
    unittest.main()
