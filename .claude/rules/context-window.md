# Condensation Context Window

**Version:** 2.0.0 (condensed)
**MAJ:** 2026-04-05

## Regle : Seuil 80%

**Pour modeles GLM (z.ai), seuil OBLIGATOIRE = 80%.**

Contexte reel = ~131k tokens (pas 200K annonces — les 200K incluent les tokens de sortie).

| Seuil | Resultat |
|-------|----------|
| 50% (defaut) | Boucle infinie (#502) |
| 70% | Boucle avec harnais lourd (#736) |
| **80%** | **OK** — compaction ~105k, marge 26k |
| 90% | Trop haut, risque saturation |

## Config

`~/.claude/settings.json` : `"CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "80"`

**JAMAIS 50%.** 70% insuffisant avec harnais lourd.

## Modeles concernes

GLM-5, GLM-4.7, GLM-4.7 Flash, GLM-4.5 Air (tous z.ai) — 131k reels, seuil 80% = ~105k.

**Detail complet :** `.claude/docs/condensation-thresholds.md`
