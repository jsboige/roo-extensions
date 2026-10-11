#!/usr/bin/env node
// Tests du hook echo-loop-counter (#3724) — sans dependance, lances par `node`.
//
//   node scripts/hooks/tests/echo-loop-counter.test.js     # exit 0 = tout vert
//
// Chaque cas utilise une session_id distincte : l'etat du hook est par session, donc les
// cas ne se marchent pas dessus meme lances dans le meme $TMP.

const { spawnSync } = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");

const HOOK = path.join(__dirname, "..", "echo-loop-counter.js");
const TMP = fs.mkdtempSync(path.join(os.tmpdir(), "echo-loop-counter-tests-"));
const STATE_DIR = path.join(os.tmpdir(), "echo-loop-counter");

let failures = 0;
const touchedSessions = [];

function check(name, cond, detail) {
  if (cond) {
    console.log("  ok   " + name);
  } else {
    failures += 1;
    console.log("  FAIL " + name + (detail ? " -- " + detail : ""));
  }
}

function call(session, toolName, toolInput, env) {
  const log = path.join(TMP, session + ".jsonl");
  const payload = JSON.stringify({
    session_id: session,
    transcript_path: path.join(TMP, "absent-transcript.jsonl"),
    tool_name: toolName,
    tool_input: toolInput,
  });
  const r = spawnSync(process.execPath, [HOOK], {
    input: payload,
    encoding: "utf8",
    env: { ...process.env, ECHO_LOOP_LOG: log, ...(env || {}) },
  });
  return { code: r.status, stderr: r.stderr || "", log };
}

function events(log) {
  if (!fs.existsSync(log)) return [];
  return fs
    .readFileSync(log, "utf8")
    .split("\n")
    .filter((l) => l.trim() !== "")
    .map((l) => JSON.parse(l));
}

function repeat(n, fn) {
  const out = [];
  for (let i = 0; i < n; i += 1) out.push(fn(i));
  return out;
}

function session(name) {
  touchedSessions.push(name);
  return name;
}

// ---------------------------------------------------------------------------
console.log("cas 1 — defaut : 60 appels ToolSearch identiques, refus au 60e");
{
  const s = session("t1-default-60");
  const toolSearch = { query: "select:roosync_messages" };
  const runs = repeat(60, () => call(s, "ToolSearch", toolSearch));
  check("les 59 premiers passent (exit 0)", runs.slice(0, 59).every((r) => r.code === 0),
    "codes: " + runs.slice(0, 59).map((r) => r.code).join(","));
  check("le 60e est refuse (exit 2)", runs[59].code === 2, "code=" + runs[59].code);
  check("le refus porte la consigne de la famille toolsearch",
    /l'outil est deja charge/.test(runs[59].stderr), JSON.stringify(runs[59].stderr.slice(0, 120)));
  const evts = events(runs[0].log);
  const phases = evts.map((e) => e.phase);
  check("log : threshold a run=5, puis blocked a run=60",
    evts.some((e) => e.phase === "threshold" && e.run === 5) &&
      evts.some((e) => e.phase === "blocked" && e.run === 60 && e.family === "toolsearch"),
    "phases=" + phases.join(","));
  check("log : un seul evenement blocked par serie",
    phases.filter((p) => p === "blocked").length === 1);
  check("log : break_threshold=60 journalise", evts.every((e) => e.break_threshold === 60));

  const after = call(s, "Bash", { command: "ls" });
  const evts2 = events(after.log);
  check("un appel different passe et ferme la serie (run-end run=60)",
    after.code === 0 && evts2.some((e) => e.phase === "run-end" && e.run === 60),
    "code=" + after.code);
}

// ---------------------------------------------------------------------------
console.log("cas 2 — famille append (dashboard), seuil abaisse a 3");
{
  const s = session("t2-append");
  const append = { action: "append", type: "workspace", content: "x" };
  const runs = repeat(3, () => call(s, "mcp__roo-state-manager__roosync_dashboard", append, {
    ECHO_LOOP_BREAK_THRESHOLD: "3",
  }));
  check("refus au 3e (exit 2)", runs[2].code === 2, "code=" + runs[2].code);
  check("le message dit de relire le dashboard", /relis le dashboard/.test(runs[2].stderr),
    JSON.stringify(runs[2].stderr.slice(0, 160)));
  check("family=append journalisee",
    events(runs[0].log).some((e) => e.phase === "blocked" && e.family === "append"));
}

// ---------------------------------------------------------------------------
console.log("cas 3 — famille generique, seuil abaisse a 3");
{
  const s = session("t3-generic");
  const runs = repeat(3, () => call(s, "Bash", { command: "echo STOP-NOW-REAL-16" }, {
    ECHO_LOOP_BREAK_THRESHOLD: "3",
  }));
  check("refus au 3e (exit 2)", runs[2].code === 2, "code=" + runs[2].code);
  check("le message generique dit de changer d'approche",
    /change d'approche ou termine/.test(runs[2].stderr), JSON.stringify(runs[2].stderr.slice(0, 160)));
  check("family=generic journalisee",
    events(runs[0].log).some((e) => e.phase === "blocked" && e.family === "generic"));
}

// ---------------------------------------------------------------------------
console.log("cas 4 — ECHO_LOOP_BREAK_THRESHOLD=0 : retour au comptage seul");
{
  const s = session("t4-counter-only");
  const runs = repeat(70, () => call(s, "Bash", { command: "echo STOP-NOW-REAL-16" }, {
    ECHO_LOOP_BREAK_THRESHOLD: "0",
  }));
  check("70 appels identiques passent tous (exit 0)", runs.every((r) => r.code === 0),
    "codes distincts: " + [...new Set(runs.map((r) => r.code))].join(","));
  check("aucun evenement blocked", !events(runs[0].log).some((e) => e.phase === "blocked"));
  check("aucun message sur stderr", runs.every((r) => r.stderr === ""));
  check("le seuil de mesure reste actif (threshold a run=5)",
    events(runs[0].log).some((e) => e.phase === "threshold" && e.run === 5));
}

// ---------------------------------------------------------------------------
console.log("cas 5 — fail-open : entree illisible");
{
  const log = path.join(TMP, "t5-failopen.jsonl");
  const r = spawnSync(process.execPath, [HOOK], {
    input: "ceci n'est pas du JSON",
    encoding: "utf8",
    env: { ...process.env, ECHO_LOOP_LOG: log, ECHO_LOOP_BREAK_THRESHOLD: "1" },
  });
  check("exit 0 malgre une entree invalide", r.status === 0, "code=" + r.status);
  check("stderr vide", (r.stderr || "") === "", JSON.stringify((r.stderr || "").slice(0, 120)));
}

// ---------------------------------------------------------------------------
console.log("cas 6 — sessions independantes");
{
  const a = session("t6-a");
  const b = session("t6-b");
  repeat(2, () => call(a, "Bash", { command: "echo loop" }, { ECHO_LOOP_BREAK_THRESHOLD: "3" }));
  const thirdOther = call(b, "Bash", { command: "echo loop" }, { ECHO_LOOP_BREAK_THRESHOLD: "3" });
  check("l'etat d'une session ne bloque pas l'autre", thirdOther.code === 0, "code=" + thirdOther.code);
}

// ---------------------------------------------------------------------------
for (const s of touchedSessions) {
  const p = path.join(STATE_DIR, s + ".json");
  if (fs.existsSync(p)) fs.unlinkSync(p);
}

console.log("");
console.log(failures === 0 ? "TOUT VERT" : failures + " echec(s)");
console.log("artefacts de test : " + TMP);
process.exit(failures === 0 ? 0 : 1);
