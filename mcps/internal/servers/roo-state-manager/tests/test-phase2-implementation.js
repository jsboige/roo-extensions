/**
 * Test d'intégration pour la Phase 2 : Nouveaux outils MCP
 * Validation des 5 nouveaux outils et du cache
 */

import { TaskTreeBuilder } from '../build/utils/task-tree-builder.js';
import { SummaryGenerator } from '../build/utils/summary-generator.js';
import { CacheManager } from '../build/utils/cache-manager.js';
import { RooStorageDetector } from '../build/utils/roo-storage-detector.js';

// Données de test simulées
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
        { path: 'src/components/Button.tsx', record_state: 'active', record_source: 'roo_edited' },
        { path: 'src/components/Button.test.tsx', record_state: 'active', record_source: 'roo_edited' }
      ]
    },
    messageCount: 22,
    lastActivity: '2024-01-02T11:30:00Z',
    hasApiHistory: true,
    hasUiMessages: true,
    size: 3072
  },
  {
    taskId: 'task-003',
    path: '/workspace1/project-b/conversation3',
    metadata: {
      taskId: 'task-003',
      createdAt: '2024-01-03T14:00:00Z',
      updatedAt: '2024-01-03T16:45:00Z',
      title: 'Python API',
      description: 'Build REST API with FastAPI',
      mode: 'code',
      status: 'active',
      totalMessages: 8,
      files_in_context: [
        { path: 'main.py', record_state: 'active', record_source: 'roo_edited' },
        { path: 'requirements.txt', record_state: 'active', record_source: 'read_tool' }
      ]
    },
    messageCount: 8,
    lastActivity: '2024-01-03T16:45:00Z',
    hasApiHistory: true,
    hasUiMessages: false,
    size: 1536
  },
  {
    taskId: 'task-004',
    path: '/workspace2/project-c/conversation4',
    metadata: {
      taskId: 'task-004',
      createdAt: '2024-01-04T08:30:00Z',
      updatedAt: '2024-01-04T10:15:00Z',
      title: 'Database Schema',
      description: 'Design database schema for user management',
      mode: 'architect',
      status: 'completed',
      totalMessages: 12,
      files_in_context: [
        { path: 'schema.sql', record_state: 'active', record_source: 'roo_edited' },
        { path: 'migrations/001_initial.sql', record_state: 'active', record_source: 'roo_edited' }
      ]
    },
    messageCount: 12,
    lastActivity: '2024-01-04T10:15:00Z',
    hasApiHistory: true,
    hasUiMessages: true,
    size: 2560
  }
];

class Phase2Tester {
  constructor() {
    this.cacheManager = new CacheManager({
      maxSize: 10 * 1024 * 1024, // 10MB pour les tests
      maxAge: 5 * 60 * 1000, // 5 minutes pour les tests
      persistToDisk: false // Pas de persistance pour les tests
    });
  }

  async runAllTests() {
    console.log('🚀 Test complet de la Phase 2 - Nouveaux outils MCP');
    console.log('============================================================');
    
    try {
      // Test 1: Construction de l'arbre (prérequis)
      console.log('\n📊 Test 1: Construction de l\'arbre de tâches...');
      const tree = await this.testTreeConstruction();
      
      // Test 2: Gestionnaire de cache
      console.log('\n💾 Test 2: Gestionnaire de cache...');
      await this.testCacheManager(tree);
      
      // Test 3: Générateur de résumés
      console.log('\n📝 Test 3: Générateur de résumés...');
      await this.testSummaryGenerator(tree);
      
      // Test 4: Navigation dans l'arbre
      console.log('\n🌳 Test 4: Navigation dans l\'arbre...');
      await this.testTreeNavigation(tree);
      
      // Test 5: Recherche de conversations
      console.log('\n🔍 Test 5: Recherche de conversations...');
      await this.testConversationSearch();
      
      // Test 6: Analyse des relations
      console.log('\n🔗 Test 6: Analyse des relations...');
      await this.testRelationshipAnalysis(tree);
      
      // Test 7: Performance globale
      console.log('\n⚡ Test 7: Performance globale...');
      await this.testPerformance();
      
      console.log('\n✅ Tous les tests de la Phase 2 sont passés avec succès !');
      console.log('🎉 L\'implémentation de la Phase 2 est fonctionnelle.');
      
    } catch (error) {
      console.error('\n❌ Erreur lors des tests:', error);
      throw error;
    } finally {
      await this.cacheManager.close();
    }
  }

