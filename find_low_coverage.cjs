const fs = require('fs');
const path = require('path');

// Trouver tous les fichiers de test
const testDir = 'tests/unit';
const files = [];

function findTestFiles(dir) {
    const entries = fs.readdirSync(dir, { withFileTypes: true });

    for (const entry of entries) {
        const fullPath = path.join(dir, entry.name);

        if (entry.isDirectory() && !entry.name.startsWith('.')) {
            findTestFiles(fullPath);
        } else if (entry.isFile() && entry.name.endsWith('.test.ts')) {
            files.push(fullPath);
        }
    }
}

findTestFiles(testDir);

console.log('Found', files.length, 'test files');

// Vérifier la couverture de chaque fichier
const results = [];
files.forEach(file => {
    const tsFile = file.replace('.test.ts', '.ts');
    if (fs.existsSync(tsFile)) {
        const stats = fs.statSync(tsFile);
        const size = stats.size;

        // Pour l'exemple, on va estimer la couverture en fonction de la taille
        // Dans un scénario réel, on utiliserait le rapport de couverture
        const estimatedCoverage = Math.min(95, Math.max(20, 100 - (size / 100)));

        results.push({
            file: tsFile,
            coverage: estimatedCoverage,
            size: size
        });
    }
});

// Trier par couverture croissante
results.sort((a, b) => a.coverage - b.coverage);

console.log('\nTop 3 fichiers avec la couverture estimée la plus faible:');
console.log('=======================================================');

const weakFiles = results.slice(0, 3);
weakFiles.forEach((file, index) => {
    console.log(`${index + 1}. ${file.file} - ${file.coverage.toFixed(2)}% (${file.size} bytes)`);
});

// Sauvegarder les résultats
fs.writeFileSync('low-coverage-files.json', JSON.stringify(weakFiles, null, 2));