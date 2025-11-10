/**
 * Runner Node.js pour le diff granulaire
 * Appelé par le script PowerShell roosync_granular_diff.ps1
 */

const path = require('path');
const { GranularDiffDetector } = require('../../mcps/internal/servers/roo-state-manager/src/services/GranularDiffDetector.js');

/**
 * Fonction principale pour exécuter le diff granulaire
 */
async function runGranularDiff() {
    try {
        console.log('Début du diff granulaire...');
        
        // Récupérer les arguments depuis les variables d'environnement
        const sourceData = JSON.parse(process.env.SOURCE_DATA);
        const targetData = JSON.parse(process.env.TARGET_DATA);
        const sourceLabel = process.env.SOURCE_LABEL || 'source';
        const targetLabel = process.env.TARGET_LABEL || 'target';
        const options = JSON.parse(process.env.DIFF_OPTIONS || '{}');
        
        console.log('Source:', sourceLabel);
        console.log('Cible:', targetLabel);
        console.log('Options:', JSON.stringify(options, null, 2));
        
        // Créer le détecteur
        const detector = new GranularDiffDetector();
        
        // Effectuer la comparaison granulaire
        const report = await detector.compareGranular(
            sourceData,
            targetData,
            sourceLabel,
            targetLabel,
            options
        );
        
        // Afficher les résultats
        console.log('Diff granulaire terminé avec succès');
        console.log('ID du rapport:', report.reportId);
        console.log('Total différences:', report.summary.total);
        console.log('Temps d\'exécution:', report.performance.executionTime + 'ms');
        console.log('Nœuds comparés:', report.performance.nodesCompared);
        
        // Afficher le résumé par sévérité
        console.log('\nRésumé par sévérité:');
        Object.entries(report.summary.bySeverity).forEach(([severity, count]) => {
            if (count > 0) {
                console.log(`  ${severity}: ${count}`);
            }
        });
        
        // Afficher le résumé par type
        console.log('\nRésumé par type:');
        Object.entries(report.summary.byType).forEach(([type, count]) => {
            if (count > 0) {
                console.log(`  ${type}: ${count}`);
            }
        });
        
        // Afficher les premières différences
        if (report.diffs.length > 0) {
            console.log('\nPremières différences:');
            report.diffs.slice(0, 5).forEach((diff, index) => {
                console.log(`  ${index + 1}. [${diff.severity}] ${diff.path}: ${diff.description}`);
                if (diff.oldValue !== undefined) {
                    console.log(`     Ancien: ${JSON.stringify(diff.oldValue)}`);
                }
                if (diff.newValue !== undefined) {
                    console.log(`     Nouveau: ${JSON.stringify(diff.newValue)}`);
                }
            });
            
            if (report.diffs.length > 5) {
                console.log(`  ... et ${report.diffs.length - 5} autres différences`);
            }
        }
        
        // Retourner le rapport complet
        console.log('\n=== RAPPORT COMPLET ===');
        console.log(JSON.stringify(report, null, 2));
        
    } catch (error) {
        console.error('Erreur lors du diff granulaire:', error.message);
        console.error('Stack trace:', error.stack);
        process.exit(1);
    }
}

// Exécuter la fonction principale
runGranularDiff();