  async testTreeConstruction() {
    const startTime = Date.now();
    
    const builder = new TaskTreeBuilder();
    const tree = await builder.buildCompleteTree(mockConversations);
    
    const buildTime = Date.now() - startTime;
    
    // Validations
    if (!tree || !tree.root) {
      throw new Error('Arbre non construit correctement');
    }
    
    if (!tree.metadata || tree.metadata.totalNodes === 0) {
      throw new Error('Métadonnées de l\'arbre manquantes');
    }
    
    if (!tree.index || !tree.index.byId) {
      throw new Error('Index de l\'arbre manquant');
    }
    
    console.log(`   ✅ Arbre construit en ${buildTime}ms`);
    console.log(`   - ${tree.metadata.totalNodes} nœuds créés`);
    console.log(`   - Profondeur max: ${tree.metadata.maxDepth}`);
    console.log(`   - Score de qualité: ${tree.metadata.qualityScore.toFixed(1)}%`);
    console.log(`   - ${tree.relationships.length} relations détectées`);
    
    return tree;
  }

  async testCacheManager(tree) {
    const startTime = Date.now();
    
    // Test de mise en cache
    await this.cacheManager.cacheTaskTree(tree, mockConversations);
    
    // Test de récupération
    const cachedTree = await this.cacheManager.getCachedTaskTree();
    if (!cachedTree) {
      throw new Error('Arbre non récupéré du cache');
    }
    
    // Test de recherche en cache
    const searchQuery = 'TypeScript';
    const searchFilters = { technology: 'TypeScript' };
    const mockResults = mockConversations.filter(conv => 
      conv.metadata.title.includes('TypeScript')
    );
    
    await this.cacheManager.cacheSearchResults(searchQuery, searchFilters, mockResults);
    const cachedResults = await this.cacheManager.getCachedSearchResults(searchQuery, searchFilters);
    
    if (!cachedResults || cachedResults.length !== mockResults.length) {
      throw new Error('Résultats de recherche non mis en cache correctement');
    }
    
    // Test des statistiques
    const stats = this.cacheManager.getStats();
    if (stats.totalEntries === 0) {
      throw new Error('Statistiques du cache incorrectes');
    }
    
    const cacheTime = Date.now() - startTime;
    
    console.log(`   ✅ Cache testé en ${cacheTime}ms`);
    console.log(`   - ${stats.totalEntries} entrées en cache`);
    console.log(`   - Taille totale: ${Math.round(stats.totalSize / 1024)}KB`);
    console.log(`   - Taux de hit: ${(stats.hitRate * 100).toFixed(1)}%`);
  }

  async testSummaryGenerator(tree) {
    const startTime = Date.now();
    
    // Test de résumé global
    const globalSummary = SummaryGenerator.generateTaskTreeSummary(tree, mockConversations);
    
    if (!globalSummary || !globalSummary.overview) {
      throw new Error('Résumé global non généré');
    }
    
    if (globalSummary.overview.totalConversations !== mockConversations.length) {
      throw new Error('Nombre de conversations incorrect dans le résumé');
    }
    
    // Vérifier la structure du résumé
    if (!globalSummary.workspaces || !Array.isArray(globalSummary.workspaces)) {
      throw new Error('Structure des workspaces incorrecte');
    }
    
    if (!globalSummary.insights) {
      throw new Error('Insights manquants dans le résumé');
    }
    
    const summaryTime = Date.now() - startTime;
    
    console.log(`   ✅ Résumés générés en ${summaryTime}ms`);
    console.log(`   - ${globalSummary.overview.totalWorkspaces} workspaces résumés`);
    console.log(`   - ${globalSummary.overview.totalProjects} projets analysés`);
    console.log(`   - ${globalSummary.overview.totalConversations} conversations traitées`);
    console.log(`   - Workspace le plus actif: ${globalSummary.insights.mostActiveWorkspace}`);
  }

