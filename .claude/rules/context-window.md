# Condensation — Context Window

**Version:** 6.2.0 (slim — historique des mécanismes retirés déporté vers condensation-thresholds.md, #2368)
**Supersede :** v5.0.0 « seuil UNIVERSEL 200k/90 » (décision user 2026-05-25)

---

## Règle : `settings.json` de la machine fait foi

**La fenêtre de compaction se décide dans `~/.claude/settings.json`, et nulle part ailleurs.**
Aucun script ne la surcharge à l'exécution. Pas de valeur universelle : chaque machine configure
la fenêtre que ses modèles tiennent réellement.

## Le seul invariant : jamais un POURCENTAGE bas

`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` **≥ 90** — le défaut (50 %) produit une boucle de condensation
infinie (#502), 70 % la reproduit sous harnais lourd (#736). Garde-fou unique :
`deploy-claude-mcp-settings.ps1` (condition `< 90`). **Une grande fenêtre n'est jamais dangereuse
pour la compaction tokenique** : aucun plancher/plafond sur `CLAUDE_CODE_AUTO_COMPACT_WINDOW`.

**Exception multimodale (#3579) :** ne couvre pas les tool results **atomiques** — un `Read` PDF
rend ~200-340k caractères/page en un bloc, sans budget d'octets ni troncature. Règle : **texte
d'abord** (`pdftotext`), vision par tranches de **1-2 pages max**, **jamais relire le PDF après
une erreur de contexte** (session fraîche). Garde opt-in : `scripts/hooks/guard-pdf-read.js`
([pdf-read-guard](../../docs/harness/reference/pdf-read-guard.md)).

## `[1m]` : la fenêtre seule ne suffit pas

Un ID sans suffixe `[1m]` est clampé au contexte catalogué **quelle que soit** la fenêtre. Les deux
doivent être cohérents dans `settings.json` **par machine** :

```json
"ANTHROPIC_DEFAULT_OPUS_MODEL":   "claude-opus-5[1m]",
"ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-4-6[1m]",
"ANTHROPIC_DEFAULT_HAIKU_MODEL":  "claude-haiku-4-5-20251001[1m]"
```

Hors documentation, `[1m]` n'a **aucune occurrence dans le dépôt** (vérifié 2026-08-22, deux
instruments) : aucune PR ne peut corriger le suffixe à votre place.

## La fenêtre est VOLONTAIREMENT sous le contexte

`[1m]` = ce que le modèle **peut** tenir ; `CLAUDE_CODE_AUTO_COMPACT_WINDOW` = ce qu'on **veut**
laisser grandir avant de condenser. L'écart est une **décision user (2026-08-22)** : garder les
modèles frais, borner les coûts. **Ne pas « corriger » une fenêtre choisie (280k/310k) vers 1M**
sous prétexte que le modèle le supporte — une valeur choisie se respecte dans les deux sens.

## Machine neuve + sessions vivantes

- **Déployer AVANT le premier spawn** (`deploy-claude-mcp-settings.ps1`) : sur machine neuve,
  `claude -p` retombe au défaut ~50 % et retrouve la boucle #502 — les scripts de spawn ne
  rattrapent plus. Machine en service : rien à faire (pct déjà ≥ 90).
- **Une session interactive ne recharge pas `settings.json`** : tout changement prend effet au
  restart, jamais mid-session.

---

**Historique des seuils, mécanismes retirés (env overrides de spawn, garde symétrique, `[1m]`),
réalité de contexte par famille (GLM ~131k), config Roo :**
[`docs/harness/reference/condensation-thresholds.md`](../../docs/harness/reference/condensation-thresholds.md)
