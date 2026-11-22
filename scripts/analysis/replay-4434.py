#!/usr/bin/env python3
"""#4434 — Condensation replay, status leg + summary leg (read-only instrument).

RECONSTRUCTION (2026-11-16, lane myia-ai-01:roo-extensions): the original
`replay-4434.py` that produced the 02/11 measurement (issue comment
6572874103, lane po-2025) lived on a session scratchpad; its transfer was
still pending (msg-20261115T150322-vl3zv0, report note of 15/11). This file
rebuilds the PUBLISHED protocol — it is not the bytes that produced the 02/11
numbers. If the original ever lands, it supersedes this reconstruction.

Protocol (per c.6572874103):
- Real pairs from `<shared-state>/dashboards/archive/`: entry = the
  "## Statut avant condensation" block of archive T (input status) + the
  messages archive T archived (feed, all annotated [SERA ARCHIVÉ] — the
  documented approximation: production also shows [CONSERVÉ] messages);
  comparator = the "Statut avant condensation" block of the next archive of
  the same key (= the status pass T actually wrote in production).
- Production prompts, extracted MECHANICALLY from `dashboard.ts` at a chosen
  revision: system + user templates of `generateStatusUpdate`, budget lines
  derived from STATUS_SECTION_WORD_BUDGETS in the same file (no paraphrase).
- Production params: max_tokens = CONDENSE_LLM_MAX_TOKENS (7200), temperature
  0.3, chat_template_kwargs {enable_thinking: false} on vLLM endpoints
  (localhost/private IP) else a `/no_think` prefix + top-level
  `enable_thinking: false` (#4434 G7b production parity), strictly sequential, one
  call per pair, wait budget 600 s.
- Conservation (structural, no content judgment): canonical sections present
  in BOTH input and output / canonical sections present in the input.

Summary leg (--leg summary, added 2026-11-17 for the #4434 G-series; the
status leg alone says nothing about the OTHER condensation pass):
- entry = the messages archive T archived (feed rebuilt in the PRODUCTION
  format of generateLLMSummary: `[ts] machineId|workspace` + content, joined
  by blank `---` separators, no [SERA ARCHIVÉ] annotation — the summary pass
  receives the raw messages);
- comparator = the `CONDENSATION-SUMMARY` system message condensation T
  posted (it lives in archive T+1's feed; joined by the footer line naming
  `archive/<fn T>`, falling back to nearest timestamp to T's archivedAt);
- templates extracted MECHANICALLY from `generateLLMSummary` in dashboard.ts
  (same file/revision mechanics as the status leg); params identical;
- structural metric = the three imposed FORMAT sections (Thèmes principaux,
  Actions et résultats, Décisions et métriques) present in the output,
  compared case- and accent-insensitively, mirroring the production guard
  `validateSummaryCompleteness` (dashboard.ts); plus finish reason, output
  bytes vs the 5 Ko prompt ceiling and line count vs the 20-line ceiling.

Read-only: no dashboard/PG/Qdrant write. The output JSON holds counters,
sizes and section NAMES only — never status or message content, no API key.

Usage:
    python scripts/analysis/replay-4434.py [n] [--dry-run] [...filters]

    # 02/11 regime (statuses 12-16.5 KB — predates the ms#1633 budget chain):
    python scripts/analysis/replay-4434.py 10
    # current regime (statuses 4-7 KB): widen the size window
    python scripts/analysis/replay-4434.py 10 --min-bytes 3000 --max-bytes 9000
    # summary leg (the size window then applies to the summed message bytes):
    python scripts/analysis/replay-4434.py 5 --leg summary
"""

import argparse
import json
import os
import random
import re
import subprocess
import sys
import time
import unicodedata
import urllib.request

STATUS_BEFORE_RE = re.compile(r"## Statut avant condensation \(#3962\)\n(.*?)\n---", re.S)
MSG_HEADER_RE = re.compile(r"^### \[([0-9T:.Z-]+)\] (.+)$", re.M)
ARCHIVE_TS_RE = re.compile(r"-(\d{4}-\d{2}-\d{2})T(\d{2})-(\d{2})-(\d{2})")
FM_RE = re.compile(r"^---\n(.*?)\n---\n", re.S)

