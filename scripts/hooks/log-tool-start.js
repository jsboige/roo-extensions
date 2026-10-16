#!/usr/bin/env node
// log-tool-start — horodatage du DÉBUT d'exécution des outils shell (#4214 volet 3a)
//
// Origine : le scanner scan-approval-waits.py apparie tool_use → tool_result côté
// transcript ; l'écart couvre approbation + exécution + overhead client SANS
// départage (un `npx vitest run` de 320 s est une exécution, pas une attente).
// Ce hook pose le marqueur manquant : l'instant où l'outil COMMENCE à tourner.
// La jointure (volet 3b, --hook-log) scinde ensuite l'écart en
//   pre_exec_s = tool_use → hook_ts   (attente d'approbation + overhead)
//   exec_s     = hook_ts → tool_result (exécution réelle)
//
// Contrat :
//   - stdin   : le payload JSON du PreToolUse (session_id, tool_name, tool_input)
//   - stdout  : rien
//   - stderr  : rien (un hook de log ne parle jamais au modèle)
//   - exit 0  : TOUJOURS — y compris sur erreur de parse ou d'écriture.
//               Un hook d'horodatage ne doit jamais bloquer ni retarder l'outil.
//
// Câblage (détail : docs/harness/reference/tool-start-hook.md) :
//   settings harness → hooks.PreToolUse → matcher "Bash|PowerShell|mcp__win-cli__execute_command|mcp__win-cli__ssh_execute"
//   → command : node <repo>/scripts/hooks/log-tool-start.js
//   Déploiement = PILOTE web1 d'abord (taxe de spawn node ~100-300 ms/appel à
//   mesurer avant toute extension flotte) — cf. #4214 design c.6204283891.
//
// Fichier : ~/.claude/tool-start-log.jsonl (surcharge env TOOL_START_LOG pour
// les tests). Une ligne par invocation d'outil shell :
//   {"ts":"2026-10-16T07:30:00.123Z","session_id":"...","tool":"Bash","command":"..."}
// La commande est stockée BRUTE (empreinte exacte pour la jointure) dans un
// fichier local du profil — la réduction de secrets s'applique à la SORTIE du
// scanner (redact(), PR #4227/#4228), pas à ce journal privé.
// Rotation : à ROTATE_BYTES (défaut 5 Mo) le fichier devient .1 (une seule
// génération gardée) — un pilote qui tourne des semaines ne croît pas sans borne.

const LOG_PATH =
  process.env.TOOL_START_LOG ||
  require("path").join(require("os").homedir(), ".claude", "tool-start-log.jsonl");
const ROTATE_BYTES = parseInt(process.env.TOOL_START_ROTATE_BYTES || String(5 * 1024 * 1024), 10);

// Seuls les outils que le scanner apparie sont journalisés — les autres appels
// ne produiraient que du bruit pour la même taxe de spawn.
const SHELL_TOOLS = new Set([
  "Bash",
  "PowerShell",
  "mcp__win-cli__execute_command",
  "mcp__win-cli__ssh_execute",
]);

const fs = require("fs");
const path = require("path");

function appendLine(line) {
  try {
    try {
      if (fs.statSync(LOG_PATH).size >= ROTATE_BYTES) {
        fs.renameSync(LOG_PATH, LOG_PATH + ".1"); // peut échouer si .1 tenu — non fatal
      }
    } catch (e) {
      /* fichier absent au premier appel — normal */
    }
    fs.mkdirSync(path.dirname(LOG_PATH), { recursive: true });
    fs.appendFileSync(LOG_PATH, line + "\n");
  } catch (e) {
    /* exit 0 par contrat — un échec d'écriture ne bloque jamais l'outil */
  }
}

let d = "";
process.stdin.on("data", (c) => (d += c));
process.stdin.on("end", () => {
  try {
    const payload = JSON.parse(d);
    if (SHELL_TOOLS.has(payload.tool_name)) {
      const command = String((payload.tool_input || {}).command || "");
      const entry = {
        ts: new Date().toISOString(),
        session_id: payload.session_id || null,
        tool: payload.tool_name,
        command,
      };
      appendLine(JSON.stringify(entry));
    }
  } catch (e) {
    /* payload non parsable — rien à horodater, exit 0 */
  }
  process.exit(0);
});
