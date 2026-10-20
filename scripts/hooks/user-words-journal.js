#!/usr/bin/env node
// user-words-journal — what the user SAID survives the session (user mandate 20/10)
//
// Origin: user, 20/10/2026 — « si tu n'as pris aucune note de tout ce que je
// t'ai dit entre hier et aujourd'hui, c'est comme si je pissais dans un violon
// car tu auras tout oublié demain » / « un resserrage de harnais pour lutter
// [...] sur l'amnésie systémique ». Measured the same day: the coordinator's
// memory kept what it DID, not what the user SAID; 13 compactions in 48 h, each
// summary written by the agent itself, and nothing re-reads a transcript.
//
// Two roles, chosen by the payload's hook_event_name:
//   Stop / PreCompact / SessionEnd -> CAPTURE: copy every transcript entry
//       marked origin.kind == "human" into the workspace journal, verbatim.
//       Two shapes carry it: `type:"user"` (typed prompt) and the
//       `queued_command` attachment (message sent mid-turn). Cron prompts,
//       task notifications, skill bodies (isMeta) and compaction summaries
//       carry no human origin and are never captured.
//   SessionStart (startup / resume / clear / compact) -> RECALL: re-inject the
//       last RECALL_DAYS of the journal as additionalContext.
//
// Contract:
//   - stdin : the hook JSON payload (session_id, transcript_path, cwd, hook_event_name)
//   - stdout: only on SessionStart, the hookSpecificOutput JSON
//   - exit 0: ALWAYS — a memory hook must never block a turn or a session.
//
// Journal: <dir of transcript_path>/memory/user-words-journal.jsonl — the
// workspace's own memory directory, one JSON line per human message:
//   {"ts":"...","session_id":"...","key":"<uuid>","text":"..."}
// State (byte offset per transcript, seen keys): user-words-journal.state.json
// next to it. Overrides for tests: USER_WORDS_JOURNAL, USER_WORDS_STATE.
// The journal stays in the user profile, like the transcripts it copies.

const fs = require("fs");
const path = require("path");

const RECALL_DAYS = parseFloat(process.env.USER_WORDS_RECALL_DAYS || "7");
const RECALL_MAX_CHARS = parseInt(process.env.USER_WORDS_RECALL_MAX_CHARS || "8000", 10);
const ENTRY_MAX_CHARS = 4000;
const SEEN_KEEP = 2000;

function readStdin() {
  try {
    return fs.readFileSync(0, "utf8");
  } catch (e) {
    return "";
  }
}

function paths(payload) {
  const base = payload.transcript_path ? path.join(path.dirname(payload.transcript_path), "memory") : null;
  const journal = process.env.USER_WORDS_JOURNAL || (base && path.join(base, "user-words-journal.jsonl"));
  const state = process.env.USER_WORDS_STATE || (journal && journal.replace(/\.jsonl$/, "") + ".state.json");
  return { journal, state };
}

function textOf(content) {
  if (typeof content === "string") return content;
  if (Array.isArray(content)) {
    return content
      .filter((b) => b && b.type === "text" && typeof b.text === "string")
      .map((b) => b.text)
      .join("\n");
  }
  return "";
}

// A typed slash command is recorded as <command-name>/x</command-name> plus
// optional <command-args>. Keep "/x args" when there are args, drop it otherwise:
// a bare "/coordinate" carries no words to remember.
function normalize(text) {
  const name = text.match(/<command-name>([^<]*)<\/command-name>/);
  if (name) {
    const args = text.match(/<command-args>([\s\S]*?)<\/command-args>/);
    const a = args ? args[1].trim() : "";
    return a ? name[1].trim() + " " + a : "";
  }
  return text.trim();
}

// Returns { key, ts, text } for a human entry, null otherwise.
function humanEntry(d) {
  if (!d || typeof d !== "object") return null;
  if (d.type === "user" && d.origin && d.origin.kind === "human" && !d.isMeta && d.message) {
    return { key: d.uuid, ts: d.timestamp, text: textOf(d.message.content) };
  }
  const a = d.attachment;
  if (d.type === "attachment" && a && a.type === "queued_command" && a.origin && a.origin.kind === "human") {
    return { key: a.source_uuid || d.uuid, ts: a.timestamp || d.timestamp, text: textOf(a.prompt) };
  }
  return null;
}

function loadState(file) {
  try {
    const s = JSON.parse(fs.readFileSync(file, "utf8"));
    return { offsets: s.offsets || {}, seen: Array.isArray(s.seen) ? s.seen : [] };
  } catch (e) {
    return { offsets: {}, seen: [] };
  }
}

