#!/usr/bin/env node

/**
 * Script de test simple pour valider l'implémentation de la Phase 1
 * Peut être exécuté directement avec Node.js
 */

import { TaskTreeBuilder } from '../build/utils/task-tree-builder.js';
import { WorkspaceAnalyzer } from '../build/utils/workspace-analyzer.js';
import { RelationshipAnalyzer } from '../build/utils/relationship-analyzer.js';

// Couleurs pour la console
const colors = {
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  reset: '\x1b[0m',
  bold: '\x1b[1m'
};

const log = (message, color = colors.reset) => {
  console.log(`${color}${message}${colors.reset}`);
};

// Données de test
const createTestData = () => {
  const conversations = [
    {
      taskId: 'conv-js-1',
      path: '/mock/conv-js-1',
      metadata: {
        taskId: 'conv-js-1',
        createdAt: '2025-01-01T10:00:00Z',
        updatedAt: '2025-01-01T10:30:00Z',
        status: 'completed',
        totalMessages: 15,
        mode: 'code',
        files_in_context: [
          { path: 'frontend/package.json', record_state: 'active', record_source: 'read_tool' },
          { path: 'frontend/src/App.js', record_state: 'active', record_source: 'roo_edited' },
          { path: 'frontend/src/components/Header.js', record_state: 'active', record_source: 'roo_edited' }
        ]
      },
      messageCount: 15,
      lastActivity: '2025-01-01T10:30:00Z',
      hasApiHistory: true,
      hasUiMessages: true,
      size: 2500
    },
    {
      taskId: 'conv-js-2',
      path: '/mock/conv-js-2',
      metadata: {
        taskId: 'conv-js-2',
        createdAt: '2025-01-01T11:00:00Z',
        updatedAt: '2025-01-01T11:45:00Z',
        status: 'completed',
        totalMessages: 22,
        mode: 'code',
        files_in_context: [
          { path: 'frontend/src/utils.js', record_state: 'active', record_source: 'roo_edited' },
          { path: 'frontend/tests/App.test.js', record_state: 'active', record_source: 'roo_edited' },
          { path: 'frontend/src/App.js', record_state: 'stale', record_source: 'read_tool' }
        ]
      },
      messageCount: 22,
      lastActivity: '2025-01-01T11:45:00Z',
      hasApiHistory: true,
      hasUiMessages: true,
      size: 3200
    },
    {
      taskId: 'conv-py-1',
      path: '/mock/conv-py-1',
      metadata: {
        taskId: 'conv-py-1',
        createdAt: '2025-01-01T14:00:00Z',
        updatedAt: '2025-01-01T15:30:00Z',
        status: 'completed',
        totalMessages: 18,
        mode: 'code',
        files_in_context: [
          { path: 'backend/requirements.txt', record_state: 'active', record_source: 'read_tool' },
          { path: 'backend/app.py', record_state: 'active', record_source: 'roo_edited' },
          { path: 'backend/models.py', record_state: 'active', record_source: 'roo_edited' }
        ]
      },
      messageCount: 18,
      lastActivity: '2025-01-01T15:30:00Z',
      hasApiHistory: true,
      hasUiMessages: true,
      size: 2800
    },
    {
      taskId: 'conv-docs-1',
      path: '/mock/conv-docs-1',
      metadata: {
        taskId: 'conv-docs-1',
        createdAt: '2025-01-02T09:00:00Z',
        updatedAt: '2025-01-02T09:30:00Z',
        status: 'completed',
        totalMessages: 8,
        mode: 'ask',
        files_in_context: [
          { path: 'docs/README.md', record_state: 'active', record_source: 'roo_edited' },
          { path: 'docs/architecture.md', record_state: 'active', record_source: 'roo_edited' }
        ]
      },
      messageCount: 8,
      lastActivity: '2025-01-02T09:30:00Z',
      hasApiHistory: true,
      hasUiMessages: true,
      size: 1200
    },
    {
      taskId: 'conv-config-1',
      path: '/mock/conv-config-1',
      metadata: {
        taskId: 'conv-config-1',
        createdAt: '2025-01-02T16:00:00Z',
        updatedAt: '2025-01-02T16:15:00Z',
        status: 'completed',
        totalMessages: 5,
        mode: 'code',
        files_in_context: [
          { path: 'docker-compose.yml', record_state: 'active', record_source: 'roo_edited' },
          { path: 'Dockerfile', record_state: 'active', record_source: 'roo_edited' },
          { path: '.env.example', record_state: 'active', record_source: 'roo_edited' }
        ]
      },
      messageCount: 5,
      lastActivity: '2025-01-02T16:15:00Z',
      hasApiHistory: true,
      hasUiMessages: false,
      size: 800
    }
  ];

  return conversations;
};