# Ported from STATUS_SECTION_WORD_BUDGETS tests (dashboard.ts) — the metric
# regexes live here so the instrument stays self-contained; the PROMPT budget
# lines are still extracted mechanically from dashboard.ts.
SECTION_RES = [
    ("Résumé", re.compile(r"^#{1,6}\s*R[ée]sum[ée](?![A-Za-zÀ-ÿ])", re.I | re.M)),
    ("État des systèmes", re.compile(r"^#{1,6}\s*État des syst[èe]mes(?![A-Za-zÀ-ÿ])", re.I | re.M)),
    ("Décisions actées", re.compile(r"^#{1,6}\s*D[ée]cisions act[ée]es(?![A-Za-zÀ-ÿ])", re.I | re.M)),
    ("Blocages structurels", re.compile(r"^#{1,6}\s*Blocages structur(?:els|es)(?![A-Za-zÀ-ÿ])", re.I | re.M)),
    ("Livrables récents", re.compile(r"^#{1,6}\s*Livrables r[ée]cents(?![A-Za-zÀ-ÿ])", re.I | re.M)),
    ("En cours", re.compile(r"^#{1,6}\s*En cours(?![A-Za-zÀ-ÿ])", re.I | re.M)),
    ("Métriques de référence", re.compile(r"^#{1,6}\s*M[ée]triques de r[ée]f[ée]rence(?![A-Za-zÀ-ÿ])", re.I | re.M)),
    ("Patterns appris", re.compile(r"^#{1,6}\s*Patterns appris(?![A-Za-zÀ-ÿ])", re.I | re.M)),
]

# Summary leg — ported from SUMMARY_REQUIRED_SECTIONS / validateSummaryCompleteness
# (dashboard.ts): the three FORMAT headings the summary prompt imposes,
# matched on a case- and accent-folded copy of the text (the production guard
# normalizes NFD, strips combining marks, lowercases — reproduced here so the
# instrument stays self-contained and faithful to the gate it mirrors).
SUMMARY_REQUIRED_SECTIONS = ["themes principaux", "actions et resultats", "decisions et metriques"]
CONDENSE_SUMMARY_TS_RE = re.compile(r"\*\*CONDENSATION-SUMMARY\*\* - ([0-9T:.Z-]+)")


def normalize_fold(s: str) -> str:
    return "".join(
        ch for ch in unicodedata.normalize("NFD", s) if not unicodedata.combining(ch)
    ).lower()


def summary_sections_present(text: str) -> list:
    n = normalize_fold(text)
    return [s for s in SUMMARY_REQUIRED_SECTIONS if s in n]


def sections_of(status: str) -> list:
    return [name for name, rx in SECTION_RES if rx.search(status)]


def parse_frontmatter(text: str) -> dict:
    m = FM_RE.match(text)
    fm = {}
    if m:
        for line in m.group(1).split("\n"):
            if ":" in line:
                k, v = line.split(":", 1)
                fm[k.strip()] = v.strip().strip("'\"")
    return fm


def split_status_and_messages(text: str):
    """Archive body -> (input status block, [(ts, author, content)])."""
    sb = STATUS_BEFORE_RE.search(text)
    if not sb:
        return None, []
    status = sb.group(1).strip()
    rest = text[sb.end():]
    msgs = []
    headers = list(MSG_HEADER_RE.finditer(rest))
    for i, h in enumerate(headers):
        end = headers[i + 1].start() if i + 1 < len(headers) else len(rest)
        content = rest[h.end():end]
        lines = [ln for ln in content.split("\n")]
        while lines and lines[0].strip() in ("", "---"):
            lines.pop(0)
        while lines and lines[-1].strip() in ("", "---"):
            lines.pop()
        msgs.append((h.group(1), h.group(2), "\n".join(lines).strip()))
    return status, msgs


