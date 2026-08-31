# Script de correction des exports DiffDetector
# Ajoute les types et méthode manquants pour RooSyncService

$diffDetectorPath = "mcps/internal/servers/roo-state-manager/src/services/DiffDetector.ts"

Write-Host "🔧 Correction des exports DiffDetector..." -ForegroundColor Cyan

# Lire le fichier actuel
$content = Get-Content $diffDetectorPath -Raw

# Vérifier si les exports existent déjà
if ($content -match "export.*ComparisonReport") {
    Write-Host "✅ Les exports existent déjà" -ForegroundColor Green
    exit 0
}

# Ajouter les types et la méthode à la fin du fichier (avant la dernière accolade)
$newContent = $content -replace '(\}\s*)$', @'

  /**
   * Compare deux inventaires machines (interface RooSync)
   * @param source - Inventaire machine source
   * @param target - Inventaire machine cible
   * @returns Rapport de comparaison avec différences détectées
   */
  public async compareInventories(
    source: MachineInventory,
    target: MachineInventory
  ): Promise<ComparisonReport> {
    const reportId = `comp-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    const startTime = Date.now();

    // Collecter toutes les différences via les méthodes existantes
    const allDifferences: DetectedDifference[] = [];

    // Comparer via baseline (réutilise la logique existante)
    const baselineConfig: BaselineConfig = {
      machineId: source.machineId || 'source',
      version: '1.0',
      createdAt: new Date().toISOString(),
      config: source.config
    };

    const baselineDiffs = await this.compareBaselineWithMachine(baselineConfig, target);

    // Convertir BaselineDifference vers DetectedDifference
    for (const diff of baselineDiffs) {
      allDifferences.push({
        id: `${reportId}-${allDifferences.length}`,
        category: this.mapCategoryToRooSync(diff.category),
        severity: diff.severity as DiffSeverity,
        path: diff.path,
        type: 'modified', // Type simplifié
        description: diff.description,
        source: {
          machineId: source.machineId || 'source',
          value: diff.baselineValue
        },
        target: {
          machineId: target.machineId || 'target',
          value: diff.actualValue
        },
        recommendedAction: diff.recommendedAction
      });
    }

    // Calculer le résumé
    const summary = this.calculateComparisonSummary(allDifferences);
    const executionTime = Date.now() - startTime;

    return {
      reportId,
      sourceMachine: source.machineId || 'source',
      targetMachine: target.machineId || 'target',
      differences: allDifferences,
      summary,
      metadata: {
        comparisonTimestamp: new Date().toISOString(),
        executionTime,
        version: '1.0'
      }
    };
  }

  /**
   * Mappe les catégories baseline vers RooSync
   */
  private mapCategoryToRooSync(category: string): DiffCategory {
    const mapping: Record<string, DiffCategory> = {
      'config': 'roo_config',
      'hardware': 'hardware',
      'software': 'software',
      'system': 'system'
    };
    return mapping[category] || 'roo_config';
  }

  /**
   * Calcule le résumé de comparaison
   */
  private calculateComparisonSummary(differences: DetectedDifference[]): ComparisonSummary {
    const summary: ComparisonSummary = {
      total: differences.length,
      bySeverity: {
        CRITICAL: 0,
        IMPORTANT: 0,
        WARNING: 0,
        INFO: 0
      },
      byCategory: {
        roo_config: 0,
        hardware: 0,
        software: 0,
        system: 0
      }
    };

    for (const diff of differences) {
      summary.bySeverity[diff.severity]++;
      summary.byCategory[diff.category]++;
    }

    return summary;
  }
$1'

# Ajouter les exports de types au début (après les imports)
$newContent = $newContent -replace '(import.*from.*baseline\.js.*;\s*)', @'
$1

/**
 * Types pour l'interface RooSync
 */

// Types de sévérité des différences
export type DiffSeverity = 'CRITICAL' | 'IMPORTANT' | 'WARNING' | 'INFO';

// Types de catégories de différences
export type DiffCategory = 'roo_config' | 'hardware' | 'software' | 'system';

// Structure d'une différence détectée
export interface DetectedDifference {
  id: string;
  category: DiffCategory;
  severity: DiffSeverity;
  path: string;
  type: 'added' | 'removed' | 'modified';
  description: string;
  source: {
    machineId: string;
    value: any;
  };
  target: {
    machineId: string;
    value: any;
  };
  recommendedAction?: string;
  affectedComponents?: string[];
}

// Résumé de comparaison
export interface ComparisonSummary {
  total: number;
  bySeverity: {
    CRITICAL: number;
    IMPORTANT: number;
    WARNING: number;
    INFO: number;
  };
  byCategory: {
    roo_config: number;
    hardware: number;
    software: number;
    system: number;
  };
}

// Rapport de comparaison complet
export interface ComparisonReport {
  reportId: string;
  sourceMachine: string;
  targetMachine: string;
  differences: DetectedDifference[];
  summary: ComparisonSummary;
  metadata: {
    comparisonTimestamp: string;
    executionTime: number;
    version: string;
  };
}

'@

# Écrire le fichier modifié
Set-Content -Path $diffDetectorPath -Value $newContent -Encoding UTF8

Write-Host "✅ Exports et méthode compareInventories ajoutés" -ForegroundColor Green
Write-Host "📝 Fichier modifié: $diffDetectorPath" -ForegroundColor Yellow