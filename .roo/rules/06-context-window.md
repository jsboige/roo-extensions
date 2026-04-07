# Condensation Context Window

**Version:** 1.1.0
**Issue:** #1033
**MAJ:** 2026-04-07

---

## Regle : Seuil 75%

**Pour modeles GLM (z.ai), seuil OBLIGATOIRE = 75%.**

Contexte reel = ~131k tokens (pas 200K annonces — les 200K incluent les tokens de sortie).

| Seuil | Resultat |
|-------|----------|
| 50% (defaut) | Boucle infinie (#502) |
| 70% | Boucle avec harnais lourd (#736) |
| **75%** | **OK** — standard unifie Roo + Claude (#1152), compaction ~98k, marge 33k |
| 80% | OK alternatif, marge 26k |
| 90% | Trop haut, risque saturation |

## Config

`~/.claude/settings.json` :

```json
"CLAUDE_CODE_AUTO_COMPACT_WINDOW": "200000",
"CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "75"
```

`CLAUDE_CODE_AUTO_COMPACT_WINDOW` fixe la fenetre a 200k (evite que Claude Code devinue une valeur incorrecte).
75% de 200k = 150k tokens = seuil de declenchement de la compaction.

**JAMAIS 50%.** 70% insuffisant avec harnais lourd. 75% = standard unifie (#1152).

## Modeles concernes

GLM-5, GLM-5.1, GLM-4.7, GLM-4.7 Flash, GLM-4.5 Air (tous z.ai) — 131k reels.

## Contexte Scheduler Roo

Les taches orchestrateur-simple qui deleguent 4+ sous-taches atteignent souvent la limite de contexte. Si la tache s'arrete apres Etape 2b sans atteindre Etape 3 (rapport), c'est un signe de saturation contexte.

**Voir aussi :** Issue #1032 (investigation executor n'atteint Etape 3 que dans 30% des cycles)

---

**Source :** `.claude/rules/context-window.md` (auto-load Claude)
