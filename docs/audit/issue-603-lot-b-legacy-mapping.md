# Issue #603 - Lot B - Legacy Tool Mapping (2026-04-08)

## Objet

Documenter le mapping exact entre les outils legacy (encore routés) et leur remplaçant consolidé.
Ceci sert de **source de vérité** pour l'exécution de Lot B et valide l'absence de régressions.

## Matrice complète (source registry.ts + tool-definitions.ts)

| Handler Name | Type | Replacement | Consolidation | Status | InListTools | Backward-Compat Only |
|---|---|---|---|---|---|---|
| `roosync_collect_config` | legacy | `roosync_config(action: collect)` | CONS-3 | routed | NO | YES |
| `roosync_publish_config` | legacy | `roosync_config(action: publish)` | CONS-3 | routed | NO | YES |
| `roosync_apply_config` | legacy | `roosync_config(action: apply)` | CONS-3 | routed | NO | YES |
| `roosync_config` | **consolidated** | N/A | CONS-3 | routed | YES | NO |
| `roosync_get_decision_details` | legacy | `roosync_decision_info` | CONS-5 | routed | NO | YES |
| `roosync_approve_decision` | legacy | `roosync_decision(action: approve)` | CONS-5 | routed | NO | YES |
| `roosync_reject_decision` | legacy | `roosync_decision(action: reject)` | CONS-5 | routed | NO | YES |
| `roosync_apply_decision` | legacy | `roosync_decision(action: apply)` | CONS-5 | routed | NO | YES |
| `roosync_rollback_decision` | legacy | `roosync_decision(action: rollback)` | CONS-5 | routed | NO | YES |
| `roosync_decision` | **consolidated** | N/A | CONS-5 | routed | YES | NO |
| `roosync_decision_info` | **consolidated** | N/A | CONS-5 | routed | YES | NO |
| `roosync_update_baseline` | legacy | `roosync_baseline(action: update)` | CONS-2 | routed | NO | YES |
| `roosync_manage_baseline` | legacy | `roosync_baseline(action: manage)` | CONS-2 | routed | NO | YES |
| `roosync_baseline` | **consolidated** | N/A | CONS-2 | routed | YES | NO |
| `roosync_get_machine_inventory` | legacy | `roosync_inventory` | N/A | routed | NO | YES |
| `roosync_inventory` | **consolidated** | N/A | N/A | routed | YES | NO |

## Stratégie Lot B

### Phase 1 : Documentation et marquage (PR 1)
1. Ajouter un **marqueur explicite** dans `registry.ts` pour chaque route legacy :
   ```typescript
   // [BACKWARD-COMPAT ONLY] roosync_collect_config → use roosync_config(action: 'collect')
   case 'roosync_collect_config': {
       // ... handler code ...
   }
   ```

2. Verifier que **TOUS les outils legacy sont absents de `tool-definitions.ts`** :
   - ✅ `roosync_collect_config` → NOT in ListTools
   - ✅ `roosync_publish_config` → NOT in ListTools
   - ✅ `roosync_apply_config` → NOT in ListTools
   - etc.

3. Ajouter une **assertion de test** :
   ```typescript
   describe('Tool Discoverability - Backward Compat', () => {
       test('Legacy tools NOT exposed via ListTools (CallTool only)', () => {
           const legacyTools = [
               'roosync_collect_config',
               'roosync_publish_config',
               // ...
           ];
           legacyTools.forEach(toolName => {
               expect(allToolDefinitions.map(t => t.name)).not.toContain(toolName);
           });
       });
   });
   ```

### Phase 2 : Retrait conditionnel (Après PR 1 merged)
Si **usage = 0** (grep search + code audit prouve qu'aucun script/doc/MCP ne l'invoque) :
- Retirer le handler du registry
- Update tests
- Merge PR

Si **usage > 0** : conserver même après marquage (backward-compat indefinitely)

### Phase 3 : Client migration guide
Mettre à jour `.claude/CLAUDE.md` et `.roo/CLAUDE.md` avec:
- Liste des outils deprecated (marqués)
- Chemin de migration pour chaque agent

## Fichiers à modifier (Lot B PR)

| Fichier | Modifications |
|---|---|
| `src/tools/registry.ts` | Ajouter marqueurs `[BACKWARD-COMPAT ONLY]` aux cases legacy |
| `src/tools/__tests__/tool-discoverability.test.ts` | Ajouter assertion "legacy not in ListTools" |
| `docs/audit/issue-603-lot-b-legacy-mapping.md` | THIS FILE — source de vérité |

## Validation gate avant merge

- [ ] TypeScript build OK
- [ ] `npm test` (all tests) OK
- [ ] `npm run test:ci` (CI config) OK
- [ ] `grep -r "roosync_collect_config\|roosync_publish_config" scripts/` → 0 results
- [ ] All consolidated tools still in ListTools

## Notes

- **Retrait destructif = JAMAIS** sans preuve d'absence d'usage
- **Backward-compat = conservé indefiniment** tant qu'on ne prouve pas absence d'usage
- **Source de vérité = ce document** jusqu'à fermeture #603 Lot B
