# Règles de Validation - Roo Code

## CHECKLIST DE VALIDATION TECHNIQUE OBLIGATOIRE

⚠️ **NOUVELLE RÈGLE (2026-02-01) - Suite erreurs CONS-3/CONS-4**

Pour **TOUTE** tâche de consolidation, refactoring, ou modification significative, tu DOIS suivre cette checklist :

### Avant de Commencer

- [ ] **Compter** : Nombre d'outils/fichiers/modules actuels (état AVANT)
- [ ] **Documenter** : Noter ce décompte dans l'issue GitHub ou dans INTERCOM

### Pendant l'Implémentation

- [ ] **Coder** : Implémenter la modification
- [ ] **Tester** : Build + tous les tests passent (`npx vitest run`)
- [ ] **Vérifier imports/exports** : Aucun export orphelin, aucun import cassé

### Après l'Implémentation (CRITIQUE)

- [ ] **Recompter** : Nombre d'outils/fichiers/modules final (état APRÈS)
- [ ] **Calculer écart** : Écart réel = APRÈS - AVANT
- [ ] **Comparer** : Écart réel DOIT égaler écart annoncé (ex: 4→2 = -2)
- [ ] **SI ÉCART INCORRECT** : Identifier ce qui manque (retrait d'anciens fichiers?)
- [ ] **Retirer deprecated** : Les éléments marqués [DEPRECATED] doivent être RETIRÉS de l'array/exports, pas juste commentés
- [ ] **Mettre à jour array/exports** : Vérifier que roosyncTools, exports, etc. sont corrects

### Documentation Commit

- [ ] **Commit message** : Inclure décompte avant/après (ex: "CONS-3: Config 4→2 (29→24 outils)")
- [ ] **Vérifier** : Le nombre dans le commit message correspond à la réalité Git

### Exemple d'Erreur à Éviter

❌ **MAUVAIS** :
```typescript
// Tu crées le nouvel outil
export { roosyncConfig } from './config.js';

// Mais tu laisses les anciens dans roosyncTools
export const roosyncTools = [
  ...
  collectConfigToolMetadata, // ❌ ENCORE LÀ
  publishConfigToolMetadata, // ❌ ENCORE LÀ
  applyConfigToolMetadata,   // ❌ ENCORE LÀ
  configToolMetadata,        // ✓ Le nouveau
  ...
];
```

Résultat : 29→30 outils (+1) au lieu de 29→27 (-2) ❌

✅ **BON** :
```typescript
// Tu crées le nouvel outil
export { roosyncConfig } from './config.js';

// ET tu retires les 3 anciens de roosyncTools
export const roosyncTools = [
  ...
  // collectConfigToolMetadata,  // RETIRÉ
  // publishConfigToolMetadata,  // RETIRÉ
  // applyConfigToolMetadata,    // RETIRÉ
  configToolMetadata,            // ✓ Le nouveau seul
  ...
];
```

Résultat : 29→27 outils (-2) ✓

### Communication avec Claude

Si tu as un doute sur la validation, **DEMANDE À CLAUDE de vérifier** via INTERCOM :

```markdown
## [2026-02-01 22:00:00] roo → claude-code [ASK]

J'ai terminé CONS-X. Peux-tu vérifier que :
1. Le nombre d'outils est bien passé de X à Y (-Z)
2. Les anciens outils deprecated sont bien retirés de roosyncTools
3. Tous les tests passent

---
```

**Cette checklist est OBLIGATOIRE. Claude vérifiera systématiquement ton respect de ces règles.**
