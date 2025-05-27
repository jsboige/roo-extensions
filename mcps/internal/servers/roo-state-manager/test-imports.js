/**
 * Test simple des imports des modules Phase 2
 */

console.log('🔍 Test des imports des modules Phase 2...');

async function testImports() {
  try {
    console.log('📦 Test cache-manager...');
    const { CacheManager } = await import('./build/utils/cache-manager.js');
    console.log('✅ cache-manager importé avec succès');
    
    console.log('📦 Test summary-generator...');
    const { SummaryGenerator } = await import('./build/utils/summary-generator.js');
    console.log('✅ summary-generator importé avec succès');
    
    console.log('📦 Test task-tree-builder...');
    const { TaskTreeBuilder } = await import('./build/utils/task-tree-builder.js');
    console.log('✅ task-tree-builder importé avec succès');
    
    console.log('📦 Test roo-storage-detector...');
    const { RooStorageDetector } = await import('./build/utils/roo-storage-detector.js');
    console.log('✅ roo-storage-detector importé avec succès');
    
    console.log('\n🎉 Tous les modules sont importables !');
    
    // Test rapide d'instanciation
    console.log('\n🧪 Test d\'instanciation...');
    const cache = new CacheManager({ maxSize: 1024, maxAge: 1000, persistToDisk: false });
    console.log('✅ CacheManager instancié');
    
    const builder = new TaskTreeBuilder();
    console.log('✅ TaskTreeBuilder instancié');
    
    console.log('\n✨ Tests d\'imports réussis !');
    
  } catch (error) {
    console.error('❌ Erreur lors des tests d\'imports:', error);
    process.exit(1);
  }
}

testImports();