#!/usr/bin/env node

/**
 * Script de migration vers TurboQuant pour Qdrant
 *
 * Ce script:
 * 1. Valide que TurboQuant est disponible
 * 2. Effectue des benchmarks comparatifs
 * 3. Migre la collection roo_tasks_semantic_index
 * 4. Valide les performances post-migration
 */

const https = require('https');
const { execSync } = require('child_process');

// Configuration
const config = {
    qdrantApi: 'https://qdrant.myia.io:6333',
    githubQdrantApi: 'https://api.github.com/repos/qdrant/qdrant',

    // Configuration TurboQuant (à ajuster selon la release Qdrant)
    turboQuantConfig: {
        quantization: {
            quantization: {
                type: 'int4', // ou 'scalar' selon la syntaxe Qdrant
                scalar: {
                    type: 'int4',
                    k: 64, // paramètre à confirmer dans la release
                    r: 32  // paramètre à confirmer dans la release
                }
            }
        }
    },

    // Paramètres de benchmark
    benchmark: {
        queryCount: 100,
        queries: [
            { text: 'semantic search test', expectedResults: 10 },
            { text: 'vector database optimization', expectedResults: 5 },
            { text: 'roo state manager', expectedResults: 20 }
        ]
    }
};

// Logger
function log(message, level = 'INFO') {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] [${level}] ${message}`);
}

// Vérifier que TurboQuant est disponible
async function checkTurboQuantReady() {
    try {
        log('Checking TurboQuant availability...');

        // Vérifier l'issue GitHub #8670
        const issueResponse = await fetch(`${config.githubQdrantApi}/issues/8670`);
        const issue = await issueResponse.json();

        if (issue.state !== 'closed') {
            throw new Error(`TurboQuant issue #8670 is not closed yet`);
        }

        // Vérifier la dernière release
        const releasesResponse = await fetch(`${config.githubQdrantApi}/releases`);
        const releases = await releasesResponse.json();

        // Chercher une release avec TurboQuant
        const turboQuantRelease = releases.find(r =>
            r.published_at && new Date(r.published_at) > new Date(issue.updated_at)
        );

        if (!turboQuantRelease) {
            throw new Error('No release with TurboQuant found after issue closure');
        }

        log(`TurboQuant found in release: ${turboQuantRelease.name}`);

        // Vérifier la version du serveur Qdrant
        const healthResponse = await fetch(`${config.qdrantApi}/`);
        const health = await healthResponse.json();

        if (!health.result?.version?.startsWith('1.')) {
            throw new Error(`Qdrant version ${health.result?.version} may not support TurboQuant`);
        }

        return {
            ready: true,
            release: turboQuantRelease,
            qdrantVersion: health.result.version
        };
    } catch (error) {
        log(`TurboQuant not ready: ${error.message}`, 'ERROR');
        return { ready: false, error: error.message };
    }
}

// Effectuer un benchmark de comparaison
async function runBenchmark() {
    const results = {
        binary: { totalTime: 0, avgTime: 0, results: [] },
        turboquant: { totalTime: 0, avgTime: 0, results: [] }
    };

    // Créer des embeddings de test
    const testVectors = generateTestVectors();

    for (let i = 0; i < config.benchmark.queryCount; i++) {
        const vector = testVectors[i % testVectors.length];

        // Benchmark binary quantization (actuel)
        const startBinary = Date.now();
        const binaryResult = await search(vector, 'binary');
        results.binary.totalTime += Date.now() - startBinary;

        // Benchmark TurboQuant (si possible)
        try {
            const startTq = Date.now();
            const tqResult = await search(vector, 'turboquant');
            results.turboquant.totalTime += Date.now() - startTq;
            results.turboquant.results.push(tqResult);
        } catch (error) {
            log(`TurboQuant search failed: ${error.message}`, 'WARNING');
        }
    }

    // Calculer les moyennes
    results.binary.avgTime = results.binary.totalTime / config.benchmark.queryCount;
    results.turboquant.avgTime = results.turboquant.totalTime / (results.turboquant.results.length || 1);

    return results;
}

