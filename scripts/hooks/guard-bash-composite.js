#!/usr/bin/env node
// guard-bash-composite — garde PreToolUse anti gel silencieux des Bash composees (#4243)
//
// Origine : incidents ai-01:CoursIA 15/10 (~1 h) et 17/10 (~16 h) — en bypass,
// une commande composee qui fait un `cd` hors du repertoire de travail AVEC un
// `rm` sur un chemin dans la MEME commande declenche une attente d'approbation
// SILENCIEUSE : l'agent ne sait pas qu'il attend, le cron suivant ne debloque
// pas, la lane est gelee. 2-3 agents/jour perdus (priorite user 18/10).
//
// Contrat (modeles sur guard-pdf-read, #3579) :
//   - stdin   : le payload JSON du PreToolUse (tool_name / tool_input.command)
//   - stdout  : rien
//   - stderr  : le motif du refus + la reecriture attendue (remonte au modele)
//   - exit 2  : REFUS si commande composee contenant a la fois un `cd <cible>`
//               (cible != ".") et un `rm` portant un chemin
//   - exit 0  : laisser passer — y compris sur erreur de parse (FAIL-OPEN :
//               un hook casse ne doit jamais couper l'outil)
//
// Deliberement conservateur (deny-wide) : la conjunction seule suffit au refus,
// sans resolution de cwd — `cd sous-dossier && rm x` est refuse aussi ; la
// reecriture (`git -C`, suppression isolee) est toujours disponible et le
// message la donne mot pour mot. Les faux negatifs d'une detection plus fine
// (quel cd est "hors cwd" ?) coutent des lanes gelees ; les faux positifs
// coutent une reecriture.
//
// Câblage (detail : docs/harness/reference/bash-composite-guard.md) :
//   settings harness -> hooks.PreToolUse -> matcher "Bash"
//   -> command : node <repo>/scripts/hooks/guard-bash-composite.js
//
// Rollback : BASH_COMPOSITE_GUARD=0 desactive la garde (env, defaut actif).

const SEPARATORS = /(?:&&|\|\||;|\n|\|)/;

function hasCdOut(command) {
  // Tout `cd <cible>` dont la cible n'est pas "." — les deux incidents mesures
  // portaient `cd <autre dossier>` ; `cd ..`/`cd -`/chemins absolus inclus.
  const re = /(?:^|[\s;&|(])cd\s+([^\s;&|)\\]+)/g;
  let m;
  while ((m = re.exec(command)) !== null) {
    if (m[1] !== "." && m[1] !== "") return true;
  }
  return false;
}

function hasRmPath(command) {
  // `rm` avec au moins un argument qui n'est pas une option nue (`-f`, `--`).
  const re = /(?:^|[\s;&|(])rm\s+([^;&|\n]*)/g;
  let m;
  while ((m = re.exec(command)) !== null) {
    const args = m[1].trim();
    if (args === "") continue;
    const nonOption = args
      .split(/\s+/)
      .filter((a) => a !== "" && !a.startsWith("-"));
    if (nonOption.length > 0) return true;
  }
  return false;
}

function blockReason() {
  return [
    "guard-bash-composite (#4243) : commande composee `cd` + `rm` sur un chemin —",
    "cette forme declenche en bypass une attente d'approbation SILENCIEUSE qui gele la lane.",
    "Reecrire : `git -C <chemin> ...` au lieu de `cd` ; suppression en commande ISOLEE",
    "(jamais `rm` dans une commande composee) ; worktree -> `git worktree remove`.",
  ].join("\n");
}

let d = "";
process.stdin.on("data", (c) => (d += c));
process.stdin.on("end", () => {
  try {
    if (process.env.BASH_COMPOSITE_GUARD === "0") process.exit(0);
    const payload = JSON.parse(d) || {};
    if (payload.tool_name !== "Bash") process.exit(0);
    const command = String((payload.tool_input || {}).command || "");
    if (!SEPARATORS.test(command)) process.exit(0); // commande simple : jamais bloquee
    if (hasCdOut(command) && hasRmPath(command)) {
      process.stderr.write(blockReason());
      process.exit(2);
    }
    process.exit(0);
  } catch (e) {
    // FAIL-OPEN : payload illisible = laisser passer.
    process.exit(0);
  }
});
