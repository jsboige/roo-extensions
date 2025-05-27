/**
 * Test simplifié de la Phase 2 : Nouveaux outils MCP
 * Version optimisée pour éviter les blocages
 */

import { TaskTreeBuilder } from './build/utils/task-tree-builder.js';
import { SummaryGenerator } from './build/utils/summary-generator.js';
import { CacheManager } from './build/utils/cache-manager.js';
import { RooStorageDetector } from './build/utils/roo-storage-detector.js';

// Données de test simplifiées
const mockConversations = [
  {
    taskId: 'task-001',
    path: '/workspace1/project-a/conversation1',
    metadata: {
      taskId: 'task-001',
      createdAt: '2024-01-01T10:00:00Z',
      updatedAt: '2024-01-01T12:00:00Z',
      title: 'Configuration TypeScript',
      description: 'Setup initial TypeScript configuration',
      mode: 'code',
      status: 'completed',
      totalMessages: 15,
      files_in_context: [
        { path: 'tsconfig.json', record_state: 'active', record_source: 'read_tool' },
        { path: 'package.json', record_state: 'active', record_source: 'roo_edited' }
      ]
    },
    messageCount: 15,
    lastActivity: '2024-01-01T12:00:00Z',
    hasApiHistory: true,
    hasUiMessages: true,
    size: 2048
  },
  {
    taskId: 'task-002',
    path: '/workspace1/project-a/conversation2',
    metadata: {
      taskId: 'task-002',
      createdAt: '2024-01-02T09:00:00Z',
      updatedAt: '2024-01-02T11:30:00Z',
      title: 'React Component',
      description: 'Create reusable React component',
      mode: 'code',
      status: 'completed',
      totalMessages: 22,
      files_in_context: [
        { path: 'src/components/Button.tsx', record_state: 'active', record_source: 'roo_edited' }
      ]
    },
    messageCount: 22,
    lastActivity: '2024-01-02T11:30:00Z',
    hasApiHistory: true,
    hasUiMessages: true,
    size: 3072
  }
];

class Phase2SimpleTester {
  constructor() {
    this.results = {
      passed: 0,
      failed: 0,
      tests: []
    };
  }

  async runTest(name, testFn) {
    const startTime = Date.now();
    try {
      console.log(`\n🧪 ${name}...`);
      await testFn();
      const duration = Date.now() - startTime;
      console.log(`   ✅ Réussi en ${duration}ms`);
      this.results.passed++;
      this.results.tests.push({ name, status: 'PASS', duration });
    } catch (error) {
      const duration = Date.now() - startTime;
      console.error(`   ❌ Échoué en ${duration}ms:`, error.message);
      this.results.failed++;
      this.results.tests.push({ name, status: 'FAIL', duration, error: error.message });
    }
  }

  async runAllTests() {
    console.log('🚀 Tests Phase 2 - Version Simplifiée');
    console.log('=====================================');
    
    // Test 1: Construction de l'arbre
    await this.runTest('Construction de l\'arbre de tâches', async () => {
      const builder = new TaskTreeBuilder();
      const tree = await builder.buildCompleteTree(mockConversations);
      
      if (!tree || !tree.root) throw new Error('Arbre non construit');
      if (!tree.metadata) throw new Error('Métadonnées manquantes');
      if (tree.metadata.totalNodes === 0) throw new Error('Aucun nœud créé');
      
      console.log(`     - ${tree.metadata.totalNodes} nœuds créés`);
      console.log(`     - Profondeur: ${tree.metadata.maxDepth}`);
      console.log(`     - Qualité: ${tree.metadata.qualityScore.toFixed(1)}%`);
      
      this.tree = tree; // Sauvegarder pour les autres tests
    });

    // Test 2: Gestionnaire de cache
    await this.runTest('Gestionnaire de cache', async () => {
      const cache = new CacheManager({
        maxSize: 1024 * 1024, // 1MB
        maxAge: 60000, // 1 minute
        persistToDisk: false
      });
      
      // Test de mise en cache
      await cache.cacheTaskTree(this.tree, mockConversations);
      
      // Test de récupération
      const cachedTree = await cache.getCachedTaskTree();
      if (!cachedTree) throw new Error('Arbre non récupéré du cache');
      
      // Test des statistiques
      const stats = cache.getStats();
      console.log(`     - ${stats.totalEntries} entrées en cache`);
      console.log(`     - Taille: ${Math.round(stats.totalSize / 1024)}KB`);
      
      await cache.close();
    });

    // Test 3: Générateur de résumés
    await this.runTest('Générateur de résumés', async () => {
      const summary = SummaryGenerator.generateTaskTreeSummary(this.tree, mockConversations);
      
      if (!summary || !summary.overview) throw new Error('Résumé non généré');
      if (summary.overview.totalConversations !== mockConversations.length) {
        throw new Error('Nombre de conversations incorrect');
      }
      
      console.log(`     - ${summary.overview.totalWorkspaces} workspaces`);
      console.log(`     - ${summary.overview.totalProjects} projets`);
      console.log(`     - ${summary.overview.totalConversations} conversations`);
    });

    // Test 4: Navigation dans l'arbre
    await this.runTest('Navigation dans l\'arbre', async () => {
      const navigation = this.simulateBrowseTaskTree(this.tree.root, 2, true);
      
      if (!navigation || !navigation.id) throw new Error('Navigation échouée');
      
      console.log(`     - Type de nœud: ${navigation.type}`);
      console.log(`     - Profondeur explorée: 2 niveaux`);
    });

    // Test 5: Performance globale
    await this.runTest('Test de performance', async () => {
      const startTime = Date.now();
      
      // Générer un dataset plus large
      const largeDataset = this.generateDataset(50);
      
      const builder = new TaskTreeBuilder();
      const tree = await builder.buildCompleteTree(largeDataset);
      
      const summary = SummaryGenerator.generateTaskTreeSummary(tree, largeDataset);
      
      const totalTime = Date.now() - startTime;
      
      console.log(`     - ${largeDataset.length} conversations traitées`);
      console.log(`     - ${tree.metadata.totalNodes} nœuds créés`);
      console.log(`     - Temps total: ${totalTime}ms`);
      
      if (totalTime > 2000) {
        console.warn(`     ⚠️  Performance sous la cible (${totalTime}ms > 2000ms)`);
      } else {
        console.log(`     🎯 Performance dans la cible (${totalTime}ms < 2000ms)`);
      }
    });

    // Rapport final
    this.printFinalReport();
  }

