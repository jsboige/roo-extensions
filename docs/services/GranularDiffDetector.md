# GranularDiffDetector

**Fichier:** `src/services/GranularDiffDetector.ts`
**Lignes:** 952
**Version:** 1.0.0

---

## Résumé

Service de détection de différences granulaire entre deux objets JSON. Il compare récursivement les nœuds, catégorise les changements par type (added, removed, modified, moved), sévérité (CRITICAL, IMPORTANT, WARNING, INFO) et catégorie (roo_config, hardware, software, system). Supporte les règles personnalisées avec handlers.

---

## Méthodes clés

| Méthode | Paramètres | Retour | Usage |
|---------|------------|--------|-------|
| `compareGranular` | `source, target, sourceLabel?, targetLabel?, options?` | `Promise<GranularDiffReport>` | Comparaison principale |
| `performGranularComparison` | `source, target, currentPath, options` | `Promise<GranularDiffResult[]>` | Comparaison récursive |
| `calculateGranularSummary` | `diffs` | `Summary` | Calcule les statistiques |
| `applyCustomRule` | `rule, oldValue, newValue, path` | `GranularResult \| null` | Applique une règle personnalisée |

---

## Dépendances

- **BaselineDifference** : Types de différences baseline
- **StateManagerError** : Gestion d'erreurs
- **Types internes** : `GranularDiffType`, `GranularDiffSeverity`, `GranularDiffCategory`

---

## Patterns

- **Strategy Pattern** : Règles personnalisées avec handlers
- **Recursive Tree Traversal** : Parcours profondeur avec maxDepth
- **Rule Engine** : Règles priorisées par path (regex)
- **Performance Metrics** : Tracking nodesCompared, executionTime

---

## Limitations

- **MaxDepth=50** par défaut (configurable)
- **Pas de diff sémantique** par défaut (semanticAnalysis=false)
- **Arrays** comparées par position ou identité (pas par contenu)
- **Whitespace ignoré** par défaut (ignoreWhitespace=true)

---

## Exemple d'appel

```typescript
import { GranularDiffDetector } from './services/GranularDiffDetector.js';

const detector = new GranularDiffDetector();

const report = await detector.compareGranular(
  { config: { mcp: { server1: { port: 8080 } } } },
  { config: { mcp: { server1: { port: 9090 } } } },
  'baseline',
  'current',
  {
    includeUnchanged: false,
    ignoreWhitespace: true,
    maxDepth: 50,
    semanticAnalysis: false
  }
);

console.log(report.summary);
// { total: 1, byType: { modified: 1 }, bySeverity: { IMPORTANT: 1 } }
```

---

## Règles par défaut

| Règle | Path Pattern | Sévérité | Catégorie |
|-------|--------------|----------|-----------|
| Critical config changes | `config.(mcp\|server\|critical)` | CRITICAL | roo_config |
| Hardware changes | `hardware.*` | IMPORTANT | hardware |
| Software version changes | `software.*.version` | IMPORTANT | software |
| System changes | `system.*` | CRITICAL | system |
| Roo model profile | `roo.modelProfile.activeProfile` | CRITICAL | roo_config |

---

## Types

```typescript
type GranularDiffType = 'added' | 'removed' | 'modified' | 'moved' | 'copied' | 'unchanged';
type GranularDiffSeverity = 'CRITICAL' | 'IMPORTANT' | 'WARNING' | 'INFO';
type GranularDiffCategory = 'roo_config' | 'hardware' | 'software' | 'system' | 'nested' | 'array' | 'semantic';
```
