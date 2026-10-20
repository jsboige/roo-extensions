#!/usr/bin/env node
// Tests du hook user-words-journal — sans dependance, lances par `node`.
//
//   node scripts/hooks/tests/user-words-journal.test.js     # exit 0 = tout vert
//
// Chaque cas pipe un payload reel (spawnSync du VRAI hook) sur un transcript
// fabrique avec les formes MESUREES le 20/10 dans un transcript ai-01 :
// prompt tape (type:user + origin human), message mid-turn (attachment
// queued_command + origin human), et les quatre formes qui ne sont PAS des
// paroles du user (cron sans origin, task-notification, isMeta, resume de
// compaction). La contre-epreuve est structurante : un journal qui capture
// le bruit noie la parole, un journal qui rate le mid-turn rate le cas fondateur.

const { spawnSync } = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");

const HOOK = path.join(__dirname, "..", "user-words-journal.js");
const DIR = fs.mkdtempSync(path.join(os.tmpdir(), "uwj-"));
const TRANSCRIPT = path.join(DIR, "session.jsonl");
const JOURNAL = path.join(DIR, "memory", "user-words-journal.jsonl");
const STATE = path.join(DIR, "memory", "user-words-journal.state.json");

let failures = 0;
function check(name, cond, detail) {
  if (cond) console.log("  ok   " + name);
  else {
    failures += 1;
    console.log("  FAIL " + name + (detail ? " -- " + detail : ""));
  }
}

function run(event, extra, env) {
  const payload = JSON.stringify({
    session_id: "s1",
    transcript_path: TRANSCRIPT,
    cwd: DIR,
    hook_event_name: event,
    ...(extra || {}),
  });
  const r = spawnSync(process.execPath, [HOOK], { input: payload, encoding: "utf8", env: { ...process.env, ...(env || {}) } });
  return { code: r.status, out: r.stdout || "" };
}

function journal() {
  try {
    return fs.readFileSync(JOURNAL, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));
  } catch (e) {
    return [];
  }
}

const now = new Date().toISOString();
const old = new Date(Date.now() - 10 * 86400000).toISOString();
const L = (o) => JSON.stringify(o) + "\n";

// --- Transcript, premiere tranche ---------------------------------------
fs.writeFileSync(
  TRANSCRIPT,
  L({ type: "user", uuid: "u1", timestamp: now, origin: { kind: "human" }, message: { role: "user", content: "Go pour tes recos" } }) +
    L({ type: "user", uuid: "u2", timestamp: now, message: { content: "<command-message>coordinate</command-message>\n<command-name>/coordinate</command-name>" } }) +
    L({ type: "user", uuid: "u3", timestamp: now, isMeta: true, origin: { kind: "human" }, message: { content: "# Coordination skill body" } }) +
    L({ type: "user", uuid: "u4", timestamp: now, origin: { kind: "task-notification" }, message: { content: "<task-notification>x</task-notification>" } }) +
    L({ type: "user", uuid: "u5", timestamp: now, isCompactSummary: true, message: { content: "This session is being continued" } }) +
    L({ type: "user", uuid: "u6", timestamp: now, message: { content: [{ type: "tool_result", tool_use_id: "t", content: "human" }] } }) +
    L({ type: "attachment", uuid: "a1", timestamp: now, attachment: { type: "queued_command", origin: { kind: "human" }, source_uuid: "src-1", timestamp: now, prompt: [{ type: "text", text: "Et puis note accessoirement" }] } }) +
    L({ type: "attachment", uuid: "a2", timestamp: now, attachment: { type: "queued_command", origin: { kind: "task-notification" }, source_uuid: "src-2", prompt: "<task-notification>y</task-notification>" } }) +
    L({ type: "user", uuid: "u7", timestamp: now, origin: { kind: "human" }, message: { content: "<command-name>/coordinate</command-name>" } }) +
    L({ type: "user", uuid: "u8", timestamp: now, origin: { kind: "human" }, message: { content: "<command-name>/executor</command-name>\n<command-args>prends #4293</command-args>" } }) +
    // ligne a moitie ecrite : ne doit pas etre lue avant d'etre complete
    '{"type":"user","uuid":"u9","origin":{"kind":"human"},"message":{"content":"plus tard'
);

let r = run("Stop", null, { USER_WORDS_JOURNAL: JOURNAL, USER_WORDS_STATE: STATE });
let j = journal();
check("Stop exits 0", r.code === 0, "exit=" + r.code);
check("Stop writes nothing to stdout", r.out === "", JSON.stringify(r.out));
check("typed prompt captured verbatim", j.some((e) => e.text === "Go pour tes recos"));
check("mid-turn queued_command captured", j.some((e) => e.text === "Et puis note accessoirement" && e.key === "src-1"));
check("slash command with args kept as '/cmd args'", j.some((e) => e.text === "/executor prends #4293"));
check("bare slash command dropped", !j.some((e) => /coordinate/.test(e.text)));
check("cron / isMeta / notification / summary / tool_result not captured", j.length === 3, "got " + j.length + ": " + j.map((e) => e.text).join(" | "));
check("half-written line not read yet", !j.some((e) => /plus tard/.test(e.text)));

