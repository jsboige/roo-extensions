# MCP Surface & Profils — empreinte outils MCP

**Version:** 1.1.0
**Date:** 2026-09-27
**Issue:** #2224 ([META-HARNESS] Audit & reduce MCP tools footprint)
**Machines de mesure:** myia-po-2026 (2026-09-22, submodule RSM `93b0d02b`) · myia-ai-01 (2026-09-27, vintage `ccb14127` — complète la matrice flotte, § ci-dessous)

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

**Re-mesure 2026-09-27 (ai-01, vintage `ccb14127`)** : RSM 17 outils /
**40 004 chars** (~10 001 tok) — 38 507 (22/09) → 39 025 (24/09, byte-identique
sur deux lanes) → 40 004 : **+3,9 % en 5 jours** (tapis roulant, cf. leçon
ci-dessous). `conversation_browser` 5 253 → 5 565 (+312).

## Matrice flotte — deltas par lane (`ENABLE_TOOL_SEARCH`, sept. 2026)

Chaque lane mesure son propre delta (règle `harnais-tightening` §3) : nombre
d'outils MCP différés, poids contrefactuel (ce qui serait payé inline **à chaque
requête** sans le drapeau), et preuve que 0 schéma n'est payé au boot.

| Lane | Date | Outils MCP | Chars sérialisés | ~Tok inline évités/requête | Détail |
|------|------|-----------:|-----------------:|---------------------------:|--------|
| po-2026 (matrice canonique) | 22/09 | 53 | 65 467 | ~16 368 | RSM 38 507 · pw 17 407 · sk 7 826 · sx 1 727 |
| po-2027 | 24/09 | 46 | 66 859 | ~16 715 | RSM 38 507 (build `00b5a038`) · pw 21 143 · sx **4** |
| web1 | 24/09 | 60 (décompte) | — | ~24 000 (estimé) | 0 inline au boot ; décompte #3137 |
| po-2025 | 24/09 | 53 | ~78 100 | ~19 500 | RSM 39 025 exact (probe `build-1094fcd1`) · sx 2 |
| po-2023 | 24/09 | 50 | ~75 600 | ~18 900 | RSM 39 035 (build local) ; 4 RSM hydratés à l'usage |
| po-2024 | 24/09 | 98 (décompte) | RSM 39 025 (exact) | RSM seul : 9 756 | + google-workspace 45 différés · 4/17 RSM hydratés (−55 %) |
| **ai-01** | 27/09 | **129** | **179 265** | **~44 816** | voir ci-dessous |

### Datapoint ai-01 (27/09, dernière lane non mesurée)

Lane coordinateur, workspace `roo-extensions`, session worker schedulée. Toutes
les pesées **EXACTES** (probes JSON-RPC stdio sur le chemin exact que le client
spawn, 27/09 ~04:55-05:02Z) :

| Serveur | Outils | Chars | ~Tokens | Méthode |
|---------|-------:|------:|--------:|---------|
| roo-state-manager (vintage `build-80b4b9a1`, sha `ccb14127`) | 17 | 40 004 | 10 001 | probe `mcp-wrapper.cjs` |
| google-workspace (`uvx workspace-mcp --tool-tier core`) | 43 | **81 821** | 20 455 | tools/list live |
| jupyter-papermill | 25 | 27 020 | 6 755 | tools/list live |
| playwright 1.64.0-alpha | 25 | 20 102 | 5 026 | tools/list live |
| sk-agent 1.26.0 | 9 | 9 125 | 2 281 | tools/list live |
| searxng 0.4.5 | 2 | 1 193 | 298 | tools/list live |
| **Total mesuré (6 serveurs)** | **121** | **179 265** | **~44 816** | |
| claude.ai Claude Docs (connecteur distant) | 8 | — | — | session-effectif seulement (non spawnable localement) |

