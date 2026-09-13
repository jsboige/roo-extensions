# Condensation — Context Window

**Version:** 6.1.0 (amende v6.0.0 : « grande fenêtre jamais dangereuse » rescopée à la compaction tokenique seule, + règle PDF #3579)
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

**Une grande fenêtre n'est jamais dangereuse pour la compaction tokenique** — seul un pourcentage
bas l'est. Il n'y a donc aucun plancher ni plafond à imposer sur `CLAUDE_CODE_AUTO_COMPACT_WINDOW`.

**Exception multimodale (#3579) :** cette affirmation ne couvre pas les tool results **atomiques**.
Un `Read` PDF rend chaque page en image base64 (~200-340k caractères/page) injectée en un bloc,
sans budget d'octets ni troncature — aucune variable `CLAUDE_CODE_*` ne plafonne ce canal ; une
grande fenêtre y rend le défaut moins visible. Règle : **texte d'abord** (`pdftotext` : tout un
document pèse moins qu'une page-image), vision par tranches de **1-2 pages max** (`pages`),
**jamais relire le PDF après une erreur de contexte** (session fraîche requise). Garde
structurel opt-in : `scripts/hooks/guard-pdf-read.js` — interception VÉRIFIÉE
([pdf-read-guard](../../docs/harness/reference/pdf-read-guard.md)).

## Ce qui a été retiré, et pourquoi

Trois mécanismes ramenaient la flotte à 200k **quoi qu'il y ait dans `settings.json`** : les
overrides d'env posés par les scripts de spawn avant chaque `claude -p` (**supprimés** — les env
vars priment sur `settings.json`), la réécriture par `deploy-claude-mcp-settings.ps1` (garde rendue
**symétrique** : la fenêtre n'est écrite que si elle est **absente**), et l'absence de `[1m]` sur
l'ID de modèle.

L'asymétrie de la deuxième rendait la régression **discrète** : un seul run rétrogradait une machine
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

Deux réglages **distincts** : `[1m]` dit ce que le modèle **peut** tenir,
`CLAUDE_CODE_AUTO_COMPACT_WINDOW` ce qu'on **veut** laisser grandir avant de condenser. L'écart
est intentionnel — 280k sur po-2023, 310k sur ai-01 — et c'est **une décision** (user, 2026-08-22) :
garder les modèles frais, ne pas laisser filer les coûts.

**Ne pas « corriger » une fenêtre de 280k/310k vers 1M sous prétexte que le modèle le supporte.**
Le mandat 200k était un bug parce qu'il **écrasait** un choix machine, pas parce que 200k était trop
petit : une valeur choisie se respecte dans les deux sens.

## Machine neuve : déployer AVANT le premier spawn

Le plancher #502 ne vit plus que dans `deploy-claude-mcp-settings.ps1` : sur une machine jamais
déployée, `claude -p` retombe sur le défaut Claude Code (~50 %) et retrouve la boucle — les scripts
de spawn ne le rattrapent plus. **Lancer `deploy-claude-mcp-settings.ps1` avant le premier spawn.**
Machine déjà en service : rien à faire, le pourcentage y est déjà ≥ 90.

## Le piège qui reste

**Une session interactive ne recharge pas `settings.json` en cours de route.** Un changement de
fenêtre ou de seuil ne prend effet qu'au **restart** de la session, jamais mid-session.

---

**Réalité de contexte par famille (GLM ~131k en entrée), historique des seuils, config Roo,
distinction condensation contexte vs dashboard :**
[`docs/harness/reference/condensation-thresholds.md`](../../docs/harness/reference/condensation-thresholds.md)
