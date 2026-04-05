# Issue #1026 - Réduction Empreinte Harnais Claude Code

**Date:** 2026-04-02
**Machine:** myia-po-2026
**Issue:** https://github.com/jsboige/roo-extensions/issues/1026

---

## Diagnostic Actuel

Le harnais Claude Code consomme environ **61K tokens** :

| Composante | Tokens |
|------------|--------|
| Global CLAUDE.md | 4,125 |
| Project CLAUDE.md | 8,048 |
| Worktree CLAUDE.md | 8,048 |
| Auto-loaded rules (15 fichiers) | 23,400 |
| Settings.json | 298 |
| MCP tool schemas | 3,500 |
| Native system prompt (estimé) | 7,500 |
| **TOTAL** | **~61,457** |

**Note:** L'issue mentionne 114K tokens - cette différence pourrait être due à :
- Mesure avec un tokenizer différent (tiktoken vs estimation)
- Inclusion de composantes supplémentaires
- Version différente du harnais

## Objectif

Réduire l'empreinte à **<30K tokens** pour permettre :
1. Utiliser Haiku pour les tâches simples (maintenance)
2. Réduire les coûts de ~50%
3. Plus d'espace utile pour le travail réel

## Plan de Réduction

### Phase 1: Réorganiser les règles (économies: ~10K tokens)

**Actions:**
1. **Déplacer ces règles vers `docs/harness/` (on-demand) :**
   - `sddd-conversational-grounding.md` (344 lignes, ~3K tokens) - recherche uniquement
   - `delegation.md` (219 lignes, ~2K tokens) - tâches complexes uniquement
   - `github-cli.md` (166 lignes, ~1.5K tokens) - opérations gh uniquement
   - `test-success-rates.md` (120 lignes, ~1K tokens) - tests uniquement
   - `worktree-cleanup.md` (320 lignes, ~2.5K tokens) - maintenance uniquement

2. **Garder dans `.claude/rules/` (auto-loaded) :**
   - `tool-availability.md` - CRITIQUE (sécurité)
   - `validation.md` - CRITIQUE (qualité)
   - `pr-mandatory.md` - CRITIQUE (workflow)
   - `ci-guardrails.md` - CRITIQUE (prévention régressions)
   - `no-deletion-without-proof.md` - CRITIQUE (anti-destruction)
   - `file-writing.md` - IMPORTANT (opérations fichiers)
   - `intercom-protocol.md` - IMPORTANT (communication)
   - `skepticism-protocol.md` - IMPORTANT (vérification)
   - `agents-architecture.md` - IMPORTANT (référence agents)
   - `context-window.md` - IMPORTANT (condensation)

### Phase 2: Condenser CLAUDE.md (économies: ~5K tokens)

**Actions:**
1. Fusionner global + project CLAUDE.md
2. Supprimer les redondances
3. Réduire les exemples verbeux
4. Garder uniquement les informations critiques

### Phase 3: Profil Scheduler Minimal (économies: ~8K tokens)

**Actions:**
1. Créer `CLAUDE.scheduler.md` avec contenu minimal
2. Désactiver MCPs non-essentiels pour schedulers :
   - playwright (pas nécessaire pour build/test)
   - markitdown (pas nécessaire pour maintenance)
3. Garder uniquement : roo-state-manager + sk-agent

### Phase 4: Réduire descriptions MCP (économies: ~2K tokens)

**Actions:**
1. Réduire les descriptions des outils dans les schemas MCP
2. Utiliser des descriptions plus concises

## Implémentation Prioritaire

**Quick Win (Phase 1):** Déplacer 5 règles vers on-demand (~10K tokens)
- Peut être fait immédiatement
- Aucun risque de breaking
- Réduction immédiate significative

**Next Steps:**
1. Implémenter Phase 1
2. Mesurer l'impact
3. Décider si Phases 2-4 sont nécessaires

## Recommandation

Commencer par **Phase 1 uniquement** pour réduire le harnais à ~51K tokens, puis évaluer si c'est suffisant pour permettre l'utilisation de Haiku.

Si plus de réduction est nécessaire, procéder à **Phase 2** (CLAUDE.md condensé).

**Phases 3-4** peuvent être faites plus tard si nécessaire.
