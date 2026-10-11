#!/usr/bin/env node
// echo-loop-counter — compteur + DISJONCTEUR des boucles de tool_use identiques (#3724)
//
// Origine : session Maintenance 17/09 servie en DeepSeek Flash PAYG (4e fallback) —
// >=16 echo tool_use quasi identiques sans jamais invoquer l'outil d'envoi annonce ;
// sortie seulement par exit 1 accidentel. Re-scope user 23/09 (RX28 item 13) :
// « on mesure et on verra » -> option 3, compteur LOG-ONLY, livre le 25/09 (PR #3858).
//
// Decision user 11/10 (~11:30Z, cf #3724 c.6109241778) : « oui, on ne peut pas accepter
// des boucles d'appels identiques » -> option (b), le compteur DEVIENT un disjoncteur
// reglable. Motif du seuil par defaut (60) : les sept sieges ont releve leurs series —
// les longues (1613, 380, 373, 273, 95, 91, 80) sont TOUTES sur des marches de secours
// (k3, kimi-for-coding, deepseek-flash, glm), la plus longue sur Sonnet nominal fait 48.
// 60 passe donc au-dessus de tout ce qu'un modele nominal a produit d'observe, et sous
// tout runaway reel.
//
// Contrat :
//   - stdin   : payload JSON du PreToolUse ({session_id, transcript_path, tool_name, tool_input})
//   - stdout  : rien
//   - stderr  : message de refus, UNIQUEMENT quand le disjoncteur tire (remonte au modele)
//   - exit 0  : laisser passer — pour tout le comptage, et FAIL-OPEN sur toute erreur du
//               hook lui-meme : un hook casse ne doit jamais couper la session
//   - exit 2  : BLOCAGE (tool call rejete) quand la serie atteint ECHO_LOOP_BREAK_THRESHOLD
//   - evenement : append d'une ligne JSON dans le log durable, phase
//               "threshold" (seuil de mesure franchi) / "blocked" (disjoncteur tire) /
//               "run-end" (serie terminee, run = total final). Un seul evenement
//               "threshold" et un seul "blocked" par serie — pas de spam ligne par ligne.
//
// Attribution "par modele servi" : le dernier "model":"..." du transcript (lecture
// des derniers ECHO_LOOP_TAIL_BYTES, defaut 64 KB). Absent -> "unknown".
//
// Câblage (détail : docs/harness/reference/echo-loop-counter.md) :
//   settings harness → hooks.PreToolUse → matcher ABSENT (= tous les outils)
//   → command : node <repo>/scripts/hooks/echo-loop-counter.js
//
// Etat : $TMP/echo-loop-counter/<session_id>.json (ephemere par design — le log
// durable vit dans $HOME/.claude/echo-loop-counter.jsonl, hors $TEMP qui est rotate).

const fs = require("fs");
const os = require("os");
const path = require("path");
const crypto = require("crypto");

function envInt(name, def, opts) {
  const raw = process.env[name];
  if (raw === undefined || raw === "") return def;
  const n = parseInt(raw, 10);
  if (!Number.isFinite(n) || n < 0) return def;
  if (n === 0) return opts && opts.allowZero ? 0 : def;
  return n;
}

const THRESHOLD = envInt("ECHO_LOOP_THRESHOLD", 5);
// 0 = comptage seul (retour au comportement du 25/09), jamais "seuil a 0".
const BREAK_THRESHOLD = envInt("ECHO_LOOP_BREAK_THRESHOLD", 60, { allowZero: true });
const TAIL_BYTES = envInt("ECHO_LOOP_TAIL_BYTES", 65536);
const LOG_PATH =
  process.env.ECHO_LOOP_LOG || path.join(os.homedir(), ".claude", "echo-loop-counter.jsonl");

function stableStringify(v) {
  if (v === null || typeof v !== "object") return JSON.stringify(v) ?? "undefined";
  if (Array.isArray(v)) return "[" + v.map(stableStringify).join(",") + "]";
  const keys = Object.keys(v).sort();
  return "{" + keys.map((k) => JSON.stringify(k) + ":" + stableStringify(v[k])).join(",") + "}";
}

function signature(toolName, toolInput) {
  return crypto
    .createHash("sha256")
    .update(toolName + "\u0000" + stableStringify(toolInput))
    .digest("hex");
}

// Familles mesurees sur les sept sieges (cf #3724 c.6109241778) : chacune a sa cause,
// donc chacune a sa consigne. Le refus doit dire QUOI FAIRE, pas seulement "stop".
function familyOf(toolName, toolInput) {
  if (/toolsearch/i.test(toolName)) return "toolsearch";
  const action = String((toolInput || {}).action || "");
  if (/dashboard/i.test(toolName) && /^append$/i.test(action)) return "append";
  return "generic";
}