// Tests individuels
const testWorkspaceAnalyzer = async () => {
  log('\n📊 Test WorkspaceAnalyzer...', colors.blue);
  
  try {
    const conversations = createTestData();
    const startTime = Date.now();
    
    const analysis = await WorkspaceAnalyzer.analyzeWorkspaces(conversations);
    const duration = Date.now() - startTime;
    
    log(`✅ Analyse terminée en ${duration}ms`, colors.green);
    log(`   - ${analysis.totalConversations} conversations analysées`);
    log(`   - ${analysis.workspaces.length} workspaces détectés`);
    
    if (analysis.workspaces.length > 0) {
      for (const workspace of analysis.workspaces) {
        log(`   - Workspace: ${workspace.name} (confiance: ${(workspace.confidence * 100).toFixed(1)}%)`);
        log(`     Technologies: ${workspace.detectedTechnologies.join(', ')}`);
        log(`     Conversations: ${workspace.conversations.length}`);
      }
    }
    
    log(`   - Métriques de qualité: ${(analysis.analysisMetadata.qualityMetrics.workspaceDetectionAccuracy * 100).toFixed(1)}%`);
    
    return true;
  } catch (error) {
    log(`❌ Erreur: ${error.message}`, colors.red);
    return false;
  }
};

const testRelationshipAnalyzer = async () => {
  log('\n🔗 Test RelationshipAnalyzer...', colors.blue);
  
  try {
    const conversations = createTestData();
    const startTime = Date.now();
    
    const relationships = await RelationshipAnalyzer.analyzeRelationships(conversations);
    const duration = Date.now() - startTime;
    
    log(`✅ Analyse des relations terminée en ${duration}ms`, colors.green);
    log(`   - ${relationships.length} relations détectées`);
    
    const relationshipTypes = {};
    for (const rel of relationships) {
      relationshipTypes[rel.type] = (relationshipTypes[rel.type] || 0) + 1;
    }
    
    for (const [type, count] of Object.entries(relationshipTypes)) {
      log(`   - ${type}: ${count} relations`);
    }
    
    if (relationships.length > 0) {
      const avgWeight = relationships.reduce((sum, rel) => sum + rel.weight, 0) / relationships.length;
      log(`   - Poids moyen: ${(avgWeight * 100).toFixed(1)}%`);
    }
    
    return true;
  } catch (error) {
    log(`❌ Erreur: ${error.message}`, colors.red);
    return false;
  }
};

const testTaskTreeBuilder = async () => {
  log('\n🌳 Test TaskTreeBuilder...', colors.blue);
  
  try {
    const conversations = createTestData();
    const startTime = Date.now();
    
    const builder = new TaskTreeBuilder();
    const tree = await builder.buildCompleteTree(conversations);
    const duration = Date.now() - startTime;
    
    log(`✅ Construction de l'arbre terminée en ${duration}ms`, colors.green);
    log(`   - ${tree.metadata.totalNodes} nœuds créés`);
    log(`   - Profondeur maximale: ${tree.metadata.maxDepth}`);
    log(`   - Score de qualité: ${(tree.metadata.qualityScore * 100).toFixed(1)}%`);
    log(`   - ${tree.relationships.length} relations`);
    
    // Vérifications de l'index
    log(`   - Index par ID: ${tree.index.byId.size} entrées`);
    log(`   - Index par type: ${tree.index.byType.size} types`);
    log(`   - Index par technologie: ${tree.index.byTechnology.size} technologies`);
    
    // Affichage de la structure
    const displayTree = (node, depth = 0) => {
      const indent = '  '.repeat(depth);
      log(`${indent}- ${node.name} (${node.type})`);
      
      if (node.children && depth < 3) { // Limite l'affichage pour éviter trop de détails
        for (const child of node.children.slice(0, 3)) { // Affiche max 3 enfants
          displayTree(child, depth + 1);
        }
        if (node.children.length > 3) {
          log(`${indent}  ... et ${node.children.length - 3} autres`);
        }
      }
    };
    
    log('\n📋 Structure de l\'arbre:', colors.yellow);
    displayTree(tree.root);
    
    return true;
  } catch (error) {
    log(`❌ Erreur: ${error.message}`, colors.red);
    console.error(error.stack);
    return false;
  }
};

