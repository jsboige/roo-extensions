#!/usr/bin/env node
// Tests du hook guard-bash-composite (#4243) — sans dependance, lances par `node`.
//
//   node scripts/hooks/tests/guard-bash-composite.test.js     # exit 0 = tout vert
//
// Chaque cas pipe un payload PreToolUse reel (spawnSync du VRAI hook) et
// verifie le code de sortie. La contre-epreuve est structurante : chaque forme
// d'incident mesure sur #4243 doit rougir (exit 2), chaque forme bénigne
// proche doit passer (exit 0) — sinon la garde deny-wide devient deny-total.

const { spawnSync } = require("child_process");
const path = require("path");

const HOOK = path.join(__dirname, "..", "guard-bash-composite.js");

let failures = 0;

function check(name, cond, detail) {
  if (cond) {
    console.log("  ok   " + name);
  } else {
    failures += 1;
    console.log("  FAIL " + name + (detail ? " -- " + detail : ""));
  }
}

function call(toolName, toolInput, rawPayload, env) {
  const payload =
    rawPayload !== undefined
      ? rawPayload
      : JSON.stringify({ session_id: "s", tool_name: toolName, tool_input: toolInput });
  const r = spawnSync(process.execPath, [HOOK], {
    input: payload,
    encoding: "utf8",
    env: { ...process.env, ...(env || {}) },
  });
  return { code: r.status, stderr: r.stderr || "" };
}

// --- Les deux incidents mesures sur #4243 (formes exactes) : REFUS ---

const INCIDENT_1 =
  "rm -rf /c/Temp/x 2>/dev/null; git worktree add ../wt-x -b b && cd ../wt-x && ls ; timeout 120 wsl -d Ubuntu -- bash -lc 'echo hi'";
const INCIDENT_2 =
  "cd ../other-worktree && rm -f ../file.txt; git status --short; python -m pytest -q";

const r1 = call("Bash", { command: INCIDENT_1 });
check("incident 15/10 (rm -rf + worktree + cd) refuse", r1.code === 2, "exit=" + r1.code);
check(
  "  ... message porte la reecriture git -C",
  /git -C/.test(r1.stderr) && /rm/.test(r1.stderr),
  JSON.stringify(r1.stderr)
);

const r2 = call("Bash", { command: INCIDENT_2 });
check("incident 17/10 (cd worktree + rm -f) refuse", r2.code === 2, "exit=" + r2.code);

// --- Formes benignes proches : PASSER ---

const PASS = [
  ["rm seul (pas compose)", "rm -f build/out.js"],
  ["cd seul (pas compose)", "cd ../wt-x && git status"],
  ["cd + git sans rm", "cd ../wt-x && git log --oneline -3"],
  ["rm + git sans cd", "rm -f out.js; git status --short"],
  ["cd . exempte", "cd . && rm -f out.js"],
  ["rm options seules sans chemin", "git status && rm -rf"],
  ["commande simple cd+rm sans separateur", "cd ../x"], // pas de composite
  ["pipe sans cd/rm", "git log --oneline | head -5"],
  ["rm mot dans une string", "echo 'please rm nothing' && git status"],
  ["cd mot dans un chemin (pas un builtin)", "ls ../cd-folder && rm -f x 2>/dev/null; true"],
];

for (const [name, command] of PASS) {
  const r = call("Bash", { command });
  check("passe: " + name, r.code === 0, "exit=" + r.code + " stderr=" + r.stderr);
}

// --- Payloads non-Bash / malformes : FAIL-OPEN ---

check(
  "outil non-Bash ignore",
  call("Read", { file_path: "x.pdf", command: INCIDENT_2 }).code === 0
);
check(
  "JSON malforme = exit 0 (fail-open)",
  call(null, null, "{not json").code === 0
);
check(
  "tool_input absent = exit 0",
  call(null, null, JSON.stringify({ tool_name: "Bash" })).code === 0
);
check(
  "command absente = exit 0",
  call(null, null, JSON.stringify({ tool_name: "Bash", tool_input: {} })).code === 0
);

// --- Rollback env ---

check(
  "BASH_COMPOSITE_GUARD=0 desactive",
  call("Bash", { command: INCIDENT_2 }, undefined, { BASH_COMPOSITE_GUARD: "0" }).code === 0
);

// --- Cas limites du detecteur ---

const EDGE_DENY = [
  ["cd en tete de commande (^)", "cd ../x && rm -f y"],
  ["separateur newline", "cd ../x\nrm -f y"],
  ["rm avant le cd (; ordre inverse)", "rm -f ../y ; cd ../x"],
  ["cd avec chemin absolu", "cd /d/other && rm -f ./x"],
  ["cd cible '-'", "git status && cd - && rm -f y"],
];

for (const [name, command] of EDGE_DENY) {
  const r = call("Bash", { command });
  check("refuse: " + name, r.code === 2, "exit=" + r.code);
}

console.log(
  failures === 0 ? "\nGUARD-BASH-COMPOSITE: ALL GREEN" : "\nGUARD-BASH-COMPOSITE: " + failures + " FAILURE(S)"
);
process.exit(failures === 0 ? 0 : 1);
