/**
 * Script de Tests Phase 2 - Tests de Charge Progressifs Indexer-Qdrant
 * Tests 2.1 à 2.4 du plan de tests
 * 
 * Protocole Go/No-Go strict entre chaque batch
 */

// Charger les variables d'environnement
require('dotenv').config({ path: './mcps/internal/servers/roo-state-manager/.env' });

const https = require('https');
const crypto = require('crypto');
const fetch = (...args) => import('node-fetch').then(({ default: fetch }) => fetch(...args));

// Configuration depuis .env
const QDRANT_URL = process.env.QDRANT_URL || 'https://qdrant.myia.io';
const QDRANT_API_KEY = process.env.QDRANT_API_KEY || '';
const QDRANT_COLLECTION = process.env.QDRANT_COLLECTION_NAME || 'roo_tasks_semantic_index';
const OPENAI_API_KEY = process.env.OPENAI_API_KEY || '';

// Configuration des tests
const RATE_LIMIT_DELAY_MS = 100; // 100ms entre chaque requête
const BATCH_SIZES = [100, 500, 1000]; // 5000 optionnel
const EMBEDDING_BATCH_SIZE = 100; // Batch pour OpenAI pour éviter rate limit

// Critères Go/No-Go
const CRITERIA = {
  successRate: {
    batch100: 100,     // 100% requis pour baseline
    batch500: 99,      // ≥99%
    batch1000: 98,     // ≥98%
    batch5000: 90      // ≥90%
  },
  avgTimePerDoc: {
    batch100: 2000,    // <2000ms
    batch500: 4000,    // ≤2× baseline
    batch1000: 3000,   // <3000ms
    batch5000: 5000    // <5000ms
  },
  p95Latency: {
    batch100: 3000,    // <3000ms
    batch500: 5000,    // <5000ms
    batch1000: 200,    // <200ms (objectif prod)
    batch5000: 1000    // <1000ms
  },
  throughput: {
    batch100: 0.5,     // ≥0.5 docs/s
    batch500: 0.3,     // ≥0.3 docs/s
    batch1000: 0.2,    // ≥0.2 docs/s
    batch5000: 0.1     // ≥0.1 docs/s
  }
};

// État global
const testState = {
  phase2Results: {},
  allGeneratedTasks: [],
  startTime: Date.now()
};

/**
 * Affichage de la configuration
 */
function printConfiguration() {
  console.log('\n🔧 Configuration chargée:');
  console.log(`   QDRANT_URL: ${QDRANT_URL}`);
  console.log(`   QDRANT_API_KEY: ${QDRANT_API_KEY ? 'sk-...' + QDRANT_API_KEY.slice(-4) : '❌ NON CHARGÉE'}`);
  console.log(`   QDRANT_COLLECTION: ${QDRANT_COLLECTION}`);
  console.log(`   OPENAI_API_KEY: ${OPENAI_API_KEY ? 'sk-...' + OPENAI_API_KEY.slice(-4) : '❌ NON CHARGÉE'}`);
  console.log(`   RATE_LIMIT_DELAY: ${RATE_LIMIT_DELAY_MS}ms`);
}

/**
 * Générateur de contenu varié pour les tâches de test
 */
