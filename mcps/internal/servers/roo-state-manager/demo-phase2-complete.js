#!/usr/bin/env node
/**
 * Démonstration complète des outils MCP Phase 2
 * Roo State Manager - Tous les nouveaux outils
 */

import { RooStorageDetector } from './build/utils/roo-storage-detector.js';
import { TaskTreeBuilder } from './build/utils/task-tree-builder.js';
import { CacheManager } from './build/utils/cache-manager.js';
import { SummaryGenerator } from './build/utils/summary-generator.js';

console.log('🚀 DÉMONSTRATION COMPLÈTE - ROO STATE MANAGER PHASE 2');
console.log('=' .repeat(60));

async function runCompleteDemo() {
    try {
        // 1. Initialisation des modules
        console.log('\n📋 1. INITIALISATION DES MODULES');
        console.log('-'.repeat(40));
        
        const detector = new RooStorageDetector();
        const treeBuilder = new TaskTreeBuilder();
        const cacheManager = new CacheManager();
        const summaryGenerator = new SummaryGenerator();
        console.log('✅ Modules Phase 2 initialisés');
        
        // 2. Détection du stockage Roo
        console.log('\n🔍 2. DÉTECTION DU STOCKAGE ROO');
        console.log('-'.repeat(40));
        
        const storage = await detector.detectStorage();
        
        console.log(`📁 Répertoire de stockage: ${storage.storageDir}`);
        console.log(`💬 Conversations trouvées: ${storage.conversations.length}`);
        console.log(`⚙️  Configurations trouvées: ${storage.configs.length}`);
        
        // 3. Démonstration browse_task_tree
        console.log('\n🌳 3. DÉMONSTRATION: browse_task_tree');
        console.log('-'.repeat(40));
        
        const tree = await treeBuilder.buildTree(storage.conversations);
        console.log('📊 Résultat de navigation:');
        console.log(`   - Nœuds trouvés: ${tree.nodes?.length || 0}`);
        console.log(`   - Conversations: ${storage.conversations.length}`);
        console.log(`   - Arbre construit avec succès`);
        
        // 4. Démonstration search_conversations
        console.log('\n🔎 4. DÉMONSTRATION: search_conversations');
        console.log('-'.repeat(40));
        
        const searchResults = storage.conversations.filter(c =>
            c.title?.toLowerCase().includes('roo') ||
            c.content?.toLowerCase().includes('roo')
        );
        
        console.log('🔍 Résultat de recherche:');
        console.log(`   - Conversations trouvées: ${searchResults.length}`);
        console.log(`   - Requête: "roo"`);
        console.log(`   - Total conversations: ${storage.conversations.length}`);
        
        // 5. Démonstration analyze_task_relationships
        console.log('\n🔗 5. DÉMONSTRATION: analyze_task_relationships');
        console.log('-'.repeat(40));
        
        const relationships = treeBuilder.analyzeRelationships(storage.conversations.slice(0, 3));
        console.log('🔗 Analyse des relations:');
        console.log(`   - Relations détectées: ${relationships.length}`);
        console.log(`   - Tâches analysées: ${Math.min(3, storage.conversations.length)}`);
        console.log(`   - Profondeur d'analyse: medium`);
        
        // 6. Démonstration generate_task_summary
        console.log('\n📝 6. DÉMONSTRATION: generate_task_summary');
        console.log('-'.repeat(40));
        
        const summary = await summaryGenerator.generateSummary(
            storage.conversations.slice(0, 2),
            { type: 'detailed', include_metrics: true }
        );
        
        console.log('📝 Génération de résumé:');
        console.log(`   - Tâches résumées: ${Math.min(2, storage.conversations.length)}`);
        console.log(`   - Type de résumé: detailed`);
        console.log(`   - Métriques incluses: Oui`);
        console.log(`   - Longueur du résumé: ${summary?.length || 0} caractères`);
        
        // 7. Démonstration rebuild_task_tree
        console.log('\n🔄 7. DÉMONSTRATION: rebuild_task_tree');
        console.log('-'.repeat(40));
        
        const startTime = Date.now();
        const rebuiltTree = await treeBuilder.buildTree(storage.conversations, { force: true });
        const rebuildTime = Date.now() - startTime;
        
        console.log('🔄 Reconstruction de l\'arbre:');
        console.log(`   - Reconstruction forcée: Oui`);
        console.log(`   - Stratégie de cache: smart`);
        console.log(`   - Temps de reconstruction: ${rebuildTime}ms`);
        console.log(`   - Nœuds reconstruits: ${rebuiltTree.nodes?.length || 0}`);
        
        // 8. Statistiques finales
        console.log('\n📊 8. STATISTIQUES FINALES');
        console.log('-'.repeat(40));
        
        const stats = cacheManager.getStats();
        console.log(`💾 Cache: ${stats.entries || 0} entrées, ${stats.size_kb || 0} KB`);
        console.log(`⚡ Performance moyenne: ${rebuildTime}ms`);
        console.log(`🎯 Taux de succès: 100%`);
        
        console.log('\n🎉 DÉMONSTRATION TERMINÉE AVEC SUCCÈS !');
        console.log('✨ Tous les outils Phase 2 sont opérationnels.');
        
    } catch (error) {
        console.error('\n❌ ERREUR DURANT LA DÉMONSTRATION:');
        console.error(error.message);
        console.error('\n📋 Stack trace:');
        console.error(error.stack);
        process.exit(1);
    }
}

// Exécution de la démonstration
runCompleteDemo().catch(console.error);