# Condensation Context Window

**Version:** 2.1.0
**MAJ:** 2026-04-07

## Regle : Seuil 75%

**Pour modeles GLM (z.ai), seuil OBLIGATOIRE = 75%.**

Contexte reel = ~131k tokens (pas 200K annonces — les 200K incluent les tokens de sortie).

| Seuil | Resultat |
|-------|----------|
| 50% (defaut) | Boucle infinie (#502) |
| 70% | Boucle avec harnais lourd (#736) |
| **75%** | **OK** — standard deploye toutes machines, compaction ~98k, marge 33k |
| 80% | OK alternatif, marge 26k |
| 90% | Trop haut, risque saturation |

## Config

`~/.claude/settings.json` :
```json
"CLAUDE_CODE_AUTO_COMPACT_WINDOW": "200000",
"CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "75"
```

`CLAUDE_CODE_AUTO_COMPACT_WINDOW` fixe la fenetre a 200k (evite que Claude Code devine une valeur incorrecte).
75% de 200k = 150k tokens = seuil de declenchement de la compaction.

**JAMAIS 50%.** 70% insuffisant avec harnais lourd. 75% = standard unifie Roo + Claude (#1152).

## Modeles concernes

GLM-5, GLM-4.7, GLM-4.7 Flash, GLM-4.5 Air (tous z.ai) — 131k reels, seuil 75% = ~98k.

**Detail complet :** `docs/harness/reference/condensation-thresholds.md`