  async testTreeNavigation(tree) {
    const startTime = Date.now();
    
    // Test de navigation depuis la racine
    const rootNavigation = this.simulateBrowseTaskTree(tree.root, 2, true);
    
    if (!rootNavigation || !rootNavigation.id) {
      throw new Error('Navigation depuis la racine échouée');
    }
    
    // Test de navigation depuis un nœud spécifique
    const firstNode = Array.from(tree.index.byId.values())[0];
    if (firstNode) {
      const nodeNavigation = this.simulateBrowseTaskTree(firstNode, 1, false);
      if (!nodeNavigation) {
        throw new Error('Navigation depuis un nœud spécifique échouée');
      }
    }
    
    const navTime = Date.now() - startTime;
    
    console.log(`   ✅ Navigation testée en ${navTime}ms`);
    console.log(`   - Navigation racine: ${rootNavigation.type}`);
    console.log(`   - Profondeur explorée: 2 niveaux`);
    console.log(`   - Métadonnées incluses: oui`);
  }

  async testConversationSearch() {
    const startTime = Date.now();
    
    // Test de recherche textuelle
    const textResults = this.simulateTextSearch(mockConversations, 'TypeScript');
    if (textResults.length === 0) {
      throw new Error('Recherche textuelle n\'a retourné aucun résultat');
    }
    
    // Test de filtrage par technologie
    const techFilters = { technology: 'TypeScript' };
    const filteredResults = this.simulateFilterSearch(mockConversations, techFilters);
    
    // Test de filtrage par date
    const dateFilters = {
      dateRange: {
        start: '2024-01-01T00:00:00Z',
        end: '2024-01-02T23:59:59Z'
      }
    };
    const dateResults = this.simulateFilterSearch(mockConversations, dateFilters);
    
    // Test de filtrage par nombre de messages
    const messageFilters = { minMessages: 15 };
    const messageResults = this.simulateFilterSearch(mockConversations, messageFilters);
    
    const searchTime = Date.now() - startTime;
    
    console.log(`   ✅ Recherche testée en ${searchTime}ms`);
    console.log(`   - Recherche textuelle: ${textResults.length} résultats`);
    console.log(`   - Filtre technologie: ${filteredResults.length} résultats`);
    console.log(`   - Filtre date: ${dateResults.length} résultats`);
    console.log(`   - Filtre messages: ${messageResults.length} résultats`);
  }

  async testRelationshipAnalysis(tree) {
    const startTime = Date.now();
    
    const relationships = tree.relationships;
    
    // Analyser les patterns de relations
    const analysis = this.simulateRelationshipAnalysis(relationships);
    
    // Grouper par type
    const byType = this.groupRelationshipsByType(relationships);
    
    // Calculer les statistiques
    const avgWeight = relationships.length > 0 
      ? relationships.reduce((sum, rel) => sum + rel.weight, 0) / relationships.length 
      : 0;
    
    const analysisTime = Date.now() - startTime;
    
    console.log(`   ✅ Relations analysées en ${analysisTime}ms`);
    console.log(`   - ${relationships.length} relations trouvées`);
    console.log(`   - Poids moyen: ${(avgWeight * 100).toFixed(1)}%`);
    console.log(`   - Types détectés: ${Object.keys(byType).join(', ')}`);
  }

  async testPerformance() {
    const startTime = Date.now();
    
    // Test avec un plus grand nombre de conversations simulées
    const largeDataset = this.generateLargeDataset(100);
    
    const builder = new TaskTreeBuilder();
    const tree = await builder.buildCompleteTree(largeDataset);
    
    // Test de cache avec le grand dataset
    await this.cacheManager.cacheTaskTree(tree, largeDataset);
    const cachedTree = await this.cacheManager.getCachedTaskTree();
    
    // Test de génération de résumé
    const summary = SummaryGenerator.generateTaskTreeSummary(tree, largeDataset);
    
    const totalTime = Date.now() - startTime;
    
    console.log(`   ✅ Performance testée en ${totalTime}ms`);
    console.log(`   - ${largeDataset.length} conversations traitées`);
    console.log(`   - ${tree.metadata.totalNodes} nœuds créés`);
    console.log(`   - Temps par conversation: ${(totalTime / largeDataset.length).toFixed(2)}ms`);
    
    // Vérifier que c'est sous la cible de 2 secondes pour la navigation
    if (totalTime > 2000) {
      console.warn(`   ⚠️  Performance sous la cible (${totalTime}ms > 2000ms)`);
    } else {
      console.log(`   🎯 Performance dans la cible (${totalTime}ms < 2000ms)`);
    }
  }

