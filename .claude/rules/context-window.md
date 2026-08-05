# Condensation — Context Window

**Version:** 5.0.0 (slim — table et historique déjà portés par la doc de référence)
**Décision user :** 2026-05-25 (supersede le model-aware #2173)

---

## Règle : seuil **UNIVERSEL** 200k / 90%

**Toutes les familles de modèle** — Claude (opus/sonnet/haiku), GLM, Qwen — utilisent la même
fenêtre `200 000` et le même `90%`, soit **180k effectifs**. Pas d'exception par modèle.

```json
// ~/.claude/settings.json
"CLAUDE_CODE_AUTO_COMPACT_WINDOW": "200000",
"CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "90"
```

`spawn-claude.ps1` et `start-claude-worker.ps1` positionnent ces deux env vars **inconditionnellement**
avant chaque `claude -p` ; les env vars priment sur `settings.json`.

## Les deux pièges

- **`JAMAIS 50%`** — c'est le défaut, et il produit une boucle de condensation infinie (#502).
- **Une session interactive ne recharge pas `settings.json` en cours de route.** Un changement de
  seuil ne prend effet qu'au **restart** de la session, jamais mid-session.

---

**Table complète par famille, historique des seuils, config Roo, distinction condensation
contexte vs dashboard :**
[`docs/harness/reference/condensation-thresholds.md`](../../docs/harness/reference/condensation-thresholds.md)
