# Condensation Context Window

**Version:** 2.0.0 (condensed from 1.1.0, aligned with .claude/rules/context-window.md)
**MAJ:** 2026-04-08

## Regle : Seuil 75%

**Pour modeles GLM (z.ai), seuil OBLIGATOIRE = 75%.**

Contexte reel = ~131k tokens (pas 200K annonces). 75% de 200k = 150k = seuil de compaction.

| Seuil | Resultat |
| ----- | -------- |
| 50% (defaut) | Boucle infinie (#502) |
| 70% | Boucle avec harnais lourd (#736) |
| **75%** | **OK** — standard unifie (#1152) |
| 80% | OK alternatif |
| 90% | Trop haut |

## Config

`~/.claude/settings.json` : `CLAUDE_CODE_AUTO_COMPACT_WINDOW: "200000"` + `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE: "75"`

**JAMAIS 50%.** 75% = standard unifie Roo + Claude (#1152).

## Modeles concernes

GLM-5, GLM-5.1, GLM-4.7, GLM-4.7 Flash, GLM-4.5 Air (tous z.ai).

## Contexte Scheduler Roo

Orchestrateur-simple deleguant 4+ sous-taches → souvent saturation. Si tache s'arrete avant rapport → saturation contexte (#1032).

---
**Historique versions completes :** Git history avant 2026-04-08
