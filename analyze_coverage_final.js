const fs = require('fs');
const path = require('path');

// Dictionnaire pour agréger la couverture par fichier
const fileCoverage = {};

// Lire tous les fichiers de couverture
const coverageDir = 'mcps/internal/servers/roo-state-manager/coverage/.tmp';
const files = fs.readdirSync(coverageDir).filter(f => f.startsWith('coverage-') && f.endsWith('.json'));

console.log('Analyse détaillée de la couverture:');
console.log('===================================');

files.forEach(file => {
    const filePath = path.join(coverageDir, file);
    const data = fs.readFileSync(filePath, 'utf8');
    const report = JSON.parse(data);

    if (report.result) {
        report.result.forEach(script => {
            if (script.url) {
                const fileName = path.basename(script.url);

                if (!fileCoverage[fileName]) {
                    fileCoverage[fileName] = {
                        fileName: fileName,
                        totalStatements: 0,
                        coveredStatements: 0,
                        runs: 0,
                        coverages: []
                    };
                }

                let totalStatements = 0;
                let coveredStatements = 0;

                if (script.functions) {
                    script.functions.forEach(func => {
                        if (func.ranges && func.ranges.length > 0) {
                            func.ranges.forEach(range => {
                                totalStatements++;
                                if (range.count > 0) {
                                    coveredStatements++;
                                }
                            });
                        }
                    });
                }

                const coverage = totalStatements > 0 ? (coveredStatements / totalStatements) * 100 : 0;
                fileCoverage[fileName].totalStatements += totalStatements;
                fileCoverage[fileName].coveredStatements += coveredStatements;
                fileCoverage[fileName].runs++;
                fileCoverage[fileName].coverages.push(coverage);
            }
        });
    }
});

// Calculer la couverture moyenne finale
const results = Object.values(fileCoverage);
results.forEach(file => {
    if (file.totalStatements > 0) {
        file.averageCoverage = file.coveredStatements / file.totalStatements * 100;
    } else {
        file.averageCoverage = 0;
    }
});

// Trier par couverture décroissante
results.sort((a, b) => b.averageCoverage - a.averageCoverage);

console.log('\nFichiers couverts (en ordre décroissant):');
console.log('=========================================');

results.slice(0, 20).forEach((file, index) => {
    console.log(`${index + 1}. ${file.fileName} - ${file.averageCoverage.toFixed(2)}%
     (${file.coveredStatements}/${file.totalStatements}) [${file.runs} runs]`);
});

// Trouver et afficher le IdentityManager
const identityManager = results.find(r => r.fileName.includes('IdentityManager.ts'));
console.log('\n--- IdentityManager.ts ---');
if (identityManager) {
    console.log(`Couverture finale: ${identityManager.averageCoverage.toFixed(2)}%`);
    console.log(`Lignes couvertes: ${identityManager.coveredStatements}/${identityManager.totalStatements}`);
    console.log(`Nombre de runs: ${identityManager.runs}`);
    console.log(`Couvertures individuelles: ${identityManager.coverages.map(c => c.toFixed(2)).join(', ')}%`);
} else {
    console.log('IdentityManager.ts non trouvé');
}

// Afficher les 3 fichiers avec la couverture la plus faible
const weakFiles = results.slice(0, 3);
console.log('\nTop 3 fichiers avec la couverture la plus faible:');
console.log('===============================================');

weakFiles.forEach((file, index) => {
    console.log(`${index + 1}. ${file.fileName} - ${file.averageCoverage.toFixed(2)}% (${file.coveredStatements}/${file.totalStatements})`);
});

// Sauvegarder le résumé
const summary = {
    generated: new Date().toISOString(),
    totalFiles: results.length,
    averageCoverage: results.reduce((sum, r) => sum + r.averageCoverage, 0) / results.length,
    identityManager: identityManager ? {
        coverage: identityManager.averageCoverage,
        covered: identityManager.coveredStatements,
        total: identityManager.totalStatements,
        runs: identityManager.runs
    } : null,
    weakestFiles: weakFiles.map(f => ({
        file: f.fileName,
        coverage: f.averageCoverage,
        covered: f.coveredStatements,
        total: f.totalStatements
    }))
};

fs.writeFileSync('coverage-summary-final.json', JSON.stringify(summary, null, 2));
console.log('\nRésumé final sauvegardé dans coverage-summary-final.json');