const contentTemplates = {
  short: [
    "Implémenter validation formulaire contact",
    "Corriger bug affichage mobile",
    "Ajouter bouton export CSV",
    "Optimiser requête SQL lente",
    "Mettre à jour dépendances npm",
    "Créer endpoint API status",
    "Ajouter tests unitaires utils",
    "Documenter API REST",
    "Configurer CI/CD pipeline",
    "Corriger fuite mémoire cache"
  ],
  medium: [
    "Créer une API REST pour la gestion des utilisateurs avec authentification JWT, endpoints CRUD complets, validation des données d'entrée, gestion des erreurs appropriée et documentation Swagger.",
    "Développer un système de notifications en temps réel utilisant WebSocket avec reconnexion automatique, file d'attente de messages persistante, et interface utilisateur réactive avec Toast.",
    "Implémenter un module de recherche avancée avec filtres multiples, pagination optimisée, tri dynamique, mise en cache intelligente et suggestions en temps réel.",
    "Concevoir et développer un tableau de bord analytics avec graphiques interactifs D3.js, export PDF/Excel, filtres temporels et comparaisons période sur période.",
    "Créer un système de gestion des permissions granulaire avec rôles hiérarchiques, héritage de permissions, audit trail complet et interface d'administration intuitive.",
    "Développer un module d'import/export de données supportant CSV, JSON, XML avec validation, transformation, mapping de colonnes et gestion des erreurs détaillée.",
    "Implémenter un système de cache multi-niveaux avec Redis, stratégies d'invalidation intelligentes, monitoring des hit rates et fallback gracieux.",
    "Créer une architecture microservices avec service discovery, load balancing, circuit breaker, distributed tracing et centralized logging.",
    "Développer un système de versioning d'API avec dépréciation progressive, migration automatique des clients, documentation des breaking changes.",
    "Implémenter un workflow d'approbation multi-étapes avec notifications, historique complet, délégation de pouvoir et intégration Slack/Teams."
  ],
  long: [
    "Développer une plateforme complète de gestion de projets agiles incluant : tableau Kanban interactif avec drag & drop, sprint planning avec estimation en story points, burndown charts automatiques, gestion des backlogs produit et sprint, système de notifications configurable par utilisateur, intégration Git pour le suivi des commits, rapports de vélocité d'équipe, gestion des dépendances entre tâches, templates de projets réutilisables, et API complète pour intégrations tierces. Technologies requises : React pour le frontend, Node.js/Express pour le backend, PostgreSQL pour la persistance, Redis pour le cache, Socket.io pour le temps réel, JWT pour l'authentification, et Docker pour le déploiement. Contraintes : architecture scalable pour 1000+ utilisateurs simultanés, temps de réponse < 200ms, disponibilité 99.9%, RGPD compliant.",
    "Concevoir et implémenter un système de recommandation intelligent basé sur le machine learning pour une plateforme e-commerce. Le système doit analyser : historique d'achat des utilisateurs, comportement de navigation (pages vues, temps passé, rebonds), données démographiques, tendances saisonnières, stock disponible, et marge produit. Algorithmes à implémenter : collaborative filtering (user-based et item-based), content-based filtering avec NLP sur descriptions produits, hybrid approach combinant les deux, et reinforcement learning pour optimisation continue. Infrastructure : pipeline de données temps réel avec Kafka, feature store avec Redis, modèles ML avec TensorFlow Serving, A/B testing framework intégré. Métriques à optimiser : conversion rate, panier moyen, customer lifetime value. Performance requise : prédictions en < 50ms, retraining automatique quotidien, explainability des recommandations.",
    "Créer une infrastructure complète de CI/CD pour une application microservices moderne incluant : pipeline multi-stages (build, test, security scan, deploy), orchestration des déploiements blue-green et canary, rollback automatique sur échec des health checks, gestion des secrets avec Vault, scanning de vulnérabilités avec Snyk, tests de charge automatisés avec k6, monitoring avec Prometheus/Grafana, alerting intelligent avec PagerDuty, et documentation auto-générée. Technologies : GitLab CI, Kubernetes, Helm charts, Terraform pour l'IaC, ArgoCD pour GitOps, service mesh avec Istio. Exigences : zero-downtime deployments, compliance SOC2/ISO27001, audit trail complet, disaster recovery avec RPO < 1h, RTO < 30min.",
    "Développer un système d'authentification et d'autorisation enterprise-grade supportant : SSO avec SAML 2.0 et OpenID Connect, authentification multi-facteur (TOTP, SMS, biométrique, hardware tokens), gestion des sessions avec refresh tokens et rotation automatique, politique de mots de passe configurable avec historique, lockout après tentatives échouées, réinitialisation sécurisée par email/SMS, intégration Active Directory et LDAP, API de provisioning automatique des comptes, audit logging détaillé de toutes les actions, conformité RGPD avec consentement explicite et droit à l'oubli. Architecture : service indépendant scalable horizontalement, base de données chiffrée au repos et en transit, rate limiting par IP et par utilisateur, protection contre brute force et credential stuffing. Certifications requises : OAuth 2.0, OpenID Connect, PCI-DSS Level 1.",
    "Implémenter une solution complète de data pipeline ETL pour analytics big data : ingestion de données multi-sources (APIs REST, fichiers CSV/JSON/Parquet, bases SQL/NoSQL, streaming Kafka), transformation avec validation de qualité et nettoyage, enrichissement avec données externes, agrégations pré-calculées pour performance, stockage dans data warehouse columnar (Clickhouse ou Snowflake), et serving via API GraphQL. Processing : batch quotidien et streaming temps réel avec Apache Spark, orchestration avec Airflow, monitoring de la qualité des données avec Great Expectations, gestion des erreurs avec retry logic et dead letter queue. Scalabilité : support de pétaoctets de données, processing parallèle massif, partitionnement intelligent par date/région. Gouvernance : data lineage traçable, metadata management, access control granulaire, data masking pour PII."
  ]
};

