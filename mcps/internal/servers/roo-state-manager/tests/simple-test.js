#!/usr/bin/env node

/**
 * Test simple pour vérifier le chargement des modules
 */

console.log('🚀 Début du test simple...');

try {
  console.log('📦 Chargement des modules...');
  
  const { WorkspaceAnalyzer } = await import('../build/utils/workspace-analyzer.js');
  console.log('✅ WorkspaceAnalyzer chargé');
  
  const { RelationshipAnalyzer } = await import('../build/utils/relationship-analyzer.js');
  console.log('✅ RelationshipAnalyzer chargé');
  
  const { TaskTreeBuilder } = await import('../build/utils/task-tree-builder.js');
  console.log('✅ TaskTreeBuilder chargé');
  
  // Test simple avec données minimales
  console.log('\n🧪 Test avec données minimales...');
  
  const testConversation = {
    taskId: 'test-conv-1',
    path: '/test/path',
    metadata: {
      taskId: 'test-conv-1',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      status: 'completed',
      totalMessages: 5,
      files_in_context: [
        { path: 'test/file.js', record_state: 'active', record_source: 'read_tool' }
      ]
    },
    messageCount: 5,
    lastActivity: new Date().toISOString(),
    hasApiHistory: true,
    hasUiMessages: true,
    size: 1000
  };
  
  // Test WorkspaceAnalyzer
  console.log('🔍 Test WorkspaceAnalyzer...');
  const analysis = await WorkspaceAnalyzer.analyzeWorkspaces([testConversation]);
  console.log(`✅ Analyse terminée: ${analysis.totalConversations} conversations, ${analysis.workspaces.length} workspaces`);
  
  // Test RelationshipAnalyzer
  console.log('🔗 Test RelationshipAnalyzer...');
  const relationships = await RelationshipAnalyzer.analyzeRelationships([testConversation]);
  console.log(`✅ Relations analysées: ${relationships.length} relations trouvées`);
  
  // Test TaskTreeBuilder
  console.log('🌳 Test TaskTreeBuilder...');
  const builder = new TaskTreeBuilder();
  const tree = await builder.buildCompleteTree([testConversation]);
  console.log(`✅ Arbre construit: ${tree.metadata.totalNodes} nœuds, profondeur ${tree.metadata.maxDepth}`);
  
  console.log('\n🎉 Tous les tests simples sont passés !');
  
} catch (error) {
  console.error('❌ Erreur:', error.message);
  console.error(error.stack);
  process.exit(1);
}