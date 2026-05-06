# Rapport des Issues roo-schedulable

**Date:** 2026-05-06T05:33Z
**Machine:** myia-po-2025
**Total issues roo-schedulable:** 15

---

## 1. #1967 - [INFRA] win-cli debridé hardcoded — deploy on all 6 machines

| Champ | Valeur |
|-------|--------|
| **Labels** | enhancement, roo-schedulable |
| **Assignee** | jsboige |
| **Statut** | **EN COURS** |
| **Derniere activite** | 2026-05-05 [CLAIMED] myia-po-2026 |

**Details:**
- myia-web1: [RESULT] PASS (2026-05-04)
- myia-po-2023: deployment status (2026-05-04)
- myia-po-2025 (jsboigeEpita): Deployed (2026-05-04)
- myia-po-2026: [CLAIMED] (2026-05-05)
- web1: Deploy verified (2026-05-05)

---

## 2. #1843 - [AUDIT] Code review focalisée 1 service roo-state-manager (le plus actif)

| Champ | Valeur |
|-------|--------|
| **Labels** | enhancement, roo-schedulable |
| **Assignee** | jsboige |
| **Statut** | **EN COURS** |
| **Derniere activite** | 2026-05-02 Code Review — BaselineManager.ts |

**Details:**
- [CLAIMED] myia-po-2025 (2026-04-30)
- Audit en cours sur po-2025: ConfigSharingService, background-services, BaselineManager
- Multiple rapports d'audit produits

---

## 3. #1841 - [AUDIT] Inventaire d'utilisation réelle des 34 outils roo-state-manager

| Champ | Valeur |
|-------|--------|
| **Labels** | enhancement, roo-schedulable, investigation |
| **Assignee** | jsboige |
| **Statut** | **EN COURS** |
| **Derniere activite** | 2026-05-05 Consolidation Candidates (Post Cluster B+E) |

**Details:**
- Audit multi-machines en cours
- Dernier rapport: Consolidation Candidates (2026-05-05)
- PR creee par myia-ai-01 (RESULT PASS)

---

## 4. #1822 - chore(maintenance): run session classification + cleanup on all machines

| Champ | Valeur |
|-------|--------|
| **Labels** | enhancement, roo-schedulable |
| **Assignee** | jsboige |
| **Statut** | **EN COURS** |
| **Derniere activite** | 2026-05-01 [CLAIMED] myia-po-2025 |

**Details:**
- myia-po-2023: [RESULT] PASS (2026-04-29)
- myia-po-2025: [CLAIMED] (2026-05-01)
- Classification en cours sur les machines restantes

---

## 5. #1808 - [CLAUDE-ALL] Investigation thrashing tâches (scheduler/worktree/condensation explosée)

| Champ | Valeur |
|-------|--------|
| **Labels** | enhancement, roo-schedulable, investigation |
| **Assignee** | jsboige |
| **Statut** | **EN COURS** |
| **Derniere activite** | 2026-05-02 [BACKLOG-SWEEP] Run #4 |

**Details:**
- myia-ai-01: [RESULT] PASS (2026-04-28)
- Backlog-sweep Run #4 en cours
- Analyse thrashing en cours

---

## 6. #1807 - [CLAUDE-ALL] Audit pression disque cross-machine

| Champ | Valeur |
|-------|--------|
| **Labels** | enhancement, roo-schedulable, investigation |
| **Assignee** | jsboige |
| **Statut** | **EN COURS** |
| **Derniere activite** | 2026-05-02 [DISK-AUDIT] myia-po-2024 |

**Details:**
- web1: [RESULT] PASS, PR #1814 (2026-04-28)
- Backlog-sweep Run #4 en cours
- Audit disque po-2024 (2026-05-02)

---

## 7. #1639 - [CLEANUP] Nettoyage .shared-state/meta-analysis/

| Champ | Valeur |
|-------|--------|
| **Labels** | documentation, roo-schedulable |
| **Assignee** | jsboige |
| **Statut** | **TERMINE** |
| **Derniere activite** | 2026-05-02 Status update po-2026 |

**Details:**
- myia-po-2025: [RESULT] PASS (2026-04-23)
- myia-po-2025: [RESULT] VERIFIED - NO ACTION REQUIRED (2026-04-28)
- po-2024: DONE (2026-04-25)
- po-2026: Status update (2026-05-02)

---

## 8. #1509 - [NORMAL] Redistribute Workload from myia-ai-01 to Executor Machines

| Champ | Valeur |
|-------|--------|
| **Labels** | enhancement, roo-schedulable, harness-change |
| **Assignee** | jsboige |
| **Statut** | **EN COURS** |
| **Derniere activite** | 2026-04-21 Redistribution Results |

**Details:**
- [CLAIMED] myia-po-2025 (2026-04-21)
- Audit de charge po-2025 realise
- Redistribution results produits

---

## 9. #1492 - [META-ANALYSIS] Regression: Roo _index.json entries empty on po-2026