const statusOptions = ['pending', 'in_progress', 'completed', 'blocked', 'cancelled'];
const priorityOptions = ['low', 'medium', 'high', 'urgent'];

/**
 * Génère une tâche de test avec contenu varié
 */
function generateTestTask(batchNum, docNum, type = 'medium') {
  const templates = contentTemplates[type];
  const content = templates[Math.floor(Math.random() * templates.length)];
  const status = statusOptions[Math.floor(Math.random() * statusOptions.length)];
  const priority = priorityOptions[Math.floor(Math.random() * priorityOptions.length)];
  
  return {
    id: `test-phase2-batch${batchNum}-doc${docNum}`,
    description: content,
    status: status,
    priority: priority,
    created_at: new Date(Date.now() - Math.random() * 30 * 24 * 60 * 60 * 1000).toISOString(),
    metadata: {
      test_phase: 2,
      batch: batchNum,
      doc_type: type,
      doc_number: docNum
    }
  };
}

/**
 * Génère un batch de tâches variées
 */
function generateBatch(batchNum, size) {
  const tasks = [];
  const distribution = {
    short: Math.floor(size * 0.25),
    medium: Math.floor(size * 0.50),
    long: Math.ceil(size * 0.25)
  };
  
  let docNum = 1;
  
  // Tâches courtes (25%)
  for (let i = 0; i < distribution.short; i++) {
    tasks.push(generateTestTask(batchNum, docNum++, 'short'));
  }
  
  // Tâches moyennes (50%)
  for (let i = 0; i < distribution.medium; i++) {
    tasks.push(generateTestTask(batchNum, docNum++, 'medium'));
  }
  
  // Tâches longues (25%)
  for (let i = 0; i < distribution.long; i++) {
    tasks.push(generateTestTask(batchNum, docNum++, 'long'));
  }
  
  return tasks;
}

/**
 * Crée un embedding via OpenAI
 */
async function createEmbedding(text) {
  try {
    const response = await fetch('https://api.openai.com/v1/embeddings', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${OPENAI_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: 'text-embedding-3-small',
        input: text
      })
    });
    
    if (!response.ok) {
      throw new Error(`OpenAI API error: ${response.status}`);
    }
    
    const data = await response.json();
    return {
      embedding: data.data[0].embedding,
      tokens: data.usage.total_tokens
    };
  } catch (error) {
    console.error(`❌ Erreur création embedding: ${error.message}`);
    return null;
  }
}

/**
 * Insère un point dans Qdrant
 */