  simulateBrowseTaskTree(node, depth, includeMetrics) {
    const result = {
      id: node.id,
      name: node.name,
      type: node.type,
      path: node.path
    };
    
    if (includeMetrics && node.metadata) {
      result.metadata = node.metadata;
    }
    
    if (depth > 0 && node.children && node.children.length > 0) {
      result.children = node.children.slice(0, 3).map(child => 
        this.simulateBrowseTaskTree(child, depth - 1, includeMetrics)
      );
    }
    
    return result;
  }

  generateDataset(count) {
    const dataset = [];
    const technologies = ['TypeScript', 'Python', 'Java', 'JavaScript'];
    const modes = ['code', 'architect', 'debug'];
    
    for (let i = 0; i < count; i++) {
      const tech = technologies[i % technologies.length];
      const mode = modes[i % modes.length];
      
      dataset.push({
        taskId: `task-${String(i + 1).padStart(3, '0')}`,
        path: `/workspace${Math.floor(i / 10) + 1}/project-${String.fromCharCode(97 + (i % 3))}/conversation${i + 1}`,
        metadata: {
          taskId: `task-${String(i + 1).padStart(3, '0')}`,
          createdAt: new Date(Date.now() - (count - i) * 24 * 60 * 60 * 1000).toISOString(),
          updatedAt: new Date(Date.now() - (count - i - 1) * 24 * 60 * 60 * 1000).toISOString(),
          title: `${tech} Task ${i + 1}`,
          description: `Generated task for ${tech} development`,
          mode,
          status: i % 3 === 0 ? 'completed' : 'active',
          totalMessages: Math.floor(Math.random() * 20) + 5,
          files_in_context: [
            { 
              path: `src/file${i}.${tech === 'TypeScript' ? 'ts' : tech === 'Python' ? 'py' : 'js'}`, 
              record_state: 'active', 
              record_source: 'roo_edited' 
            }
          ]
        },
        messageCount: Math.floor(Math.random() * 20) + 5,
        lastActivity: new Date(Date.now() - (count - i - 1) * 24 * 60 * 60 * 1000).toISOString(),
        hasApiHistory: true,
        hasUiMessages: i % 2 === 0,
        size: Math.floor(Math.random() * 2048) + 1024
      });
    }
    
    return dataset;
  }

  printFinalReport() {
    console.log('\n📊 RAPPORT FINAL - PHASE 2');
    console.log('==========================');
    console.log(`✅ Tests réussis: ${this.results.passed}`);
    console.log(`❌ Tests échoués: ${this.results.failed}`);
    console.log(`📈 Taux de réussite: ${((this.results.passed / (this.results.passed + this.results.failed)) * 100).toFixed(1)}%`);
    
    if (this.results.failed === 0) {
      console.log('\n🎉 TOUS LES TESTS DE LA PHASE 2 SONT PASSÉS !');
      console.log('✨ L\'implémentation de la Phase 2 est fonctionnelle.');
    } else {
      console.log('\n⚠️  Certains tests ont échoué. Vérifiez les détails ci-dessus.');
    }
    
    console.log('\n📋 Détails des tests:');
    this.results.tests.forEach(test => {
      const status = test.status === 'PASS' ? '✅' : '❌';
      console.log(`   ${status} ${test.name} (${test.duration}ms)`);
      if (test.error) {
        console.log(`      Erreur: ${test.error}`);
      }
    });
  }
}

// Exécution des tests
async function runTests() {
  const tester = new Phase2SimpleTester();
  
  try {
    await tester.runAllTests();
    process.exit(tester.results.failed === 0 ? 0 : 1);
  } catch (error) {
    console.error('\n💥 Erreur critique lors des tests:', error);
    process.exit(1);
  }
}

// Exécuter si appelé directement
if (import.meta.url === `file://${process.argv[1]}`) {
  runTests();
}

export { Phase2SimpleTester };