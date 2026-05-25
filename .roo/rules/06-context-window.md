# Condensation Context Window

**Version:** 3.0.0 (aligned with .claude/rules/context-window.md v4.0.0 — universal 200k/90%, user GO 2026-05-25)
**MAJ:** 2026-05-25

## Regle : Seuil UNIVERSEL 90%

**Tous les modeles (Claude, GLM, Qwen) : fenetre 200 000 / seuil 90% = 180k effectif.**

Le reglage est desormais unifie pour toutes les familles (decision user 2026-05-25, supersede le model-aware #2173). Contexte reel GLM = ~131k tokens ; 90% de 200k = 180k = seuil de compaction tardif qui maximise le contexte utile.

| Seuil | Resultat |
| ----- | -------- |
| 50% (defaut) | Boucle infinie (#502) |
| 70% | Boucle avec harnais lourd (#736) |
| 75% | Standard historique (#1152) |
| **90%** | **Actif (universel)** — compact tardif, maximise le contexte utile |

## Config

`~/.claude/settings.json` : `CLAUDE_CODE_AUTO_COMPACT_WINDOW: "200000"` + `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE: "90"`

**JAMAIS 50%.** Tous les modeles = 90%.

## Modeles concernes

GLM-5, GLM-5.1, GLM-4.7, GLM-4.7 Flash, GLM-4.5 Air (tous z.ai), Qwen3.6-35B (vLLM), Claude Opus/Sonnet/Haiku.

## Contexte Scheduler Roo

Orchestrateur-simple deleguant 4+ sous-taches → souvent saturation. Si tache s'arrete avant rapport → saturation contexte (#1032).

---
**Reference canonique :** `.claude/rules/context-window.md` v4.0.0. **Historique versions completes :** Git history.
