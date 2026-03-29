# Issue #603 - Lot B Candidates (2026-03-29)

## Objet

Definir un lot de simplification controlee, non destructif, pour reduire le dual-stack legacy tout en preservant la compatibilite.

## Source de verite

- Mapping backward-compat: `src/tools/__tests__/tool-discoverability.test.ts` (`BACKWARD_COMPAT_ROUTES`)
- Handler routing: `src/tools/registry.ts`
- Outil consolide cible: `src/tools/roosync/config.ts`

## Matrice legacy -> remplaçant

### Configuration

- roosync_collect_config -> roosync_config(action: collect)
- roosync_publish_config -> roosync_config(action: publish)
- roosync_apply_config -> roosync_config(action: apply)

### Decision

- roosync_get_decision_details -> roosync_decision_info
- roosync_approve_decision -> roosync_decision
- roosync_reject_decision -> roosync_decision
- roosync_apply_decision -> roosync_decision
- roosync_rollback_decision -> roosync_decision

### Baseline

- roosync_update_baseline -> roosync_baseline
- roosync_manage_baseline -> roosync_baseline
- roosync_export_baseline -> roosync_baseline

### Inventory

- roosync_get_machine_inventory -> roosync_inventory

## Strategie Lot B (ordre recommande)

1. Documentation first
- Marquer les handlers legacy restants comme "backward-compat only" dans registry.
- Pointer explicitement le remplaçant dans chaque section.

2. Discoverability hygiene
- Verifier que les outils legacy ne sont pas exposes dans ListTools.
- Garder la backward-compat uniquement via CallTool.

3. Retrait conditionnel
- Retirer les handlers legacy uniquement si absence d'usage prouvee.
- Appliquer la regle anti-destruction: preuve de remplacement + tests.

## Gate de validation avant merge

- Build TypeScript OK
- Tests unitaires OK
- Tests CI `vitest.config.ci.ts` OK
- Aucun outil consolide perdu en discoverability

## Note onboarding

Ce document est un preparatif d'execution. Il permet de lancer une PR Lot B sans phase de recadrage supplementaire.
