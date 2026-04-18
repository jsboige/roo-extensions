#!/usr/bin/env node

/**
 * Script de surveillance pour TurboQuant (Qdrant #8670)
 *
 * Ce script surveille:
 * 1. La disponibilité de TurboQuant dans les releases Qdrant
 * 2. L'état de la collection roo_tasks_semantic_index
 * 3. Les performances des recherches sémantiques
 */

const https = require('https');
const { execSync } = require('child_process');

// Configuration
const config = {
    // URLs de surveillance
    qdrantApi: 'https://qdrant.myia.io:6333',
    githubQdrantApi: 'https://api.github.com/repos/qdrant/qdrant',

    // Intervalle de surveillance (ms)
    checkInterval: 60000, // 1 minute

    // Seuils d'alerte
    maxSearchTimeMs: 500,
    minRecallScore: 0.95,

    // Compteurs de performance
    metrics: {
        searchCount: 0,
        totalSearchTime: 0,
        errors: 0,
        lastCheck: null
    }
};

// Logger simple
function log(message, level = 'INFO') {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] [${level}] ${message}`);
}

// Vérifier l'état de la collection Qdrant
async function checkCollectionStatus() {
    try {
        // Vérifier si Qdrant est accessible
        const healthCheck = await fetch(`${config.qdrantApi}/`);
        if (!healthCheck.ok) {
            throw new Error(`Qdrant not accessible: ${healthCheck.status}`);
        }

        // Récupérer les stats de la collection
        const response = await fetch(`${config.qdrantApi}/collections/roo_tasks_semantic_index/stats`);
        if (!response.ok) {
            throw new Error(`Failed to get collection stats: ${response.status}`);
        }

        const stats = await response.json();
        return stats;
    } catch (error) {
        log(`Qdrant collection check failed: ${error.message}`, 'ERROR');
        return null;
    }
}

// Vérifier la disponibilité de TurboQuant
async function checkTurboQuantAvailability() {
    try {
        // Vérifier l'issue #8670
        const issueResponse = await fetch(`${config.githubQdrantApi}/issues/8670`);
        if (!issueResponse.ok) {
            throw new Error(`GitHub API error: ${issueResponse.status}`);
        }

        const issue = await issueResponse.json();

        // Vérifier si TurboQuant est disponible dans une release
        const releasesResponse = await fetch(`${config.githubQdrantApi}/releases`);
        if (!releasesResponse.ok) {
            throw new Error(`GitHub releases error: ${releasesResponse.status}`);
        }

        const releases = await releasesResponse.json();
        const turboQuantRelease = releases.find(r =>
            r.name.toLowerCase().includes('turboquant') ||
            r.body?.toLowerCase().includes('turboquant')
        );

        return {
            issue: {
                state: issue.state,
                title: issue.title,
                body: issue.body,
                comments: issue.comments,
                updated_at: issue.updated_at
            },
            release: turboQuantRelease ? {
                name: turboQuantRelease.name,
                tag: turboQuantRelease.tag_name,
                created_at: turboQuantRelease.created_at,
                published_at: turboQuantRelease.published_at
            } : null,
            available: !!turboQuantRelease && issue.state === 'closed'
        };
    } catch (error) {
        log(`TurboQuant availability check failed: ${error.message}`, 'ERROR');
        return null;
    }
}

// Effectuer une recherche de test
async function testSemanticSearch() {
    try {
        const startTime = Date.now();

        const response = await fetch(`${config.qdrantApi}/collections/roo_tasks_semantic_index/points/search`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                vector: [0.1, 0.2, 0.3, 0.4, 0.5], // Exemple vector
                limit: 10,
                with_payload: true,
                score_threshold: 0.5
            })
        });

        const endTime = Date.now();
        const searchTime = endTime - startTime;

        if (!response.ok) {
            throw new Error(`Search failed: ${response.status}`);
        }

        const result = await response.json();

        // Mettre à jour les métriques
        config.metrics.searchCount++;
        config.metrics.totalSearchTime += searchTime;

        log(`Search completed in ${searchTime}ms (${result.result.length} results)`);

        return {
            success: true,
            searchTime,
            resultsCount: result.result.length,
            avgSearchTime: config.metrics.totalSearchTime / config.metrics.searchCount
        };
    } catch (error) {
        config.metrics.errors++;
        log(`Test search failed: ${error.message}`, 'ERROR');
        return { success: false, error: error.message };
    }
}

// Générer un rapport
function generateReport(collectionStatus, turboQuantInfo, testSearch) {
    const report = {
        timestamp: new Date().toISOString(),
        collection: collectionStatus,
        turboQuant: turboQuantInfo,
        search: testSearch,
        metrics: { ...config.metrics },
        recommendations: []
    };

    // Générer des recommandations
    if (collectionStatus?.config?.params?.quantization?.quantization?.type === 'Binary') {
        report.recommendations.push({
            type: 'INFO',
            message: 'Collection using binary quantization (current)'
        });
    }

    if (turboQuantInfo?.available) {
        report.recommendations.push({
            type: 'URGENT',
            message: 'TurboQuant is available in Qdrant release! Consider migration.'
        });
    }

    if (testSearch.success && testSearch.searchTime > config.maxSearchTimeMs) {
        report.recommendations.push({
            type: 'WARNING',
            message: `Search time ${testSearch.searchTime}ms exceeds threshold ${config.maxSearchTimeMs}ms`
        });
    }

    return report;
}

// Exporter le rapport
function exportReport(report) {
    const reportFile = `./reports/turboquant-monitor-${Date.now()}.json`;

    // Créer le répertoire reports si nécessaire
    const fs = require('fs');
    const path = require('path');
    const reportsDir = path.dirname(reportFile);
    if (!fs.existsSync(reportsDir)) {
        fs.mkdirSync(reportsDir, { recursive: true });
    }

    fs.writeFileSync(reportFile, JSON.stringify(report, null, 2));
    log(`Report saved to ${reportFile}`);

    return reportFile;
}

// Fonction principale de surveillance
async function monitorTurboQuant() {
    log('Starting TurboQuant monitoring...');

    try {
        // Vérifier l'état de la collection
        const collectionStatus = await checkCollectionStatus();
        log(`Collection status: ${collectionStatus ? 'OK' : 'Not available'}`);

        // Vérifier la disponibilité de TurboQuant
        const turboQuantInfo = await checkTurboQuantAvailability();
        log(`TurboQuant available: ${turboQuantInfo?.available || false}`);

        // Effectuer un test de recherche
        const testSearch = await testSemanticSearch();

        // Générer et exporter le rapport
        const report = generateReport(collectionStatus, turboQuantInfo, testSearch);
        const reportFile = exportReport(report);

        // Afficher un résumé
        console.log('\n=== TURBOQUANT MONITORING REPORT ===');
        console.log(`Timestamp: ${report.timestamp}`);
        console.log(`Collection points: ${collectionStatus?.result?.vector_count || 'Unknown'}`);
        console.log(`TurboQuant available: ${turboQuantInfo?.available || false}`);
        console.log(`Avg search time: ${testSearch.avgSearchTime?.toFixed(2) || 'N/A'}ms`);
        console.log(`Report: ${reportFile}\n`);

        return report;
    } catch (error) {
        log(`Monitoring failed: ${error.message}`, 'ERROR');
        return null;
    }
}

// Exécuter la surveillance
if (require.main === module) {
    monitorTurboQuant().then(() => {
        process.exit(0);
    }).catch(error => {
        log(`Fatal error: ${error.message}`, 'CRITICAL');
        process.exit(1);
    });
}

module.exports = { monitorTurboQuant, checkCollectionStatus, checkTurboQuantAvailability };