const ADVICE = {
  toolsearch:
    "l'outil est deja charge : appelle-le directement par son nom. Le recharger par ToolSearch ne le chargera pas mieux.",
  append:
    "relis le dashboard avant d'ecrire. Un append qui a echoue ne se retente pas a l'identique : il se relit, puis on ecrit une fois.",
  generic: "change d'approche ou termine le tour.",
};

function refusalMessage(family, toolName, run, breakAt) {
  return [
    "BOUCLE D'APPELS IDENTIQUES REFUSEE (hook echo-loop-counter, #3724) : " +
      run +
      " appels consecutifs identiques a " +
      toolName +
      " (seuil de blocage " +
      breakAt +
      ").",
    "-> " + ADVICE[family],
    "Tout nouvel appel identique sera refuse lui aussi. Si la tache est finie, termine le tour.",
  ].join("\n");
}

function lastModelFromTranscript(transcriptPath) {
  try {
    const st = fs.statSync(transcriptPath);
    if (!st.isFile() || st.size === 0) return "unknown";
    const len = Math.min(TAIL_BYTES, st.size);
    const buf = Buffer.alloc(len);
    const fd = fs.openSync(transcriptPath, "r");
    try {
      fs.readSync(fd, buf, 0, len, st.size - len);
    } finally {
      fs.closeSync(fd);
    }
    const matches = buf.toString("utf8").match(/"model"\s*:\s*"([^"]+)"/g);
    if (!matches || matches.length === 0) return "unknown";
    const m = matches[matches.length - 1].match(/"model"\s*:\s*"([^"]+)"/);
    return m ? m[1] : "unknown";
  } catch {
    return "unknown";
  }
}

function appendEvent(evt) {
  fs.mkdirSync(path.dirname(LOG_PATH), { recursive: true });
  fs.appendFileSync(LOG_PATH, JSON.stringify(evt) + "\n");
}

function preview(toolInput) {
  const s = stableStringify(toolInput) || "";
  return s.length > 200 ? s.slice(0, 200) + "…" : s;
}

let d = "";
process.stdin.on("data", (c) => (d += c));
process.stdin.on("end", () => {
  let refusal = null;
  try {
    const p = JSON.parse(d);
    const sessionId = String(p.session_id || "nosession");
    const toolName = String(p.tool_name || "?");
    const sig = signature(toolName, p.tool_input);

    const stateDir = path.join(os.tmpdir(), "echo-loop-counter");
    const statePath = path.join(stateDir, sessionId + ".json");
    let st = { lastSig: null, run: 0, reported: false, blocked: false };
    try {
      st = JSON.parse(fs.readFileSync(statePath, "utf8"));
    } catch {
      /* premiere serie de la session */
    }
    // Etat ecrit par la version log-only du 25/09 : pas de champ "blocked".
    if (typeof st.run !== "number") st.run = 0;
    st.blocked = st.blocked === true;

    const base = {
      ts: new Date().toISOString(),
      session_id: sessionId,
      model: lastModelFromTranscript(p.transcript_path),
      tool_name: toolName,
      threshold: THRESHOLD,
      break_threshold: BREAK_THRESHOLD,
      log_path: LOG_PATH,
    };

    if (sig === st.lastSig) {
      st.run += 1;
      if (st.run === THRESHOLD && !st.reported) {
        st.reported = true;
        appendEvent({
          ...base,
          phase: "threshold",
          run: st.run,
          input_preview: preview(p.tool_input),
        });
      }
      if (BREAK_THRESHOLD > 0 && st.run >= BREAK_THRESHOLD) {
        const fam = familyOf(toolName, p.tool_input);
        if (!st.blocked) {
          st.blocked = true;
          // reported=true : garantit qu'un "run-end" porte le total final de la serie,
          // meme si le disjoncteur tire avant le seuil de mesure (config break < log).
          st.reported = true;
          appendEvent({
            ...base,
            phase: "blocked",
            family: fam,
            run: st.run,
            input_preview: preview(p.tool_input),
          });
        }
        refusal = refusalMessage(fam, toolName, st.run, BREAK_THRESHOLD);
      }
    } else {
      if (st.reported) {
        appendEvent({ ...base, phase: "run-end", run: st.run, input_preview: preview(p.tool_input) });
      }
      st = { lastSig: sig, run: 1, reported: false, blocked: false };
    }

    fs.mkdirSync(stateDir, { recursive: true });
    fs.writeFileSync(statePath, JSON.stringify(st));
  } catch {
    /* fail-open : jamais de blocage sur une erreur du hook lui-meme */
    refusal = null;
  }

  if (refusal !== null) {
    // fs.writeSync et non console.error : process.exit() tronque les ecritures
    // asynchrones sur un pipe, et c'est precisement cette ligne qui doit atteindre
    // le modele pour qu'il change d'approche.
    try {
      fs.writeSync(2, refusal + "\n");
    } catch {
      /* fail-open */
    }
    process.exit(2);
  }
  process.exit(0);
});
