#!/usr/bin/env node
// block-placeholder — garde PreToolUse anti "envoi-first" (#3367)
//
// Origine : hook Tier-1 du groupe NanoClaw (ai-01), 8 interceptions le seul
// 01/09. Porté au repo pour que tout groupe/machine puisse le référencer par
// chemin stable depuis ses settings harness.
//
// Contrat :
//   - stdin   : le payload JSON du PreToolUse (tool_input.text inspecté)
//   - stdout  : rien
//   - stderr  : message de blocage (remonté au modèle)
//   - exit 2  : BLOCAGE (tool call rejeté)
//   - exit 0  : laisser passer — y compris sur erreur de parse (FAIL-OPEN :
//               un hook cassé ne doit jamais couper l'outil)
//
// Câblage (détail : docs/harness/reference/block-placeholder-hook.md) :
//   settings harness → hooks.PreToolUse → matcher "mcp__nanoclaw__send_message"
//   → command : node <repo>/scripts/hooks/block-placeholder.js
//
// Règle protégée : le premier tool call d'un tour (cron ou interactif) est une
// LECTURE, jamais un envoi. Ce hook n'attrape que la signature littérale
// « placeholder » — l'extension au cas général « tout send en 1er tool call »
// exige un état de position-dans-le-tour qu'un PreToolUse stateless n'a pas.

let d = "";
process.stdin.on("data", (c) => (d += c));
process.stdin.on("end", () => {
  try {
    const t = String((JSON.parse(d).tool_input || {}).text || "");
    if (/^\s*placeholder\s*$/i.test(t)) {
      console.error(
        "BLOCAGE (hook block-placeholder) : un tour cron commence par la LECTURE dashboard, jamais par un envoi Telegram (règle Tier 1)."
      );
      process.exit(2);
    }
  } catch (e) {
    /* fail-open */
  }
});
