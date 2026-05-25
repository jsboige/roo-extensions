# Condensation Context Window

**Version:** 4.0.0 (universal 200k/90% — user GO 2026-05-25, supersedes #2173 model-aware)
**MAJ:** 2026-05-25

## Regle : Seuil UNIVERSEL 200k / 90% (toutes familles de modele)

**Toutes les familles de modele (Claude, GLM, Qwen) utilisent le meme seuil : fenetre 200 000 / 90% = 180k effectif.**

| Famille | WINDOW | PCT | Seuil effectif |
|---------|--------|-----|---------------|
| **Claude** (opus/sonnet/haiku) | 200 000 | 90% | 180k |
| **GLM / Qwen** (z.ai, vLLM) | 200 000 | 90% | 180k |

Les spawn scripts (`spawn-claude.ps1`, `start-claude-worker.ps1`) positionnent ces env vars de maniere inconditionnelle avant chaque invocation `claude -p`, quel que soit le modele.

### Pourquoi universel (decision user 2026-05-25)

Le reglage model-aware #2173 (Claude = 1M/25% = 250k) a ete **supersede** : tous les modeles passent a 200k/90%. La reduction de fenetre Claude (250k→180k) est compensee par la reduction de la surface de contexte systeme en cours (#2307 audit MCP tools → moins d'outils ; #2224 redistribution memoire → CLAUDE.md/rules slim). Reglage deja eprouve avec succes sur ai-01.

## Config

`~/.claude/settings.json` (defaults machine — les spawn scripts positionnent les memes valeurs au runtime) :
```json
"CLAUDE_CODE_AUTO_COMPACT_WINDOW": "200000",
"CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "90"
```

**Spawn scripts override** : `spawn-claude.ps1` et `start-claude-worker.ps1` positionnent `$env:CLAUDE_CODE_AUTO_COMPACT_WINDOW` et `$env:CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` avant chaque invocation `claude -p`. Les env vars prennent le pas sur settings.json.

**Sessions interactives** : utilisent directement `~/.claude/settings.json`. Le changement de seuil ne prend effet qu'au **restart** de la session Claude Code (pas mid-session).

## Historique des seuils

| Seuil | Resultat |
|-------|----------|
| 50% (defaut) | Boucle infinie (#502) |
| 70% | Boucle avec harnais lourd (#736) |
| 75% | Standard historique (#1152) |
| 25% (Claude) + 90% (GLM/Qwen) | Model-aware #2173, **supersede 2026-05-25** |
| **90% (universel)** | **Actif pour TOUTES les familles** — compact tardif, maximise le contexte utile |

**JAMAIS 50%.** Tous les modeles = 90%.

## Modeles concernes

- **Claude Opus/Sonnet/Haiku** (Anthropic) — ~200k reels, seuil 90% = 180k
- **GLM-5, GLM-4.7, GLM-4.5 Air** (z.ai) — ~131k reels, seuil 90% de 200k = 180k
- **Qwen3.6-35B** (vLLM) — meme config

**Detail complet :** `docs/harness/reference/condensation-thresholds.md`
