# SYNTHESIS — Rapports Archives docs/archive/

**Date:** 2026-04-30
**Auteur:** myia-po-2026 (Claude Code)
**Issue:** #1844 Task 4

---

## Resume Executif

28 fichiers archives repartis en 4 categories, couvrant fevrier 2026 a avril 2026. La plupart des recommandations ont ete implementees. Ce document consolide les findings encore pertinents et identifie les rapports redondants supprimables.

---

## 1. Scheduler Design & Audits (Fev 2026)

**Fichiers:** 4 rapports + 3 doublons dans `2026-03-03-issue553-phase2/`
**Issue origine:** #487

### Findings

| Finding | Statut | Resolution |
|---------|--------|------------|
| INTERCOM scheduler non mis a jour (po-2023, po-2026) | RESOLU | Dashboard workspace remplace INTERCOM comme canal principal (#745) |
| Orchestrateur ne peut ecrire INTERCOM (permissions) | RESOLU | Orchestrator-simple decommissionne au profit de `start-claude-worker.ps1` |
| Traces scheduler inaccessibles | RESOLU | `conversation_browser` + `roosync_search` remplacent l'acces direct |
| Architecture scheduler Claude Code | IMPLEMENTE | `scripts/claude/start-claude-worker.ps1` (1903 lignes) |

### Doublons identifies

- `scheduler-audit-myia-po-2026.md` existe dans `reports/` ET `2026-03-03-issue553-phase2/` (meme contenu)
- `scheduler-claude-code.md` (issue553) chevauche `scheduler-claude-code-design.md` (reports/)
- `scheduler-documentation-validation.md` (issue553) est un sous-produit de l'audit

### Recommandation

Les 4 fichiers `reports/scheduler-*.md` sont consolidables : findings implementes, design realise dans les scripts actuels.

---

## 2. Issue #543/#553 Phase 2 (Mar 2026)

**Fichiers:** 12 rapports dans `2026-03-03-issue553-phase2/`
**Issue origine:** #553 (Phase 2 de #543 harmonisation)

### Findings

| Rapport | Contenu | Statut |
|---------|---------|--------|
| `issue-543-execution-summary.md` | Resume execution Phase 2 | RESOLU |
| `issue-543-harmonisation-report.md` | Rapport harmonisation .roo/rules/ | RESOLU |
| `issue-543-phase-2-report.md` | Rapport Phase 2 | RESOLU |
| `issue-543-phase-4-plan.md` | Plan Phase 4 | RESOLU |
| `issue-543-scenario-a-report.md` | Scenario A | RESOLU |
| `issue-543-scenarios-b-c-plan.md` | Scenarios B+C | RESOLU |
| `issue-543-validation-framework.md` | Framework validation | RESOLU |
| `BUGS_TRACKING-archived-2026-03-03.md` | Suivi bugs Phase 2 | RESOLU |
| `scheduler-audit-myia-po-2026.md` | Doublon avec reports/ | DOUBLON |
| `scheduler-claude-code.md` | Doublon partiel avec reports/ | DOUBLON |
| `scheduler-documentation-validation.md` | Validation docs scheduler | RESOLU |
| `sk-agent-investigation-2026-02-16.md` | Investigation sk-agent | PARTIEL — sk-agent toujours actif |

### Recommandation

Dossier complet archivable. Les findings sont historiques (Phases 1-4 de #543 terminees et mergees). Le rapport `sk-agent-investigation` est le seul avec une valeur de reference (configuration sk-agent).

---

## 3. MCP Analysis & Infrastructure (Mar 2026)

**Fichiers:** `mcp-analysis-report.md`, `project-67-myia-po-2026-report.md`
**Issues origine:** #644, #646

### Findings MCP

| Finding | Pertinence actuelle |
|---------|---------------------|
| Seuls 4 MCPs actifs (win-cli, playwright, markitdown, roo-state-manager) | PERTINENT — configuration stable |
| jinavigator-server en erreur (module non trouve) | PERTINENT — toujours en erreur sur po-2026 |
| github-projects-mcp deprecie (remplace par gh CLI) | RESOLU — retire |
| desktop-commander, quickfiles inactifs | RESOLU — retires |
| sk-agent non detecte dans logs | PARTIEL — sk-agent actif mais intermitent |

### Findings Project #67

| Metric | Mars 2026 | Avril 2026 |
|--------|-----------|------------|
| Total items | 283 | ~350+ |
| Issues po-2026 | 2 | 0 assignees actifs |

**Statut:** Snapshot obsolete. Project #67 maintenant synchronise via `gh` CLI + workflow GitHub Actions (#1835).

### Recommandation

`mcp-analysis-report.md` conservable comme reference MCP status. `project-67-myia-po-2026-report.md` obsolete, supprimable.

---

## 4. Architecture & System (Fev 2026)

**Fichiers:** `diagnostic-systeme-2026-02-02.md`, `task-440-exploration-architecture.md`
**Issues origine:** #440, system diagnostic

### Findings Systeme

| Finding | Statut |
|---------|--------|
| 4425 taches indexees, 100% sync | BASELINE — index maintenant ~15000+ |
| Aucune tache orpheline | CONFIRME — `cleanup_orphans` tool ajoute (#1821) |
| SQLite index operationnel | CONFIRME — toujours en service |

### Findings Architecture (Task #440)

| Finding | Statut |
|---------|--------|
| `task_browse` (CONS-9) | IMPLEMENTE → `conversation_browser(action: "tree")` |
| `view_conversation_tree` | IMPLEMENTE → `conversation_browser(action: "view")` |
| `roosync_summarize` (CONS-12) | IMPLEMENTE → `conversation_browser(action: "summarize")` |
| 95% taches orphelines (one-shot) | PERTINENT — pattern toujours vrai |

### Recommandation

Ces 2 rapports ont une valeur architecturale. `diagnostic-systeme` = baseline reference. `task-440` = historique de la genese de `conversation_browser`. A conserver.

---

## 5. Harness Cross-Analysis (Mar 2026)

**Fichiers:** 4 rapports dans `harness-reports/`
**Issue origine:** Meta-analyse harness coherence

### Evolution des rapports

| Date | Fichier | Score coherence | Focus |
|------|---------|----------------|-------|
| 2026-03-13 | `cross-analysis-harnesses-2026-03-13.md` | Non score | 10 incoherences + 11 lacunes |
| 2026-03-14 | `harness-cross-analysis-report-2026-03-14.md` | Non score | Affinage INCO/GAP |
| 2026-03-15 | `harness-cross-analysis-report-2026-03-15.md` | 65% | Score + classification |
| (final) | `harness-cross-analysis-report.md` | 65% | Version de reference |

### Findings encore pertinents

| Finding | Statut |
|---------|--------|
| INC-001: Seuil condensation Roo 70% vs Claude non documente | RESOLU — 75% standardise (#1152) |
| INC-007: win-cli OBLIGATOIRE pour Roo, pas Claude | PERTINENT — toujours vrai |
| GAP-001: Regle condensation absente Claude | RESOLU — `.claude/rules/context-window.md` |
| GAP-006: Escalade niveau 4 (claude -p) | PARTIEL — non standardise |
| GAP-009: CI guardrails vitest.config.ci.ts | RESOLU — `.claude/rules/ci-guardrails.md` |

### Recommandation

Les 3 premiers rapports (03-13, 03-14, 03-15) sont des iterations intermediaires. Seul le rapport final (`harness-cross-analysis-report.md`) a valeur de reference.

---

## 6. Roo/Claude Cross-Analysis (Avr 2026)

**Fichier:** `roo-analysis-2026-04-07.md`
**Issue origine:** Meta-analyse coherence

### Findings

| Finding | Statut |
|---------|--------|
| Condensation threshold: 75% vs 80% incoherence | PARTIELLEMENT RESOLU — 75% standardise, mais `.roo/rules/12-machine-constraints.md` et `18-meta-analysis.md` mentionnent encore 80% |
| Version drift: .roo/rules/ 15-43 jours derriere .claude/rules/ | PARTIELLEMENT RESOLU — redistribute-memory skill cree pour synchroniser |
| 11 fichiers uniques a .roo/rules/ | PERTINENT — specificites Roo toujours valides |

### Recommandation

Rapport le plus recent et le plus pertinent. A conserver comme reference pour le prochain audit coherence.

---

## 7. Autres fichiers archives

| Fichier | Contenu | Recommandation |
|---------|---------|----------------|
| `docs/archive/git-merge-commits-analysis-20251016.md` | Analyse merge commits oct 2025 | Conserver — reference historique |
| `docs/archive/gpu-specs-myia-po-2023.md` | Specs GPU po-2023 | Conserver — reference hardware |

---

## Synthese des Redondances

### Supprimables (doublons ou totalement obsoletes)

| Fichier | Raison |
|---------|--------|
| `reports/project-67-myia-po-2026-report.md` | Snapshot obsolete (283 items → 350+), remplace par gh CLI |
| `reports/scheduler-audit-myia-po-2026.md` | Doublon avec `2026-03-03-issue553-phase2/scheduler-audit-myia-po-2026.md` |
| `harness-reports/cross-analysis-harnesses-2026-03-13.md` | Iteration intermediaire, supplanee par rapport final |
| `harness-reports/harness-cross-analysis-report-2026-03-14.md` | Iteration intermediaire |
| `harness-reports/harness-cross-analysis-report-2026-03-15.md` | Iteration intermediaire |

### Consolidables (findings implementes, reference uniquement)

| Fichier | Finding principal | Implementation |
|---------|-------------------|----------------|
| `reports/scheduler-claude-code-design.md` | Architecture scheduler | `start-claude-worker.ps1` |
| `reports/scheduler-workflow-adjustments.md` | Ajustements workflow | Dashboard workspace |
| `reports/scheduler-audit-myia-po-2023.md` | Audit 80% success | Dashboard workspace |
| `reports/mcp-analysis-report.md` | Inventaire MCPs | Config actuelle stable |

### A conserver (valeur de reference)

| Fichier | Valeur |
|---------|--------|
| `reports/diagnostic-systeme-2026-02-02.md` | Baseline sante systeme |
| `reports/task-440-exploration-architecture.md` | Historique genese `conversation_browser` |
| `reports/roo-analysis-2026-04-07.md` | Dernier audit coherence harnais |
| `harness-reports/harness-cross-analysis-report.md` | Rapport final cross-analysis |
| `2026-03-03-issue553-phase2/` (dossier) | Archive Phase 2 #543 |

---

## Statistiques

| Metric | Valeur |
|--------|--------|
| Total fichiers archives | 28 |
| Categories identifiees | 7 |
| Doublons exacts | 1 |
| Iterations intermediaires | 3 |
| Obsoletes confirmes | 1 |
| Findings implementes | 15/20 (75%) |
| Findings encore pertinents | 5/20 (25%) |