**Le delta** : 129 outils MCP différés observés en session (instrument #3137),
**0 inline au boot**. Contrefactuel sans drapeau : ~179 265 chars ≈ **~44 816
tok/requête** ≈ 22,4 % d'une fenêtre 200k (4,5 % de [1m]) — la lane la plus
lourde de la flotte mesurée (2,3-2,7× une lane exécutrice). Ce que la session a
réellement payé : **3/17 RSM hydratés** (`roosync_dashboard` 6 288 +
`roosync_messages` 4 442 + `codebase_search` 1 119 = 11 849 chars ≈ 2 962 tok) ;
**0 appel** playwright/searxng/sk-agent/papermill/google-workspace/Claude Docs
(les probes sont des spawns manuels, pas des appels MCP) — leurs 139 261 chars
hors-RSM sont un gain pur.

**Datapoints distinctifs :**

1. **google-workspace est le serveur le plus lourd de la lane** (81 821 chars ≈
   20 455 tok — **2× RSM**). Porté par `.mcp.json` projet (ai-01, po-2024). En
   différé, son coût est usage-only — c'est le cas d'école du pacte §1.
2. **Tapis roulant au niveau serveur** : ~70 outils différés observés sur ai-01
   au 15/09 (`harnais-tightening` §3) → **129 au 27/09** (+84 % d'outils en
   12 jours) pendant que le coût de boot restait ≈ 0. La surface croît, la garde
   tient.
3. **searxng = 2 outils sur ai-01** (v0.4.5 : `searxng_web_search`,
   `web_url_read`) — la divergence inter-machines (2 vs 4 chez po-2027) est
   réelle et persistante.
4. **sk-agent 1.26.0 : 9 125 chars** vs 7 826 le 22/09 (+16 %) — dérive de
   version/descriptions hors contrôle du dépôt.

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
| 2026-09-24 | Datapoints deltas 5 lanes (po-2027, web1, po-2025, po-2023, po-2024) | ~16,7k-24k tok/requête évités selon lane |
| 2026-09-27 | Datapoint ai-01 (dernière lane) : RSM 40 004 ch (`ccb14127`) ; lane 129 outils / 179 265 ch contrefactuels | matrice flotte complète ; **google-workspace devient le 1ᵉʳ contributeur de la lane coordinateur (2× RSM)** |

**Leçon (tapis roulant).** La réduction de surface est un tapis roulant : les
gains de consolidation se réinvestissent en nouvelles fonctionnalités (+49 %
de chars RSM en 3 mois, +3,9 % encore sur les 5 derniers jours mesurés). Ce
n'est pas un défaut à corriger une fois — c'est un
rythme à surveiller. La garde qui tient durablement est le chargement différé,
pas un plafond de chars.

## Décisions per-MCP (état effectif 2026-09-27)

| MCP | Décision | Justification |
|-----|----------|---------------|
| roo-state-manager | **KEEP** (permanent, coordination) | cœur flotte ; 2 outils (dashboard + conversation_browser) = 30 % de sa surface ; déjà fusionné 34 → 17 |
| playwright | **KEEP** (mandat user 2026-05-24) ; coût réel ≈ 0 en différé | usage réel concentrate : 7/25 outils sur exécuteur (navigate, evaluate, close, screenshot, resize, snapshot, find) |
| sk-agent | **KEEP** ; aliases dépréciés déjà retirés | ~0 invocation directe depuis Claude sur exécuteur ; sert les agents internes (5/30 agents utilisent playwright via lui) |
| searxng | **KEEP** (web canonique) | 2-4 outils selon version installée (2 mesuré sur po-2025/po-2023/ai-01, 4 sur po-2027) ; minimal |
| google-workspace | **KEEP** (ai-01, po-2024 — `.mcp.json` projet, tier core) | 43 outils / 81 821 ch = **1ᵉʳ contributeur de la lane coordinateur** ; en différé, coût usage-only |
| jupyter-papermill | **KEEP** (ai-01 ; mandataire notebooks #3657 §2) | 25 outils / 27 020 ch ; activation au besoin, différé natif |
| claude.ai Claude Docs | **KEEP** (connecteur distant, ai-01) | 8 outils, non spawnable localement — présence session-effective uniquement |
| win-cli | KEEP — **Roo uniquement** (pas dans config Claude) | zéro empreinte Claude Code |
| markitdown | Roo uniquement (`mcp_settings.json`) | zéro empreinte Claude Code |
| Google Drive | RETIRED (2026-05-15, antérieur à l'issue) | — |

*(Décisions mises à jour 2026-09-27 avec les serveurs spécifiques aux lanes ai-01/po-2024 ; les mesures correspondantes dans la section Datapoint ai-01.)*

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