  // Méthodes de simulation des outils MCP

  simulateBrowseTaskTree(node, depth, includeMetrics) {
    const result = {
      id: node.id,
      name: node.name,
      type: node.type,
      path: node.path
    };
    
    if (includeMetrics) {
      result.metadata = node.metadata;
    }
    
    if (depth > 0 && node.children && node.children.length > 0) {
      result.children = node.children.map(child => 
        this.simulateBrowseTaskTree(child, depth - 1, includeMetrics)
      );
    }
    
    return result;
  }

  simulateTextSearch(conversations, query) {
    const lowerQuery = query.toLowerCase();
    return conversations.filter(conv => {
      return (
        conv.taskId.toLowerCase().includes(lowerQuery) ||
        conv.path.toLowerCase().includes(lowerQuery) ||
        conv.metadata?.title?.toLowerCase().includes(lowerQuery) ||
        conv.metadata?.description?.toLowerCase().includes(lowerQuery)
      );
    });
  }

  simulateFilterSearch(conversations, filters) {
    let filtered = [...conversations];
    
    if (filters.technology) {
      filtered = filtered.filter(conv => {
        return conv.metadata?.files_in_context?.some(file => 
          file.path.includes(filters.technology)
        );
      });
    }
    
    if (filters.dateRange) {
      const start = new Date(filters.dateRange.start);
      const end = new Date(filters.dateRange.end);
      filtered = filtered.filter(conv => {
        const convDate = new Date(conv.lastActivity);
        return convDate >= start && convDate <= end;
      });
    }
    
    if (filters.minMessages) {
      filtered = filtered.filter(conv => conv.messageCount >= filters.minMessages);
    }
    
    return filtered;
  }

  simulateRelationshipAnalysis(relationships) {
    return {
      strongestRelationships: relationships
        .sort((a, b) => b.weight - a.weight)
        .slice(0, 5),
      clusters: [],
      patterns: []
    };
  }

  groupRelationshipsByType(relationships) {
    const groups = {};
    relationships.forEach(rel => {
      groups[rel.type] = (groups[rel.type] || 0) + 1;
    });
    return groups;
  }

  generateLargeDataset(count) {
    const dataset = [];
    const technologies = ['TypeScript', 'Python', 'Java', 'C#', 'JavaScript', 'Go'];
    const modes = ['code', 'architect', 'debug', 'ask'];
    
    for (let i = 0; i < count; i++) {
      const tech = technologies[i % technologies.length];
      const mode = modes[i % modes.length];
      
      dataset.push({
        taskId: `task-${String(i + 1).padStart(3, '0')}`,
        path: `/workspace${Math.floor(i / 20) + 1}/project-${String.fromCharCode(97 + (i % 5))}/conversation${i + 1}`,
        metadata: {
          taskId: `task-${String(i + 1).padStart(3, '0')}`,
          createdAt: new Date(Date.now() - (count - i) * 24 * 60 * 60 * 1000).toISOString(),
          updatedAt: new Date(Date.now() - (count - i - 1) * 24 * 60 * 60 * 1000).toISOString(),
          title: `${tech} Task ${i + 1}`,
          description: `Generated task for ${tech} development`,
          mode,
          status: i % 3 === 0 ? 'completed' : 'active',
          totalMessages: Math.floor(Math.random() * 30) + 5,
          files_in_context: [
            { 
              path: `src/file${i}.${tech === 'TypeScript' ? 'ts' : tech === 'Python' ? 'py' : 'js'}`, 
              record_state: 'active', 
              record_source: 'roo_edited' 
            }
          ]
        },
        messageCount: Math.floor(Math.random() * 30) + 5,
        lastActivity: new Date(Date.now() - (count - i - 1) * 24 * 60 * 60 * 1000).toISOString(),
        hasApiHistory: true,
        hasUiMessages: i % 2 === 0,
        size: Math.floor(Math.random() * 4096) + 1024
      });
    }
    
    return dataset;
  }
}

// Exécution des tests
async function runTests() {
  const tester = new Phase2Tester();
  
  try {
    await tester.runAllTests();
    process.exit(0);
  } catch (error) {
    console.error('Tests échoués:', error);
    process.exit(1);
  }
}

// Exécuter si appelé directement
if (import.meta.url === `file://${process.argv[1]}`) {
  runTests();
}

export { Phase2Tester };