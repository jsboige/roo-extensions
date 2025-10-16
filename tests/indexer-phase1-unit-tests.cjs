/**
 * Script de Tests Phase 1 - Tests Unitaires Indexer-Qdrant
 * Tests 1.1 à 1.7 du plan de tests
 */

// ⚠️ CORRECTION: Charger le .env AVANT toute utilisation
// Chemin relatif au répertoire d'exécution (d:/roo-extensions)
require('dotenv').config({ path: './mcps/internal/servers/roo-state-manager/.env' });

const https = require('https');
const fetch = (...args) => import('node-fetch').then(({ default: fetch }) => fetch(...args));

// Configuration depuis .env
const QDRANT_URL = process.env.QDRANT_URL || 'https://qdrant.myia.io';
const QDRANT_API_KEY = process.env.QDRANT_API_KEY || '';
const QDRANT_COLLECTION = process.env.QDRANT_COLLECTION_NAME || 'roo_tasks_semantic_index';
const OPENAI_API_KEY = process.env.OPENAI_API_KEY || '';

// 🔍 DEBUG: Vérification du chargement des variables d'environnement
console.log('\n🔧 Configuration chargée:');
console.log(`   QDRANT_URL: ${QDRANT_URL}`);
console.log(`   QDRANT_API_KEY: ${QDRANT_API_KEY ? 'sk-...' + QDRANT_API_KEY.slice(-4) : '❌ NON CHARGÉE'}`);
console.log(`   QDRANT_COLLECTION: ${QDRANT_COLLECTION}`);
console.log(`   OPENAI_API_KEY: ${OPENAI_API_KEY ? 'sk-...' + OPENAI_API_KEY.slice(-4) : '❌ NON CHARGÉE'}`);

const results = {
  test_1_1: { name: 'Connexion MCP → Qdrant', status: 'pending', time: 0, details: {} },
  test_1_2: { name: 'Création Point de Test', status: 'pending', time: 0, details: {} },
  test_1_3: { name: 'Insertion (Upsert) Point', status: 'pending', time: 0, details: {} },
  test_1_4: { name: 'Recherche Sémantique', status: 'pending', time: 0, details: {} }
};

/**
 * Test 1.1 : Connexion au serveur Qdrant
 */