async function upsertPoint(task, embedding) {
  try {
    const pointId = crypto.randomUUID();
    const point = {
      id: pointId,
      vector: embedding,
      payload: {
        task_id: task.id,
        chunk_id: `chunk-${pointId}`,
        content: task.description,
        content_summary: task.description.substring(0, 100),
        chunk_type: task.metadata.doc_type,
        status: task.status,
        priority: task.priority,
        timestamp: task.created_at,
        workspace: '/test/phase2',
        indexed: true,
        test_phase: task.metadata.test_phase,
        batch: task.metadata.batch
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
      throw new Error(`Qdrant upsert error: ${response.status}`);
    }
    
    return { success: true, pointId };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

/**
 * Calcule les statistiques d'un tableau de valeurs
 */
function calculateStats(values) {
  if (values.length === 0) return { min: 0, max: 0, avg: 0, p50: 0, p95: 0, p99: 0 };
  
  const sorted = [...values].sort((a, b) => a - b);
  const sum = values.reduce((acc, v) => acc + v, 0);
  
  return {
    min: Math.round(sorted[0]),
    max: Math.round(sorted[sorted.length - 1]),
    avg: Math.round(sum / values.length),
    p50: Math.round(sorted[Math.floor(sorted.length * 0.5)]),
    p95: Math.round(sorted[Math.floor(sorted.length * 0.95)]),
    p99: Math.round(sorted[Math.floor(sorted.length * 0.99)])
  };
}

/**
 * Exécute un batch de tests de charge
 */
async function runBatch(batchNum, size) {
  console.log(`\n${'═'.repeat(60)}`);
  console.log(`   TEST 2.${batchNum} : BATCH ${size} DOCUMENTS`);
  console.log(`${'═'.repeat(60)}`);
  
  const startTime = Date.now();
  const metrics = {
    batchNum,
    size,
    startTime: new Date().toISOString(),
    tasksGenerated: 0,
    embeddingsCreated: 0,
    pointsIndexed: 0,
    errors: [],
    latencies: [],
    embeddingTokens: 0,
    status: 'pending'
  };
  
  // Étape 1 : Génération des tâches
  console.log(`\n📋 Génération de ${size} tâches de test...`);
  const tasks = generateBatch(batchNum, size);
  metrics.tasksGenerated = tasks.length;
  testState.allGeneratedTasks.push(...tasks);
  console.log(`✅ ${tasks.length} tâches générées`);
  
  // Étape 2 : Création des embeddings par batches
  console.log(`\n🧠 Création des embeddings (batches de ${EMBEDDING_BATCH_SIZE})...`);
  const taskEmbeddings = [];
  
  for (let i = 0; i < tasks.length; i += EMBEDDING_BATCH_SIZE) {
    const batchTasks = tasks.slice(i, i + EMBEDDING_BATCH_SIZE);
    console.log(`   Processing batch ${Math.floor(i / EMBEDDING_BATCH_SIZE) + 1}/${Math.ceil(tasks.length / EMBEDDING_BATCH_SIZE)} (${batchTasks.length} tâches)...`);
    
    for (const task of batchTasks) {
      const embStart = Date.now();
      const result = await createEmbedding(task.description);
      const embDuration = Date.now() - embStart;
      
      if (result) {
        taskEmbeddings.push({ task, embedding: result.embedding });
        metrics.embeddingsCreated++;
        metrics.embeddingTokens += result.tokens;
        metrics.latencies.push(embDuration);
      } else {
        metrics.errors.push({
          step: 'embedding',
          taskId: task.id,
          error: 'Failed to create embedding'
        });
      }
      
      // Rate limiting
      await new Promise(resolve => setTimeout(resolve, RATE_LIMIT_DELAY_MS));
    }
    
    // Pause supplémentaire entre batches OpenAI
    if (i + EMBEDDING_BATCH_SIZE < tasks.length) {
      await new Promise(resolve => setTimeout(resolve, 500));
    }
  }
  
  console.log(`✅ ${metrics.embeddingsCreated}/${tasks.length} embeddings créés`);
  console.log(`   Tokens utilisés: ${metrics.embeddingTokens}`);
  
  // Étape 3 : Indexation dans Qdrant
  console.log(`\n📥 Indexation dans Qdrant...`);
  let progressCounter = 0;
  const progressInterval = Math.max(1, Math.floor(taskEmbeddings.length / 20)); // Afficher 20 updates max
  
  for (const { task, embedding } of taskEmbeddings) {
    const upsertStart = Date.now();
    const result = await upsertPoint(task, embedding);
    const upsertDuration = Date.now() - upsertStart;
    
    if (result.success) {
      metrics.pointsIndexed++;
      metrics.latencies.push(upsertDuration);
    } else {
      metrics.errors.push({
        step: 'upsert',
        taskId: task.id,
        error: result.error
      });
    }
    
    progressCounter++;
    if (progressCounter % progressInterval === 0) {
      const percent = Math.round((progressCounter / taskEmbeddings.length) * 100);
      console.log(`   Progress: ${percent}% (${progressCounter}/${taskEmbeddings.length})`);
    }
    
    // Rate limiting
    await new Promise(resolve => setTimeout(resolve, RATE_LIMIT_DELAY_MS));
  }
  
  const endTime = Date.now();
  const totalDuration = endTime - startTime;
  
  // Calcul des métriques finales
  metrics.endTime = new Date().toISOString();
  metrics.totalDuration = totalDuration;
  metrics.avgTimePerDoc = Math.round(totalDuration / size);
  metrics.throughput = (size / (totalDuration / 1000)).toFixed(2);
  metrics.successRate = ((metrics.pointsIndexed / size) * 100).toFixed(2);
  metrics.latencyStats = calculateStats(metrics.latencies);
  
  // Déterminer le statut
  const batchKey = `batch${size}`;
  const criteria = CRITERIA;
  const successRateOk = parseFloat(metrics.successRate) >= criteria.successRate[batchKey];
  const avgTimeOk = metrics.avgTimePerDoc <= criteria.avgTimePerDoc[batchKey];
  const p95Ok = metrics.latencyStats.p95 <= criteria.p95Latency[batchKey];
  const throughputOk = parseFloat(metrics.throughput) >= criteria.throughput[batchKey];
  
  metrics.status = successRateOk && avgTimeOk && p95Ok && throughputOk ? 'success' : 'failed';
  metrics.criteriaCheck = {
    successRate: { value: metrics.successRate, threshold: criteria.successRate[batchKey], pass: successRateOk },
    avgTimePerDoc: { value: metrics.avgTimePerDoc, threshold: criteria.avgTimePerDoc[batchKey], pass: avgTimeOk },
    p95Latency: { value: metrics.latencyStats.p95, threshold: criteria.p95Latency[batchKey], pass: p95Ok },
    throughput: { value: metrics.throughput, threshold: criteria.throughput[batchKey], pass: throughputOk }
  };
  
  console.log(`\n✅ Batch ${size} terminé en ${(totalDuration / 1000).toFixed(1)}s`);
  console.log(`   Documents indexés: ${metrics.pointsIndexed}/${size}`);
  console.log(`   Taux de succès: ${metrics.successRate}%`);
  console.log(`   Débit: ${metrics.throughput} docs/s`);
  console.log(`   Temps moyen: ${metrics.avgTimePerDoc}ms/doc`);
  console.log(`   Latence P95: ${metrics.latencyStats.p95}ms`);
  
  return metrics;
}

/**
 * Vérification Go/No-Go
 */
function checkGoNoGo(metrics, batchSize) {
  console.log(`\n${'═'.repeat(60)}`);
  console.log(`   VÉRIFICATION GO/NO-GO - BATCH ${batchSize}`);
  console.log(`${'═'.repeat(60)}`);
  
  const criteria = metrics.criteriaCheck;
  let allPass = true;
  
  console.log(`\n📊 Critères de validation:`);
  console.log(`   ✓ Taux de succès: ${criteria.successRate.value}% (seuil: ≥${criteria.successRate.threshold}%) ${criteria.successRate.pass ? '✅' : '❌'}`);
  console.log(`   ✓ Temps moyen/doc: ${criteria.avgTimePerDoc.value}ms (seuil: <${criteria.avgTimePerDoc.threshold}ms) ${criteria.avgTimePerDoc.pass ? '✅' : '❌'}`);
  console.log(`   ✓ Latence P95: ${criteria.p95Latency.value}ms (seuil: <${criteria.p95Latency.threshold}ms) ${criteria.p95Latency.pass ? '✅' : '❌'}`);
  console.log(`   ✓ Débit: ${criteria.throughput.value} docs/s (seuil: ≥${criteria.throughput.threshold} docs/s) ${criteria.throughput.pass ? '✅' : '❌'}`);
  
  allPass = criteria.successRate.pass && criteria.avgTimePerDoc.pass && 
            criteria.p95Latency.pass && criteria.throughput.pass;
  
  const decision = allPass ? 'GO' : 'NO-GO';
  const emoji = allPass ? '✅' : '❌';
  
  console.log(`\n${emoji} DÉCISION: ${decision} pour le batch suivant`);
  
  if (!allPass) {
    console.log(`\n⚠️ ARRÊT DES TESTS - Critères non atteints`);
    console.log(`   Documenter les résultats et analyser les échecs avant de continuer.`);
  }
  
  return allPass;
}

/**
 * Effectue quelques recherches sémantiques de validation
 */
async function validateSemanticSearch(sampleSize = 5) {
  console.log(`\n🔍 Validation recherche sémantique (${sampleSize} requêtes)...`);
  
  const queries = [
    "authentification utilisateur JWT",
    "optimisation performance base de données",
    "système de notifications temps réel",
    "gestion des erreurs API REST",
    "monitoring et logging applicatif"
  ];
  
  let successCount = 0;
  
  for (const query of queries.slice(0, sampleSize)) {
    try {
      const embResult = await createEmbedding(query);
      if (!embResult) continue;
      
      const response = await fetch(`${QDRANT_URL}/collections/${QDRANT_COLLECTION}/points/search`, {
        method: 'POST',
        headers: {
          'api-key': QDRANT_API_KEY,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          vector: embResult.embedding,
          limit: 3,
          with_payload: true
        })
      });
      
      if (response.ok) {
        const data = await response.json();
        const resultsFound = data.result?.length || 0;
        console.log(`   ✅ "${query}": ${resultsFound} résultats`);
        successCount++;
      }
      
      await new Promise(resolve => setTimeout(resolve, RATE_LIMIT_DELAY_MS));
    } catch (error) {
      console.log(`   ❌ "${query}": ${error.message}`);
    }
  }
  
  console.log(`\n   Résumé: ${successCount}/${sampleSize} recherches réussies`);
  return successCount === sampleSize;
}

/**
 * Génère le rapport final
 */
async function generateFinalReport() {
  const totalDuration = Date.now() - testState.startTime;
  const batches = Object.values(testState.phase2Results);
  
  const report = {
    timestamp: new Date().toISOString(),
    duration_ms: totalDuration,
    duration_formatted: `${Math.floor(totalDuration / 60000)}min ${Math.round((totalDuration % 60000) / 1000)}s`,
    batches_completed: batches.length,
    total_tasks_generated: testState.allGeneratedTasks.length,
    total_points_indexed: batches.reduce((sum, b) => sum + b.pointsIndexed, 0),
    global_success_rate: (batches.reduce((sum, b) => sum + parseFloat(b.successRate), 0) / batches.length).toFixed(2),
    verdict: batches.every(b => b.status === 'success') ? 'GO Phase 3' : 'NO-GO Phase 3',
    batches: batches,
    recommendations: []
  };
  
  // Générer recommandations
  if (parseFloat(report.global_success_rate) < 99) {
    report.recommendations.push("⚠️ Taux de succès global < 99% - Analyser les erreurs d'indexation");
  }
  
  const avgThroughput = batches.reduce((sum, b) => sum + parseFloat(b.throughput), 0) / batches.length;
  if (avgThroughput < 0.3) {
    report.recommendations.push("⚠️ Débit moyen < 0.3 docs/s - Optimiser le rate limiting ou paralléliser");
  }
  
  const hasHighLatency = batches.some(b => b.latencyStats.p95 > 1000);
  if (hasHighLatency) {
    report.recommendations.push("⚠️ Latence P95 élevée détectée - Vérifier performances Qdrant et réseau");
  }
  
  if (report.recommendations.length === 0) {
    report.recommendations.push("✅ Tous les critères sont satisfaisants - Prêt pour production");
  }
  
  return report;
}

/**
 * Sauvegarde le rapport
 */
async function saveReport(report) {
  const fs = require('fs');
  const path = require('path');
  
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-').substring(0, 16);
  const reportDir = path.join(__dirname, '../docs/testing/reports');
  const reportPath = path.join(reportDir, `phase2-charge-${timestamp}.md`);
  
  // Créer le répertoire si nécessaire
  if (!fs.existsSync(reportDir)) {
    fs.mkdirSync(reportDir, { recursive: true });
  }
  
  // Générer le contenu Markdown
  let markdown = `# Rapport Phase 2 : Tests de Charge Indexer-Qdrant\n\n`;
  markdown += `**Date** : ${report.timestamp}\n`;
  markdown += `**Durée** : ${report.duration_formatted}\n\n`;
  markdown += `## Résumé Exécutif\n\n`;
  markdown += `- **Tests réalisés** : ${report.batches_completed}/4 batches\n`;
  markdown += `- **Documents indexés** : ${report.total_points_indexed}/${report.total_tasks_generated} total\n`;
  markdown += `- **Taux de succès global** : ${report.global_success_rate}%\n`;
  markdown += `- **Décision** : **${report.verdict}**\n\n`;
  
  markdown += `## Résultats par Batch\n\n`;
  
  for (const batch of report.batches) {
    const icon = batch.status === 'success' ? '✅' : '❌';
    markdown += `### Test 2.${batch.batchNum} : Batch ${batch.size} ${icon}\n\n`;
    markdown += `- **Statut** : ${batch.status.toUpperCase()}\n`;
    markdown += `- **Documents** : ${batch.pointsIndexed}/${batch.size}\n`;
    markdown += `- **Temps total** : ${(batch.totalDuration / 1000).toFixed(1)}s\n`;
    markdown += `- **Temps moyen** : ${batch.avgTimePerDoc}ms/doc\n`;
    markdown += `- **Débit** : ${batch.throughput} docs/s\n`;
    markdown += `- **Latence P95** : ${batch.latencyStats.p95}ms\n`;
    markdown += `- **Taux de succès** : ${batch.successRate}%\n`;
    markdown += `- **Erreurs** : ${batch.errors.length}\n\n`;
    
    markdown += `**Critères de validation** :\n`;
    for (const [key, criterion] of Object.entries(batch.criteriaCheck)) {
      const icon = criterion.pass ? '✅' : '❌';
      markdown += `- ${icon} ${key}: ${criterion.value} (seuil: ${criterion.threshold})\n`;
    }
    markdown += `\n`;
  }
  
  markdown += `## Métriques Comparatives\n\n`;
  markdown += `| Batch | Taille | Durée (s) | Débit (docs/s) | Latence P95 (ms) | Succès (%) |\n`;
  markdown += `|-------|--------|-----------|----------------|------------------|------------|\n`;
  for (const batch of report.batches) {
    markdown += `| ${batch.batchNum} | ${batch.size} | ${(batch.totalDuration / 1000).toFixed(1)} | ${batch.throughput} | ${batch.latencyStats.p95} | ${batch.successRate} |\n`;
  }
  markdown += `\n`;
  
  markdown += `## Recommandations\n\n`;
  for (const rec of report.recommendations) {
    markdown += `${rec}\n\n`;
  }
  
  markdown += `## Détails Techniques\n\n`;
  markdown += `- **QDRANT_URL** : ${QDRANT_URL}\n`;
  markdown += `- **QDRANT_COLLECTION** : ${QDRANT_COLLECTION}\n`;
  markdown += `- **Rate Limiter** : ${RATE_LIMIT_DELAY_MS}ms entre requêtes\n`;
  markdown += `- **Embedding Model** : text-embedding-3-small (1536 dimensions)\n`;
  markdown += `- **Total Tokens OpenAI** : ${report.batches.reduce((sum, b) => sum + b.embeddingTokens, 0)}\n\n`;
  
  markdown += `---\n\n`;
  markdown += `*Rapport généré automatiquement par tests/indexer-phase2-load-tests.cjs*\n`;
  
  fs.writeFileSync(reportPath, markdown, 'utf-8');
  
  console.log(`\n📄 Rapport sauvegardé: ${reportPath}`);
  return reportPath;
}

/**
 * Exécution principale
 */
async function main() {
  console.log('═'.repeat(60));
  console.log('   TESTS PHASE 2 - Tests de Charge Progressifs');
  console.log('═'.repeat(60));
  console.log(`Timestamp: ${new Date().toISOString()}`);
  
  printConfiguration();
  
  // Validation environnement
  if (!OPENAI_API_KEY || !QDRANT_API_KEY) {
    console.error('\n❌ ERREUR: Variables d\'environnement manquantes');
    process.exit(1);
  }
  
  // Exécution des batches
  for (const size of BATCH_SIZES) {
    const metrics = await runBatch(BATCH_SIZES.indexOf(size) + 1, size);
    testState.phase2Results[`batch${size}`] = metrics;
    
    // Go/No-Go check
    const canContinue = checkGoNoGo(metrics, size);
    
    if (!canContinue) {
      console.log(`\n⛔ Arrêt des tests après batch ${size}`);
      break;
    }
    
    // Pause entre batches
    if (size < BATCH_SIZES[BATCH_SIZES.length - 1]) {
      console.log(`\n⏸️ Pause de 10s avant le batch suivant...`);
      await new Promise(resolve => setTimeout(resolve, 10000));
    }
  }
  
  // Validation recherche sémantique
  await validateSemanticSearch();
  
  // Génération rapport final
  console.log(`\n${'═'.repeat(60)}`);
  console.log('   GÉNÉRATION DU RAPPORT FINAL');
  console.log('═'.repeat(60));
  
  const report = await generateFinalReport();
  const reportPath = await saveReport(report);
  
  // Affichage résumé
  console.log(`\n${'═'.repeat(60)}`);
  console.log('   RÉSUMÉ FINAL PHASE 2');
  console.log(`${'═'.repeat(60)}\n`);
  console.log(`Batches complétés: ${report.batches_completed}`);
  console.log(`Documents indexés: ${report.total_points_indexed}/${report.total_tasks_generated}`);
  console.log(`Taux de succès global: ${report.global_success_rate}%`);
  console.log(`Durée totale: ${report.duration_formatted}`);
  console.log(`\n🎯 VERDICT: ${report.verdict}`);
  
  console.log(`\n✅ Tests Phase 2 terminés avec succès`);
}

// Exécution
main().catch(error => {
  console.error('\n💥 ERREUR FATALE:', error);
  process.exit(1);
});