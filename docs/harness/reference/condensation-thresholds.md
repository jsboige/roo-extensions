# Règles de Condensation - Context Window

**Version:** 5.0.0 (le clamp universel 200k est un **bug** — `settings.json` par machine fait foi, décision user 2026-08-22)
**Créé:** 2026-02-21
**Mis à jour:** 2026-06-23
**Issues:** #502 (boucle) + #555 (saturation) + #618 (harmonisation) + #736 (boucle po-2023) → historique 75% (#1152) → UNIVERSEL 200k/90 (mandate user 2026-05-25) → **`settings.json` par machine (décision user 2026-08-22 : le clamp universel était un bug)**

> **⚠️ Source canonique :** [`.claude/rules/context-window.md`](../../../.claude/rules/context-window.md) v6.0.0. Ce document en est le **détail**. En cas d'écart, la **règle** gagne.

---

## Problème (historique)

Les modèles GLM (Zhipu AI) annoncent **200k tokens** de contexte mais la réalité en entrée est **~131k tokens** (les 200k incluent les tokens de sortie). Avec un seuil de condensation par défaut de 50% (100k) et un harnais lourd (INTERCOM + rules Roo ~65k), le seuil était atteint trop tôt → **boucle infinie de condensation** (#502, #736).

---

## Solution active : `settings.json` par machine, avec un plancher sur le POURCENTAGE

**Décision user 2026-08-22** — le mandat « fenêtre 200 000 pour tous » (2026-05-25) est **supersedé** : il était appliqué par trois scripts qui écrasaient `settings.json` à chaque `claude -p`, rendant la valeur configurée inatteignable. Ces overrides ont été retirés.

**La fenêtre est une décision de machine.** Il n'y a plus de table de flotte à faire respecter — seulement un plancher, et un fait de contexte à connaître :

| Famille | Contexte réel en entrée | Fenêtre raisonnable | `% override` |
|---------|--------------------------|---------------------|--------------|
| **Claude avec `[1m]`** (opus/sonnet/haiku) | ~1M | ce que la machine configure (280k–1M constatés) | **≥ 90%** |
| **Claude sans `[1m]`** | clampé au catalogue | la fenêtre ne rattrape pas l'absence de `[1m]` | **≥ 90%** |
| **GLM-5 / 4.7 / 4.5 Air** (z.ai) | **~131k** (les 200k annoncés incluent la sortie) | 200 000 reste adapté | **≥ 90%** |
| **Qwen3.6-35B** (vLLM) | ~131k | 200 000 reste adapté | **≥ 90%** |

**Une grande fenêtre n'est jamais dangereuse** — seul un pourcentage bas l'est (#502). C'est pourquoi le garde-fou porte sur le pct (`< 90`) et **pas** sur la fenêtre.

**Note GLM/Qwen :** un seuil effectif qui dépasse le contexte réel d'entrée (~131k) est **délibéré** — compact tardif, maximise le contexte utile. La fenêtre est l'espace de **comptage** Claude Code, pas la limite hard du provider.

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

**Les scripts de spawn ne positionnent plus aucune variable de compaction** (`spawn-claude.ps1`, `start-claude-worker.ps1`, `start-claude-executor.ps1`) : une session spawnée et une session manuelle héritent désormais du même `settings.json`. Auparavant les env vars y étaient posées inconditionnellement et **primaient sur settings.json**, ce qui clampait toute session `claude -p` à 200k quelle que soit la configuration — c'est le bug corrigé le 2026-08-22.

`deploy-claude-mcp-settings.ps1` n'écrit la fenêtre que si elle est **absente** ; une fenêtre configurée est préservée. Le pct reste corrigé s'il est `< 90`.

Les sessions interactives lisent settings.json directement ; le changement ne prend effet qu'au **restart** de la session.

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

## Pourquoi la régression de 2026-08-22 était discrète

`deploy-claude-mcp-settings.ps1` corrigeait le **pourcentage** seulement s'il était `< 90`, mais
**réécrivait la fenêtre** dès qu'elle différait de `200000`. Cette **asymétrie** rendait la
régression difficile à voir : un seul run rétrogradait une machine réglée à 280k/310k vers 200k
**en préservant son pourcentage** — la moitié visible du réglage avait donc l'air respectée.

## `[1m]` et la fenêtre sont DEUX réglages distincts

| Réglage | Où | Ce qu'il dit |
|---|---|---|
| `[1m]` sur l'ID de modèle | `settings.json` | ce que le modèle **peut** tenir |
| `CLAUDE_CODE_AUTO_COMPACT_WINDOW` | `settings.json` | ce qu'on **veut** laisser grandir avant de condenser |

L'écart entre les deux est **intentionnel** (280k po-2023, 310k ai-01 ; décision user 2026-08-22) :
garder les modèles frais et borner les coûts. **Ne pas « corriger » une fenêtre de 280k/310k vers
1M** sous prétexte que le modèle le supporte — le mandat 200k était un bug parce qu'il **écrasait**
un choix machine, pas parce que 200k était trop petit. Une valeur choisie se respecte dans les deux
sens.

## Machine neuve : déployer AVANT le premier spawn

Le plancher #502 ne vit plus que dans `deploy-claude-mcp-settings.ps1` — les scripts de spawn ne le
rattrapent plus depuis le retrait des overrides. Sur une machine dont `settings.json` n'a jamais été
déployé, un `claude -p` tombe donc sur le défaut Claude Code (~50 %) et **retrouve la boucle #502**.
Lancer `deploy-claude-mcp-settings.ps1` avant le premier spawn. Machine déjà en service : rien à
faire, le pourcentage y est déjà ≥ 90.

## Distinction : condensation CONTEXTE vs condensation DASHBOARD

Ne pas confondre (deux mécanismes distincts) :
- **Context window** (ce doc, `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`) : seuil **≥ 90%** de la fenêtre configurée sur la machine (`settings.json` fait foi) → déclenche la compaction de la **conversation** Claude Code.
- **Dashboard RooSync** (`roosync_dashboard`) : auto-condensation **préemptive à 92%** (~46 KB) / réactive à 50 KB → gère l'espace du **fichier dashboard** shared (GDrive). Voir [`.claude/rules/intercom-protocol.md`](../../../.claude/rules/intercom-protocol.md).

---

## Références

- **Source canonique :** [`.claude/rules/context-window.md`](../../../.claude/rules/context-window.md) v6.0.0
- **INDEX :** [`INDEX.md`](./INDEX.md) — entrée Condensation (`settings.json` fait foi)
- **Issue #502 :** Boucle infinie condensation Roo
- **Issue #1152 :** Standard unifié historique 75%
- **Issue #2173 :** Réglage model-aware (superseded)
- **Mandate 2026-05-25 :** seuil universel 90% (ralentir la flotte)
- **Source communauté :** taille réelle GLM ~131k (200k inclut output)

---

**Dernière mise à jour :** 2026-06-23 (v4.0.0 — aligné sur `context-window.md` universel 90%, supersedes v3.0.0 model-aware 75%)
**Mainteneur :** Coordinateur RooSync (myia-ai-01)
