#!/usr/bin/env node

/**
 * Test complet pour valider l'implémentation de la Phase 1
 */

console.log('🚀 Test complet de la Phase 1 - Arborescence de Tâches');
console.log('='.repeat(60));

try {
  const { WorkspaceAnalyzer } = await import('../build/utils/workspace-analyzer.js');
  const { RelationshipAnalyzer } = await import('../build/utils/relationship-analyzer.js');
  const { TaskTreeBuilder } = await import('../build/utils/task-tree-builder.js');
  
  // Données de test plus complètes
  const conversations = [
    {
      taskId: 'frontend-setup',
      path: '/mock/frontend-setup',
      metadata: {
        taskId: 'frontend-setup',
        createdAt: '2025-01-01T10:00:00Z',
        updatedAt: '2025-01-01T10:30:00Z',
        status: 'completed',
        totalMessages: 15,
        mode: 'code',
        files_in_context: [
          { path: 'frontend/package.json', record_state: 'active', record_source: 'read_tool' },
          { path: 'frontend/src/App.js', record_state: 'active', record_source: 'roo_edited' },
          { path: 'frontend/src/components/Header.js', record_state: 'active', record_source: 'roo_edited' },
          { path: 'frontend/src/utils/api.js', record_state: 'active', record_source: 'roo_edited' }
        ]
      },
      messageCount: 15,
      lastActivity: '2025-01-01T10:30:00Z',
      hasApiHistory: true,
      hasUiMessages: true,
      size: 2500
    },
    {
      taskId: 'frontend-tests',
      path: '/mock/frontend-tests',
      metadata: {
        taskId: 'frontend-tests',
        createdAt: '2025-01-01T11:00:00Z',
        updatedAt: '2025-01-01T11:45:00Z',
        status: 'completed',
        totalMessages: 22,
        mode: 'code',
        files_in_context: [
          { path: 'frontend/src/App.js', record_state: 'stale', record_source: 'read_tool' },
          { path: 'frontend/tests/App.test.js', record_state: 'active', record_source: 'roo_edited' },
          { path: 'frontend/tests/utils.test.js', record_state: 'active', record_source: 'roo_edited' },
          { path: 'frontend/package.json', record_state: 'stale', record_source: 'read_tool' }
        ]
      },
      messageCount: 22,
      lastActivity: '2025-01-01T11:45:00Z',
      hasApiHistory: true,
      hasUiMessages: true,
      size: 3200
    },
    {
      taskId: 'backend-api',
      path: '/mock/backend-api',
      metadata: {
        taskId: 'backend-api',
        createdAt: '2025-01-01T14:00:00Z',
        updatedAt: '2025-01-01T15:30:00Z',
        status: 'completed',
        totalMessages: 18,
        mode: 'code',
        files_in_context: [
          { path: 'backend/requirements.txt', record_state: 'active', record_source: 'read_tool' },
          { path: 'backend/app.py', record_state: 'active', record_source: 'roo_edited' },
          { path: 'backend/models/user.py', record_state: 'active', record_source: 'roo_edited' },
          { path: 'backend/routes/api.py', record_state: 'active', record_source: 'roo_edited' }
        ]
      },
      messageCount: 18,
      lastActivity: '2025-01-01T15:30:00Z',
      hasApiHistory: true,
      hasUiMessages: true,
      size: 2800
    },
    {
      taskId: 'backend-database',
      path: '/mock/backend-database',
      metadata: {
        taskId: 'backend-database',
        createdAt: '2025-01-01T16:00:00Z',
        updatedAt: '2025-01-01T17:00:00Z',
        status: 'completed',
        totalMessages: 12,
        mode: 'code',
        files_in_context: [
          { path: 'backend/models/user.py', record_state: 'stale', record_source: 'read_tool' },
          { path: 'backend/database/migrations.py', record_state: 'active', record_source: 'roo_edited' },
          { path: 'backend/database/connection.py', record_state: 'active', record_source: 'roo_edited' },
          { path: 'backend/requirements.txt', record_state: 'stale', record_source: 'read_tool' }
        ]
      },
      messageCount: 12,
      lastActivity: '2025-01-01T17:00:00Z',
      hasApiHistory: true,
      hasUiMessages: true,
      size: 2100
    },
    {
      taskId: 'docs-readme',
      path: '/mock/docs-readme',
      metadata: {
        taskId: 'docs-readme',
        createdAt: '2025-01-02T09:00:00Z',
        updatedAt: '2025-01-02T09:30:00Z',
        status: 'completed',
        totalMessages: 8,
        mode: 'ask',
        files_in_context: [
          { path: 'README.md', record_state: 'active', record_source: 'roo_edited' },
          { path: 'docs/installation.md', record_state: 'active', record_source: 'roo_edited' },
          { path: 'docs/api.md', record_state: 'active', record_source: 'roo_edited' }
        ]
      },
      messageCount: 8,
      lastActivity: '2025-01-02T09:30:00Z',
      hasApiHistory: true,
      hasUiMessages: true,
      size: 1200
    },
    {
      taskId: 'deployment-config',
      path: '/mock/deployment-config',
      metadata: {
        taskId: 'deployment-config',
        createdAt: '2025-01-02T16:00:00Z',
        updatedAt: '2025-01-02T16:15:00Z',
        status: 'completed',
        totalMessages: 5,
        mode: 'code',
        files_in_context: [
          { path: 'docker-compose.yml', record_state: 'active', record_source: 'roo_edited' },
          { path: 'Dockerfile', record_state: 'active', record_source: 'roo_edited' },
          { path: '.env.example', record_state: 'active', record_source: 'roo_edited' },
          { path: 'deploy/nginx.conf', record_state: 'active', record_source: 'roo_edited' }
        ]
      },
      messageCount: 5,
      lastActivity: '2025-01-02T16:15:00Z',
      hasApiHistory: true,
      hasUiMessages: false,
      size: 800
    }
  ];

  console.log(`📊 Test avec ${conversations.length} conversations`);
  
  // Test 1: WorkspaceAnalyzer
  console.log('\n🔍 Test WorkspaceAnalyzer...');
  const startTime1 = Date.now();
  const analysis = await WorkspaceAnalyzer.analyzeWorkspaces(conversations);
  const duration1 = Date.now() - startTime1;
  
  console.log(`✅ Analyse terminée en ${duration1}ms`);
  console.log(`   - ${analysis.totalConversations} conversations analysées`);
  console.log(`   - ${analysis.workspaces.length} workspaces détectés`);
  
  for (const workspace of analysis.workspaces) {
    console.log(`   - Workspace: "${workspace.name}" (confiance: ${(workspace.confidence * 100).toFixed(1)}%)`);
    console.log(`     Technologies: ${workspace.detectedTechnologies.join(', ')}`);
    console.log(`     Conversations: ${workspace.conversations.length}`);
    console.log(`     Patterns: ${workspace.filePatterns.slice(0, 3).join(', ')}${workspace.filePatterns.length > 3 ? '...' : ''}`);
  }
  
  // Test 2: RelationshipAnalyzer
  console.log('\n🔗 Test RelationshipAnalyzer...');
  const startTime2 = Date.now();
  const relationships = await RelationshipAnalyzer.analyzeRelationships(conversations);
  const duration2 = Date.now() - startTime2;
  
  console.log(`✅ Analyse des relations terminée en ${duration2}ms`);
  console.log(`   - ${relationships.length} relations détectées`);
  
  const relationshipTypes = {};
  for (const rel of relationships) {
    relationshipTypes[rel.type] = (relationshipTypes[rel.type] || 0) + 1;
  }
  
  for (const [type, count] of Object.entries(relationshipTypes)) {
    console.log(`   - ${type}: ${count} relations`);
  }
  
  if (relationships.length > 0) {
    const avgWeight = relationships.reduce((sum, rel) => sum + rel.weight, 0) / relationships.length;
    console.log(`   - Poids moyen: ${(avgWeight * 100).toFixed(1)}%`);
    
    // Affiche quelques exemples de relations
    console.log('   - Exemples de relations:');
    for (const rel of relationships.slice(0, 3)) {
      console.log(`     * ${rel.type}: ${rel.source} → ${rel.target} (${(rel.weight * 100).toFixed(1)}%)`);
    }
  }
  
  // Test 3: TaskTreeBuilder
  console.log('\n🌳 Test TaskTreeBuilder...');
  const startTime3 = Date.now();
  const builder = new TaskTreeBuilder();
  const tree = await builder.buildCompleteTree(conversations);
  const duration3 = Date.now() - startTime3;
  
  console.log(`✅ Construction de l'arbre terminée en ${duration3}ms`);
  console.log(`   - ${tree.metadata.totalNodes} nœuds créés`);
  console.log(`   - Profondeur maximale: ${tree.metadata.maxDepth}`);
  console.log(`   - Score de qualité: ${(tree.metadata.qualityScore * 100).toFixed(1)}%`);
  console.log(`   - ${tree.relationships.length} relations dans l'arbre`);
  
  // Vérifications de l'index
  console.log(`   - Index par ID: ${tree.index.byId.size} entrées`);
  console.log(`   - Index par type: ${tree.index.byType.size} types`);
  console.log(`   - Index par technologie: ${tree.index.byTechnology.size} technologies`);
  console.log(`   - Index par période: ${tree.index.byTimeRange.size} périodes`);
  
  // Affichage de la structure (limité)
  console.log('\n📋 Structure de l\'arbre:');
  const displayTree = (node, depth = 0, maxDepth = 2) => {
    const indent = '  '.repeat(depth);
    const nodeInfo = `${node.name} (${node.type})`;
    const metadata = node.metadata;
    
    if (depth === 0) {
      console.log(`${indent}🌳 ${nodeInfo}`);
      if (metadata.totalConversations) {
        console.log(`${indent}   📊 ${metadata.totalConversations} conversations, ${(metadata.totalSize / 1024).toFixed(1)} KB`);
      }
    } else {
      console.log(`${indent}├─ ${nodeInfo}`);
      if (metadata.conversationCount) {
        console.log(`${indent}   📊 ${metadata.conversationCount} conversations`);
      }
      if (metadata.technologies && metadata.technologies.length > 0) {
        console.log(`${indent}   🔧 ${metadata.technologies.slice(0, 3).join(', ')}`);
      }
    }
    
    if (node.children && depth < maxDepth) {
      const childrenToShow = Math.min(node.children.length, 5);
      for (let i = 0; i < childrenToShow; i++) {
        displayTree(node.children[i], depth + 1, maxDepth);
      }
      if (node.children.length > childrenToShow) {
        console.log(`${indent}  └─ ... et ${node.children.length - childrenToShow} autres`);
      }
    }
  };
  
  displayTree(tree.root);
  
  // Test de performance
  console.log('\n⚡ Résumé des performances:');
  const totalTime = duration1 + duration2 + duration3;
  console.log(`   - Analyse workspace: ${duration1}ms`);
  console.log(`   - Analyse relations: ${duration2}ms`);
  console.log(`   - Construction arbre: ${duration3}ms`);
  console.log(`   - Temps total: ${totalTime}ms`);
  console.log(`   - Temps par conversation: ${(totalTime / conversations.length).toFixed(2)}ms`);
  
  // Validation des critères de succès
  console.log('\n✅ Validation des critères de succès:');
  
  const criteria = [
    { name: 'Performance < 30s', value: totalTime < 30000, actual: `${totalTime}ms` },
    { name: 'Workspaces détectés', value: analysis.workspaces.length > 0, actual: `${analysis.workspaces.length}` },
    { name: 'Relations détectées', value: relationships.length > 0, actual: `${relationships.length}` },
    { name: 'Arbre construit', value: tree.metadata.totalNodes > 1, actual: `${tree.metadata.totalNodes} nœuds` },
    { name: 'Index fonctionnel', value: tree.index.byId.size > 0, actual: `${tree.index.byId.size} entrées` },
    { name: 'Qualité acceptable', value: tree.metadata.qualityScore > 0.3, actual: `${(tree.metadata.qualityScore * 100).toFixed(1)}%` }
  ];
  
  let passed = 0;
  for (const criterion of criteria) {
    const status = criterion.value ? '✅' : '❌';
    console.log(`   ${status} ${criterion.name}: ${criterion.actual}`);
    if (criterion.value) passed++;
  }
  
  console.log('\n' + '='.repeat(60));
  console.log(`📊 Résultats: ${passed}/${criteria.length} critères validés`);
  
  if (passed === criteria.length) {
    console.log('🎉 Phase 1 implémentée avec succès ! Tous les critères sont validés.');
  } else {
    console.log(`⚠️  ${criteria.length - passed} critère(s) non validé(s). Vérifiez les détails ci-dessus.`);
  }
  
} catch (error) {
  console.error('❌ Erreur lors du test:', error.message);
  console.error(error.stack);
  process.exit(1);
}