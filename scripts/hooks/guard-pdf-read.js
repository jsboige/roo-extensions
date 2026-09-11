#!/usr/bin/env node
// guard-pdf-read — garde PreToolUse anti injection multimodale PDF non bornée (#3579)
//
// Origine : incident CoursIA 10/09 — un seul Read PDF pages "1-15" a injecté
// 15 JPEG base64 (203-343k chars/page, record JSONL 4 388 885 octets) ;
// requête suivante context_length_exceeded, session bloquée toute la nuit
// (/compact héritait du contexte excessif et ne pouvait pas produire de résumé).
//
// Contrat :
//   - stdin   : le payload JSON du PreToolUse (tool_input.file_path / .pages inspectés)
//   - stdout  : rien
//   - stderr  : message de blocage (remonté au modèle)
//   - exit 2  : BLOCAGE si Read sur *.pdf avec pages absentes ou > MAX_PAGES pages
//   - exit 0  : laisser passer — y compris sur erreur de parse (FAIL-OPEN :
//               un hook cassé ne doit jamais couper l'outil)
//
// Câblage (détail : docs/harness/reference/pdf-read-guard.md) :
//   settings harness → hooks.PreToolUse → matcher "Read"
//   → command : node <repo>/scripts/hooks/guard-pdf-read.js
//
// Plafond : PDF_READ_MAX_PAGES (env, défaut 2). Le built-in Read autorise
// jusqu'à 20 pages PDF par appel sans budget d'octets — chaque page devient
// une image base64 injectée atomiquement dans l'historique.

const MAX_PAGES = parseInt(process.env.PDF_READ_MAX_PAGES || "2", 10) || 2;

function countPages(pages) {
  // Formats acceptés par le built-in Read : "3", "1-15", plages séparées par virgule.
  let total = 0;
  for (const token of String(pages).split(",")) {
    const m = token.trim().match(/^(\d+)\s*(?:-\s*(\d+))?$/);
    if (!m) return NaN;
    const lo = parseInt(m[1], 10);
    const hi = m[2] !== undefined ? parseInt(m[2], 10) : lo;
    if (hi < lo) return NaN;
    total += hi - lo + 1;
  }
  return total;
}

let d = "";
process.stdin.on("data", (c) => (d += c));
process.stdin.on("end", () => {
  try {
    const input = (JSON.parse(d).tool_input || {}) || {};
    const filePath = String(input.file_path || "");
    if (/\.pdf$/i.test(filePath)) {
      const pages = input.pages;
      const n = pages === undefined ? NaN : countPages(pages);
      const reason =
        pages === undefined
          ? "pages ABSENT (le défaut du built-in lit jusqu'à 20 pages)"
          : `pages "${pages}" = ${n} pages demandées (plafond ${MAX_PAGES})`;
      if (pages === undefined || n > MAX_PAGES || Number.isNaN(n)) {
        console.error(
          `BLOCAGE (hook guard-pdf-read) : lecture PDF non bornée — ${reason}. ` +
            "Le built-in Read rend chaque page PDF en image base64 (~200-340k chars/page, incident #3579 : " +
            "4,39 MB injectés en un tool result, session bloquée en context_length_exceeded). " +
            "Extraire le TEXTE d'abord (pdftotext ou équivalent). Si la vision est nécessaire (tableau, figure, scan), " +
            `relire par tranches de ${MAX_PAGES} pages max via le paramètre pages.`
        );
        process.exit(2);
      }
    }
  } catch (e) {
    /* fail-open */
  }
});
