# MCP Surface & Profils — empreinte outils MCP

**Version:** 1.0.0
**Date:** 2026-09-22
**Issue:** #2224 ([META-HARNESS] Audit & reduce MCP tools footprint)
**Machine de mesure:** myia-po-2026 (submodule RSM `93b0d02b`, build frais)

---

## Objet

Répondre au critère « Doc » de #2224 et servir de référence pour toute question
d'empreinte/surface des MCP sur la flotte. **Le mot « profiles » a survécu au
re-scoping, pas le mécanisme** : les profils qui retirent des serveurs ont été
rejetés par arbitrage user (2026-05-24), et le chargement différé
(`ENABLE_TOOL_SEARCH`, #3657, 15/09) a rendu le coût de boot obsolète comme
levier. Ce document conserve la trace des deux et le pacte actuel.

## Empreinte canonique (mesurée 2026-09-22)

| Serveur | Outils | Chars sérialisés | ~Tokens (4 ch/tok) | Méthode |
|---------|-------:|-----------------:|-------------------:|---------|
| roo-state-manager | 17 | 38 507 | ~9 627 | EXACT — `JSON.stringify(allToolDefinitions)` sur build frais |
| playwright | 25 | 17 407 | ~4 352 | EXACT — `tools/list` JSON-RPC live |
| sk-agent | 9 | 7 826 | ~1 957 | EXACT — `tools/list` live |
| searxng | 2 | 1 727 | ~432 | EXACT — `tools/list` live |
| **TOTAL** | **53** | **65 467** | **~16 368** | |

Cible indicative de #2224 : **< 25k tokens** → dépassée (~16,4k). Et surtout :
sur harnais resserré (#3657), **zéro de ces tokens n'est payé au boot** — les
schémas ne sont chargés qu'à l'appel effectif. Mesure de référence #99 (13/09) :
~64 % du prompt en définitions MCP inline pour 0,4 % d'appels.

## Trajectoire 2026-05 → 2026-09

| Date | Événement | Effet surface |
|------|-----------|---------------|
| 2026-05-16 | Création #2224 | Estimé 30-40k tok, RSM 34 outils |
| 2026-05 | Fusions CONS (CONS-1..13, #457/#603…) | RSM 34 → 15 outils |
| 2026-05-24 | PR submod #500 : condensation descriptions RSM | source 48 239 → 35 722 chars (−26 %) |
| 2026-05-24 | PR submod #522 : aliases sk-agent dépréciés retirés | sk-agent 15 → 9 outils (piste D livrée) |
| 2026-05-24 | **Arbitrage user — re-scope** | profils-retrait REJETÉS : garder tous les serveurs, réduire la surface (descriptions compactes, fusions, wrappers fins) |
| 2026-05-29 | Mesure po-2024 post-#500 | RSM 15 outils / 25 759 chars / ~6 440 tok |
| 2026-06→09 | Nouveaux outils RSM : `claudish_traffic` (#3591), `roosync_harmonization` (#3545) ; croissance `roosync_messages` (idempotence #1157/#1191, attachments #3256, filtres inbox #3351) | RSM 15 → 17 outils / 38 507 chars (**+49 % chars** vs creux de mai) |
| 2026-09-15 | #3657 harnais maigre : `ENABLE_TOOL_SEARCH: "true"` | chargement différé — coût de boot MCP ≈ 0 |

**Leçon (tapis roulant).** La réduction de surface est un tapis roulant : les
gains de consolidation se réinvestissent en nouvelles fonctionnalités (+49 %
de chars RSM en 3 mois). Ce n'est pas un défaut à corriger une fois — c'est un
rythme à surveiller. La garde qui tient durablement est le chargement différé,
pas un plafond de chars.

## Décisions per-MCP (état effectif 2026-09-22)

| MCP | Décision | Justification |
|-----|----------|---------------|
| roo-state-manager | **KEEP** (permanent, coordination) | cœur flotte ; 2 outils (dashboard + conversation_browser) = 30 % de sa surface ; déjà fusionné 34 → 17 |
| playwright | **KEEP** (mandat user 2026-05-24) ; coût réel ≈ 0 en différé | usage réel concentrate : 7/25 outils sur exécuteur (navigate, evaluate, close, screenshot, resize, snapshot, find) |
| sk-agent | **KEEP** ; aliases dépréciés déjà retirés | ~0 invocation directe depuis Claude sur exécuteur ; sert les agents internes (5/30 agents utilisent playwright via lui) |
| searxng | **KEEP** (web canonique) | 2 outils, minimal |
| win-cli | KEEP — **Roo uniquement** (pas dans config Claude) | zéro empreinte Claude Code |
| markitdown | Roo uniquement (`mcp_settings.json`) | zéro empreinte Claude Code |
| Google Drive | RETIRED (2026-05-15, antérieur à l'issue) | — |

### Statut des 5 pistes de l'issue

| Piste | Statut |
|-------|--------|
| (A) Profils `.mcp.*.json` | **REJETÉE** (arbitrage user 2026-05-24) puis **rendue obsolète** par le différé #3657 |
| (B) RSM `--lite` | **OBSOLÈTE** : les fusions CONS ont fait le travail (34→17) ; le différé supprime le coût résiduel |
| (C) playwright lazy | **SUPERSEDÉE** par #3657 (lazy natif) ; note : `.mcp.json` workspace roo-extensions porte `disabled: true` mais le user-scope le maintient disponible (l'instrument qui ne ment pas = présence des outils en session, #3137) |
| (D) sk-agent stale tools | **LIVRÉE** — PR submod #522, 15 → 9 outils (vérifié live 2026-09-22) |
| (E) Feedback Anthropic | **MOOT côté boot** : `ENABLE_TOOL_SEARCH` est la solution native (ranking/méta-outil du commentaire externe ctxslim = désormais couvert nativement) |

## Matrice d'usage (criterion #2224-2)

**Méthode** (2026-09-22, po-2026, toutes workspaces locales) : comptage
grep des `tool_use`/listings dans les JSONL de session (agrégat noms+comptes
seul — aucun contenu de session chargé), lu comme **delta au-dessus du plancher
d'exposition** de chaque serveur (le plancher = mentions de listing de schéma,
uniforme par serveur ; ex. ~618/outil playwright, ~404/outil quantconnect).
Corroboration croisée : `roosync_search(action:"semantic", tool_name:X,
chunk_type:"tool_interaction")` multi-machines.

| Outil / famille | Delta usage (signal d'invocation) |
|---|---|
| `roosync_messages` | ~+9 300 — **très lourd** |
| `roosync_dashboard` | ~+9 050 — **très lourd** |
| `roosync_inventory` | ~+280 |
| `roosync_search` | ~+250 |
| `codebase_search` | ~+130 |
| `conversation_browser` | ~+120 |
| `roosync_diagnose` | ~+110 |
| `roosync_indexing` | ~+27 |
| `roosync_compare_config` / `roosync_config` | ~+17 / ~+9 |
| `export_data`, `read_vscode_logs`, `roosync_mcp_management`, `roosync_storage_management`, `roosync_baseline`, `claudish_traffic` | ≈ 0 (au plancher) |
| `roosync_harmonization` | exposition 667 (outil récent, plancher propre plus bas — delta non calculable) |
| playwright `browser_navigate` / `browser_evaluate` | ~+516 / ~+493 |
| playwright autres (close, screenshot, resize, snapshot, find) | +11..+68 |
| playwright 17 outils restants | ≈ 0 |
| sk-agent (9 outils) | ≈ 0 direct (plancher ~90 uniforme) |
| searxng (2 outils) | ≈ 0 sur cette machine |

**Datapoint bruit** : ~50 invocations locales vers des noms d'outils
hallucinés (`mcp__roosync__*`, chaînes `dasmcp`) — marginal, mais la
consolidation réduit aussi la surface de noms devinables à tort.

## Ajouter/étendre une surface MCP — le pacte

1. **Charger en différé d'abord** — `ENABLE_TOOL_SEARCH: "true"` est le garde
   structurel (#3657, `~/.claude/settings.json`). Une grande surface y coûte
   son coût d'usage, pas son coût de présence.
2. **Consolider avant d'ajouter** — pattern CONS : un outil multi-actions
   (`action`/`subAction`) plutôt que N outils plats. Voir `tool-definitions.ts`
   (les commentaires `[REMOVED #1841 Cluster X]` documentent chaque fusion).
3. **Descriptions compactes** — pattern #500 : condenser sans toucher
   enums/defaults/required/mots-clés FR de découvrabilité.
4. **Ne pas retirer de serveurs pour économiser** — arbitrage user 2026-05-24 ;
   la désactivation ciblée reste un outil ponctuel par workspace (#3137, 3
   emplacements de lecture), pas une politique.

## Références

- Harnais maigre & différé : `.claude/rules/harnais-tightening.md` (#3657)
- Décisions désactivation/activation par workspace : `.claude/rules/tool-availability.md` (#3137)
- Inventaire MCP complet : `.claude/rules/tool-availability.md`
- Issue mère (audits, arbitrages, historique complet) : #2224
- Sœur mémoire (tiers rules) : `rules-footprint.md` (#1606/#2223)
