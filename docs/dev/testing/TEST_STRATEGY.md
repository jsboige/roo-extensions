# Test Strategy - roo-state-manager

**Derniere mise a jour :** 2026-02-09
**Issue :** #380

---

## Etat Actuel

| Metrique | Valeur |
|----------|--------|
| Fichiers de test | 167 |
| Tests passants | 1969 |
| Tests skippes | 13 |
| Fichiers source (services + tools) | ~179 |
| Couverture estimee | ~70% |

### Commandes

```bash
cd mcps/internal/servers/roo-state-manager

# Tests complets
npx vitest run

# Test unique
npx vitest run path/to/test.ts

# Build check
npx tsc --noEmit
```

**IMPORTANT :** Ne jamais utiliser `npm test` (mode watch interactif bloquant).

---

## Tests Skippes (13)

| Fichier | Skippes | Raison | Fixable ? |
|---------|---------|--------|-----------|
| ConfigSharingService-mcp-filtering.test.ts | 5 | Mocking `applyConfig` trop complexe (5 deps) | Refactoring requis |
| new-task-extraction.test.ts | 5 | Singleton ESM `globalTaskInstructionIndex` | Refactoring requis |
| roosync-workflow.test.ts | 2 | Tests manuels E2E (modifient l'etat reel) | Intentionnel |
| orphan-robustness.test.ts | 1 | Mock FS insuffisant pour `doReconstruction` | memfs ou fixtures |

### Pour desactiver un test

- `describe.skip` / `it.skip` - Test non reintegrable (documenter la raison)
- E2E manuels - Garder skippes, executer manuellement en environnement isole

### Pour corriger les tests skippes

**ConfigSharingService (5) :**
- Refactorer `applyConfig` pour injecter les dependances (InventoryService, ConfigNormalizationService)
- Alternative : utiliser `memfs` pour un filesystem virtuel

**NewTask extraction (5) :**
- Refactorer `task-instruction-index.js` pour ne plus utiliser de singleton
- Voir : https://github.com/vitest-dev/vitest/issues/4043

---

## Couverture par Module

### Modules bien testes (>80%)

| Module | Fichiers | Tests | Couverture |
|--------|----------|-------|------------|
| Services/Baseline | 6 | 6 | 100% |
| Services/Config | 5 | 5 | 100% |
| Services/RooSync | 13 | 11 | 85% |
| Services/TaskIndexer | 5 | 5 | 100% |
| Services/TraceSummary | 5 | 5 | 100% |
| Tools/Export | 8 | 8 | 100% |
| Tools/RooSync | ~70 | ~65 | ~93% |
| Tools/Storage | 3 | 3 | 100% |

### Angles morts critiques (0-25%)

| Module | Fichiers | Tests | Couverture | Risque |
|--------|----------|-------|------------|--------|
| **Services/Reporting** | 11 | 1 | ~10% | Corrige 2026-02-09 (6 strategies + factory) |
| **Tools/Diagnostic** | 2 | 2 | 100% | Corrige 2026-02-08 |
| **Tools/Repair** | 2 | 2 | 100% | Corrige 2026-02-08/09 |
| **Tools/Cache** | 1 | 0 | 0% | CRITIQUE |
| **Services/Core** | 20 | 8 | 40% | Corrige 2026-02-09 (+ServiceRegistry, +AssistantMessageParser) |
| **Tools/Conversation** | 4 | 1 | 25% | ELEVE |
| **Tools/Summary** | 4 | 1 | 25% | ELEVE |
| **Tools/Indexing** | 4 | 1 | 25% | MOYEN |

---

## Services Sans Tests - Priorites

### Priorite 1 : CRITIQUE

Services utilises en production sans aucun test :

1. ~~**ServiceRegistry.ts**~~ - ✅ 31 tests (2026-02-09)
2. **InventoryCollector.ts** (~600 lignes) - Collecte inventaire via PowerShell
3. ~~**AssistantMessageParser.ts**~~ - ✅ 27 tests (2026-02-09)
4. ~~**Reporting strategies**~~ - ✅ 37 tests (6 strategies + factory, 2026-02-09)

### Priorite 2 : ELEVE

5. **TwoLevelProcessingOrchestrator.ts** - Fast (<5s) + background processing
6. **background-services.ts** - Orchestration jobs asynchrones
7. **task-summarizer.ts** - Summarization LLM
8. **synthesis/LLMService.ts** - Abstraction API LLM
9. **conversation/debug-analyze.tool.ts** - Debug analysis
10. **summary/generate-trace-summary.tool.ts** - Trace summaries

### Priorite 3 : MOYEN

11. **state-manager.service.ts** - Gestion d'etat central
12. **skeleton-cache.service.ts** - Cache conversations
13. **CacheAntiLeakManager.ts** - Prevention fuites memoire
14. **SmartCleanerService.ts** - Nettoyage cache

---

## Patterns de Test

### Pattern ESM Mock (vi.hoisted)

**Obligatoire** pour les dependances transitives en ESM :

```typescript
// 1. Creer le mock avec vi.hoisted (avant tout import)
const { mockFn } = vi.hoisted(() => ({
    mockFn: vi.fn()
}));

// 2. Appliquer le mock au module
vi.mock('../../services/MyService.js', () => ({
    MyService: class {
        myMethod = mockFn;
    }
}));

// 3. Re-initialiser dans beforeEach (car mockReset: true en config globale)
beforeEach(() => {
    vi.clearAllMocks();
    mockFn.mockResolvedValue({ success: true });
});
```

**Erreur courante :** Utiliser `vi.fn().mockResolvedValue(...)` dans la factory sans `vi.hoisted` -> le mock est perdu apres `clearAllMocks`.

### Pattern Union Type (MCP SDK)

```typescript
// result.content[0].text -> TS2339
// Fix :
const text = (result.content[0] as any).text;

// Ou avec helper :
function getTextContent(result: CallToolResult): string {
    const c = result.content[0];
    return c && c.type === 'text' ? c.text : '';
}
```

### Pattern ConversationSkeleton Mock

```typescript
// Utiliser sequence: [] PAS turns: []
const mock: ConversationSkeleton = {
    taskId: 'test-id',
    sequence: [],  // MessageSkeleton | ActionMetadata
    metadata: { ... }
};
```

### Mock Global os

Le setup global (`jest.setup.js`) mock `os` avec des valeurs limitees.
Pour les tests qui ont besoin du vrai `os` :

```typescript
vi.unmock('os');
```

---

## Tests E2E

### Etat actuel

- 13 fichiers de tests E2E
- 2 tests manuels (skippes par defaut) dans `roosync-workflow.test.ts`
- ESM issue : certains tests E2E desactives

### Scenarios couverts

- Workflows RooSync (conflits, erreurs, multi-machine)
- Recherche semantique
- Navigation de taches
- Workflows de synthese

### Scenarios manquants

- Workflow complet de collecte d'inventaire
- Reparation BOM end-to-end
- Generation de rapports
- Processing en arriere-plan (background services)

---

## Scripts de Validation PowerShell

| Script | Description | Localisation |
|--------|-------------|-------------|
| count-tools.ps1 | Comptage ListTools/CallTool/Wrapper | scripts/validation/ |
| validate-cons.ps1 | Validation consolidations CONS-X | scripts/validation/ |
| validate-mcp-live.ps1 | Validation E2E via JSON-RPC (a creer) | scripts/validation/ |

---

## Recommandations

### Court terme (cette session)

- [x] Corriger les 2 tests skippes export-data
- [x] Ajouter tests diagnose_env (8 tests)
- [x] Ajouter tests analyze_problems (10 tests)
- [x] Ajouter tests diagnose-conversation-bom (10 tests)
- [x] Documenter la strategie (ce fichier)

### Moyen terme (prochaines sessions)

- [x] Ajouter tests pour ServiceRegistry (DI container) - 31 tests (2026-02-09)
- [x] Ajouter tests pour AssistantMessageParser - 27 tests (2026-02-09)
- [ ] Ajouter tests pour InventoryCollector
- [x] Creer un test suite partage pour les 9 reporting strategies - 37 tests (2026-02-09)
- [ ] Fixer les 5 tests ConfigSharingService (refactoring applyConfig)

### Long terme

- [ ] Fixer les 5 tests NewTask extraction (refactoring singleton)
- [ ] Migrer le test orphan-robustness vers memfs
- [ ] Creer le script validate-mcp-live.ps1 (E2E JSON-RPC)
- [ ] Atteindre 80% de couverture globale

---

## Historique des changements

| Date | Tests avant | Tests apres | Delta | Details |
|------|-------------|-------------|-------|---------|
| 2026-02-08 | 1829 pass / 15 skip | 1859 pass / 13 skip | +30 / -2 | Fix export-data, +diagnose_env, +analyze_problems, +diagnose-conversation-bom |
| 2026-02-09 | 1859 pass / 13 skip | 1969 pass / 13 skip | +110 / 0 | +ServiceRegistry(31), +AssistantMessageParser(27), +reporting-strategies(37), +coordinateur(15) |