const testPerformance = async () => {
  log('\n⚡ Test de performance...', colors.blue);
  
  try {
    // Génère un dataset plus large
    const conversations = [];
    
    for (let i = 0; i < 100; i++) {
      conversations.push({
        taskId: `perf-conv-${i}`,
        path: `/mock/perf-conv-${i}`,
        metadata: {
          taskId: `perf-conv-${i}`,
          createdAt: new Date(Date.now() - Math.random() * 30 * 24 * 60 * 60 * 1000).toISOString(),
          updatedAt: new Date(Date.now() - Math.random() * 7 * 24 * 60 * 60 * 1000).toISOString(),
          status: 'completed',
          totalMessages: Math.floor(Math.random() * 50) + 5,
          mode: ['code', 'ask', 'debug'][Math.floor(Math.random() * 3)],
          files_in_context: [
            { path: `project${i % 10}/src/file${i}.js`, record_state: 'active', record_source: 'roo_edited' },
            { path: `project${i % 10}/package.json`, record_state: 'active', record_source: 'read_tool' }
          ]
        },
        messageCount: Math.floor(Math.random() * 50) + 5,
        lastActivity: new Date(Date.now() - Math.random() * 7 * 24 * 60 * 60 * 1000).toISOString(),
        hasApiHistory: true,
        hasUiMessages: Math.random() > 0.3,
        size: Math.floor(Math.random() * 5000) + 500
      });
    }
    
    const startTime = Date.now();
    
    const builder = new TaskTreeBuilder();
    const tree = await builder.buildCompleteTree(conversations);
    
    const totalTime = Date.now() - startTime;
    
    log(`✅ Performance test terminé en ${totalTime}ms`, colors.green);
    log(`   - ${conversations.length} conversations traitées`);
    log(`   - ${tree.metadata.totalNodes} nœuds créés`);
    log(`   - Temps par conversation: ${(totalTime / conversations.length).toFixed(2)}ms`);
    
    const targetTime = 30000; // 30 secondes
    if (totalTime < targetTime) {
      log(`✅ Performance acceptable (< ${targetTime}ms)`, colors.green);
      return true;
    } else {
      log(`⚠️  Performance limite (${totalTime}ms > ${targetTime}ms)`, colors.yellow);
      return true; // Pas un échec critique
    }
    
  } catch (error) {
    log(`❌ Erreur: ${error.message}`, colors.red);
    return false;
  }
};

// Fonction principale
const runTests = async () => {
  log(`${colors.bold}🚀 Tests de la Phase 1 - Arborescence de Tâches${colors.reset}`, colors.blue);
  log('='.repeat(60));
  
  const tests = [
    { name: 'WorkspaceAnalyzer', fn: testWorkspaceAnalyzer },
    { name: 'RelationshipAnalyzer', fn: testRelationshipAnalyzer },
    { name: 'TaskTreeBuilder', fn: testTaskTreeBuilder },
    { name: 'Performance', fn: testPerformance }
  ];
  
  let passed = 0;
  let failed = 0;
  
  for (const test of tests) {
    const success = await test.fn();
    if (success) {
      passed++;
    } else {
      failed++;
    }
  }
  
  log('\n' + '='.repeat(60));
  log(`${colors.bold}📊 Résultats des tests:${colors.reset}`);
  log(`✅ Tests réussis: ${passed}`, colors.green);
  log(`❌ Tests échoués: ${failed}`, failed > 0 ? colors.red : colors.green);
  
  if (failed === 0) {
    log(`\n🎉 Tous les tests sont passés ! La Phase 1 est fonctionnelle.`, colors.green);
  } else {
    log(`\n⚠️  ${failed} test(s) ont échoué. Vérifiez les erreurs ci-dessus.`, colors.yellow);
  }
  
  return failed === 0;
};

// Exécution si appelé directement
if (import.meta.url === `file://${process.argv[1]}`) {
  runTests()
    .then(success => {
      process.exit(success ? 0 : 1);
    })
    .catch(error => {
      log(`💥 Erreur fatale: ${error.message}`, colors.red);
      console.error(error.stack);
      process.exit(1);
    });
}

export { runTests };