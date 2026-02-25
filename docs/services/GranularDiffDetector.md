# GranularDiffDetector

**Fichier:** `src/services/GranularDiffDetector.ts`
**Lignes:** 952
**Dernière mise à jour:** 2026-02-25

---

## Résumé

Service de détection de différences granulaire avancé pour comparer deux objets JSON de manière récursive. Supporte la classification automatique par sévérité et catégorie, les règles personnalisables, et l'export multi-formats.

Utilisé principalement par le système RooSync pour comparer les configurations entre machines et détecter les dérives (drift detection).

---

## Méthodes Clés

| Méthode | Paramètres | Retour | Usage |
|---------|------------|--------|-------|
| `compareGranular()` | `source: any, target: any, sourceLabel?: string, targetLabel?: string, options?: GranularDiffOptions` | `Promise<GranularDiffReport>` | Point d'entrée principal - compare deux objets |
| `addCustomRule()` | `rule: GranularDiffRule` | `void` | Ajoute une règle de détection personnalisée |
| `removeCustomRule()` | `name: string` | `boolean` | Supprime une règle par son nom |
| `getCustomRules()` | - | `GranularDiffRule[]` | Liste les règles actives |
| `exportDiff()` | `report: GranularDiffReport, format: 'json' \| 'csv' \| 'html'` | `Promise<string>` | Exporte le rapport |

---

## Types Principaux

### GranularDiffType
```typescript
type GranularDiffType = 'added' | 'removed' | 'modified' | 'moved' | 'copied' | 'unchanged'
```

### GranularDiffSeverity
```typescript
type GranularDiffSeverity = 'CRITICAL' | 'IMPORTANT' | 'WARNING' | 'INFO'
```

### GranularDiffCategory
```typescript
type GranularDiffCategory = 'roo_config' | 'hardware' | 'software' | 'system' | 'nested' | 'array' | 'semantic'
```

### GranularDiffOptions
```typescript
interface GranularDiffOptions {
  includeUnchanged?: boolean;      // Inclure les éléments non modifiés (défaut: false)
  ignoreWhitespace?: boolean;      // Ignorer les espaces (défaut: true)
  ignoreCase?: boolean;            // Ignorer la casse (défaut: false)
  arrayDiffMode?: 'position' | 'identity';  // Mode comparaison tableaux (défaut: identity)
  semanticAnalysis?: boolean;      // Analyse sémantique (défaut: false)
  maxDepth?: number;               // Profondeur max récursion (défaut: 50)
  customRules?: GranularDiffRule[]; // Règles personnalisées
}
```

### GranularDiffReport
```typescript
interface GranularDiffReport {
  reportId: string;
  timestamp: string;
  sourceLabel: string;
  targetLabel: string;
  options: GranularDiffOptions;
  summary: {
    total: number;
    byType: Record<GranularDiffType, number>;
    bySeverity: Record<GranularDiffSeverity, number>;
    byCategory: Record<GranularDiffCategory, number>;
  };
  diffs: GranularDiffResult[];
  performance: {
    executionTime: number;
    nodesCompared: number;
    memoryUsage?: number;
  };
}
```

---

## Dépendances

| Service/Module | Usage |
|----------------|-------|
| `DiffDetector` | Types de base (`DetectedDifference`, `ComparisonReport`) |
| `baseline.ts` | Type `BaselineDifference` |
| `errors.ts` | `StateManagerError` pour les erreurs |

---

## Règles par Défaut

Le service initialise automatiquement des règles pour les chemins critiques :

| Nom | Pattern | Sévérité | Catégorie |
|-----|---------|----------|-----------|
| Critical config changes | `^(config\.(mcp\|server\|critical))` | CRITICAL | roo_config |
| Hardware changes | `^(hardware\.)` | IMPORTANT | hardware |
| Software version changes | `^(software\..*\.version)` | IMPORTANT | software |
| System changes | `^(system\.)` | CRITICAL | system |
| Roo model profile changes | `^(roo\.modelProfile\.activeProfile)` | CRITICAL | roo_config |
| Roo model profile hash | `^(roo\.modelProfile\.profileHash)` | WARNING | roo_config |

---

## Patterns Utilisés

- **Strategy Pattern**: `arrayDiffMode` permet de choisir entre comparaison par position ou par identité
- **Rule Engine**: Système de règles personnalisables avec handlers optionnels
- **Recursive Descent**: Comparaison récursive avec contrôle de profondeur
- **Builder Pattern**: Construction progressive du rapport avec métriques

---

## Limitations

1. **Pas de détection de mouvements complexes**: Le type `moved` est défini mais pas entièrement implémenté
2. **Analyse sémantique limitée**: `semanticAnalysis: true` n'ajoute pas de fonctionnalité actuellement
3. **Pas de streaming**: Les gros objets sont chargés entièrement en mémoire
4. **Pas de parallélisation**: La comparaison est séquentielle

---

## Exemple d'Appel

```typescript
import { GranularDiffDetector } from './services/GranularDiffDetector.js';

const detector = new GranularDiffDetector();

// Ajouter une règle personnalisée
detector.addCustomRule({
  name: 'API key changes',
  path: /^config\.api\.key/,
  severity: 'CRITICAL',
  category: 'system',
  handler: (oldValue, newValue, path) => {
    if (oldValue !== newValue) {
      return {
        id: `api-key-change-${Date.now()}`,
        path,
        type: 'modified',
        severity: 'CRITICAL',
        category: 'system',
        description: `Clé API modifiée`,
        oldValue: '***',
        newValue: '***', // Masquer les valeurs sensibles
      };
    }
    return null;
  }
});

// Comparer deux configurations
const report = await detector.compareGranular(
  configMachineA,
  configMachineB,
  'machine-a',
  'machine-b',
  { ignoreWhitespace: true, maxDepth: 30 }
);

// Consulter les résultats
console.log(`Total différences: ${report.summary.total}`);
console.log(`Critiques: ${report.summary.bySeverity.CRITICAL}`);

// Exporter en HTML
const html = await detector.exportDiff(report, 'html');
```

---

## Tests

- **Localisation:** `src/services/__tests__/GranularDiffDetector.test.ts`
- **Couverture:** Comparaison objets, tableaux, règles personnalisées, export
