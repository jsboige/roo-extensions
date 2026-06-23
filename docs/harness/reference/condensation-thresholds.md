# Règles de Condensation - Context Window

**Version:** 4.0.0 (UNIVERSEL 200k/90% — supersedes model-aware #2173)
**Créé:** 2026-02-21
**Mis à jour:** 2026-06-23
**Issues:** #502 (boucle) + #555 (saturation) + #618 (harmonisation) + #736 (boucle po-2023) → historique 75% (#1152) → **UNIVERSEL 90% (mandate user 2026-05-25)**

> **⚠️ Source canonique :** [`.claude/rules/context-window.md`](../../../.claude/rules/context-window.md) v4.0.0. Ce document en est le **détail**. En cas d'écart, la **règle** gagne.

---

## Problème (historique)

Les modèles GLM (Zhipu AI) annoncent **200k tokens** de contexte mais la réalité en entrée est **~131k tokens** (les 200k incluent les tokens de sortie). Avec un seuil de condensation par défaut de 50% (100k) et un harnais lourd (INTERCOM + rules Roo ~65k), le seuil était atteint trop tôt → **boucle infinie de condensation** (#502, #736).

---

## Solution active : Seuil UNIVERSEL 90% (200k)

**Mandate user 2026-05-25** — ralentir la flotte, maximiser le contexte utile (compact tardif). **Une seule fenêtre + un seul pct pour TOUTES les familles** (Claude, GLM, Qwen). Le réglage model-aware #2173 (Claude = 1M/25% = 250k) est **SUPERSEDÉ**.

| Famille | Fenêtre (`AUTO_COMPACT_WINDOW`) | `% override` | Seuil effectif | Contexte réel |
|---------|----------------------------------|--------------|----------------|---------------|
| **Claude** (opus/sonnet/haiku) | 200 000 | **90%** | 180k | ~200k |
| **GLM-5 / 4.7 / 4.5 Air** (z.ai) | 200 000 | **90%** | 180k | ~131k |
| **Qwen3.6-35B** (vLLM) | 200 000 | **90%** | 180k | ~131k |

**Note :** pour GLM/Qwen le seuil effectif (180k) dépasse le contexte réel d'entrée (~131k) — c'est **délibéré** (compact tardif, maximise le contexte utile). La fenêtre var (`200000`) est l'espace de **comptage** Claude Code, pas la limite hard du provider. Réglage validé empiriquement sur ai-01.

### Historique des seuils

| Seuil | Résultat |
|-------|----------|
| 50% (défaut) | Boucle infinie (#502) |
| 70% | Boucle avec harnais lourd (#736) |
| 75% | Standard historique unifié (#1152) |
| 25% (Claude) + 90% (GLM/Qwen) | Model-aware #2173 — **superseded 2026-05-25** |
| **90% (universel)** | **Actif pour TOUTES les familles** — compact tardif, contexte utile maximal |

**JAMAIS 50%.** Tous les modèles = 90%.

---

## Configuration Claude Code

**Chemin :** `~/.claude/settings.json` (defaults machine)

```json
{
  "CLAUDE_CODE_AUTO_COMPACT_WINDOW": "200000",
  "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "90"
}
```

**S'applique à TOUTES les familles** (Claude, GLM, Qwen) — y compris Anthropic. Les spawn scripts (`spawn-claude.ps1`, `start-claude-worker.ps1`) positionnent ces vars **inconditionnellement** avant chaque `claude -p`, quel que soit le modèle (elles priment sur settings.json). Les sessions interactives lisent settings.json directement ; le changement de seuil ne prend effet qu'au **restart** de la session.

**⚠️ NE JAMAIS utiliser 50%** → Boucle de condensation infinie (#502).

---

## Configuration Roo (via UI)

**Chemin :** Settings → Context Management → Auto-condensation

```
Seuil de déclenchement : 90%
```

**Pourquoi 90% (et pas moins) ?**

- 50% de 200k = 100k → Boucle infinie (#502)
- 70% de 200k = 140k → Boucle avec harnais lourd (#736, po-2023)
- 75% de 200k = 150k → Standard unifié #1152 (historique)
- **90% de 200k = 180k** → Compact tardif, **maximise le contexte utile** (mandate user 2026-05-25 — ralentir la flotte)

**Standard unifié Roo + Claude** : le harnais condensé (rules slim, surface contexte réduite via #2307 audit MCP tools + #2224 redistribution mémoire) rend 90% viable. Seuil validé sur toutes les machines.

---

## Distinction : condensation CONTEXTE vs condensation DASHBOARD

Ne pas confondre (deux mécanismes distincts) :
- **Context window** (ce doc, `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`) : seuil **90%** de la fenêtre 200k → déclenche la compaction de la **conversation** Claude Code.
- **Dashboard RooSync** (`roosync_dashboard`) : auto-condensation **préemptive à 92%** (~46 KB) / réactive à 50 KB → gère l'espace du **fichier dashboard** shared (GDrive). Voir [`.claude/rules/intercom-protocol.md`](../../../.claude/rules/intercom-protocol.md).

---

## Références

- **Source canonique :** [`.claude/rules/context-window.md`](../../../.claude/rules/context-window.md) v4.0.0
- **INDEX :** [`INDEX.md`](./INDEX.md) — entrée Condensation (seuil universel 90%)
- **Issue #502 :** Boucle infinie condensation Roo
- **Issue #1152 :** Standard unifié historique 75%
- **Issue #2173 :** Réglage model-aware (superseded)
- **Mandate 2026-05-25 :** seuil universel 90% (ralentir la flotte)
- **Source communauté :** taille réelle GLM ~131k (200k inclut output)

---

**Dernière mise à jour :** 2026-06-23 (v4.0.0 — aligné sur `context-window.md` universel 90%, supersedes v3.0.0 model-aware 75%)
**Mainteneur :** Coordinateur RooSync (myia-ai-01)