| Champ | Valeur |
|-------|--------|
| **Labels** | bug, roo-schedulable, claude-only |
| **Assignee** | myia-po-2023 |
| **Statut** | **DISPATCHEE a myia-po-2023** |
| **Derniere activite** | 2026-05-04 Investigation from myia-po-2024 |

**Details:**
- Dispatchee a myia-po-2023 (assignee)
- Investigation en cours sur po-2026
- Multiple investigations rapportees

---

## 10. #1476 - [BUG] Schedulers Roo manquants sur myia-po-2025

| Champ | Valeur |
|-------|--------|
| **Labels** | bug, roo-schedulable, claude-only |
| **Assignee** | MyIA-Web1 |
| **Statut** | **DISPATCHEE a MyIA-Web1** |
| **Derniere activite** | 2026-04-19 Audit po-2025 |

**Details:**
- Dispatchee a MyIA-Web1 (assignee)
- [CLAIMED] by claude on myia-po-2026
- [RESULT] myia-po-2026: PASS
- Checklist incomplete, issue rouverte

---

## 11. #1410 - [FRICTIONS] roo-state-manager UX & consistency

| Champ | Valeur |
|-------|--------|
| **Labels** | enhancement, roo-schedulable, claude-only |
| **Assignee** | MyIA-Web1 |
| **Statut** | **EN COURS** |
| **Derniere activite** | 2026-04-19 Audit po-2025 |

**Details:**
- [CLAIMED] by claude on myia-po-2026
- [RESULT] myia-po-2026: PASS
- Checklist incomplete, issue rouverte automatiquement

---

## 12. #1409 - [REGRESSIONS] roo-state-manager data quality

| Champ | Valeur |
|-------|--------|
| **Labels** | bug, roo-schedulable, claude-only |
| **Assignee** | jsboige |
| **Statut** | **EN COURS** |
| **Derniere activite** | 2026-05-05 Evidence: Items resolved |

**Details:**
- [CLAIMED] by claude on myia-po-2023
- [RESULT] myia-po-2023: PASS
- Checklist incomplete, issue rouverte (1/3)
- Evidence: Items resolved by merged PRs (2026-05-05)
- Investigation po-2025 en cours (2026-05-04)

---

## 13. #644 - fix(security): Key rotation verification after commit leak

| Champ | Valeur |
|-------|--------|
| **Labels** | bug, roo-schedulable |
| **Assignee** | jsboige |
| **Statut** | **EN COURS** |
| **Derniere activite** | 2026-03-16 Verification po-2026 |

**Details:**
- [DISPATCH] All, Priority: MEDIUM (2026-03-15)
- myia-po-2025: verified (2026-03-14)
- myia-po-2023: Verification Report (2026-03-15)
- myia-po-2026: Verification Report (2026-03-12)
- Verification en cours sur toutes les machines

---

## 14. #568 - [TEST] Validation end-to-end schedulers sur toutes les machines

| Champ | Valeur |
|-------|--------|
| **Labels** | roo-schedulable, testing |
| **Assignee** | jsboige |
| **Statut** | **EN COURS** |
| **Derniere activite** | 2026-03-06 Rapport Intermédiaire |

**Details:**
- Claimed by claude on myia-po-2025, Executed by Claude Code scheduler
- Phase 1 Validation: po-2024, po-2023, ai-01
- Validation multi-phases en cours

---

## 15. #486 - [AMELIORATION] Amélioration continue skills/agents/commands/rules/modes Roo

| Champ | Valeur |
|-------|--------|
| **Labels** | enhancement, roo-schedulable |
| **Assignee** | jsboige |
| **Statut** | **EN COURS** |
| **Derniere activite** | 2026-03-03 Propositions d'amelioration |

**Details:**
- Phase 1: myia-ai-01, po-2024, po-2025, web1
- Phase 2: Worker Prompt Improvement - DONE (po-2025)
- Result: FOUND - issue open and actionable
- Propositions d'amelioration en cours

---

## Resume par Statut

| Statut | Nombre | Issues |
|--------|--------|--------|
| **TERMINE** | 1 | #1639 |
| **EN COURS** | 12 | #1967, #1843, #1841, #1822, #1808, #1807, #1509, #1410, #1409, #644, #568, #486 |
| **DISPATCHEE** | 2 | #1492 (po-2023), #1476 (MyIA-Web1) |
| **DISPONIBLE** | 0 | - |

## Issues avec activite recente (< 7 jours)

| Issue | Date | Activite |
|-------|------|----------|
| #1967 | 2026-05-05 | [CLAIMED] myia-po-2026 |
| #1841 | 2026-05-05 | Consolidation Candidates |
| #1409 | 2026-05-05 | Evidence: Items resolved |
| #1843 | 2026-05-02 | Code Review BaselineManager.ts |
| #1807 | 2026-05-02 | [DISK-AUDIT] po-2024 |
| #1808 | 2026-05-02 | [BACKLOG-SWEEP] Run #4 |

## Issues avec checklist incomplete (rouvertes automatiquement)

| Issue | Raison |
|-------|--------|
| #1410 | Checklist incomplete |
| #1409 | Checklist incomplete (1/3) |
| #1967 | Checklist incomplete (1/3) |