function capture(payload, p) {
  const tp = payload.transcript_path;
  if (!tp || !p.journal) return;
  let size;
  try {
    size = fs.statSync(tp).size;
  } catch (e) {
    return;
  }
  const state = loadState(p.state);
  let start = state.offsets[tp] || 0;
  if (start > size) start = 0; // transcript rewritten: rescan, the seen keys dedup
  if (start === size) return;

  const fd = fs.openSync(tp, "r");
  const buf = Buffer.alloc(size - start);
  fs.readSync(fd, buf, 0, buf.length, start);
  fs.closeSync(fd);
  // Stop at the last complete line; a half-written line is read next time.
  const lastNl = buf.lastIndexOf(0x0a);
  if (lastNl < 0) return;
  const lines = buf.slice(0, lastNl).toString("utf8").split("\n");

  const seen = new Set(state.seen);
  const out = [];
  for (const line of lines) {
    if (line.indexOf('"human"') < 0) continue; // cheap prefilter
    let d;
    try {
      d = JSON.parse(line);
    } catch (e) {
      continue;
    }
    const h = humanEntry(d);
    if (!h || !h.key || seen.has(h.key)) continue;
    const text = normalize(h.text);
    seen.add(h.key);
    if (!text) continue;
    out.push(
      JSON.stringify({
        ts: h.ts || new Date().toISOString(),
        session_id: payload.session_id || d.sessionId || "",
        key: h.key,
        text: text.length > ENTRY_MAX_CHARS ? text.slice(0, ENTRY_MAX_CHARS) + " […]" : text,
      })
    );
  }
  fs.mkdirSync(path.dirname(p.journal), { recursive: true });
  if (out.length) fs.appendFileSync(p.journal, out.join("\n") + "\n", "utf8");
  state.offsets[tp] = start + lastNl + 1;
  const keep = Array.from(seen).slice(-SEEN_KEEP);
  fs.writeFileSync(p.state, JSON.stringify({ offsets: state.offsets, seen: keep }), "utf8");
}

function recall(payload, p) {
  if (!p.journal) return;
  let raw;
  try {
    raw = fs.readFileSync(p.journal, "utf8");
  } catch (e) {
    return;
  }
  const cutoff = Date.now() - RECALL_DAYS * 86400000;
  const entries = [];
  for (const line of raw.split("\n")) {
    if (!line) continue;
    try {
      const e = JSON.parse(line);
      if (Date.parse(e.ts) >= cutoff) entries.push(e);
    } catch (err) {
      /* a torn line never kills the recall */
    }
  }
  if (!entries.length) return;
  // Several sessions append to the same journal (and the backfill goes file by
  // file): order by timestamp, not by line.
  entries.sort((a, b) => Date.parse(a.ts) - Date.parse(b.ts));
  // Newest first until the budget is spent, then print oldest -> newest.
  const picked = [];
  let used = 0;
  for (let i = entries.length - 1; i >= 0; i--) {
    const line = "- [" + String(entries[i].ts).slice(0, 16).replace("T", " ") + "Z] " + entries[i].text;
    if (used + line.length > RECALL_MAX_CHARS && picked.length) break;
    picked.unshift(line);
    used += line.length;
  }
  const dropped = entries.length - picked.length;
  const header =
    "User's own words in this workspace over the last " + RECALL_DAYS + " days " +
    "(automatic journal, verbatim, " + picked.length + " message(s)" +
    (dropped ? ", " + dropped + " older one(s) beyond the budget in " + p.journal : "") +
    "). These are instructions ALREADY GIVEN: act on them, never ask them again. " +
    "Anything that must outlive " + RECALL_DAYS + " days must be promoted into a memory fiche with the verbatim quote.";
  process.stdout.write(
    JSON.stringify({
      hookSpecificOutput: { hookEventName: "SessionStart", additionalContext: header + "\n" + picked.join("\n") },
    })
  );
}

// One-shot at install time: `node user-words-journal.js --backfill <projectDir> [days]`
// captures every transcript of that project directory touched in the last
// `days` (default RECALL_DAYS), so the first recall is not empty.
function backfill(projectDir, days) {
  const cutoff = Date.now() - days * 86400000;
  let n = 0;
  for (const f of fs.readdirSync(projectDir)) {
    if (!f.endsWith(".jsonl")) continue;
    const tp = path.join(projectDir, f);
    if (fs.statSync(tp).mtimeMs < cutoff) continue;
    capture({ transcript_path: tp, session_id: f.replace(/\.jsonl$/, "") }, paths({ transcript_path: tp }));
    n += 1;
  }
  process.stdout.write("backfilled " + n + " transcript(s) into " + paths({ transcript_path: path.join(projectDir, "x") }).journal + "\n");
}

function main() {
  if (process.argv[2] === "--backfill") {
    try {
      backfill(process.argv[3], parseFloat(process.argv[4] || String(RECALL_DAYS)));
    } catch (e) {
      process.stdout.write("backfill failed: " + e.message + "\n");
    }
    return;
  }
  let payload;
  try {
    payload = JSON.parse(readStdin() || "{}");
  } catch (e) {
    return;
  }
  const p = paths(payload);
  const ev = payload.hook_event_name;
  try {
    if (ev === "SessionStart") recall(payload, p);
    else if (ev === "Stop" || ev === "PreCompact" || ev === "SessionEnd") capture(payload, p);
  } catch (e) {
    /* exit 0 whatever happens */
  }
}

main();
process.exit(0);
