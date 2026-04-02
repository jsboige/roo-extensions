# Issue #603 - Baseline Technique (2026-03-29)

## Objet

Etablir une baseline factuelle pour la remise a plat de la gestion de configuration RooSync avant tout retrait de routes legacy.

## Constat Code (etat actuel)

### 1) Outils exposes dans la famille RooSync (ListTools)

Dans `src/tools/roosync/index.ts`, la liste `roosyncTools` decrit un socle consolide de **22 outils** (version 3.17 documentee dans le fichier).

Points importants:
- `roosync_config` est deja l'outil consolide pour collect/publish/apply/apply_profile.
- `modes-management` est explicitement note comme API interne (pas expose MCP).
- Plusieurs consolidations sont deja en place (CONS-1, CONS-3, CONS-4, CONS-5, CONS-6, CONS-7).

### 2) Handlers encore routes dans registry

Dans `src/tools/registry.ts`, extraction des cases `roosync_*` + `export_config`:
- **40 handlers** routes cote `CallTool`.

Parmi eux, on retrouve encore des routes legacy/depreciees (compat backward):
- config legacy: `roosync_collect_config`, `roosync_publish_config`, `roosync_apply_config`
- decision legacy: `roosync_approve_decision`, `roosync_reject_decision`, `roosync_apply_decision`, `roosync_rollback_decision`, `roosync_get_decision_details`
- messaging legacy: `roosync_send_message`, `roosync_read_inbox`, `roosync_get_message`, `roosync_archive_message`, `roosync_reply_message`
- attachments legacy: `roosync_list_attachments`, `roosync_get_attachment`, `roosync_delete_attachment`
- autres legacy/deprecie: `roosync_sync_event`, `roosync_get_machine_inventory`, `roosync_update_baseline`, `roosync_manage_baseline`

### 3) Tests d'audit qui figent encore le legacy

Dans `src/tools/__tests__/mcp-tools-audit.test.ts`, le bloc `ALL_MCP_TOOLS` inclut encore de nombreux noms legacy, ce qui indique que le retrait ne peut pas etre fait sans migration explicite des assertions et attentes de discoverability/audit.

## Lecture technique

Le systeme est deja partiellement consolide, mais il est en **mode dual-stack**:
- couche consolidee presente et fonctionnelle,
- couche legacy encore routable pour compatibilite.

Le risque n'est pas l'absence de consolidation, mais le **retrait non orchestre** qui casserait:
- compat backward de certains workflows,
- tests d'audit/discoverability,
- eventuels scripts externes qui invoquent encore les anciens noms.

## Plan minimal sans regression (lot suivant)

### Lot A - Cartographie executable
Statut: TERMINE le 2026-03-29.

Preuves:
- Script de cartographie: scripts/audit/export-issue603-tool-inventory.ps1
- Rapport genere: docs/audit/issue-603-tool-inventory-2026-03-29.md
- Resultat actuel: 40 handlers roosync/export, 68 entrees ALL_MCP_TOOLS, ecart 6+6

Actions realisees:
1. Ajouter un tableau source de verite (doc + script) avec colonnes:
   - `tool_name`
   - `status` (active|legacy|deprecated)
   - `replacement`
   - `listtools_exposed` (yes/no)
   - `calltool_routed` (yes/no)
   - `covered_by_tests` (yes/no)
2. Cibler d'abord les familles config/decision/messaging.

### Lot B - Simplification controlee
Statut: PROCHAINE ETAPE.

Preparation d'execution disponible:
- docs/audit/issue-603-lot-b-candidates-2026-03-29.md

1. Conserver en priorite les outils consolides:
   - `roosync_config`, `roosync_decision`, `roosync_decision_info`, `roosync_send`, `roosync_read`, `roosync_manage`, `roosync_attachments`.
2. Marquer explicitement les legacy encore routes comme "backward-compat only" dans un seul endroit (registry + doc).
3. Retirer d'abord les routes legacy sans usage prouve (si preuves d'usage nulles).

### Lot C - Validation
Statut: EN ATTENTE DU LOT B.

1. Build TypeScript.
2. Tests unitaires + tests CI (vitest config CI).
3. Verification discoverability apres retrait.

## Etat onboarding (machine)

Etat de reprise confirme le 2026-03-29:
- Submodule mcps/internal realigne sur le commit attendu par HEAD
- Heartbeat RooSync redemarre
- Outil de recherche rg installe et valide (ripgrep 15.1.0)
- Traces partagees publiees (issue #603 + dashboard workspace)

Etat local restant:
- Fichiers non suivis relies a #603 (baseline + inventory + script)

## Decision Gate avant suppression

Aucune suppression de route legacy sans:
- preuve d'absence d'usage (code + scripts + docs),
- chemin de remplacement explicite,
- tests verts sur config CI.

---

Auteur: Claude Code (myia-po-2025)
Date: 2026-03-29
Contexte: reprise onboarding + relance issue #603