// --- Deuxieme passe : idempotence + reprise a l'offset -------------------
r = run("Stop", null, { USER_WORDS_JOURNAL: JOURNAL, USER_WORDS_STATE: STATE });
check("second Stop with no new line adds nothing", journal().length === 3, "got " + journal().length);

fs.appendFileSync(TRANSCRIPT, '"}}\n' + L({ type: "user", uuid: "u1", timestamp: now, origin: { kind: "human" }, message: { content: "Go pour tes recos" } }));
r = run("PreCompact", null, { USER_WORDS_JOURNAL: JOURNAL, USER_WORDS_STATE: STATE });
j = journal();
check("PreCompact captures the completed line", j.some((e) => e.text === "plus tard"));
check("an already seen uuid is not duplicated", j.filter((e) => e.text === "Go pour tes recos").length === 1);

// --- Recall ---------------------------------------------------------------
fs.appendFileSync(JOURNAL, JSON.stringify({ ts: old, session_id: "s0", key: "old", text: "vieille consigne" }) + "\n");
r = run("SessionStart", { source: "compact" }, { USER_WORDS_JOURNAL: JOURNAL, USER_WORDS_STATE: STATE });
let ctx = "";
try {
  ctx = JSON.parse(r.out).hookSpecificOutput.additionalContext;
} catch (e) {}
check("SessionStart exits 0", r.code === 0, "exit=" + r.code);
check("SessionStart emits additionalContext", /ALREADY GIVEN/.test(ctx), r.out.slice(0, 200));
check("recall carries the mid-turn message", ctx.indexOf("Et puis note accessoirement") >= 0);
check("recall drops entries older than the window", ctx.indexOf("vieille consigne") < 0);

r = run("SessionStart", { source: "startup" }, { USER_WORDS_JOURNAL: JOURNAL, USER_WORDS_STATE: STATE, USER_WORDS_RECALL_MAX_CHARS: "40" });
try {
  ctx = JSON.parse(r.out).hookSpecificOutput.additionalContext;
} catch (e) {
  ctx = "";
}
check("budget keeps the newest and names the overflow", ctx.indexOf("plus tard") >= 0 && /beyond the budget/.test(ctx), ctx.slice(0, 300));

// --- Fail-open ------------------------------------------------------------
let bad = spawnSync(process.execPath, [HOOK], { input: "not json", encoding: "utf8" });
check("malformed payload exits 0 silently", bad.status === 0 && !bad.stdout);
bad = spawnSync(process.execPath, [HOOK], {
  input: JSON.stringify({ hook_event_name: "Stop", transcript_path: path.join(DIR, "absent.jsonl") }),
  encoding: "utf8",
  env: { ...process.env, USER_WORDS_JOURNAL: JOURNAL, USER_WORDS_STATE: STATE },
});
check("missing transcript exits 0", bad.status === 0);
bad = spawnSync(process.execPath, [HOOK], {
  input: JSON.stringify({ hook_event_name: "SessionStart", transcript_path: path.join(DIR, "nowhere", "x.jsonl") }),
  encoding: "utf8",
});
check("no journal yet: SessionStart exits 0 and says nothing", bad.status === 0 && !bad.stdout);

// --- Default location = the workspace memory directory ----------------------
const d2 = fs.mkdtempSync(path.join(os.tmpdir(), "uwj2-"));
const t2 = path.join(d2, "s.jsonl");
fs.writeFileSync(t2, L({ type: "user", uuid: "x1", timestamp: now, origin: { kind: "human" }, message: { content: "ici" } }));
spawnSync(process.execPath, [HOOK], { input: JSON.stringify({ hook_event_name: "Stop", transcript_path: t2 }), encoding: "utf8" });
check("default journal lands in <transcript dir>/memory/", fs.existsSync(path.join(d2, "memory", "user-words-journal.jsonl")));

// --- Backfill at install time, then chronological recall across sessions ---
const d3 = fs.mkdtempSync(path.join(os.tmpdir(), "uwj3-"));
const t1 = new Date(Date.now() - 2 * 86400000).toISOString();
const t3 = new Date(Date.now() - 1 * 86400000).toISOString();
fs.writeFileSync(path.join(d3, "b-newer.jsonl"), L({ type: "user", uuid: "n1", timestamp: t3, origin: { kind: "human" }, message: { content: "hier" } }));
fs.writeFileSync(path.join(d3, "a-older.jsonl"), L({ type: "user", uuid: "o1", timestamp: t1, origin: { kind: "human" }, message: { content: "avant-hier" } }));
const bf = spawnSync(process.execPath, [HOOK, "--backfill", d3, "7"], { encoding: "utf8" });
check("backfill reports both transcripts", /backfilled 2 transcript/.test(bf.stdout), bf.stdout);
const rec = spawnSync(process.execPath, [HOOK], {
  input: JSON.stringify({ hook_event_name: "SessionStart", source: "startup", transcript_path: path.join(d3, "new.jsonl") }),
  encoding: "utf8",
});
let ctx3 = "";
try {
  ctx3 = JSON.parse(rec.stdout).hookSpecificOutput.additionalContext;
} catch (e) {}
check("recall is chronological across sessions", ctx3.indexOf("avant-hier") >= 0 && ctx3.indexOf("avant-hier") < ctx3.indexOf("] hier"), ctx3);

console.log(failures ?"\n" + failures + " FAIL" : "\nall green");
process.exit(failures ? 1 : 0);
