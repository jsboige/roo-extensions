# Condensation Context Window

**Version:** 3.0.0 (#2173 model-aware compact override)
**MAJ:** 2026-05-14

## Regle : Seuil par famille de modele (#2173)

Les spawn scripts (`spawn-claude.ps1`, `start-claude-worker.ps1`) positionnent automatiquement les env vars de compact selon le modele lance :

| Famille | WINDOW | PCT | Seuil effectif | Raison |
|---------|--------|-----|---------------|--------|
| **Claude** (opus/sonnet/haiku) | 1 000 000 | 25% | 250k | 200k reels, marge generreuse |
| **GLM / Qwen** (z.ai, vLLM) | 200 000 | 90% | 180k | ~131k reels, compact tardif mais safe |

## Config

`~/.claude/settings.json` (defaults machine — overriden par spawn scripts au runtime) :
```json
"CLAUDE_CODE_AUTO_COMPACT_WINDOW": "200000",
"CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "90"
```

**Spawn scripts override** : `spawn-claude.ps1` et `start-claude-worker.ps1` positionnent `$env:CLAUDE_CODE_AUTO_COMPACT_WINDOW` et `$env:CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` avant chaque invocation `claude -p`. Les env vars prennent le pas sur settings.json.

## Historique des seuils

| Seuil | Resultat |
|-------|----------|
| 50% (defaut) | Boucle infinie (#502) |
| 70% | Boucle avec harnais lourd (#736) |
| 75% | Standard historique (#1152), remplace par 90% (#2173) |
| **90%** | **Actif pour GLM/Qwen** — compact tardif, maximise le contexte utile |
| 25% | Actif pour Claude — contexte large, compact precoce (pas de risque) |

**JAMAIS 50%.** Modeles non-Claude = 90% minimum. Modeles Claude = 25%.

## Modeles concernes

- **GLM-5, GLM-4.7, GLM-4.5 Air** (z.ai) — ~131k reels, seuil 90% de 200k = 180k
- **Qwen3.6-35B** (vLLM) — meme config que GLM
- **Claude Opus/Sonnet/Haiku** (Anthropic) — 200k reels, seuil 25% de 1M = 250k

**Detail complet :** `docs/harness/reference/condensation-thresholds.md`
