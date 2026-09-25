#!/usr/bin/env node
// echo-loop-counter — compteur LOG-ONLY des boucles de tool_use identiques (#3724, option 3)
//
// Origine : session Maintenance 17/09 servie en DeepSeek Flash PAYG (4e fallback) —
// >=16 echo tool_use quasi identiques sans jamais invoquer l'outil d'envoi annonce ;
// sortie seulement par exit 1 accidentel. Re-scope user 23/09 (RX28 item 13) :
// « on mesure et on verra » — un compteur d'abord, rien n'est bloque. Le circuit
// breaker (option 1) ne sera reconsidere que si le compteur montre >1 cas reel/mois.
//
// Contrat :
//   - stdin   : payload JSON du PreToolUse ({session_id, transcript_path, tool_name, tool_input})
//   - stdout  : rien
//   - exit 0  : TOUJOURS — log-only par design (#3724), et fail-open : un hook
//               casse ne doit ni bloquer l'outil ni perdre la session
//   - evenement : append d'une ligne JSON dans le log quand une serie d'appels
//               consecutifs identiques atteint ECHO_LOOP_THRESHOLD (defaut 5),
//               puis un evenement "run-end" avec le decompte final quand la serie
//               s'arrete (signature change). Un seul evenement "threshold" par serie.
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

const THRESHOLD = parseInt(process.env.ECHO_LOOP_THRESHOLD || "5", 10) || 5;
const TAIL_BYTES = parseInt(process.env.ECHO_LOOP_TAIL_BYTES || "65536", 10) || 65536;
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
  try {
    const p = JSON.parse(d);
    const sessionId = String(p.session_id || "nosession");
    const toolName = String(p.tool_name || "?");
    const sig = signature(toolName, p.tool_input);

    const stateDir = path.join(os.tmpdir(), "echo-loop-counter");
    const statePath = path.join(stateDir, sessionId + ".json");
    let st = { lastSig: null, run: 0, reported: false };
    try {
      st = JSON.parse(fs.readFileSync(statePath, "utf8"));
    } catch {
      /* premiere serie de la session */
    }

    const base = {
      ts: new Date().toISOString(),
      session_id: sessionId,
      model: lastModelFromTranscript(p.transcript_path),
      tool_name: toolName,
      threshold: THRESHOLD,
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
    } else {
      if (st.reported) {
        appendEvent({ ...base, phase: "run-end", run: st.run, input_preview: preview(p.tool_input) });
      }
      st = { lastSig: sig, run: 1, reported: false };
    }

    fs.mkdirSync(stateDir, { recursive: true });
    fs.writeFileSync(statePath, JSON.stringify(st));
  } catch {
    /* fail-open : log-only, jamais de blocage */
  }
  process.exit(0);
});
