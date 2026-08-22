# Condensation — Context Window

**Version:** 6.0.0 (le clamp universel 200k est un **bug**, pas une règle — décision user 2026-08-22)
**Supersede :** v5.0.0 « seuil UNIVERSEL 200k/90 » (décision user 2026-05-25)

---

## Règle : `settings.json` de la machine fait foi

**La fenêtre de compaction se décide dans `~/.claude/settings.json`, et nulle part ailleurs.**
Aucun script ne la surcharge à l'exécution.

Chaque machine configure la fenêtre que ses modèles peuvent réellement tenir. Il n'y a **pas**
de valeur universelle : une machine qui tourne en Claude `[1m]` et une machine qui tourne en
GLM n'ont pas le même contexte utile, et c'est normal.

## Le seul invariant : jamais un POURCENTAGE bas

`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` **≥ 90**. Le défaut Claude Code (50 %) produit une boucle de
condensation infinie (#502), et 70 % la reproduit sous harnais lourd (#736). C'est le seul
garde-fou, et il vit dans `deploy-claude-mcp-settings.ps1` (condition `< 90`), au niveau du
fichier settings.

**Une grande fenêtre n'est jamais dangereuse** — seul un pourcentage bas l'est. Il n'y a donc
aucun plancher ni plafond à imposer sur `CLAUDE_CODE_AUTO_COMPACT_WINDOW`.

## Ce qui a été retiré, et pourquoi

Trois mécanismes ramenaient la flotte à 200k **quoi qu'il y ait dans `settings.json`** :

| Mécanisme | Correctif |
|---|---|
| `spawn-claude.ps1`, `start-claude-worker.ps1`, `start-claude-executor.ps1` posaient `200000`/`90` en env avant chaque `claude -p` — **et les env vars priment sur `settings.json`** | overrides **supprimés** |
| `deploy-claude-mcp-settings.ps1` **réécrivait** la fenêtre à `200000` si elle différait, alors que le pourcentage, lui, n'était corrigé que s'il était `< 90` | garde rendue **symétrique** : la fenêtre n'est écrite que si elle est **absente** |
| ID de modèle `opus` sans suffixe `[1m]` → clamp au contexte catalogué | par machine (`settings.json`), hors dépôt — voir ci-dessous |

L'asymétrie de la deuxième rendait la régression discrète : un seul run rétrogradait une machine
réglée à 280k/310k vers 200k **en préservant son pourcentage**, si bien que la moitié visible du
réglage avait l'air respectée.

## `[1m]` : la fenêtre seule ne suffit pas

Un ID de modèle sans suffixe `[1m]` est clampé au contexte catalogué **quelle que soit**
`CLAUDE_CODE_AUTO_COMPACT_WINDOW`. Les deux doivent être cohérents :

```json
"ANTHROPIC_DEFAULT_OPUS_MODEL":   "claude-opus-5[1m]",
"ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-4-6[1m]",
"ANTHROPIC_DEFAULT_HAIKU_MODEL":  "claude-haiku-4-5-20251001[1m]"
```

Ces IDs vivent dans `settings.json` **par machine**. Hors de cette documentation, `[1m]` n'a
**aucune occurrence dans du fichier exécutable ou de configuration du dépôt** (vérifié 2026-08-22,
deux instruments indépendants) : aucune PR ne peut corriger le suffixe à votre place.

## La fenêtre est VOLONTAIREMENT sous le contexte du modèle

`[1m]` déclare que le modèle tient 1M. La fenêtre de compaction, elle, est réglée
**bien en dessous** : 280k sur po-2023, 310k sur ai-01. **Ce n'est pas un clamp résiduel, c'est
une décision** (user, 2026-08-22) : garder les modèles frais et ne pas laisser filer les coûts.

Ce sont donc **deux réglages distincts**, et l'écart entre eux est intentionnel :

| Réglage | Où | Ce qu'il dit |
|---|---|---|
| `[1m]` sur l'ID de modèle | `settings.json` | ce que le modèle **peut** tenir |
| `CLAUDE_CODE_AUTO_COMPACT_WINDOW` | `settings.json` | ce qu'on **veut** laisser grandir avant de condenser |

**Ne pas « corriger » une fenêtre de 280k/310k vers 1M sous prétexte que le modèle le supporte.**
Ce serait le coup de pendule inverse de celui que cette règle vient de défaire : le mandat 200k était
un bug parce qu'il **écrasait** un choix machine, pas parce que 200k était trop petit. Une valeur
choisie se respecte dans les deux sens.

## Machine neuve : déployer AVANT le premier spawn

Le plancher #502 ne vit plus que dans `deploy-claude-mcp-settings.ps1`. Sur une machine dont
`settings.json` n'a jamais été déployé, un `claude -p` tombe donc sur le défaut Claude Code
(~50 %) et retrouve la boucle de condensation — les scripts de spawn ne le rattrapent plus.

**Sur une machine neuve : lancer `deploy-claude-mcp-settings.ps1` avant le premier spawn.** Sur
une machine déjà en service, il n'y a rien à faire : le pourcentage y est déjà ≥ 90.

## Le piège qui reste

**Une session interactive ne recharge pas `settings.json` en cours de route.** Un changement de
fenêtre ou de seuil ne prend effet qu'au **restart** de la session, jamais mid-session.

---

**Réalité de contexte par famille (GLM ~131k en entrée), historique des seuils, config Roo,
distinction condensation contexte vs dashboard :**
[`docs/harness/reference/condensation-thresholds.md`](../../docs/harness/reference/condensation-thresholds.md)