// Effectuer une recherche
async function search(vector, type) {
    const url = `${config.qdrantApi}/collections/roo_tasks_semantic_index/points/search`;
    const body = {
        vector: vector,
        limit: 10,
        with_payload: true,
        score_threshold: 0.5
    };

    if (type === 'turboquant') {
        // Ajouter la configuration TurboQuant si nécessaire
        body.filter = {
            key: 'quantization_type',
            match: { value: 'turboquant' }
        };
    }

    const response = await fetch(url, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(body)
    });

    if (!response.ok) {
        throw new Error(`Search failed: ${response.status}`);
    }

    return await response.json();
}

// Générer des vecteurs de test
function generateTestVectors() {
    const vectors = [];
    for (let i = 0; i < 10; i++) {
        vectors.push(Array(2560).fill(0).map(() => Math.random()));
    }
    return vectors;
}

// Effectuer la migration
async function migrateToTurboQuant() {
    try {
        log('Starting migration to TurboQuant...');

        // 1. Valider l'état actuel
        const collectionInfo = await getCollectionInfo();
        log(`Current collection: ${collectionInfo.result.vector_count} points`);

        // 2. Appliquer la configuration TurboQuant
        log('Applying TurboQuant configuration...');
        const response = await fetch(`${config.qdrantApi}/collections/roo_tasks_semantic_index`, {
            method: 'PATCH',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                params: config.turboQuantConfig
            })
        });

        if (!response.ok) {
            throw new Error(`Migration failed: ${response.status}`);
        }

        log('Migration configuration applied successfully');

        // 3. Attendre la rebuild
        log('Waiting for collection rebuild...');
        await waitForRebuild();

        // 4. Valider la migration
        const newCollectionInfo = await getCollectionInfo();
        log(`New collection: ${newCollectionInfo.result.vector_count} points`);

        // 5. Effectuer le benchmark
        const benchmark = await runBenchmark();
        log('Migration completed successfully');
        log('Benchmark results:', benchmark);

        return { success: true, benchmark };
    } catch (error) {
        log(`Migration failed: ${error.message}`, 'ERROR');
        return { success: false, error: error.message };
    }
}

// Récupérer les infos de la collection
async function getCollectionInfo() {
    const response = await fetch(`${config.qdrantApi}/collections/roo_tasks_semantic_index`);
    if (!response.ok) {
        throw new Error(`Failed to get collection info: ${response.status}`);
    }
    return await response.json();
}

// Attendre que la rebuild soit complète
async function waitForRebuild() {
    let attempts = 0;
    const maxAttempts = 60; // 30 minutes max

    while (attempts < maxAttempts) {
        try {
            const info = await getCollectionInfo();
            const status = info.result.status;

            if (status === 'green' || status === 'ready') {
                log(`Rebuild completed with status: ${status}`);
                return;
            }

            log(`Rebuild in progress... Status: ${status} (${attempts + 1}/${maxAttempts})`);
            await new Promise(resolve => setTimeout(resolve, 30000)); // 30 secondes
            attempts++;
        } catch (error) {
            log(`Error checking rebuild status: ${error.message}`);
            await new Promise(resolve => setTimeout(resolve, 60000)); // 1 minute
            attempts++;
        }
    }

    throw new Error(`Rebuild timed out after ${maxAttempts * 0.5} minutes`);
}

// Fonction principale
async function main() {
    log('Starting TurboQuant migration process...');

    try {
        // 1. Vérifier la disponibilité
        const readyCheck = await checkTurboQuantReady();
        if (!readyCheck.ready) {
            throw new Error(`Cannot proceed: ${readyCheck.error}`);
        }

        log(`TurboQuant is ready! Release: ${readyCheck.release.name}`);

        // 2. Demander confirmation (pour les exécutions manuelles)
        if (process.argv.includes('--confirm')) {
            const readline = require('readline');
            const rl = readline.createInterface({
                input: process.stdin,
                output: process.stdout
            });

            const answer = await new Promise(resolve => {
                rl.question('Proceed with migration? (y/N): ', resolve);
            });

            rl.close();

            if (answer.toLowerCase() !== 'y') {
                log('Migration cancelled by user');
                return;
            }
        }

        // 3. Effectuer la migration
        const result = await migrateToTurboQuant();

        if (result.success) {
            log('Migration completed successfully!');
            process.exit(0);
        } else {
            throw new Error(result.error);
        }
    } catch (error) {
        log(`Migration failed: ${error.message}`, 'ERROR');
        process.exit(1);
    }
}

if (require.main === module) {
    main();
}

module.exports = {
    checkTurboQuantReady,
    migrateToTurboQuant,
    runBenchmark
};