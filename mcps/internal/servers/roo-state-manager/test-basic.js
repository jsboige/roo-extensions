/**
 * Test basique pour identifier les problèmes
 */

console.log('🔍 Test basique du serveur MCP...');

async function testBasic() {
  try {
    console.log('1. Test import du module principal...');
    const mainModule = await import('./build/index.js');
    console.log('✅ Module principal importé:', Object.keys(mainModule));
    
    console.log('2. Test des utilitaires...');
    const { TaskTreeBuilder } = await import('./build/utils/task-tree-builder.js');
    const { CacheManager } = await import('./build/utils/cache-manager.js');
    const { SummaryGenerator } = await import('./build/utils/summary-generator.js');
    
    console.log('✅ Tous les utilitaires importés');
    
    console.log('3. Test d\'instanciation rapide...');
    const builder = new TaskTreeBuilder();
    const cache = new CacheManager({ maxSize: 1024, maxAge: 1000, persistToDisk: false });
    
    console.log('✅ Instanciation réussie');
    
    console.log('4. Test de construction d\'arbre simple...');
    const mockData = [{
      taskId: 'test-001',
      path: '/test/path',
      metadata: {
        taskId: 'test-001',
        title: 'Test Task',
        mode: 'code',
        status: 'completed',
        totalMessages: 5,
        files_in_context: []
      },
      messageCount: 5,
      lastActivity: new Date().toISOString(),
      hasApiHistory: true,
      hasUiMessages: true,
      size: 1024
    }];
    
    const tree = await builder.buildCompleteTree(mockData);
    console.log('✅ Arbre construit:', tree.metadata.totalNodes, 'nœuds');
    
    console.log('5. Test de génération de résumé...');
    const summary = SummaryGenerator.generateTaskTreeSummary(tree, mockData);
    console.log('✅ Résumé généré:', summary.overview.totalConversations, 'conversations');
    
    await cache.close();
    
    console.log('\n🎉 TOUS LES TESTS BASIQUES SONT PASSÉS !');
    console.log('✨ Le serveur MCP Phase 2 est fonctionnel.');
    
  } catch (error) {
    console.error('❌ Erreur lors du test basique:', error);
    console.error('Stack:', error.stack);
    process.exit(1);
  }
}

testBasic();