def load_dashboard_ts(path: str, ref: str | None) -> tuple:
    """Return (template source text, provenance dict). With --ref, the file is
    read from that git revision of its own repository (submodule)."""
    if ref:
        d = os.path.dirname(os.path.abspath(path))
        prefix = subprocess.run(
            ["git", "-C", d, "rev-parse", "--show-prefix"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
        blob = subprocess.run(
            ["git", "-C", d, "show", f"{ref}:{prefix}{os.path.basename(path)}"],
            capture_output=True, text=True, check=True,
        ).stdout
        return blob, {"path": os.path.relpath(path), "git_ref": ref}
    sha = ""
    try:
        d = os.path.dirname(os.path.abspath(path))
        sha = subprocess.run(
            ["git", "-C", d, "log", "-1", "--format=%H", "--", os.path.basename(path)],
            capture_output=True, text=True,
        ).stdout.strip()
    except subprocess.CalledProcessError:
        pass
    with open(path, encoding="utf-8", errors="replace") as f:
        try:
            rel = os.path.relpath(path)
        except ValueError:  # different drives (Windows) — keep the absolute form
            rel = os.path.abspath(path)
        return f.read(), {"path": rel, "git_sha": sha}


def extract_templates(ts_text: str) -> tuple:
    """System + user prompt templates of generateStatusUpdate, verbatim."""
    i = ts_text.find("async function generateStatusUpdate")
    if i < 0:
        raise RuntimeError("generateStatusUpdate not found in dashboard.ts")
    seg = ts_text[i:]
    sm = re.search(r"const systemPrompt = `(.*?)`;", seg, re.S)
    um = re.search(r"const userPrompt = `(.*?)`;", seg, re.S)
    if not sm or not um:
        raise RuntimeError("status-leg prompt templates not found in dashboard.ts")
    return sm.group(1), um.group(1)


def extract_budget_lines(ts_text: str) -> list:
    m = re.search(r"export const STATUS_SECTION_WORD_BUDGETS.*?=\s*\[(.*?)\n\]", ts_text, re.S)
    if not m:
        raise RuntimeError("STATUS_SECTION_WORD_BUDGETS table not found in dashboard.ts")
    out = []
    for name, budget, hint in re.findall(
        r"name:\s*'([^']+)'[^\n]*?budget:\s*(\d+)(?:,[^\n]*?hint:\s*'([^']*)')?", m.group(1)
    ):
        out.append(f"- {name} : ≤ {budget} mots" + (f" ({hint})" if hint else ""))
    if not out:
        raise RuntimeError("no budget entries parsed from dashboard.ts")
    return out


def extract_summary_templates(ts_text: str) -> tuple:
    """System + user prompt templates of generateLLMSummary, verbatim."""
    i = ts_text.find("async function generateLLMSummary")
    if i < 0:
        raise RuntimeError("generateLLMSummary not found in dashboard.ts")
    seg = ts_text[i:]
    sm = re.search(r"const systemPrompt = `(.*?)`;", seg, re.S)
    um = re.search(r"const userPrompt = `(.*?)`;", seg, re.S)
    if not sm or not um:
        raise RuntimeError("summary-leg prompt templates not found in dashboard.ts")
    return sm.group(1), um.group(1)


def fill_summary_prompts(sys_tpl: str, usr_tpl: str, msgs: list) -> tuple:
    """Rebuild the production feed of generateLLMSummary from parsed messages.

    Production format (dashboard.ts): `[ts] machineId|workspace\\ncontent`
    joined by blank `---` separators — the summary pass sees the raw messages,
    with no [SERA ARCHIVÉ] annotation (that annotation belongs to the status
    leg's approximation of its own feed).
    """
    feed = "\n\n---\n\n".join(f"[{ts}] {author}\n{content}" for ts, author, content in msgs)
    n = str(len(msgs))
    system = sys_tpl.replace("${messages.length}", n)
    user = usr_tpl.replace("${messages.length}", n).replace("${messagesContent}", feed)
    return system, user


def find_summary_comparator(text_next: str, fn_in: str, archived_at: str) -> tuple:
    """Locate the summary condensation T actually wrote, inside archive T+1.

    Condensation T posts its summary as a `system|system` CONDENSATION-SUMMARY
    intercom message, which the NEXT condensation archives — so the comparator
    lives in archive T+1's feed. Primary join: the message footer names
    ``archive/<fn T>`` verbatim. Fallback: the CONDENSATION-SUMMARY message
    whose embedded timestamp is nearest T's archivedAt. Returns
    (content, posted_ts) or (None, None).
    """
    _s, msgs_next = split_status_and_messages(text_next)
    exact = None
    best = None  # (abs_delta_seconds, content, posted_ts)
    for ts, author, content in msgs_next:
        if author != "system|system" or "**CONDENSATION-SUMMARY**" not in content:
            continue
        m = CONDENSE_SUMMARY_TS_RE.search(content)
        if not m:
            continue
        posted = m.group(1)
        if f"archive/{fn_in}" in content:
            exact = (content, posted)
            break
        try:
            from datetime import datetime, timezone

            def _parse(x):
                return datetime.fromisoformat(x.replace("Z", "+00:00"))

            delta = abs((_parse(posted) - _parse(archived_at)).total_seconds())
        except ValueError:
            continue
        if best is None or delta < best[0]:
            best = (delta, content, posted)
    if exact:
        return exact
    if best and best[0] <= 600:
        return best[1], best[2]
    return None, None


def fill_prompts(sys_tpl: str, usr_tpl: str, budget_lines: list, key: str, status: str, msgs: list):
    feed = "\n\n---\n\n".join(
        f"[SERA ARCHIVÉ] [{ts}] {author}\n{content}" for ts, author, content in msgs
    )
    last_date = msgs[-1][0] if msgs else "1970-01-01T00:00:00.000Z"
    system = sys_tpl.replace("${statusBudgetPromptLines().join('\\n')}", "\n".join(budget_lines))
    system = system.replace("${dashboardKey}", key).replace("${lastDate}", last_date)
    user = (
        usr_tpl.replace("${allMessages.length - archivedCount}", str(0))
        .replace("${allMessages.length}", str(len(msgs)))
        .replace("${archivedCount}", str(len(msgs)))
        .replace("${previousStatus}", status)
        .replace("${messagesContent}", feed)
        .replace("${lastDate}", last_date)
    )
    return system, user, last_date


def build_pairs(archive_dir: str, args) -> list:
    groups = {}
    for fn in sorted(os.listdir(archive_dir)):
        if not fn.endswith(".md"):
            continue
        path = os.path.join(archive_dir, fn)
        with open(path, encoding="utf-8", errors="replace") as f:
            text = f.read()
        fm = parse_frontmatter(text)
        key = fm.get("originalKey")
        if not key:
            continue
        archived_at = fm.get("archivedAt", "")
        groups.setdefault(key, []).append((fn, path, text, fm, archived_at))

    pairs = []
    for key, archives in groups.items():
        archives.sort(key=lambda a: a[4])
        for t in range(len(archives) - 1):
            fn_in, path_in, text_in, fm_in, at_in = archives[t]
            fn_out, _p, text_out, _f, at_out = archives[t + 1]
            if at_in < args.since:
                continue
            if getattr(args, "leg", "status") == "summary":
                # Summary leg: input = T's messages (production feed format);
                # comparator = the CONDENSATION-SUMMARY message T posted, found
                # in T+1's feed. Comparator filter: T's summary pass must be
                # LLM-written ('ok' / 'ok-with-fallback') — a husk/truncated
                # comparator (circuit-open, timeout, error) is not a reference.
                if not str(fm_in.get("summaryOutcome", "")).startswith("ok"):
                    continue
                _status_in, msgs = split_status_and_messages(text_in)
                if not msgs:
                    continue
                feed_bytes = sum(len(c.encode("utf-8")) for _ts, _a, c in msgs)
                if not (args.min_bytes <= feed_bytes <= args.max_bytes):
                    continue
                cmp_content, cmp_ts = find_summary_comparator(text_out, fn_in, at_in)
                if cmp_content is None:
                    continue
                pairs.append({
                    "key": key,
                    "archive_in": fn_in,
                    "archive_out": fn_out,
                    "msgs": msgs,
                    "comparator": cmp_content,
                    "comparator_ts": cmp_ts,
                    "comparator_model": fm_in.get("summaryFallbackModel", ""),
                    "feed_bytes": feed_bytes,
                })
                continue
            status_in, msgs = split_status_and_messages(text_in)
            status_out, _ = split_status_and_messages(text_out)
            if not status_in or not status_out or not msgs:
                continue
            n_bytes = len(status_in.encode("utf-8"))
            secs = sections_of(status_in)
            if not (args.min_bytes <= n_bytes <= args.max_bytes):
                continue
            if len(secs) < args.min_sections:
                continue
            if args.require_comparator_fallback and fm_in.get("statusOutcome") != "ok-with-fallback":
                continue
            pairs.append({
                "key": key,
                "archive_in": fn_in,
                "archive_out": fn_out,
                "status_in": status_in,
                "msgs": msgs,
                "comparator": status_out,
                "comparator_model": fm_in.get("statusFallbackModel", ""),
            })
    return pairs


def call_primary(system: str, user: str, args, is_vllm: bool) -> dict:
    messages = [{"role": "system", "content": system}]
    if is_vllm:
        payload_extra = {"chat_template_kwargs": {"enable_thinking": False}}
    else:
        # Production parity (#4434 G7b, dashboard.ts l.816-833): the non-vLLM
        # route sends BOTH the /no_think prefix and top-level
        # enable_thinking:false. Measured 22/11 on the hub fallback leg:
        # without the field the thinking backend burns the whole 7200-token
        # budget on hidden reasoning (0-byte content x2/6, truncated x1/6,
        # 37-42 s); with it 6/6 finish=stop, 0 reasoning chars, 12-14 s.
        payload_extra = {"enable_thinking": False}
        user = "/no_think\n" + user
    messages.append({"role": "user", "content": user})
    payload = {
        "model": args.model,
        "messages": messages,
        "max_tokens": 7200,
        "temperature": 0.3,
        **payload_extra,
    }
    req = urllib.request.Request(
        args.base_url.rstrip("/") + "/chat/completions",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {args.api_key}",
        },
        method="POST",
    )
    t0 = time.monotonic()
    with urllib.request.urlopen(req, timeout=args.budget) as resp:
        body = json.loads(resp.read().decode("utf-8"))
    elapsed = time.monotonic() - t0
    choice = body["choices"][0]
    usage = body.get("usage", {}) or {}
    return {
        "content": choice.get("message", {}).get("content") or "",
        "finish": choice.get("finish_reason"),
        "tokens_in": usage.get("prompt_tokens"),
        "tokens_out": usage.get("completion_tokens"),
        "latency_s": round(elapsed, 1),
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    repo = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    default_state = os.environ.get(
        "ROOSYNC_SHARED_PATH", "G:/Mon Drive/Synchronisation/RooSync/.shared-state"
    )
    ap.add_argument("n", nargs="?", type=int, default=10)
    ap.add_argument("--shared-state", default=default_state)
    ap.add_argument(
        "--leg", choices=("status", "summary"), default="status",
        help="condensation pass to replay: status (generateStatusUpdate) or "
             "summary (generateLLMSummary)",
    )
    ap.add_argument("--since", default="2026-10-04")  # first archives embedding the status
    ap.add_argument("--min-bytes", type=int, default=None,
                    help="status leg: input status bytes (default 12000); summary leg: "
                         "summed message bytes (default 3000)")
    ap.add_argument("--max-bytes", type=int, default=None,
                    help="status leg: default 16500; summary leg: default 60000")
    ap.add_argument("--min-sections", type=int, default=3)
    ap.add_argument("--require-comparator-fallback", action=argparse.BooleanOptionalAction, default=True)
    ap.add_argument("--seed", type=int, default=4434)
    ap.add_argument(
        "--dashboard-ts",
        default=os.path.join(repo, "mcps", "internal", "servers", "roo-state-manager",
                             "src", "tools", "roosync", "dashboard.ts"),
    )
    ap.add_argument("--ref", default=None, help="git ref of dashboard.ts (its own repo)")
    ap.add_argument("--base-url", default=os.environ.get("OPENAI_BASE_URL", ""))
    ap.add_argument("--model", default=os.environ.get("OPENAI_CHAT_MODEL_ID", "qwen3.6-35b-a3b"))
    ap.add_argument("--api-key", default=os.environ.get("VLLM_API_KEY_MEDIUM")
                    or os.environ.get("OPENAI_API_KEY", ""))
    ap.add_argument("--budget", type=int, default=600)
    ap.add_argument("--out", default="replay-4434.json")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    args.since = args.since + "T00:00:00"
    if args.min_bytes is None:
        args.min_bytes = 12000 if args.leg == "status" else 3000
    if args.max_bytes is None:
        args.max_bytes = 16500 if args.leg == "status" else 60000

    ts_text, prov = load_dashboard_ts(args.dashboard_ts, args.ref)
    if args.leg == "summary":
        sys_tpl, usr_tpl = extract_summary_templates(ts_text)
        budget_lines = None
    else:
        sys_tpl, usr_tpl = extract_templates(ts_text)
        budget_lines = extract_budget_lines(ts_text)

    archive_dir = os.path.join(args.shared_state, "dashboards", "archive")
    if not os.path.isdir(archive_dir):
        print(f"error: archive dir not found: {archive_dir}", file=sys.stderr)
        return 2
    pairs = build_pairs(archive_dir, args)
    print(f"leg={args.leg} eligible_pairs={len(pairs)} (filters: {args.min_bytes}-{args.max_bytes} o, "
          f">= {args.min_sections} sections, comparator ok-with-fallback="
          f"{args.require_comparator_fallback if args.leg == 'status' else 'n/a (summaryOutcome ok*)'}, "
          f"since {args.since})")
    if not pairs:
        print("no eligible pair — widen --min-bytes/--max-bytes for the current 4-7 KB regime",
              file=sys.stderr)
        return 1
    random.Random(args.seed).shuffle(pairs)
    selected = pairs[: args.n]

    base = args.base_url or ""
    is_vllm = any(s in base for s in
                  ("text-generation-webui", "localhost", "127.0.0.1", "192.168.", "10.0.", "172."))
    if not args.dry_run and (not base or not args.api_key):
        print("error: --base-url (OPENAI_BASE_URL) and an API key are required for live replay",
              file=sys.stderr)
        return 2

    results = []
    for i, p in enumerate(selected, 1):
        if args.leg == "summary":
            system, user = fill_summary_prompts(sys_tpl, usr_tpl, p["msgs"])
            secs_cmp = summary_sections_present(p["comparator"])
            row = {
                "key": p["key"],
                "archive_in": p["archive_in"],
                "archive_out": p["archive_out"],
                "comparator_ts": p["comparator_ts"],
                "msg_count": len(p["msgs"]),
                "last_date": p["msgs"][-1][0] if p["msgs"] else "",
                "feed_bytes": p["feed_bytes"],
                "comparator_bytes": len(p["comparator"].encode("utf-8")),
                "comparator_model": p["comparator_model"],
                "sections_comparator": secs_cmp,
                "system_prompt_bytes": len(system.encode("utf-8")),
                "user_prompt_bytes": len(user.encode("utf-8")),
            }
            metric_in = f"comparator {len(secs_cmp)}/{len(SUMMARY_REQUIRED_SECTIONS)}"
        else:
            system, user, last_date = fill_prompts(sys_tpl, usr_tpl, budget_lines, p["key"], p["status_in"], p["msgs"])
            secs_in = sections_of(p["status_in"])
            row = {
                "key": p["key"],
                "archive_in": p["archive_in"],
                "archive_out": p["archive_out"],
                "last_date": last_date,
                "in_bytes": len(p["status_in"].encode("utf-8")),
                "comparator_bytes": len(p["comparator"].encode("utf-8")),
                "comparator_model": p["comparator_model"],
                "sections_in": secs_in,
                "system_prompt_bytes": len(system.encode("utf-8")),
                "user_prompt_bytes": len(user.encode("utf-8")),
            }
            row["sections_comparator"] = sections_of(p["comparator"])
            row["conservation_comparator"] = f"{len(set(secs_in) & set(row['sections_comparator']))}/{len(secs_in)}"
            metric_in = f"in={row['in_bytes']} o, {len(secs_in)} sections"
        if args.dry_run:
            row["mode"] = "dry-run"
            results.append(row)
            print(f"[{i}/{len(selected)}] {p['key']} dry-run: {metric_in}, "
                  f"prompt={row['system_prompt_bytes']}+{row['user_prompt_bytes']} o")
            continue
        try:
            r = call_primary(system, user, args, is_vllm)
            if args.leg == "summary":
                secs_out = summary_sections_present(r["content"])
                out_bytes = len(r["content"].encode("utf-8"))
                lines_out = r["content"].count("\n") + 1
                row.update({
                    "mode": "live",
                    "out_bytes": out_bytes,
                    "lines_out": lines_out,
                    "sections_primary": secs_out,
                    "format_ok": len(secs_out) == len(SUMMARY_REQUIRED_SECTIONS),
                    "within_5kb": out_bytes <= 5120,
                    "within_20_lines": lines_out <= 20,
                    "finish": r["finish"],
                    "latency_s": r["latency_s"],
                    "tokens_in": r["tokens_in"],
                    "tokens_out": r["tokens_out"],
                    "tok_s": round(r["tokens_out"] / r["latency_s"], 1) if r.get("tokens_out") else None,
                })
                print(f"[{i}/{len(selected)}] {p['key']}: sections {len(secs_out)}/{len(SUMMARY_REQUIRED_SECTIONS)} "
                      f"({metric_in}), finish={r['finish']}, {out_bytes} o/{lines_out} lignes, "
                      f"{r['latency_s']}s")
            else:
                secs_out = sections_of(r["content"])
                row.update({
                    "mode": "live",
                    "out_bytes": len(r["content"].encode("utf-8")),
                    "sections_primary": secs_out,
                    "conservation_primary": f"{len(set(secs_in) & set(secs_out))}/{len(secs_in)}",
                    "finish": r["finish"],
                    "latency_s": r["latency_s"],
                    "tokens_in": r["tokens_in"],
                    "tokens_out": r["tokens_out"],
                    "tok_s": round(r["tokens_out"] / r["latency_s"], 1) if r.get("tokens_out") else None,
                })
                print(f"[{i}/{len(selected)}] {p['key']}: conservation {row['conservation_primary']} "
                      f"(comparator {row['conservation_comparator']}), finish={r['finish']}, "
                      f"{r['latency_s']}s")
        except Exception as e:  # noqa: BLE001 — one failure must not stop the sequence
            row.update({"mode": "live", "error": f"{type(e).__name__}: {e}"})
            print(f"[{i}/{len(selected)}] {p['key']}: ERROR {type(e).__name__}: {e}", file=sys.stderr)
        results.append(row)

    out = {
        "instrument": "replay-4434.py RECONSTRUCTION 2026-11-16 (myia-ai-01:roo-extensions), "
                      "protocol from issue #4434 comment 6572874103 (02/11, po-2025); "
                      "summary leg added 2026-11-17 (myia-po-2023:roo-extensions)",
        "leg": args.leg,
        "dashboard_ts": prov,
        "params": {
            "model": args.model,
            "base_url_host": base.split("//")[-1].split("/")[0] if base else None,
            "max_tokens": 7200,
            "temperature": 0.3,
            "thinking_control": "chat_template_kwargs" if is_vllm else "/no_think",
            "budget_s": args.budget,
            "sequential": True,
        },
        "selection": {
            "eligible_pairs": len(pairs),
            "n_selected": len(selected),
            "seed": args.seed,
            "filters": {"min_bytes": args.min_bytes, "max_bytes": args.max_bytes,
                        "min_sections": args.min_sections, "since": args.since,
                        "require_comparator_fallback": args.require_comparator_fallback},
        },
        "pairs": results,
    }
    if not args.dry_run:
        if args.leg == "summary":
            live_rows = [r for r in results if r.get("mode") == "live" and "error" not in r]
            out["aggregate"] = {
                "pairs_answered": len(live_rows),
                "format_ok_3_of_3": len([r for r in live_rows if r.get("format_ok")]),
                "finish_stop": len([r for r in live_rows if r.get("finish") == "stop"]),
                "within_5kb": len([r for r in live_rows if r.get("within_5kb")]),
                "within_20_lines": len([r for r in live_rows if r.get("within_20_lines")]),
                "comparator_format_ok": len(
                    [r for r in results if len(r.get("sections_comparator", [])) == len(SUMMARY_REQUIRED_SECTIONS)]
                ),
            }
        else:
            prim = [r for r in results if r.get("conservation_primary")]
            if prim:
                tot_in = sum(int(r["conservation_primary"].split("/")[1]) for r in prim)
                tot_out = sum(int(r["conservation_primary"].split("/")[0]) for r in prim)
                out["aggregate"] = {
                    "pairs_answered": len(prim),
                    "primary_conservation": f"{tot_out}/{tot_in}",
                    "primary_conservation_pct": round(100 * tot_out / tot_in, 1) if tot_in else None,
                }
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    print(f"wrote {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