async function test_1_1_connection() {
  const startTime = Date.now();
  console.log('\n🔍 Test 1.1 : Connexion MCP → Qdrant');
  
  try {
    const response = await fetch(`${QDRANT_URL}/collections/${QDRANT_COLLECTION}`, {
      method: 'GET',
      headers: {
        'api-key': QDRANT_API_KEY,
        'Content-Type': 'application/json'
      }
    });
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${await response.text()}`);
    }
    
    const data = await response.json();
    const duration = Date.now() - startTime;
    
    results.test_1_1 = {
      name: 'Connexion MCP → Qdrant',
      status: 'success',
      time: duration,
      details: {
        collection_exists: true,
        points_count: data.result?.points_count || 0,
        vectors_count: data.result?.vectors_count || 0,
        config: {
          distance: data.result?.config?.params?.vectors?.distance || 'unknown',
          dimension: data.result?.config?.params?.vectors?.size || 0
        }
      }
    };
    
    console.log(`✅ Test 1.1 réussi (${duration}ms)`);
    console.log(`   Collection: ${QDRANT_COLLECTION}`);
    console.log(`   Points: ${results.test_1_1.details.points_count}`);
    console.log(`   Config: ${results.test_1_1.details.config.distance}, dim=${results.test_1_1.details.config.dimension}`);
    
    return true;
  } catch (error) {
    const duration = Date.now() - startTime;
    results.test_1_1 = {
      name: 'Connexion MCP → Qdrant',
      status: 'failed',
      time: duration,
      details: { error: error.message }
    };
    console.log(`❌ Test 1.1 échoué (${duration}ms): ${error.message}`);
    return false;
  }
}

/**
 * Test 1.2 : Création d'un embedding de test
 */
async function test_1_2_create_embedding() {
  const startTime = Date.now();
  console.log('\n🔍 Test 1.2 : Création Point de Test (Embedding)');
  
  try {
    const testContent = "Ceci est un test d'indexation simple pour validation Phase 1";
    
    const response = await fetch('https://api.openai.com/v1/embeddings', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${OPENAI_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: 'text-embedding-3-small',
        input: testContent
      })
    });
    
    if (!response.ok) {
      throw new Error(`OpenAI API error: ${response.status}`);
    }
    
    const data = await response.json();
    const embedding = data.data[0].embedding;
    const duration = Date.now() - startTime;
    
    // Validation
    const hasNaN = embedding.some(v => isNaN(v));
    const hasInfinity = embedding.some(v => !isFinite(v));
    
    results.test_1_2 = {
      name: 'Création Point de Test',
      status: 'success',
      time: duration,
      details: {
        dimension: embedding.length,
        has_nan: hasNaN,
        has_infinity: hasInfinity,
        sample: embedding.slice(0, 5),
        usage: data.usage
      }
    };
    
    console.log(`✅ Test 1.2 réussi (${duration}ms)`);
    console.log(`   Dimension: ${embedding.length}`);
    console.log(`   NaN: ${hasNaN ? 'DÉTECTÉ ⚠️' : 'Non'}`);
    console.log(`   Infinity: ${hasInfinity ? 'DÉTECTÉ ⚠️' : 'Non'}`);
    console.log(`   Tokens: ${data.usage.total_tokens}`);
    
    return { embedding, content: testContent };
  } catch (error) {
    const duration = Date.now() - startTime;
    results.test_1_2 = {
      name: 'Création Point de Test',
      status: 'failed',
      time: duration,
      details: { error: error.message }
    };
    console.log(`❌ Test 1.2 échoué (${duration}ms): ${error.message}`);
    return null;
  }
}

/**
 * Test 1.3 : Insertion du point dans Qdrant
 */
async function test_1_3_upsert_point(embedding, content) {
  const startTime = Date.now();
  console.log('\n🔍 Test 1.3 : Insertion (Upsert) Point');
  
  if (!embedding) {
    console.log('❌ Test 1.3 ignoré : pas d\'embedding');
    return null;
  }
  
  try {
    // ⚠️ CORRECTION: Qdrant exige un UUID ou un entier non signé pour l'ID
    const crypto = require('crypto');
    const testPointId = crypto.randomUUID();
    const point = {
      id: testPointId,
      vector: embedding,
      payload: {
        task_id: 'test-task-phase1',
        chunk_id: `chunk-${testPointId}`,
        content: content,
        content_summary: 'Test Phase 1',
        chunk_type: 'test',
        timestamp: new Date().toISOString(),
        workspace: '/test/workspace',
        indexed: true
      }
    };
    
    const response = await fetch(`${QDRANT_URL}/collections/${QDRANT_COLLECTION}/points`, {
      method: 'PUT',
      headers: {
        'api-key': QDRANT_API_KEY,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        points: [point]
      })
    });
    
    if (!response.ok) {
      throw new Error(`Qdrant upsert error: ${response.status} - ${await response.text()}`);
    }
    
    const data = await response.json();
    const duration = Date.now() - startTime;
    
    results.test_1_3 = {
      name: 'Insertion (Upsert) Point',
      status: 'success',
      time: duration,
      details: {
        point_id: testPointId,
        operation_id: data.result?.operation_id,
        status: data.result?.status
      }
    };
    
    console.log(`✅ Test 1.3 réussi (${duration}ms)`);
    console.log(`   Point ID: ${testPointId}`);
    console.log(`   Statut: ${data.result?.status || 'completed'}`);
    
    return testPointId;
  } catch (error) {
    const duration = Date.now() - startTime;
    results.test_1_3 = {
      name: 'Insertion (Upsert) Point',
      status: 'failed',
      time: duration,
      details: { error: error.message }
    };
    console.log(`❌ Test 1.3 échoué (${duration}ms): ${error.message}`);
    return null;
  }
}

/**
 * Test 1.4 : Recherche sémantique
 */
async function test_1_4_semantic_search(queryEmbedding) {
  const startTime = Date.now();
  console.log('\n🔍 Test 1.4 : Recherche Sémantique');
  
  if (!queryEmbedding) {
    console.log('❌ Test 1.4 ignoré : pas d\'embedding de requête');
    return false;
  }
  
  try {
    // Petit délai pour s'assurer que l'indexation est terminée
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    const response = await fetch(`${QDRANT_URL}/collections/${QDRANT_COLLECTION}/points/search`, {
      method: 'POST',
      headers: {
        'api-key': QDRANT_API_KEY,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        vector: queryEmbedding,
        limit: 5,
        with_payload: true
      })
    });
    
    if (!response.ok) {
      throw new Error(`Qdrant search error: ${response.status}`);
    }
    
    const data = await response.json();
    const duration = Date.now() - startTime;
    const results_found = data.result || [];
    const testPointFound = results_found.some(r => r.payload?.task_id === 'test-task-phase1');
    const bestScore = results_found.length > 0 ? results_found[0].score : 0;
    
    results.test_1_4 = {
      name: 'Recherche Sémantique',
      status: testPointFound ? 'success' : 'partial',
      time: duration,
      details: {
        results_count: results_found.length,
        test_point_found: testPointFound,
        best_score: bestScore,
        top_results: results_found.slice(0, 3).map(r => ({
          task_id: r.payload?.task_id,
          score: r.score
        }))
      }
    };
    
    console.log(`${testPointFound ? '✅' : '⚠️'} Test 1.4 ${testPointFound ? 'réussi' : 'partiel'} (${duration}ms)`);
    console.log(`   Résultats: ${results_found.length}`);
    console.log(`   Point test trouvé: ${testPointFound}`);
    console.log(`   Meilleur score: ${bestScore.toFixed(4)}`);
    
    return testPointFound;
  } catch (error) {
    const duration = Date.now() - startTime;
    results.test_1_4 = {
      name: 'Recherche Sémantique',
      status: 'failed',
      time: duration,
      details: { error: error.message }
    };
    console.log(`❌ Test 1.4 échoué (${duration}ms): ${error.message}`);
    return false;
  }
}

/**
 * Exécution de tous les tests
 */
async function runAllTests() {
  console.log('═══════════════════════════════════════════════════════');
  console.log('   TESTS PHASE 1 - Tests Unitaires Indexer-Qdrant');
  console.log('═══════════════════════════════════════════════════════');
  console.log(`Timestamp: ${new Date().toISOString()}`);
  console.log(`Qdrant URL: ${QDRANT_URL}`);
  console.log(`Collection: ${QDRANT_COLLECTION}`);
  
  const startTime = Date.now();
  
  // Test 1.1
  const conn = await test_1_1_connection();
  if (!conn) {
    console.log('\n❌ ARRÊT: Connexion Qdrant échouée');
    printSummary();
    return;
  }
  
  // Test 1.2
  const embeddingData = await test_1_2_create_embedding();
  if (!embeddingData) {
    console.log('\n❌ ARRÊT: Création embedding échouée');
    printSummary();
    return;
  }
  
  // Test 1.3
  const pointId = await test_1_3_upsert_point(embeddingData.embedding, embeddingData.content);
  if (!pointId) {
    console.log('\n⚠️ AVERTISSEMENT: Insertion échouée, Test 1.4 peut échouer');
  }
  
  // Test 1.4
  await test_1_4_semantic_search(embeddingData.embedding);
  
  const totalDuration = Date.now() - startTime;
  
  // Résumé
  console.log('\n═══════════════════════════════════════════════════════');
  console.log('   RÉSUMÉ DES TESTS');
  console.log('═══════════════════════════════════════════════════════');
  
  printSummary(totalDuration);
}

function printSummary(totalDuration = 0) {
  const tests = Object.values(results);
  const success = tests.filter(t => t.status === 'success').length;
  const failed = tests.filter(t => t.status === 'failed').length;
  const partial = tests.filter(t => t.status === 'partial').length;
  
  console.log(`\nTests exécutés: ${tests.filter(t => t.status !== 'pending').length}/${tests.length}`);
  console.log(`✅ Réussis: ${success}`);
  console.log(`❌ Échoués: ${failed}`);
  console.log(`⚠️ Partiels: ${partial}`);
  
  if (totalDuration > 0) {
    console.log(`⏱️ Durée totale: ${totalDuration}ms`);
  }
  
  console.log('\nDétails par test:');
  Object.entries(results).forEach(([key, test]) => {
    const icon = test.status === 'success' ? '✅' : test.status === 'failed' ? '❌' : test.status === 'partial' ? '⚠️' : '⏳';
    console.log(`  ${icon} ${test.name}: ${test.status} (${test.time}ms)`);
    if (test.details.error) {
      console.log(`     Erreur: ${test.details.error}`);
    }
  });
  
  // Verdict global
  const verdict = failed === 0 && success >= 3 ? 'GO' : 'NO-GO';
  console.log(`\n🎯 VERDICT PHASE 1: ${verdict}`);
  
  // Export JSON
  const report = {
    timestamp: new Date().toISOString(),
    duration_ms: totalDuration,
    verdict,
    summary: { success, failed, partial, total: tests.length },
    tests: results
  };
  
  console.log('\n📄 Rapport JSON:');
  console.log(JSON.stringify(report, null, 2));
}

// Exécution
runAllTests().catch(error => {
  console.error('\n💥 ERREUR FATALE:', error);
  process.exit(1);
});